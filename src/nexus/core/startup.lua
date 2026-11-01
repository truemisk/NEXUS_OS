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
