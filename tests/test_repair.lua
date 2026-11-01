package.path='./src/?.lua;./tests/?.lua;'..package.path
local U=require('nexus.core.update')
local D=require('nexus.core.devicecontrol')
local H=require('nexus.core.hardware')
local count=0
local function test(title,fn)
 local ok,err=pcall(fn);if not ok then error('FAIL '..title..': '..tostring(err),0) end
 count=count+1;print('PASS '..title)
end
local function fake()
 local nodes={['/home']={dir=true},['/home/nexus']={dir=true}}
 local fs={}
 function fs.exists(p)return nodes[p]~=nil end
 function fs.size(p)return nodes[p] and #(nodes[p].data or '') or 0 end
 function fs.makeDirectory(p)nodes[p]={dir=true};return true end
 function fs.remove(p)nodes[p]=nil;return true end
 function fs.rename(a,b) if not nodes[a] or nodes[b] then return false,'collision' end;nodes[b]=nodes[a];nodes[a]=nil;return true end
 local function read(p,max)local v=nodes[p] and nodes[p].data;return v and v:sub(1,max or #v) end
 local function write(p,v)nodes[p]={data=v};return true end
 local function open(p) local all='';return {write=function(_,v)all=all..v;return true end,flush=function()return true end,close=function()nodes[p]={data=all} end} end
 local function compile(p) return load(read(p),p,'t') end
 return fs,read,write,open,compile
end
local function release(v)return '-- NEXUS-DISTRIBUTION: 1\n-- NEXUS-VERSION: '..v..'\n'..('local x=1\n'):rep(40)..'return true\n' end
test('OpenOS component.list callable table enumerates correctly',function()
 local comp={list=function()
  local i=0;local data={{'gpu-a','gpu'},{'screen-a','screen'},{'red-a','redstone'}}
  return setmetatable({}, {__call=function()i=i+1;if data[i] then return data[i][1],data[i][2] end end})
 end}
 local device=D.new(comp);local found,err=device:list()
 assert(not err,err);assert(#found==3);assert(#device:redstones()==1)
end)
test('OpenOS shell download path stages validated release',function()
 local fs,r,w,o,c=fake()
 w(U.CORE,release('0.6.0'))
 local calls=0
 local up=U.new({fs=fs,read=r,write=w,open=o,compile=c,version='0.6.0',
  shellExecute=function(command)
    assert(command=='pastebin get FIX12345 '..U.TEMP)
    w(U.TEMP,release('0.6.2'));calls=calls+1;return true
  end,fetch=function()error('must not use network when shell works')end})
 local yes,version=up:stage('FIX12345')
 assert(yes,version);assert(version=='0.6.2');assert(calls==1);assert(up:stagedVersion()=='0.6.2')
 assert(r(U.CORE):find('0.6.0',1,true))
end)
test('shell failure falls back to existing internet stream',function()
 local fs,r,w,o,c=fake()
 w(U.CORE,release('0.6.0'))
 local content=release('0.6.2');local index=0
 local up=U.new({fs=fs,read=r,write=w,open=o,compile=c,version='0.6.0',
  shellExecute=function()return false,'not installed' end,
  fetch=function()return setmetatable({},{__call=function()index=index+1;if index==1 then return content end end})end})
 assert(up:stage('ABCD1234'));assert(r(U.STAGED)==content)
end)
test('invalid shell candidate cannot overwrite running OS',function()
 local fs,r,w,o,c=fake();w(U.CORE,release('0.6.0'))
 local up=U.new({fs=fs,read=r,write=w,open=o,compile=c,version='0.6.0',
  shellExecute=function() w(U.TEMP,'<html>'..('x'):rep(160));return true end,
  fetch=function()error('not expected')end})
 local ok,why=up:stage('ABCD1234');assert(not ok)
 assert(not fs.exists(U.STAGED) and r(U.CORE)==release('0.6.0'))
end)
test('successful running version can acknowledge pending update',function()
 local fs,r,w,o,c=fake();w(U.CORE,release('0.6.2'));w(U.TXN,'trial=0.6.2\n')
 local up=U.new({fs=fs,read=r,write=w,open=o,compile=c,version='0.6.2',fetch=function()end})
 assert(up:acknowledgeRunning());assert(not fs.exists(U.TXN))
end)
test('different trial version cannot be silently accepted',function()
 local fs,r,w,o,c=fake();w(U.CORE,release('0.6.2'));w(U.TXN,'trial=0.6.1\n')
 local up=U.new({fs=fs,read=r,write=w,open=o,compile=c,version='0.6.2',fetch=function()end})
 assert(not up:acknowledgeRunning());assert(fs.exists(U.TXN))
end)
test("shell fallback does not accept unsafe ID",function()
 local fs,r,w,o,c=fake()
 local up=U.new({fs=fs,read=r,write=w,open=o,compile=c,version='0.6.0',shellExecute=function()error('called')end})
 assert(not up:stage('BAD; rm /'));assert(not up:stage('https://pastebin.com/x'))
end)
print('REPAIR: '..count..' passed')
