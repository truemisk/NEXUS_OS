-- Regression for the actual v0.6.4 -> v0.6.5 release, using a fake OpenOS disk
-- and fake wget response. No real networking, GPU, or persistent machine writes.
package.path='./src/?.lua;'..package.path
local Up=require('nexus.core.update')
local SHA=require('nexus.core.sha256')
local function diskRead(p)
  local f=assert(io.open(p,'rb'))
  local s=f:read('*a');f:close();return s
end
local release=diskRead('dist/nexus.lua')
local manifest=diskRead('update.nxs')
local old=diskRead('releases/nexus-v0.6.4.lua')
local expectedSHA=diskRead('dist/SHA256SUMS'):match('^([a-f0-9]+)')
local version=release:match('^%-%- NEXUS OS Core v(%d+%.%d+%.%d+)')
assert(version=='0.6.5', version)
assert(old:find('NEXUS%-VERSION: 0%.6%.4'))
assert(release:find('NEXUS%-VERSION: 0%.6%.5'))
assert(SHA.sum(release)==expectedSHA)
assert(SHA.sum(old)~=expectedSHA)
assert(Up.VERSION=='0.6.5')
print('PASS real v0.6.5 Lua bundle, matching SHA-256 and previous release archive')
local files={}
local fs={}
function fs.exists(path)return files[path]~=nil end
function fs.size(path) return files[path] and #(files[path].data or '') or 0 end
function fs.makeDirectory(path)files[path]={dir=true};return true end
function fs.remove(path) if files[path]==nil then return false,'not found' end;files[path]=nil;return true end
function fs.rename(source,dest)
  if not files[source] then return false,'source missing' end
  if files[dest] then return false,'already exists' end
  files[dest]=files[source];files[source]=nil;return true
end
local function read(path,limit)
  local data=files[path] and files[path].data
  if not data then return nil end
  return data:sub(1,limit or #data)
end
local function write(path,data) files[path]={data=data};return true end
local function open(path,mode)
  if mode=='rb' then
    local data=read(path)
    if not data then return nil,'file missing' end
    local pos=1
    return {read=function(_,n)
      if pos>#data then return nil end
      local chunk=data:sub(pos,pos+(n or #data)-1)
      pos=pos+#chunk
      return chunk
    end,close=function() return true end}
  end
  if mode=='wb' then
    local blocks={}
    return {write=function(_,s)blocks[#blocks+1]=s;return true end,
      flush=function()return true end,
      close=function()write(path,table.concat(blocks));return true end}
  end
  error('Unexpected file mode')
end
local function compile(path)
  local source=read(path)
  if not source then return nil,'file missing' end
  return load(source,path,'t')
end
write(Up.CORE,old)
local network={[Up.GITHUB_URL]=manifest,[Up.GITHUB_RELEASE]=release}
local up=Up.new({fs=fs,read=read,write=write,open=open,compile=compile,
  version='0.6.4',shellExecute=function(command)
    local url,dest=command:match('^wget "([^"]+)" (.+)$')
    if not url or not network[url] then return false,'URL not mocked' end
    write(dest,network[url])
    return true
  end})
local ok,m=up:checkGitHub()
assert(ok and m.version=='0.6.5' and m.newer, tostring(m))
local expected,why=up:parseGitHubManifest(manifest)
assert(expected and expected.sha256==expectedSHA,why)
assert(expected.size==#release)
print('PASS real manifest recognized as a newer version by v0.6.4')
local staged,newver,bytes=up:stageGitHub(m)
assert(staged and newver=='0.6.5' and bytes==#release,tostring(newver))
assert(read(Up.STAGED)==release and read(Up.CORE)==old)
assert(up:stagedSource()=='github-sha256')
print('PASS real GitHub bundle staged, verified, and active OS unchanged')
local installed,installedVersion=up:commit()
assert(installed and installedVersion=='0.6.5',tostring(installedVersion))
assert(read(Up.CORE)==release and read(Up.BACKUP)==old)
assert(fs.exists(Up.TXN))
print('PASS real bundle committed with backup and trial transaction')
local rolled,reason=up:rollback()
assert(rolled,reason)
assert(read(Up.CORE)==old and not fs.exists(Up.TXN))
print('PASS rollback restores the byte-identical v0.6.4 release')
-- Verify that installing the same version is forbidden even if a malicious
-- or stale manifest claims it should be newer.
local up65=Up.new({fs=fs,read=read,write=write,open=open,compile=compile,version='0.6.5',shellExecute=function()return false end})
local same=up65:parseGitHubManifest(manifest)
assert(same and same.version=='0.6.5')
assert(not up65:validate(Up.CORE) or read(Up.CORE)==old)
print('RELEASE 0.6.5: 5 passed')
