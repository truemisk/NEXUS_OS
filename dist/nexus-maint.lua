-- NEXUS MAINTENANCE v0.5.0 | safe CLI fallback
package.preload["nexus.core.update"] = function(...)
-- NEXUS update transactions: bounded Pastebin downloads, validate, backup and rollback.
-- Never execute downloaded code during staging. Only trusted user-supplied IDs.
local M={}
M.CORE='/home/osv4.lua'
M.BACKUP='/home/nexus/updates/previous.lua'
M.TEMP='/home/nexus/updates/download.part'
M.STAGED='/home/nexus/updates/staged.lua'
M.META='/home/nexus/updates/staged.meta'
M.TXN='/home/nexus/updates/transaction'
M.VERSION='0.5.0'
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
    limit=opts.limit or M.MAX_BYTES},{__index=M})
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
function M:stage(id)
  if type(id)~='string' or not id:match('^[%w]+$') or #id<6 or #id>16 then
    return false,'Pastebin ID must be 6-16 letters/digits'
  end
  local ok,why=self:ensure();if not ok then return false,why end
  if self.fs.exists(M.TXN) then return false,'Unresolved update transaction; recover first' end
  local request=self.fetch
  if not request then
    local found,internet=pcall(require,'internet')
    if not found or type(internet.request)~='function' then return false,'Internet Card / OpenOS internet API unavailable' end
    request=internet.request
  end
  local url='https://pastebin.com/raw/'..id
  local started,iter,reason=pcall(request,url)
  if not started then return false,'Network error: '..tostring(iter):sub(1,120) end
  if type(iter)~='function' then return false,'Download unavailable: '..tostring(reason or iter) end
  local f,err=self.open(M.TEMP,'wb');if not f then return false,'Cannot create staging file: '..tostring(err) end
  local bytes=0
  local transferred,problem=pcall(function()
    for block in iter do
      if type(block)~='string' then error('Invalid network response') end
      bytes=bytes+#block
      if bytes>self.limit then error('Update exceeds '..self.limit..' bytes') end
      assert(f:write(block))
    end
    assert(f:flush())
  end)
  pcall(function() f:close() end)
  if not transferred or bytes<100 then
    pcall(self.fs.remove,M.TEMP)
    return false,transferred and 'Empty/short download' or tostring(problem):sub(1,120)
  end
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

end
package.preload["nexus.core.startup"] = function(...)
-- Manage OpenOS interactive shell startup; user confirmation required for enable.
local M={}
M.CORE='/home/osv4.lua'
M.BOOT='/home/nexus-boot.lua'
M.SHRC='/home/.shrc'
M.GUARD='/home/nexus/startup.guard'
local BEGIN='# NEXUS-STARTUP BEGIN'
local END='# NEXUS-STARTUP END'
local BOOT_SOURCE=[=[
-- NEXUS-BOOT API 1 owned by NEXUS OS. Do not edit OpenOS /boot.
local fs=require('filesystem')
local core='/home/osv4.lua'
local guard='/home/nexus/startup.guard'
local txn='/home/nexus/updates/transaction'
local backup='/home/nexus/updates/previous.lua'
if fs.exists(txn) then
  if not fs.exists(backup) then
    io.write('NEXUS update recovery: backup missing; OpenOS shell available.\n');return
  end
  local failed='/home/nexus/updates/failed.lua'
  if fs.exists(failed) then fs.remove(failed) end
  if fs.exists(core) then
    local moved=fs.rename(core,failed)
    if not moved then io.write('NEXUS update recovery: cannot isolate candidate.\n');return end
  end
  local ok=fs.rename(backup,core)
  if not ok then io.write('NEXUS update recovery FAILED; use recovery helper.\n');return end
  fs.remove(txn)
  io.write('NEXUS: incomplete update rolled back.\n')
end
if fs.exists(guard) then
  io.write('NEXUS autostart paused after previous unclean run. OpenOS available.\n')
  return
end
local f,why=io.open(guard,'w')
if not f then io.write('NEXUS autostart guard unavailable: '..tostring(why)..'\n');return end
f:write('running\n');f:close()
local ok,result,detail=pcall(dofile,core)
if ok and result==true then fs.remove(guard)
else io.write('NEXUS autostart failed; skipping next startup. '..tostring(detail or result)..'\n') end
]=]
M.BOOT_SOURCE=BOOT_SOURCE
local function defaultRead(p)
  local f=io.open(p,'rb');if not f then return nil end
  local s=f:read(32769);f:close();return s
end
local function defaultWrite(p,s)
  local f,why=io.open(p,'wb');if not f then return false,why end
  local ok,e=pcall(function() assert(f:write(s));assert(f:flush()) end)
  f:close();return ok,e
end
function M.new(opts)
  opts=opts or {}
  return setmetatable({fs=opts.fs or require('filesystem'),read=opts.read or defaultRead,
    write=opts.write or defaultWrite,core=opts.core or M.CORE},{__index=M})
end
function M:status()
  local s=self.read(M.SHRC) or ''
  local b=s:find(BEGIN,1,true)
  local e=s:find(END,1,true)
  if b and e and e>b then
    local block=s:sub(b,e+#END-1)
    return block:find(M.BOOT,1,true) and 'ENABLED' or 'LEGACY'
  end
  if b or e then return 'BROKEN' end
  return 'DISABLED'
end
function M:atomic(path,data)
  local tmp=path..'.nexus-temp';local backup=path..'.nexus-prev'
  local ok,why=self.write(tmp,data);if not ok then return false,why end
  if self.fs.exists(backup) then
    local del,err=self.fs.remove(backup);if not del then self.fs.remove(tmp);return false,err end
  end
  local had=self.fs.exists(path)
  if had then
    local moved,err=self.fs.rename(path,backup)
    if not moved then self.fs.remove(tmp);return false,err end
  end
  local applied,err=self.fs.rename(tmp,path)
  if not applied then
    if had then self.fs.rename(backup,path) end
    return false,err
  end
  return true
end
function M:enable()
  if not self.fs.exists('/home/nexus') then
    local made,why=self.fs.makeDirectory('/home/nexus')
    if not made then return false,why or 'Cannot create /home/nexus' end
  end
  if not self.fs.exists(self.core) then return false,'Missing '..self.core end
  local stat=self:status()
  if stat=='ENABLED' then return true,'Already enabled' end
  if stat=='BROKEN' then return false,'Invalid .shrc markers; manual review required' end
  local original=self.read(M.SHRC) or ''
  if #original>8192 then return false,'.shrc too large; manual review required' end
  if stat=='LEGACY' then
    local b=original:find(BEGIN,1,true)
    local e=original:find(END,1,true)
    local block=original:sub(b,e+#END-1)
    if not block:find('nexus40%-bootstrap%.lua') then
      return false,'Unknown existing NEXUS startup block'
    end
    local endpos=e+#END-1
    if original:sub(endpos+1,endpos+1)=='\n' then endpos=endpos+1 end
    original=original:sub(1,b-1)..original:sub(endpos+1)
  end
  if self.fs.exists(M.BOOT) then
    local old=self.read(M.BOOT)
    if not old or not old:find('NEXUS-BOOT API 1',1,true) then return false,'Unrecognized existing boot helper' end
  end
  local ok,why=self.write(M.BOOT,BOOT_SOURCE)
  if not ok then return false,'Cannot write boot helper: '..tostring(why) end
  if #original>0 and original:sub(-1)~='\n' then original=original..'\n' end
  return self:atomic(M.SHRC,original..BEGIN..'\n'..M.BOOT..'\n'..END..'\n')
end
function M:disable()
  local stat=self:status()
  if stat=='DISABLED' then return true,'Already disabled' end
  if stat=='BROKEN' then return false,'Invalid markers; manual review required' end
  local raw=self.read(M.SHRC) or ''
  local b,e=raw:find(BEGIN,1,true),raw:find(END,1,true)
  if not b or not e or e<=b then return false,'Malformed .shrc' end
  local after=e+#END-1
  if raw:sub(after+1,after+1)=='\n' then after=after+1 end
  return self:atomic(M.SHRC,raw:sub(1,b-1)..raw:sub(after+1))
end
function M:recover()
  if not self.fs.exists(M.GUARD) then return true,'Guard is clear' end
  return self.fs.remove(M.GUARD)
end
return M

end

local Up=require('nexus.core.update').new()
local St=require('nexus.core.startup').new()
local args={...}
local op=args[1] or 'status'
if op=='status' then
  print('NEXUS autostart: '..St:status())
  print('Core: '..(St.fs.exists('/home/osv4.lua') and 'installed' or 'missing'))
  print('Guard: '..(St.fs.exists('/home/nexus/startup.guard') and 'present' or 'clear'))
  print('Staged: '..tostring(Up:stagedVersion() or 'none'))
  print('Previous release: '..(Up.fs.exists(Up.BACKUP) and 'available' or 'none'))
elseif op=='enable' then
  if args[2]~='YES' then print('Use: nexus-maint.lua enable YES');return end
  local ok,err=St:enable();print(ok and 'Autostart enabled' or tostring(err))
elseif op=='disable' then
  local ok,err=St:disable();print(ok and 'Autostart disabled' or tostring(err))
elseif op=='recover' then
  local ok,err=St:recover();print(ok and 'Guard cleared' or tostring(err))
elseif op=='rollback' then
  if args[2]~='YES' then print('Use: nexus-maint.lua rollback YES');return end
  local ok,err=Up:rollback();print(ok and 'Previous OS restored. Launch /home/osv4.lua' or tostring(err))
else
 print('Usage: nexus-maint.lua status | enable YES | disable | recover | rollback YES')
end

