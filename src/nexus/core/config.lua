-- Whitelisted scalar settings; never evaluate a configuration file as Lua code.
-- v4 file is separate; loads v2 preferences when no v4 file exists.
local M = {}
M.path = '/home/nexus/settings-v4.cfg'
local defaults={theme='cyan',layout='auto',notifications=true,splash=false,logging=true,monitorService=true}
local choices={theme={cyan=true,green=true,amber=true},layout={auto=true,compact=true,standard=true}}
local function valid(k,v)
  if choices[k] then return choices[k][v] == true end
  if k=='notifications' or k=='splash' or k=='logging' or k=='monitorService' then return v=='true' or v=='false' end
  return false
end
function M.defaults()
  local d={} for k,v in pairs(defaults) do d[k]=v end return d
end
function M.parse(data)
  local settings=M.defaults()
  if type(data)~='string' or #data>4096 then return settings end
  local count=0
  for line in (data..'\n'):gmatch('(.-)\n') do
    local k,v=line:match('^([%a]+)=([%w]+)$')
    if k and valid(k,v) then
      count=count+1
      if k=='notifications' or k=='splash' or k=='logging' or k=='monitorService' then settings[k]=(v=='true')
      else settings[k]=v end
    end
  end
  return settings,count
end
function M.encode(settings)
  local lines={}
  for _,key in ipairs({'theme','layout','notifications','splash','logging','monitorService'}) do
    local value=tostring(settings[key])
    if not valid(key,value) then value=tostring(defaults[key]) end
    lines[#lines+1]=key..'='..value
  end
  return table.concat(lines,'\n')..'\n'
end
local function readDefault()
  local sources={M.path,M.path..'.bak','/home/nexus/settings-v2.cfg'}
  for _,source in ipairs(sources) do
    local f=io.open(source,'r')
    if f then
      local contents=f:read(4097);f:close()
      local _,count=M.parse(contents)
      if count and count>0 then return contents end
    end
  end
  return nil
end
local function writeDefault(data)
  local okFs,fs=pcall(require,'filesystem')
  if not okFs or not fs then return false,'filesystem library unavailable' end
  if not fs.exists('/home/nexus') then
    local ok,why=fs.makeDirectory('/home/nexus')
    if not ok then return false,why or 'cannot create directory' end
  end
  local temp=M.path..'.tmp'
  local backup=M.path..'.bak'
  local f,why=io.open(temp,'w')
  if not f then return false,why or 'cannot open temporary file' end
  local okWrite,writeError=pcall(function() assert(f:write(data)); assert(f:flush()) end)
  f:close()
  if not okWrite then pcall(fs.remove,temp); return false,tostring(writeError) end
  -- Preserve the prior version until the new one is installed.
  pcall(fs.remove,backup)
  local had=fs.exists(M.path)
  if had then
    local okOld,whyOld=fs.rename(M.path,backup)
    if not okOld then fs.remove(temp); return false,whyOld or 'cannot back up settings' end
  end
  local okNew,whyNew=fs.rename(temp,M.path)
  if not okNew then
    if had then pcall(fs.rename,backup,M.path) end
    return false,whyNew or 'cannot install settings'
  end
  -- Keep .bak to allow recovery from a later corrupted current file.
  return true
end
function M.new(persistence)
  persistence=persistence or {read=readDefault,write=writeDefault}
  local ok,raw=pcall(persistence.read)
  local self={data=M.parse(ok and raw or nil),store=persistence}
  return setmetatable(self,{__index=M})
end
function M:set(key,value)
  local normalized=tostring(value)
  if not valid(key,normalized) then return false,'invalid setting' end
  self.data[key]=value
  return true
end
function M:save()
  local ok,result,why=pcall(self.store.write,M.encode(self.data))
  if not ok then return false,tostring(result) end
  if result~=true then return false,tostring(why or 'write failed') end
  return true
end
function M:reset()
  self.data=M.defaults()
  return self:save()
end
return M
