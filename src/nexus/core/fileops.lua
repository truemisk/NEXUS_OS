-- Filesystem operations with collision checks and bounded reads.
-- No recursive deletion, no overwrite; the OS filesystem API is authoritative.
local Path=require('nexus.core.path')
local M={}
function M.new(fs,openFn)
  assert(type(fs)=='table' and type(fs.list)=='function','OpenOS filesystem required')
  return setmetatable({fs=fs,open=openFn or io.open},{__index=M})
end
function M:list(path)
  local fs=self.fs
  if not fs.exists(path) or not fs.isDirectory(path) then return nil,'Not a directory' end
  local it,err=fs.list(path)
  if type(it)~='function' and type(it)~='table' then return nil,err or 'Cannot list directory' end
  local out,overflow={},false
  local function add(v)
    if type(v)~='string' then return end
    if #out>=128 then overflow=true;return end
    local name=v:gsub('/+$','')
    if not Path.simpleName(name) then return end
    local full=Path.join(path,name)
    out[#out+1]={name=name,path=full,dir=fs.isDirectory(full),size=fs.size(full) or 0}
  end
  if type(it)=='table' then for _,v in ipairs(it) do add(v) end
  else for v in it do add(v) end end
  table.sort(out,function(a,b)
    if a.dir~=b.dir then return a.dir end
    return a.name:lower()<b.name:lower()
  end)
  return out,overflow
end
function M:info(path)
  local fs=self.fs
  local result={}
  if type(fs.get)~='function' then return result end
  local ok,proxy=pcall(fs.get,path)
  if not ok or type(proxy)~='table' then return result end
  for _,method in ipairs({'spaceTotal','spaceUsed','isReadOnly'}) do
    if type(proxy[method])=='function' then
      local yes,value=pcall(proxy[method])
      if yes then result[method]=value end
    end
  end
  return result
end
function M:preview(path,maxBytes,maxLines)
  local fs=self.fs
  if not fs.exists(path) or fs.isDirectory(path) then return nil,'Not a file' end
  local limit=math.min(4096,maxBytes or 3072)
  local f,err=self.open(path,'rb')
  if not f then return nil,err or 'Cannot open file' end
  local ok,data=pcall(function() return f:read(limit+1) or '' end)
  pcall(function() f:close() end)
  if not ok then return nil,tostring(data) end
  local more=#data>limit
  data=data:sub(1,limit)
  if data:find('%z') then return nil,'Binary file (preview unavailable)' end
  local lines={}
  for line in (data..'\n'):gmatch('(.-)\n') do
    if #lines>=math.min(80,maxLines or 64) then more=true;break end
    lines[#lines+1]=line:gsub('[%c]',' '):sub(1,240)
  end
  return lines,more
end
local function validDestination(fs,path)
  local allowed,why=Path.mutable(path)
  if not allowed then return false,why end
  if fs.exists(path) then return false,'Target already exists (no overwrite)' end
  if not fs.exists(Path.parent(path)) or not fs.isDirectory(Path.parent(path)) then
    return false,'Destination folder missing'
  end
  return true
end
function M:copy(src,dst)
  if not self.fs.exists(src) then return false,'Source missing' end
  if self.fs.isDirectory(src) then return false,'Folder copy not supported' end
  local ok,why=validDestination(self.fs,dst)
  if not ok then return false,why end
  return self.fs.copy(src,dst)
end
function M:move(src,dst)
  if not self.fs.exists(src) then return false,'Source missing' end
  local ok,why=Path.mutable(src)
  if not ok then return false,why end
  ok,why=validDestination(self.fs,dst)
  if not ok then return false,why end
  if self.fs.isDirectory(src) and dst:sub(1,#src+1)==src..'/' then return false,'Cannot move into itself' end
  return self.fs.rename(src,dst)
end
function M:rename(src,newName)
  if not Path.simpleName(newName) then return false,'Invalid name' end
  return self:move(src,Path.join(Path.parent(src),newName))
end
function M:remove(src)
  local ok,why=Path.mutable(src)
  if not ok then return false,why end
  if not self.fs.exists(src) then return false,'File not found' end
  if self.fs.isDirectory(src) then
    local items,err=self:list(src)
    if not items then return false,err end
    if #items>0 then return false,'Folder not empty (recursive delete disabled)' end
  end
  return self.fs.remove(src)
end
function M:mkdir(folder,name)
  if not Path.simpleName(name) then return false,'Invalid folder name' end
  local dest=Path.join(folder,name)
  local ok,why=validDestination(self.fs,dest)
  if not ok then return false,why end
  return self.fs.makeDirectory(dest)
end
return M
