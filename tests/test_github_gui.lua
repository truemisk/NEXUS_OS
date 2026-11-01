package.path='./src/?.lua;./tests/?.lua;'..package.path
local App=require('nexus.apps.updatecenter')
local Graphics=require('nexus.core.graphics')
local Theme=require('nexus.core.theme')
local MockGPU=require('mock_gpu')
local count=0
local function scenario(w,h)
  local staged=false
  local requested=0
  local updater={version='0.6.4',fs={exists=function()return false end}}
  function updater:stagedVersion()return staged and '0.6.5' or nil end
  function updater:stagedSource()return staged and 'github-sha256' or 'none' end
  function updater:checkGitHub()requested=requested+1;return true,{version='0.6.5',newer=true} end
  function updater:stageGitHub(manifest)
    assert(manifest.version=='0.6.5');staged=true;return true,'0.6.5',150000
  end
  local notices={}
  local gpu=MockGPU.new(w,h)
  local ctx={gfx=Graphics.new(gpu),theme=Theme.select(8,'cyan'),config={data={layout='auto'}},
    state={running=true},updater=updater,
    startup={status=function()return 'DISABLED' end,fs={exists=function()return false end}},
    notify=function(msg,kind)notices[#notices+1]={msg,kind} end}
  App.open(ctx)
  App.draw(ctx)
  assert(ctx.state.updateCenter.tab==1)
  App.input({kind='enter'},ctx)
  assert(ctx.state.updateCenter.online.version=='0.6.5')
  assert(requested==1)
  App.input({kind='down'},ctx)
  App.input({kind='enter'},ctx)
  assert(staged and ctx.state.updateCenter.staged=='0.6.5')
  App.draw(ctx)
  App.input({kind='down'},ctx)
  App.input({kind='enter'},ctx)
  assert(ctx.state.updateCenter.confirm=='install')
  App.input({kind='char',value='y'},ctx)
  assert(ctx.state.updateAction=='install' and ctx.state.running==false)
  assert(#notices>=2)
end
scenario(80,25);count=count+1;print('PASS GitHub GUI check, download, confirm install at 80x25')
scenario(40,18);count=count+1;print('PASS GitHub GUI compact mode and install confirmation at 40x18')
print('GITHUB GUI: '..count..' passed')
