-- Lightweight sampling only while foreground, bounded history.
local Widgets=require('nexus.ui.widgets')
local M={id='monitor',name='System Monitor',description='Live RAM and component charts'}
local function sample(ctx)
  local state=ctx.state.monitor
  local snap=ctx.hardware:snapshot()
  state.snapshot=snap
  state.last=ctx.now()
  state.history[#state.history+1]={free=snap.freeMemory,total=snap.totalMemory}
  if #state.history>28 then table.remove(state.history,1) end
end
function M.open(ctx)
  ctx.state.monitor={tab=1,history={},last=-100,scroll=0,snapshot={}}
  sample(ctx)
end
function M.close(ctx) ctx.state.monitor=nil end
function M.tick(ctx)
  local s=ctx.state.monitor
  if ctx.now()-s.last>=3 then sample(ctx);return true end
end
local function drawBar(g,t,x,y,w,fraction)
  local n=math.max(0,math.min(w,math.floor((fraction or 0)*w+0.5)))
  g:fill(x,y,w,1,t.surface)
  if n>0 then g:fill(x,y,n,1,t.good,'#') end
end
function M.draw(ctx)
  local g,t=ctx.gfx,ctx.theme
  local w,h=g:size()
  local st=ctx.state.monitor
  local s=st.snapshot
  Widgets.frame(ctx,'SYSTEM MONITOR / '..(st.tab==1 and 'MEMORY' or 'COMPONENTS'))
  g:text(2,3,'[1] MEMORY    [2] HARDWARE    [R] SAMPLE',t.accent,t.bg,w-3)
  if st.tab==1 then
    local total=s.totalMemory or 0;local free=s.freeMemory or 0
    local used=math.max(0,total-free)
    g:text(3,5,string.format('FREE   %.1f KiB',free/1024),t.text,t.bg,w-4)
    g:text(3,6,string.format('USED   %.1f KiB',used/1024),t.text,t.bg,w-4)
    g:text(3,7,string.format('TOTAL  %.1f KiB',total/1024),t.text,t.bg,w-4)
    local bw=math.max(1,math.min(56,w-6))
    g:text(3,9,'MEMORY UTILIZATION',t.accent,t.bg,w-5)
    drawBar(g,t,3,10,bw,total>0 and used/total or 0)
    g:text(3,12,'FREE RAM TREND / sampled every 3s',t.accent,t.bg,w-5)
    local from=math.max(1,#st.history-math.min(w-6,28)+1)
    local x=3
    for i=from,#st.history do
      local p=st.history[i]
      local ratio=p.total and p.total>0 and p.free/p.total or 0
      local level=math.max(0,math.min(8,math.floor(ratio*8+0.5)))
      local glyph=({'_','.','-',':','=','+','*','#','@'})[level+1]
      g:text(x,14,glyph,t.good,t.bg);x=x+1
    end
    g:text(3,16,'UPTIME '..math.floor(s.uptime or 0)..' sec',t.muted,t.bg,w-4)
  else
    local rows={
      {'GPU ID',s.gpuAddress}, {'Screen',s.screen},
      {'Current resolution',(s.resolutionW or '?')..' x '..(s.resolutionH or '?')},
      {'Max resolution',(s.maxW or '?')..' x '..(s.maxH or '?')},
      {'Color depth',tostring(s.depth or '?')..' bit'},
      {'Components',s.componentCount}, {'Graphics cards',s.gpuCount},
      {'Screens',s.screenCount}, {'Uptime',math.floor(s.uptime or 0)..' s'} }
    for i,row in ipairs(rows) do
      local y=i+4
      if y<h-2 then
        g:text(3,y,row[1],t.muted,t.bg,19)
        g:text(math.min(w,23),y,tostring(row[2] or '?'),t.text,t.bg,math.max(1,w-25))
      end
    end
  end
end
function M.input(a,ctx)
  local s=ctx.state.monitor
  if a.kind=='char' then
    local v=(a.value or ''):lower()
    if v=='1' or v=='2' then s.tab=tonumber(v);return true end
    if v=='r' then sample(ctx);return true end
  end
  if a.kind=='tab' or a.kind=='left' or a.kind=='right' then s.tab=3-s.tab;return true end
  return false
end
return M
