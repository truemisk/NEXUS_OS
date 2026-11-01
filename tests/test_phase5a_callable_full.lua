package.path='./src/?.lua;'..package.path
local U=require('nexus.core.update')
local function data(path)
  local f=assert(io.open(path,'rb'))
  local value=f:read('*a');f:close();return value
end
local base=data('dist/nexus-test-update-v0.5.1.lua')
local patch=data('dist/nexus-test-update-v0.5.2.lua')
local nodes={['/home']={dir=true},['/home/nexus']={dir=true},[U.CORE]={data=base}}
local fs={}
function fs.exists(p) return nodes[p]~=nil end
function fs.size(p) return nodes[p] and #(nodes[p].data or '') or 0 end
function fs.makeDirectory(p) if nodes[p] then return false,'exists' end;nodes[p]={dir=true};return true end
function fs.remove(p) if not nodes[p] then return false,'missing' end;nodes[p]=nil;return true end
function fs.rename(a,b) if not nodes[a] or nodes[b] then return false,'collision' end;nodes[b]=nodes[a];nodes[a]=nil;return true end
local function read(p,max)
  local v=nodes[p] and nodes[p].data
  return v and v:sub(1,max or #v)
end
local function write(p,s) nodes[p]={data=s};return true end
local function open(p,mode)
  assert(mode=='wb')
  local acc=''
  return {write=function(_,x) acc=acc..x;return true end,
    flush=function()return true end,close=function() nodes[p]={data=acc} end}
end
local function compile(p) return load(read(p),p,'t') end
local reqCount=0
local function fetch(url)
  assert(url=='https://pastebin.com/raw/ABCdef89')
  local pos=1
  return setmetatable({}, {__call=function()
    reqCount=reqCount+1
    if pos>#patch then return nil end
    local result=patch:sub(pos,pos+4095);pos=pos+4096;return result
  end})
end
local upd=U.new({fs=fs,version='0.5.1',read=read,write=write,open=open,compile=compile,fetch=fetch})
local ok,ver,bytes=upd:stage('ABCdef89')
assert(ok,ver)
assert(ver=='0.5.2' and bytes==#patch)
assert(nodes[U.CORE].data==base)
assert(upd:commit())
assert(nodes[U.CORE].data==patch)
assert(nodes[U.BACKUP].data==base)
assert(upd:finish())
assert(upd:rollback())
assert(nodes[U.CORE].data==base)
print('PASS real-size callable-table 0.5.1 -> 0.5.2 stage, commit, rollback; '..reqCount..' iterator calls')
