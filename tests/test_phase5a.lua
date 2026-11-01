package.path='./src/?.lua;'..package.path
local U=require('nexus.core.update')
local S=require('nexus.core.startup')
local App=require('nexus.apps.updatecenter')
local count=0
local function test(name,fn)
 local ok,why=pcall(fn)
 if not ok then error('FAIL '..name..': '..tostring(why),0) end
 count=count+1;print('PASS '..name)
end
local function fake()
 local files={['/home']={dir=true},['/home/nexus']={dir=true}}
 local fs={files=files}
 function fs.exists(p)return files[p]~=nil end
 function fs.isDirectory(p)return files[p] and files[p].dir or false end
 function fs.size(p)return files[p] and #(files[p].data or '') or 0 end
 function fs.makeDirectory(p)if files[p]then return false,'exists' end;files[p]={dir=true};return true end
 function fs.rename(a,b)
  if not files[a] or files[b] then return false,'missing or collision' end
  files[b]=files[a];files[a]=nil;return true
 end
 function fs.remove(p)
  if not files[p] then return false,'missing' end
  files[p]=nil;return true
 end
 local function read(p,n)
  local f=files[p];return f and f.data and f.data:sub(1,n or 1000000) or nil
 end
 local function write(p,s)
  if not files[p:match('^(.*)/[^/]+$') or ''] then return false,'no parent' end
  files[p]={data=s};return true
 end
 local function open(p,mode)
  if mode=='wb' then
   local accumulated=''
   return {write=function(_,v) accumulated=accumulated..v;return true end,
    flush=function()return true end,close=function() files[p]={data=accumulated} end}
  end
  local v=read(p)
  if not v then return nil,'missing' end
  return {read=function(_,len)return v:sub(1,len or #v) end,close=function()end}
 end
 local function compile(p)
  local source=read(p)
  if not source then return nil,'missing' end
  return load(source,p,'t')
 end
 return fs,read,write,open,compile
end
local function release(ver)
 return '-- NEXUS-DISTRIBUTION: 1\n-- NEXUS-VERSION: '..ver..'\n'..('local x=1\n'):rep(20)..'return true\n'
end
local function updater(fs,r,w,o,c,fetch)
 return U.new({fs=fs,read=r,write=w,open=o,compile=c,fetch=fetch,version="0.5.0"})
end
test('Pastebin ID accepts valid IDs, rejects URL and slashes',function()
 local fs,r,w,o,c=fake();local n=updater(fs,r,w,o,c)
 assert(not n:stage('https://pastebin.com/aaa'))
 assert(not n:stage('abc/def'))
 assert(not n:stage('short'))
end)
test('staging checks version, compiles Lua, and protects active core',function()
 local fs,r,w,o,c=fake()
 assert(w(U.CORE,release('0.5.0')))
 local n=updater(fs,r,w,o,c,function(url)
  assert(url=='https://pastebin.com/raw/ABCdef89')
  return coroutine.wrap(function()coroutine.yield(release('0.5.1'))end)
 end)
 local ok,ver,bytes=n:stage('ABCdef89')
 assert(ok and ver=='0.5.1' and bytes>100)
 assert(r(U.CORE):find('0.5.0',1,true))
 assert(n:stagedVersion()=='0.5.1')
 assert(fs.exists(U.META))
end)
test('real OpenOS internet.request callable table iterator is accepted',function()
 local fs,r,w,o,c=fake()
 assert(w(U.CORE,release('0.5.0')))
 local source=release('0.5.1')
 local chunks={source:sub(1,50),source:sub(51)}
 local requests=0
 local n=updater(fs,r,w,o,c,function(url)
  assert(url=='https://pastebin.com/raw/VK7q7s0D')
  return setmetatable({close=function() end},{__call=function()
   requests=requests+1
   return chunks[requests]
  end})
 end)
 local ok,ver,bytes=n:stage('VK7q7s0D')
 assert(ok,ver)
 assert(ver=='0.5.1')
 assert(bytes==#source)
 assert(r(U.STAGED)==source)
end)
test('non-callable table reports useful error instead of table address',function()
 local fs,r,w,o,c=fake()
 local n=updater(fs,r,w,o,c,function()return {} end)
 local ok,why=n:stage('VK7q7s0D')
 assert(not ok)
 assert(why:find('non%-callable table'))
 assert(not why:find('0x',1,true))
end)
test('invalid HTML, older version, invalid Lua are rejected',function()
 for _,bad in ipairs({'<html>'..('x'):rep(140),release('0.4.0'),
  '-- NEXUS-DISTRIBUTION: 1\n-- NEXUS-VERSION: 0.6.0\n'..('local x=\n'):rep(20)}) do
  local fs,r,w,o,c=fake()
  local n=updater(fs,r,w,o,c,function()return coroutine.wrap(function()coroutine.yield(bad)end)end)
  local ok=n:stage('ABCdef89');assert(not ok);assert(not fs.exists(U.STAGED))
 end
end)
test('download cap prevents oversized staging',function()
 local fs,r,w,o,c=fake()
 local n=U.new({fs=fs,read=r,write=w,open=o,compile=c,version="0.5.0",limit=200,fetch=function()
  return coroutine.wrap(function()coroutine.yield(release('0.5.1')) end) end})
 assert(not n:stage('ABCDEf99'))
 assert(not fs.exists(U.TEMP))
end)
test('update transaction backs up and restores on rollback',function()
 local fs,r,w,o,c=fake()
 w(U.CORE,release('0.5.0'))
 local n=updater(fs,r,w,o,c,function()return coroutine.wrap(function()coroutine.yield(release('0.5.1'))end)end)
 assert(n:stage('abc12345'));local ok,ver=n:commit()
 assert(ok and ver=='0.5.1' and fs.exists(U.TXN) and fs.exists(U.BACKUP))
 assert(r(U.CORE):find('0.5.1',1,true))
 assert(n:recoverInterrupted());assert(not fs.exists(U.TXN))
 assert(r(U.CORE):find('0.5.0',1,true))
 assert(r('/home/nexus/updates/failed.lua'):find('0.5.1',1,true))
end)
test('healthy updated version retains one previous release',function()
 local fs,r,w,o,c=fake();w(U.CORE,release('0.5.0'))
 local n=updater(fs,r,w,o,c,function()return coroutine.wrap(function()coroutine.yield(release('0.5.1')) end)end)
 assert(n:stage('abc12345'));assert(n:commit());assert(n:finish());assert(not fs.exists(U.TXN))
 assert(fs.exists(U.BACKUP))
 assert(n:rollback());assert(not fs.exists(U.BACKUP))
end)
test('active system not overwritten if candidate missing or invalid',function()
 local fs,r,w,o,c=fake();w(U.CORE,release('0.5.0'))
 local n=updater(fs,r,w,o,c)
 assert(not n:commit());assert(r(U.CORE):find('0.5.0',1,true))
 w(U.STAGED,'<html>'..('x'):rep(150))
 assert(not n:commit());assert(r(U.CORE):find('0.5.0',1,true))
end)
test('autostart opt-in uses fixed osv4.lua and preserves other .shrc commands',function()
 local fs,r,w,o,c=fake();w(S.CORE,'-- executable')
 w(S.SHRC,'echo existing\n')
 local s=S.new({fs=fs,read=r,write=w})
 assert(s:status()=='DISABLED')
 local ok,err=s:enable();assert(ok,tostring(err))
 assert(s:status()=='ENABLED');assert(r(S.SHRC):find('echo existing',1,true))
 assert(r(S.SHRC):find('/home/nexus-boot.lua',1,true))
 assert(r(S.BOOT):find("core='/home/osv4.lua'",1,true))
 assert(s:disable());assert(s:status()=='DISABLED')
 assert(r(S.SHRC)=='echo existing\n')
end)
test('legacy v4 autostart migrates without discarding shell customizations',function()
 local fs,r,w,o,c=fake();w(S.CORE,'-- executable')
 w(S.SHRC,'echo old\n# NEXUS-STARTUP BEGIN\n/home/nexus40-bootstrap.lua\n# NEXUS-STARTUP END\necho end\n')
 local s=S.new({fs=fs,read=r,write=w})
 assert(s:status()=='LEGACY');assert(s:enable());assert(s:status()=='ENABLED')
 assert(r(S.SHRC):find('echo old',1,true) and r(S.SHRC):find('echo end',1,true))
 assert(not r(S.SHRC):find('nexus40%-bootstrap%.lua'))
end)
test('unknown startup markers cannot be silently overwritten',function()
 local fs,r,w,o,c=fake();w(S.CORE,'-- executable')
 w(S.SHRC,'# NEXUS-STARTUP BEGIN\n/suspicious/path\n# NEXUS-STARTUP END\n')
 local s=S.new({fs=fs,read=r,write=w})
 assert(s:status()=='LEGACY');assert(not s:enable())
end)
test('autostart recovery guard only removed when explicitly asked',function()
 local fs,r,w,o,c=fake();w(S.GUARD,'running\n')
 local s=S.new({fs=fs,read=r,write=w})
 assert(fs.exists(S.GUARD));assert(s:recover());assert(not fs.exists(S.GUARD))
end)
test('update center can open and use both tabs without F keys',function()
 local fs,r,w,o,c=fake();w(U.CORE,release('0.5.0'))
 local n=updater(fs,r,w,o,c);local s=S.new({fs=fs,read=r,write=w})
 local ctx={state={},updater=n,startup=s,notify=function()end}
 App.open(ctx);assert(ctx.state.updateCenter.tab==1)
 assert(App.input({kind='char',value='2'},ctx))
 assert(ctx.state.updateCenter.tab==2)
 assert(App.input({kind='char',value='1'},ctx))
 assert(ctx.state.updateCenter.tab==1)
 for _=1,4 do App.input({kind='down'},ctx) end
 App.input({kind='enter'},ctx)
 assert(ctx.state.updateCenter.mode=='id')
 assert(App.input({kind='back'},ctx) and ctx.state.updateCenter.mode==nil)
 App.close(ctx);assert(ctx.state.updateCenter==nil)
end)
print('PHASE 5A: '..count..' passed, 0 failed')
