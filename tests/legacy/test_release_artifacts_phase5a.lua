package.path='./src/?.lua;./tests/?.lua;'..package.path
local U=require('nexus.core.update')
local S=require('nexus.core.startup')
local function diskFile(path)
 local f=assert(io.open(path,'rb'));local data=f:read('*a');f:close();return data
end
local old=diskFile('dist/nexus.lua')
local candidate=diskFile('dist/nexus-test-update-v0.5.1.lua')
assert(#old>100000 and #candidate>100000)
assert(old:find('NEXUS%-VERSION: 0%.5%.0'))
assert(candidate:find('NEXUS%-VERSION: 0%.5%.1'))
local nodes={['/home']={dir=true},['/home/nexus']={dir=true},[U.CORE]={data=old}}
local fs={}
function fs.exists(p)return nodes[p]~=nil end
function fs.size(p)return nodes[p] and #(nodes[p].data or '') or 0 end
function fs.makeDirectory(p)nodes[p]={dir=true};return true end
function fs.remove(p)nodes[p]=nil;return true end
function fs.rename(a,b)
 if not nodes[a] or nodes[b] then return false,'rename rejected' end
 nodes[b]=nodes[a];nodes[a]=nil;return true
end
local function read(path,max)
 local n=nodes[path];return n and n.data and n.data:sub(1,max or #n.data) or nil
end
local function write(path,value)
 nodes[path]={data=value};return true
end
local function open(path,mode)
 assert(mode=='wb')
 local data=''
 return {write=function(_,x)data=data..x;return true end,flush=function()return true end,
 close=function()nodes[path]={data=data} end}
end
local function compile(path)
 return load(read(path),path,'t')
end
local function fetch(url)
 assert(url=='https://pastebin.com/raw/Test5A01')
 local n=0
 return function()
  n=n+1;local p=(n-1)*4096+1
  return p<=#candidate and candidate:sub(p,p+4095) or nil
 end
end
local updater=U.new({fs=fs,read=read,write=write,open=open,compile=compile,fetch=fetch})
local ok,ver,bytes=updater:stage('Test5A01')
assert(ok and ver=='0.5.1' and bytes==#candidate,ver)
print('PASS full 114 KB candidate download and Lua syntax validation')
assert(nodes[U.CORE].data==old)
assert(updater:commit())
assert(nodes[U.CORE].data==candidate and nodes[U.BACKUP].data==old)
print('PASS candidate committed with genuine original source preserved')
assert(updater:recoverInterrupted())
assert(nodes[U.CORE].data==old)
print('PASS full 114 KB release automatic rollback after interrupted trial')
assert(load(S.BOOT_SOURCE,'boot','t'))
print('PASS bootstrap generator compiles')
local F=require('mock_fs')
package.loaded.filesystem=F.new()
local result=pcall(dofile,'dist/nexus-maint.lua')
assert(result)
print('PASS standalone maintenance CLI loads in simulated OpenOS')
