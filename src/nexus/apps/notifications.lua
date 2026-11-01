local Widgets=require('nexus.ui.widgets')
local M={id='notifications',name='Notifications',description='Recent system messages'}
function M.draw(ctx)
  local g,t,s=ctx.gfx,ctx.theme,ctx.state
  local w,h=g:size()
  Widgets.frame(ctx,'NOTIFICATIONS / HISTORY')
  local list=ctx.notices.history
  g:text(3,4,'RECENT MESSAGES  ('..#list..'/8)',t.accent,t.bg,w-4)
  local slots=math.max(1,h-8)
  if s.notificationScroll>math.max(0,#list-slots) then s.notificationScroll=math.max(0,#list-slots) end
  for j=1,slots do
    local item=list[j+s.notificationScroll]
    if item then
      local color=item.kind=='error' and t.bad or item.kind=='warn' and t.warn or t.text
      g:text(3,5+j,math.floor(item.at)..'s  '..item.message,color,t.bg,w-5)
    end
  end
  if #list==0 then g:text(3,6,'No messages recorded.',t.muted,t.bg,w-5) end
  if h>=10 then g:text(3,h-3,'UP/DOWN scroll   ENTER clear history',t.muted,t.bg,w-5) end
end
function M.input(a,ctx)
  local s=ctx.state
  local visible=math.max(1,select(2,ctx.gfx:size())-8)
  if a.kind=='up' then s.notificationScroll=math.max(0,s.notificationScroll-1); return true end
  if a.kind=='down' then s.notificationScroll=math.min(math.max(0,#ctx.notices.history-visible),s.notificationScroll+1); return true end
  if a.kind=='enter' then
    ctx.notices.history={};ctx.notices.current=nil;s.notificationScroll=0
    return true
  end
  return false
end
return M
