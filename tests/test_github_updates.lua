package.path='./src/?.lua;./tests/?.lua;'..package.path
local Up=require('nexus.core.update')
local SHA=require('nexus.core.sha256')
local tests=0
local function test(title,fn)
  local ok,reason=pcall(fn)
  if not ok then error('FAIL '..title..': '..tostring(reason),0) end
  tests=tests+1;print('PASS '..title)
end
local function release(ver)
  return '-- NEXUS-DISTRIBUTION: 1\n-- NEXUS-VERSION: '..ver..'\n'..('local a=1\n'):rep(80)..'return true\n'
end
local function manifest(version,blob)
  return '# NEXUS-UPDATE-MANIFEST: 1\nchannel=stable\nversion='..version..'\nurl='..Up.GITHUB_RELEASE..'\nsha256='..SHA.sum(blob)..'\nsize='..#blob..'\n'
end
local function fake()
  local nodes={['/home']={dir=true},['/home/nexus']={dir=true}}
  local fs={}
  function fs.exists(p)return nodes[p]~=nil end
  function fs.size(p)return nodes[p] and #(nodes[p].data or '') or 0 end
  function fs.makeDirectory(p)nodes[p]={dir=true};return true end
  function fs.remove(p)if not nodes[p] then return false end;nodes[p]=nil;return true end
  function fs.rename(a,b)if not nodes[a] or nodes[b] then return false,'collision' end;nodes[b]=nodes[a];nodes[a]=nil;return true end
  local function read(p,len)local x=nodes[p] and nodes[p].data;return x and x:sub(1,len or #x) end
  local function write(p,x)nodes[p]={data=x};return true end
  local function open(p,mode)
    if mode=='rb' then
      local content=read(p)
      if not content then return nil,'missing' end
      local index=1
      return {read=function(_,count)
        if index>#content then return nil end
        local part=content:sub(index,index+(count or #content)-1)
        index=index+#part
        return part
      end,close=function()end}
    end
    if mode=='wb' then
      local chunks={}
      return {write=function(_,x)chunks[#chunks+1]=x;return true end,flush=function()return true end,
        close=function()write(p,table.concat(chunks))end}
    end
  end
  local function compile(p)return load(read(p),p,'t') end
  return fs,read,write,open,compile
end
local function updater(source,contents)
  local fs,r,w,o,c=fake()
  w(Up.CORE,release('0.6.2'))
  local calls={}
  local shell=function(cmd)
    calls[#calls+1]=cmd
    local url,path=cmd:match('^wget "([^"]+)" (.+)$')
    assert(url and path,'unexpected shell command: '..cmd)
    if contents[url] then w(path,contents[url]);return true end
    return false,'missing source'
  end
  local up=Up.new({fs=fs,read=r,write=w,open=o,compile=c,version='0.6.2',shellExecute=shell})
  return up,fs,r,w,calls
end
test('SHA-256 vectors and streaming file',function()
  assert(SHA.sum('')=='e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855')
  assert(SHA.sum('abc')=='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')
  assert(SHA.sum(('a'):rep(1000000))=='cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0')
end)
test('GitHub manifest strict host, keys, duplicates and size',function()
  local up=updater(nil,{})
  local b=release('0.6.4');local good=manifest('0.6.4',b)
  assert(up:parseGitHubManifest(good))
  assert(not up:parseGitHubManifest(good:gsub('githubusercontent','badhost')))
  assert(not up:parseGitHubManifest(good..'version=9.9.9\n'))
  assert(not up:parseGitHubManifest(good..'extra=yes\n'))
  assert(not up:parseGitHubManifest(good:gsub('size=%d+','size=9000000')))
end)
test('GitHub check reads manifest and detects newer version',function()
  local b=release('0.6.4')
  local up,fs,r,w,calls=updater(nil,{[Up.GITHUB_URL]=manifest('0.6.4',b)})
  local ok,m=up:checkGitHub();assert(ok,m);assert(m.version=='0.6.4' and m.newer)
  assert(not fs.exists(Up.GITHUB_MANIFEST))
  assert(calls[1]:find('wget ',1,true)==1)
end)
test('GitHub stage verifies size, SHA-256 and Lua version without active mutation',function()
  local b=release('0.6.4')
  local up,fs,r=updater(nil,{[Up.GITHUB_URL]=manifest('0.6.4',b),[Up.GITHUB_RELEASE]=b})
  local ok,ver,count=up:stageGitHub();assert(ok,ver);assert(ver=='0.6.4' and count==#b)
  assert(r(Up.STAGED)==b and r(Up.CORE):find('0.6.2',1,true))
  assert(up:stagedSource()=='github-sha256')
  assert(up:commit());assert(fs.exists(Up.BACKUP) and fs.exists(Up.TXN))
  assert(r(Up.CORE)==b)
  assert(up:rollback());assert(r(Up.CORE):find('0.6.2',1,true))
end)
test('Corrupt GitHub release cannot replace active OS or previous stage',function()
  local b=release('0.6.4');local tampered=b..'-- unwanted\n'
  local up,fs,r,w=updater(nil,{[Up.GITHUB_URL]=manifest('0.6.4',b),[Up.GITHUB_RELEASE]=tampered})
  w(Up.STAGED,release('0.6.3'))
  local ok,err=up:stageGitHub()
  assert(not ok and err:find('size mismatch'),err)
  assert(r(Up.STAGED)==release('0.6.3'))
  assert(not fs.exists(Up.TXN) and r(Up.CORE):find('0.6.2',1,true))
end)
test('Tampering after GitHub staging blocks installation',function()
  local b=release('0.6.4')
  local up,fs,r,w=updater(nil,{[Up.GITHUB_URL]=manifest('0.6.4',b),[Up.GITHUB_RELEASE]=b})
  assert(up:stageGitHub())
  w(Up.STAGED,b:gsub('local a=1','local a=2',1))
  local ok,err=up:commit()
  assert(not ok and err:find('SHA%-256 mismatch'),err)
  assert(not fs.exists(Up.TXN) and r(Up.CORE):find('0.6.2',1,true))
end)
test('No auto-install and no downgrade offered',function()
  local b=release('0.6.2')
  local up,fs,r=updater(nil,{[Up.GITHUB_URL]=manifest('0.6.2',b),[Up.GITHUB_RELEASE]=b})
  local ok,m=up:checkGitHub();assert(ok and not m.newer)
  assert(not up:stageGitHub())
  assert(not fs.exists(Up.TXN) and r(Up.CORE):find('0.6.2',1,true))
end)
test('Callable-table HTTP fallback downloads GitHub release',function()
  local b=release('0.6.4')
  local data={[Up.GITHUB_URL]=manifest('0.6.4',b),[Up.GITHUB_RELEASE]=b}
  local fs,r,w,o,c=fake();w(Up.CORE,release('0.6.2'))
  local up=Up.new({fs=fs,read=r,write=w,open=o,compile=c,version='0.6.2',
    shellExecute=function()return false,'shell failed' end,
    fetch=function(url)
      local full=data[url];assert(full);local index=1
      return setmetatable({},{__call=function()
        if index>#full then return nil end
        local part=full:sub(index,index+90);index=index+#part;return part
      end})
    end})
  assert(up:stageGitHub());assert(r(Up.STAGED)==b)
end)
print('GITHUB UPDATE: '..tests..' passed')
