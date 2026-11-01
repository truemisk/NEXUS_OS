local Widgets=require('nexus.ui.widgets')
local Theme=require('nexus.core.theme')
local M={id='settings',name='Settings',description='Themes, layout, display'}
local choices={auto='Auto',compact='Compact',standard='Standard'}
local layouts={'auto','compact','standard'}
local function rows(ctx)
  local c=ctx.config.data
  local ok,maxW,maxH=pcall(ctx.hardware.gpu.maxResolution)
  if not ok then maxW,maxH=ctx.native.w,ctx.native.h end
  local presets=ctx.display:presets(ctx.native.w,ctx.native.h,maxW,maxH)
  ctx.state.displayIndex=math.max(1,math.min(#presets,ctx.state.displayIndex))
  local selected=presets[ctx.state.displayIndex]
  return {
    {id='theme',label='Color theme',value=c.theme:upper()},
    {id='layout',label='Desktop density',value=choices[c.layout] or 'Auto'},
    {id='notifications',label='Toast notifications',value=c.notifications and 'ON' or 'OFF'},
    {id='splash',label='Boot splash',value=c.splash and 'ON' or 'OFF'},
    {id='logging',label='Persistent logs',value=c.logging and 'ON' or 'OFF'},
    {id='monitorService',label='RAM monitor service',value=(c.monitorService and ctx.services.items.memory.status=='RUNNING') and 'ON' or (c.monitorService and 'PAUSED' or 'OFF')},
    {id='resolution',label='Resolution target',value=selected.title..' '..selected.w..'x'..selected.h},
    {id='apply',label='PREVIEW DISPLAY',value='12s safe rollback'},
    {id='reset',label='Reset preferences',value='Default values'},
    {id='home',label='Return to desktop',value='Taskbar [HOME]'}
  },presets
end
function M.draw(ctx)
  local g,t,s=ctx.gfx,ctx.theme,ctx.state
  local w,h=g:size()
  Widgets.frame(ctx,'CONTROL CENTER / SETTINGS')
  g:text(2,3,'PREFERENCES   /   saved to disk',t.accent,t.bg,w-4)
  local list=rows(ctx)
  s.settingsSelection=math.max(1,math.min(#list,s.settingsSelection))
  local slots=math.max(1,math.floor((h-6)/2))
  if s.settingsSelection<s.settingsScroll+1 then s.settingsScroll=s.settingsSelection-1 end
  if s.settingsSelection>s.settingsScroll+slots then s.settingsScroll=s.settingsSelection-slots end
  s.settingsScroll=math.max(0,math.min(s.settingsScroll,math.max(0,#list-slots)))
  s.appHitboxes={}
  for slot=1,slots do
    local index=s.settingsScroll+slot
    local item=list[index]
    if item then
      local y=4+(slot-1)*2
      local sub=item.value
      Widgets.action(g,t,2,y,w-4,2,item.label,sub,index==s.settingsSelection)
      s.appHitboxes[#s.appHitboxes+1]={x=2,y=y,w=w-4,h=2,index=index}
    end
  end
  if h>=20 then g:text(3,h-3,'UP/DOWN select  LEFT/RIGHT change  ENTER activate',t.muted,t.bg,w-5) end
end
local function pick(list,old,dir)
  for i,value in ipairs(list) do if value==old then return list[(i-1+dir+#list)%#list+1] end end
  return list[1]
end
local function activate(ctx,item,dir)
  local c=ctx.config.data
  if item=='theme' then
    local themes=Theme.names
    ctx.changeSetting('theme',pick(themes,c.theme,dir))
  elseif item=='layout' then ctx.changeSetting('layout',pick(layouts,c.layout,dir))
  elseif item=='notifications' then ctx.changeSetting('notifications',not c.notifications)
  elseif item=='splash' then ctx.changeSetting('splash',not c.splash)
  elseif item=='logging' then ctx.changeSetting('logging',not c.logging)
  elseif item=='monitorService' then ctx.changeSetting('monitorService',not c.monitorService)
  elseif item=='resolution' then
    local _,presets=rows(ctx)
    ctx.state.displayIndex=(ctx.state.displayIndex-1+dir+#presets)%#presets+1
  elseif item=='apply' then ctx.beginResolution()
  elseif item=='reset' then ctx.resetSettings()
  elseif item=='home' then ctx.manager:home(ctx);ctx.session:home()
  end
end
function M.input(a,ctx)
  local s=ctx.state
  local list=rows(ctx)
  if a.kind=='up' then s.settingsSelection=math.max(1,s.settingsSelection-1); return true end
  if a.kind=='down' then s.settingsSelection=math.min(#list,s.settingsSelection+1); return true end
  if a.kind=='touch' then
    for _,b in ipairs(s.appHitboxes) do
      if a.x>=b.x and a.x<b.x+b.w and a.y>=b.y and a.y<b.y+b.h then
        s.settingsSelection=b.index
        activate(ctx,list[b.index].id,1)
        return true
      end
    end
  end
  if a.kind=='left' or a.kind=='right' or a.kind=='enter' then
    activate(ctx,list[s.settingsSelection].id,a.kind=='left' and -1 or 1)
    return true
  end
  return false
end
return M
