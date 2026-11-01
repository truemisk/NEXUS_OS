local Widgets=require('nexus.ui.widgets')
local M={id='about',name='About NEXUS',description='Version and architecture'}
function M.draw(ctx)
  local g,t=ctx.gfx,ctx.theme
  local w,h=g:size()
  Widgets.frame(ctx,'ABOUT / NEXUS')
  local lines={
    'NEXUS OS',
    'Core v0.6.4  |  GitHub Update Center',
    '',
    'Graphical environment for OpenComputers.',
    'Runs on OpenOS, without BIOS modifications.',
    'One foreground application; no multitasking.',
    'File Manager, Terminal, and System Monitor.',
    '1-9 quick launch; TAB selects other apps.',
    '[BACK] and [HOME] are clickable.',
    '',
    '[EXIT] confirms OpenOS return. Autostart opt-in.'
  }
  for i,line in ipairs(lines) do
    local y=i+3
    if y<h-1 then g:text(w>=52 and 4 or 2,y,line,i==1 and t.accent or t.text,t.bg,w-5) end
  end
end
return M
