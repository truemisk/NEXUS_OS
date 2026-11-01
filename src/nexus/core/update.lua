-- NEXUS update transactions: bounded Pastebin downloads, validate, backup and rollback.
-- Never execute downloaded code during staging. Only trusted user-supplied IDs.
local M={}
M.CORE='/home/osv4.lua'
M.BACKUP='/home/nexus/updates/previous.lua'
M.TEMP='/home/nexus/updates/download.part'
M.STAGED='/home/nexus/updates/staged.lua'
M.META='/home/nexus/updates/staged.meta'
M.TXN='/home/nexus/updates/transaction'
M.VERSION='0.6.2'
M.MAX_BYTES=300000
local function fsDefault() return require('filesystem') end
local function read(path,max)
  local f=io.open(path,'rb');if not f then return nil end
  local x=f:read(max or 1024);f:close();return x
end
local function write(path,s)
  local f,why=io.open(path,'wb');if not f then return false,why end
  local ok,err=pcall(function() assert(f:write(s));assert(f:flush()) end)
  f:close();return ok,err
end
local function parseVersion(head)
  if type(head)~='string' or not head:find('NEXUS%-DISTRIBUTION: 1') then return nil end
  local ver=head:match('NEXUS%-VERSION: (%d+%.%d+%.%d+)')
  return ver
end
local function numbers(ver)
  local a,b,c
  if ver then a,b,c=ver:match('^(%d+)%.(%d+)%.(%d+)$') end
  if not a then return nil end
  return {tonumber(a),tonumber(b),tonumber(c)}
end
function M.new(opts)
  opts=opts or {}
  return setmetatable({fs=opts.fs or fsDefault(),fetch=opts.fetch,read=opts.read or read,
    write=opts.write or write,open=opts.open or io.open,compile=opts.compile or loadfile,
    current=opts.current or M.CORE,version=opts.version or M.VERSION,
    limit=opts.limit or M.MAX_BYTES,
    -- Prefer OpenOS's proven pastebin client when no test fetch is injected.
    shellExecute=opts.shellExecute or (opts.fetch==nil and os and os.execute)},{__index=M})
end
function M:ensure()
  for _,p in ipairs({'/home/nexus','/home/nexus/updates'}) do
    if not self.fs.exists(p) then
      local ok,err=self.fs.makeDirectory(p)
      if not ok then return false,err or ('Cannot create '..p) end
    end
  end
  return true
end
function M:validate(path,allowSame)
  local head=self.read(path,512)
  local ver=parseVersion(head)
  if not ver then return nil,'Not a NEXUS Phase 5A+ release (missing release header)' end
  local a,b=numbers(ver),numbers(self.version)
  if not a or not b then return nil,'Bad version number' end
  for i=1,3 do
    if a[i]>b[i] then break end
    if a[i]<b[i] then return nil,'Downgrade blocked; use rollback' end
    if i==3 and not allowSame then return nil,'Same version; no update needed' end
  end
  local size=self.fs.size(path)
  if type(size)=='number' and (size<100 or size>self.limit) then return nil,'Invalid release file size' end
  local chunk,why=self.compile(path,'t')
  if not chunk then return nil,'Lua syntax invalid: '..tostring(why):sub(1,120) end
  return ver
end
function M:stagedVersion()
  if not self.fs.exists(M.STAGED) then return nil end
  local ver=self:validate(M.STAGED)
  if ver then return ver end
  return nil
end
-- A trial update is considered ready only after the new desktop has rendered.
-- Do not silently accept a different or corrupted active release.
function M:acknowledgeRunning()
  if not self.fs.exists(M.TXN) then return false,'No trial transaction' end
  local marker=self.read(M.TXN,128)
  local target=type(marker)=='string' and marker:match('^trial=(%d+%.%d+%.%d+)')
  if target~=self.version then return false,'Trial version does not match running OS' end
  local ver,why=self:validate(self.current,true)
  if ver~=self.version then return false,'Active release could not be verified: '..tostring(why or ver) end
  local ok,err=self:finish()
  if not ok then return false,'Cannot finalize trial: '..tostring(err) end
  return true
end
-- Run the same OpenOS Pastebin command that works from the user's terminal.
-- The ID has already been validated as strictly alphanumeric. The returned
-- file must still pass all NEXUS header, size, version and syntax checks.
function M:fetchShell(id)
  if type(self.shellExecute)~='function' then return false,'OpenOS shell unavailable' end
  pcall(self.fs.remove,M.TEMP)
  local cmd='pastebin get '..id..' '..M.TEMP
  local launched,a,b=pcall(self.shellExecute,cmd)
  if not launched then return false,'Pastebin command crashed: '..tostring(a):sub(1,100) end
  if not self.fs.exists(M.TEMP) then
    return false,'OpenOS pastebin did not save a file: '..tostring(b or a):sub(1,85)
  end
  local bytes=self.fs.size(M.TEMP)
  if type(bytes)~='number' or bytes<100 or bytes>self.limit then
    pcall(self.fs.remove,M.TEMP)
    return false,'Pastebin file size invalid: '..tostring(bytes)
  end
  return true,bytes
end
-- Streaming fallback for systems without the OpenOS pastebin command.
-- Keep iterator handling compatible with function and callable-table results.
function M:fetchInternet(id)
  local request=self.fetch
  if not request then
    local found,internet=pcall(require,'internet')
    if not found or type(internet.request)~='function' then return false,'Internet Card / API unavailable' end
    request=internet.request
  end
  local started,iter,reason=pcall(request,'https://pastebin.com/raw/'..id)
  if not started then return false,'Internet request: '..tostring(iter):sub(1,95) end
  local kind=type(iter)
  local mt=kind=='table' and getmetatable(iter) or nil
  local callable=kind=='function' or (kind=='table' and type(mt)=='table' and type(mt.__call)=='function')
  if not callable then
    if kind=='table' then return false,'Internet API returned a non-callable table' end
    return false,'HTTP iterator unavailable: '..(type(reason)=='string' and reason:sub(1,85) or kind)
  end
  pcall(self.fs.remove,M.TEMP)
  local f,err=self.open(M.TEMP,'wb')
  if not f then return false,'Staging file: '..tostring(err) end
  local bytes=0
  local transferred,problem=pcall(function()
    for block in iter do
      if type(block)~='string' then error('Invalid HTTP chunk') end
      bytes=bytes+#block
      if bytes>self.limit then error('Update too large') end
      assert(f:write(block))
    end
    assert(f:flush())
  end)
  pcall(function() f:close() end)
  if not transferred or bytes<100 then
    pcall(self.fs.remove,M.TEMP)
    return false,transferred and 'Empty/short HTTP response' or tostring(problem):sub(1,95)
  end
  return true,bytes
end
function M:stage(id)
  if type(id)~='string' or not id:match('^[%w]+$') or #id<6 or #id>16 then
    return false,'Pastebin ID must be 6-16 letters/digits'
  end
  local ok,why=self:ensure();if not ok then return false,why end
  if self.fs.exists(M.TXN) then
    local accepted,reason=self:acknowledgeRunning()
    if not accepted then return false,'Pending update transaction: '..tostring(reason) end
  end
  local success,bytesOrError,otherError
  if type(self.shellExecute)=='function' then
    success,bytesOrError=self:fetchShell(id)
    if not success then otherError='OpenOS pastebin: '..tostring(bytesOrError) end
  end
  if not success then
    success,bytesOrError=self:fetchInternet(id)
    if not success then
      return false,(otherError and (otherError..' / ') or '')..tostring(bytesOrError)
    end
  end
  local bytes=bytesOrError
  local ver,whyValid=self:validate(M.TEMP)
  if not ver then pcall(self.fs.remove,M.TEMP);return false,whyValid end
  if self.fs.exists(M.STAGED) then
    local removed,errRemove=self.fs.remove(M.STAGED)
    if not removed then self.fs.remove(M.TEMP);return false,errRemove end
  end
  local moved,whyMove=self.fs.rename(M.TEMP,M.STAGED)
  if not moved then self.fs.remove(M.TEMP);return false,whyMove end
  -- Metadata is advisory; never run or evaluate it.
  local wrote,whyWrite=self.write(M.META,'id='..id..'\nversion='..ver..'\nbytes='..bytes..'\n')
  if not wrote then self.fs.remove(M.STAGED);return false,whyWrite end
  return true,ver,bytes
end
function M:commit()
  if not self.fs.exists(M.STAGED) then return false,'No staged update' end
  local ver,why=self:validate(M.STAGED)
  if not ver then return false,why end
  if not self.fs.exists(self.current) then return false,'Active OS missing: '..self.current end
  if self.fs.exists(M.TXN) then return false,'Unresolved update transaction' end
  local ok,err=self:ensure();if not ok then return false,err end
  if self.fs.exists(M.BACKUP) then
    local removed,whyRemove=self.fs.remove(M.BACKUP)
    if not removed then return false,whyRemove end
  end
  local moved,whyMove=self.fs.rename(self.current,M.BACKUP)
  if not moved then return false,'Cannot back up OS: '..tostring(whyMove) end
  local mark,whyMark=self.write(M.TXN,'trial='..ver..'\n')
  if not mark then self.fs.rename(M.BACKUP,self.current);return false,whyMark end
  local installed,whyInstalled=self.fs.rename(M.STAGED,self.current)
  if not installed then
    self.fs.rename(M.BACKUP,self.current)
    self.fs.remove(M.TXN)
    return false,'Cannot install candidate: '..tostring(whyInstalled)
  end
  pcall(self.fs.remove,M.META)
  return true,ver
end
function M:rollback()
  if not self.fs.exists(M.BACKUP) then return false,'No previous OS backup' end
  -- Keep the bad new release for diagnosis (only one copy).
  local failed='/home/nexus/updates/failed.lua'
  if self.fs.exists(failed) then self.fs.remove(failed) end
  if self.fs.exists(self.current) then
    local ok,err=self.fs.rename(self.current,failed)
    if not ok then return false,'Cannot move failed release: '..tostring(err) end
  end
  local ok,err=self.fs.rename(M.BACKUP,self.current)
  if not ok then
    if self.fs.exists(failed) and not self.fs.exists(self.current) then self.fs.rename(failed,self.current) end
    return false,'Rollback failed: '..tostring(err)
  end
  if self.fs.exists(M.TXN) then self.fs.remove(M.TXN) end
  return true
end
function M:finish()
  if self.fs.exists(M.TXN) then return self.fs.remove(M.TXN) end
  return true
end
function M:recoverInterrupted()
  if not self.fs.exists(M.TXN) then return false end
  return self:rollback()
end
return M
