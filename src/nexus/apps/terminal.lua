local Widgets=require('nexus.ui.widgets')
local Console=require('nexus.core.console')
local M={id='terminal',name='NEXUS Terminal',description='Commands and OpenOS handoff'}
function M.open(ctx)
  local ok,fs=pcall(require,'filesystem')
  fs=ctx.fs or (ok and fs)
  if not fs then error('OpenOS filesystem library unavailable') end
  ctx.state.terminal=Console.new(fs)
end
function M.close(ctx) ctx.state.terminal=nil end
function M.draw(ctx)
  local g,t=ctx.gfx,ctx.theme
  local w,h=g:size()
  Widgets.frame(ctx,'TERMINAL / OPENOS')
  local s=ctx.state.terminal
  g:text(2,3,'BUILT-INS: help  cd  ls  cat  mem  /  run COMMAND',t.accent,t.bg,w-3)
  local limit=math.max(1,h-7)
  local first=math.max(1,#s.lines-limit+1)
  local row=4
  for i=first,#s.lines do
    g:text(2,row,s.lines[i],t.text,t.bg,w-3)
    row=row+1
  end
  g:fill(1,h-2,w,1,t.surface)
  local prefix=s.cwd..' > '
  local avail=math.max(1,w-#prefix-4)
  local start=math.max(1,s.cursor-avail+1)
  local value=s.buffer:sub(start,start+avail-1)
  g:text(2,h-2,prefix,t.accent,t.surface,w-3)
  g:text(math.min(w,2+#prefix),h-2,value,t.text,t.surface,avail)
  g:text(2,h-1,'ENTER RUN  UP HISTORY  [BACK] DESKTOP',t.muted,t.bg,w-3)
end
function M.input(a,ctx)
  local s=ctx.state.terminal
  if a.kind=='enter' then
    local input=s.buffer;s.buffer='';s.cursor=1
    s:execute(input,ctx)
    return true
  end
  return s:key(a)
end
return M
