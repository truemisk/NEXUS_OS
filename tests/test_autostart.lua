local script='./tools/nexus_startup.lua'
local files={['/home/.shrc']='# custom shell lines\nmy-custom-command\n',
 ['/home/nexus40.lua']='return true\n'}
local fs={}
function fs.exists(p)return files[p]~=nil end
function fs.remove(p)if not fs.exists(p) then return false end;files[p]=nil;return true end
function fs.rename(a,b)if not files[a] then return false,'missing' end;files[b]=files[a];files[a]=nil;return true end
local ioMock={write=function(...) return true end}
function ioMock.open(path,mode)
 if mode=='r' then
  if not fs.exists(path) then return nil,'missing' end
  return {read=function(_,n)return files[path]:sub(1,n or #files[path]) end,close=function()end}
 end
 if mode=='w' or mode=='a' then
  local buffer=mode=='a' and (files[path] or '') or ''
  return {write=function(_,s)buffer=buffer..s;return true end,flush=function()return true end,
   close=function()files[path]=buffer end}
 end
 return nil,'unsupported'
end
local output={}
local environment=setmetatable({require=function(n)if n=='filesystem' then return fs end;return require(n)end,
 io=ioMock,print=function(...)output[#output+1]=table.concat({...},' ')end}, {__index=_G})
local function command(...)
 local code=assert(loadfile(script,'t',environment));code(...)
end
local tests=0
local function check(label,fun)
 fun();tests=tests+1;print('PASS '..label)
end
check('status no mutations',function()
 command('status');assert(files['/home/.shrc']=='# custom shell lines\nmy-custom-command\n')
end)
check('no opt-in without YES',function()
 command('enable');assert(not files['/home/nexus40-bootstrap.lua'])
end)
check('explicit enable preserves existing .shrc',function()
 command('enable','YES')
 assert(files['/home/.shrc']:find('my-custom-command',1,true))
 assert(files['/home/.shrc']:find('NEXUS-STARTUP BEGIN',1,true))
 assert(files['/home/nexus40-bootstrap.lua']:find('NEXUS-BOOTSTRAP v0.4.0',1,true))
end)
check('duplicate enable rejected',function()
 local old=files['/home/.shrc'];command('enable','YES');assert(files['/home/.shrc']==old)
end)
check('autostart wrapper successful launch clears guard',function()
 local env=setmetatable({require=function(n)return fs end,io=ioMock,
 dofile=function(p)assert(p=='/home/nexus40.lua');return true end},{__index=_G})
 local run=assert(load(files['/home/nexus40-bootstrap.lua'],'bootstrap','t',env));run()
 assert(not fs.exists('/home/nexus/startup.guard'))
end)
check('autostart wrapper failed launch keeps guard and safely skips',function()
 local calls=0
 local env=setmetatable({require=function(n)return fs end,io=ioMock,
 dofile=function()calls=calls+1;return false,'fault' end},{__index=_G})
 local run=assert(load(files['/home/nexus40-bootstrap.lua'],'bootstrap','t',env));run();run()
 assert(fs.exists('/home/nexus/startup.guard') and calls==1)
end)
check('recover clears guard explicitly',function()
 command('recover');assert(not fs.exists('/home/nexus/startup.guard'))
end)
check('disable preserves other shell commands',function()
 command('disable')
 assert(files['/home/.shrc']=='# custom shell lines\nmy-custom-command\n')
end)
print('AUTOSTART: '..tests..' passed, 0 failed')
