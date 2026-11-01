local Widgets=require('nexus.ui.widgets')
local M={id='system',name='System Info',description='Live component and RAM data'}
local function fmt(v) return v==nil and '?' or tostring(v) end
local function kb(n) return type(n)=='number' and math.floor(n/1024+0.5)..' KiB' or '?' end
function M.draw(ctx)
  local g,t=ctx.gfx,ctx.theme
  local w,h=g:size()
  local s=ctx.hardware:snapshot()
  Widgets.frame(ctx,'SYSTEM / LIVE HARDWARE')
  local rows={
    {'Display',fmt(s.resolutionW)..' x '..fmt(s.resolutionH)},
    {'Maximum',fmt(s.maxW)..' x '..fmt(s.maxH)},
    {'Depth',fmt(s.depth)..' bit'},
    {'Free RAM',kb(s.freeMemory)},
    {'Total RAM',kb(s.totalMemory)},
    {'Components',fmt(s.componentCount)},
    {'GPU count',fmt(s.gpuCount)},
    {'Active GPU',fmt(s.gpuAddress)},
    {'Screen count',fmt(s.screenCount)},
    {'Screen ID',fmt(s.screen)},
    {'Uptime',type(s.uptime)=='number' and math.floor(s.uptime)..' s' or '?'}
  }
  local x=(w>=52) and 4 or 2
  local labelWidth=(w>=52) and 19 or 14
  for i,row in ipairs(rows) do
    local y=i+3
    if y<h-1 then
      g:text(x,y,row[1],t.muted,t.bg,labelWidth-1)
      g:text(x+labelWidth,y,row[2],t.text,t.bg,w-x-labelWidth-1)
    end
  end
end
return M
