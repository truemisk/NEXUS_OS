local M={}
function M.mode(w,h,preference)
  if preference=='compact' then return 'compact' end
  if w>=52 and h>=20 then return 'standard' end
  return 'compact'
end
function M.header(g,t,w,title,mode)
  g:fill(1,1,w,2,t.surface)
  g:text(2,1,'NEXUS / WORKSPACE',t.accent,t.surface,w-2)
  g:text(2,2,title or 'DESKTOP',t.text,t.surface,w-2)
  if mode=='standard' then g:text(math.max(2,w-14),1,'v0.6.0 OPENOS',t.muted,t.surface,14) end
end
function M.taskbar(ctx)
  local g,t,s=ctx.gfx,ctx.theme,ctx.state
  local w,h=g:size()
  g:fill(1,h,w,1,t.surface)
  s.navboxes={}
  local names={{'HOME','home'},{'BACK','back'},{'EXIT','exit'},{'FILE','files'},{'TERM','terminal'},{'MON','monitor'},{'HW','hardwarecenter'},{'SYS','control'},{'SET','settings'},{'LOG','notifications'},{'UPD','updatecenter'}}
  local x=2
  for _,item in ipairs(names) do
    local label='['..item[1]..']'
    if x+#label < w-1 then
      g:text(x,h,label,t.accent,t.surface,#label)
      s.navboxes[#s.navboxes+1]={x=x,y=h,w=#label,id=item[2]}
      x=x+#label+1
    end
  end
  if w>=95 then
    local help='TAB / ARROWS / ENTER'
    g:text(math.max(x+1,w-#help-1),h,help,t.muted,t.surface,w-x-1)
  end
end
function M.frame(ctx,title)
  local g,t=ctx.gfx,ctx.theme
  local w,h=g:size()
  ctx.state.screenMode=M.mode(w,h,ctx.config.data.layout)
  g:fill(1,1,w,h,t.bg)
  M.header(g,t,w,title,ctx.state.screenMode)
  M.taskbar(ctx)
end
function M.action(g,t,x,y,w,h,title,subtitle,selected)
  local bg=selected and t.activeBg or t.surface
  local fg=selected and t.activeText or t.text
  g:fill(x,y,w,h,bg)
  g:text(x+1,y,selected and '> '..title or '  '..title,fg,bg,w-2)
  if h>=2 then g:text(x+2,y+1,subtitle or '',selected and t.activeText or t.muted,bg,w-3) end
end
function M.panel(g,t,x,y,w,h,label)
  if w<3 or h<2 then return end
  g:fill(x,y,w,h,t.surface)
  g:text(x+1,y,label,t.accent,t.surface,w-2)
end
function M.toast(ctx)
  local message=ctx.notices.current
  if not message then return end
  local g,t=ctx.gfx,ctx.theme
  local w,h=g:size()
  if h<8 then return end
  local item=message.item
  local color=item.kind=='error' and t.bad or item.kind=='warn' and t.warn or t.accent
  g:fill(1,h-1,w,1,t.surface)
  g:text(2,h-1,'! '..item.message,color,t.surface,w-3)
end
function M.preview(ctx)
  local pending=ctx.display.pending
  if not pending then return end
  local g,t=ctx.gfx,ctx.theme
  local w,h=g:size()
  if h<8 or w<20 then return end
  local pw=math.min(w-2,54)
  local ph=math.min(h-2,7)
  local x=math.floor((w-pw)/2)+1
  local y=math.floor((h-ph)/2)+1
  g:fill(x,y,pw,ph,t.surface)
  g:border(x,y,pw,ph,t.accent,t.surface)
  g:text(x+2,y+1,'CONFIRM RESOLUTION',t.accent,t.surface,pw-4)
  local remaining=math.max(0,math.ceil(pending.deadline-ctx.now()))
  g:text(x+2,y+2,pending.newW..' x '..pending.newH..'  |  '..remaining..' s left',t.text,t.surface,pw-4)
  g:text(x+2,y+4,'ENTER confirm / [BACK] cancel',t.good,t.surface,pw-4)
  g:text(x+2,y+5,'[BACK] cancel / timeout rollback',t.warn,t.surface,pw-4)
end

function M.exitDialog(ctx)
  if not ctx.state.exitPending then return end
  local g,t=ctx.gfx,ctx.theme
  local w,h=g:size();if w<22 or h<10 then return end
  local pw=math.min(w-2,46);local x=math.floor((w-pw)/2)+1;local y=math.max(3,math.floor((h-6)/2))
  g:fill(x,y,pw,6,t.surface);g:border(x,y,pw,6,t.warn,t.surface)
  g:text(x+2,y+1,'EXIT NEXUS TO OPENOS?',t.warn,t.surface,pw-4)
  g:text(x+2,y+3,'[YES] [NO]  or press Y / N',t.text,t.surface,pw-4)
  ctx.state.exitButtons={{x=x+2,y=y+3,w=5,id='yes'},{x=x+8,y=y+3,w=4,id='no'}}
end
return M
