package.path='./src/?.lua;./tests/?.lua;'..package.path
local U=require('nexus.core.update')
local function bytes(path)
 local f=assert(io.open(path,'rb'));local data=f:read('*a');f:close();return data
end
local prior=bytes('dist/nexus-test-update-v0.5.1.lua')
local nextRelease=bytes('dist/nexus.lua')
assert(prior:find('NEXUS%-VERSION: 0%.5%.1') and nextRelease:find('NEXUS%-VERSION: 0%.6%.2'))
assert(#nextRelease<300000 and #nextRelease>120000)
local nodes={['/home']={dir=true},['/home/nexus']={dir=true},[U.CORE]={data=prior}}
local fs={}
function fs.exists(p)return nodes[p]~=nil end
function fs.size(p)return nodes[p] and #(nodes[p].data or '') or 0 end
function fs.makeDirectory(p)nodes[p]={dir=true};return true end
function fs.remove(p)nodes[p]=nil;return true end
function fs.rename(a,b)
 if not nodes[a] or nodes[b] then return false,'collision/missing' end
 nodes[b]=nodes[a];nodes[a]=nil;return true
end
local function read(path,max)
 local n=nodes[path];return n and n.data and n.data:sub(1,max or #n.data) or nil
end
local function write(path,content)nodes[path]={data=content};return true end
local function open(path,mode)
 assert(mode=='wb')
 local content=''
 return {write=function(_,data)content=content..data;return true end,flush=function()return true end,
  close=function()nodes[path]={data=content} end}
end
local function compile(path)
 local data=read(path);return data and load(data,path,'t') or nil,'missing'
end
local chunks,reads={},0
for i=1,#nextRelease,4096 do chunks[#chunks+1]=nextRelease:sub(i,i+4095) end
local function fetch(uri)
 assert(uri=='https://pastebin.com/raw/Phase5b1')
 return setmetatable({},{__call=function()
  reads=reads+1;return chunks[reads]
 end})
end
local u=U.new({fs=fs,current=U.CORE,version='0.5.1',read=read,write=write,open=open,compile=compile,fetch=fetch})
local ok,ver,size=u:stage('Phase5b1')
assert(ok and ver=='0.6.2' and size==#nextRelease,tostring(ver))
assert(nodes[U.CORE].data==prior)
print('PASS 0.5.1 -> 0.6.2 update stages callable-table download ('..size..' bytes)')
assert(u:commit());assert(nodes[U.CORE].data==nextRelease and nodes[U.BACKUP].data==prior)
print('PASS updater installs 0.6.2 and retains original release')
assert(u:recoverInterrupted());assert(nodes[U.CORE].data==prior)
print('PASS interrupted update restores 0.5.1 exactly')
reads=0
local u2=U.new({fs=fs,current=U.CORE,version='0.5.1',read=read,write=write,open=open,compile=compile,fetch=fetch})
assert(u2:stage('Phase5b1'));assert(u2:commit());assert(u2:finish())
assert(nodes[U.CORE].data==nextRelease and nodes[U.BACKUP].data==prior)
print('PASS successful trial retains rollback backup and clears transaction')
