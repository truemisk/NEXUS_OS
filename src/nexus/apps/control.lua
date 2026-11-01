-- System Center: cooperative services, persistent logs, diagnostics, session, recovery.
local Widgets=require('nexus.ui.widgets')
local Diagnostics=require('nexus.core.diagnostics')
local M={id='control',name='System Center',description='Services, logs, recovery, diagnostics'}
local tabs={'SERVICES','LOGS','DIAGNOSTICS','SESSION','RECOVERY'}
local function ui(ctx)return ctx.state.control end
function M.open(ctx)
  ctx.state.control={tab=1,index=1,scroll=0,hits={}}
  ctx.logger:log('INFO','ui','Opened System Center')
end
function M.close(ctx)ctx.state.control=nil end
local function getRows(ctx)
  local s=ui(ctx);local rows={}
  if s.tab==1 then
    for _,svc in ipairs(ctx.services.ordered) do
      rows[#rows+1]={label=svc.id:upper()..' / '..svc.status,
        detail='period '..svc.interval..'s  runs '..svc.runs..(svc.essential and '  [CORE]' or ''),id=svc.id}
    end
  elseif s.tab==2 then
    for _,log in ipairs(ctx.logger.rows) do
      rows[#rows+1]={label=log.at..' '..log.level..' / '..log.category,detail=log.message}
    end
  elseif s.tab==3 then
    for _,check in ipairs(Diagnostics.run(ctx)) do
      rows[#rows+1]={label=(check.ok and '[OK] ' or '[!!] ')..check.id,detail=check.detail}
    end
  elseif s.tab==4 then
    local sess=ctx.session
    rows={{label='CURRENT VIEW',detail=sess.current},{label='LAST APP',detail=sess.lastApp},
      {label='APPLICATION LAUNCHES',detail=tostring(sess.opened)},
      {label='NAVIGATION EVENTS',detail=tostring(sess.transitions)},
      {label='SESSION AGE',detail=math.floor(ctx.now()-sess.started)..'s'},
      {label='FREE RAM',detail=tostring(math.floor((ctx.performance.lastFree or 0)/1024))..' KiB'},
      {label='RECORDED REDRAWS',detail=tostring(ctx.state.redraws)}}
  else
    rows={{label='PREVIOUS SESSION',detail=ctx.recovery.unclean and 'UNCLEAN EXIT DETECTED' or 'CLEAN / NO HISTORY'},
      {label='PROTECTED RECOVERY',detail='App crashes return to desktop'},
      {label='LOG STORAGE',detail=ctx.logger.diskStatus},
      {label='GPU RESTORE',detail='On NEXUS normal exit or fatal error'}}
    for _,entry in ipairs(ctx.recovery.recent) do
      rows[#rows+1]={label='ERROR / '..entry.area,detail=entry.message}
    end
  end
  return rows
end
function M.draw(ctx)
  local g,t,s=ctx.gfx,ctx.theme,ui(ctx)
  local w,h=g:size();Widgets.frame(ctx,'SYSTEM CENTER / '..tabs[s.tab])
  s.hits={};local x=2
  for i,name in ipairs(tabs) do
    local label='['..i..':'..name..']'
    if x+#label<=w-1 then
      g:text(x,3,label,i==s.tab and t.activeText or t.accent,i==s.tab and t.activeBg or t.bg,#label)
      s.hits[#s.hits+1]={x=x,y=3,w=#label,tab=i};x=x+#label+1
    end
  end
  local rows=getRows(ctx)
  s.index=math.max(1,math.min(#rows,s.index));local slots=math.max(1,math.floor((h-9)/2))
  if s.index<s.scroll+1 then s.scroll=s.index-1 end
  if s.index>s.scroll+slots then s.scroll=s.index-slots end
  s.scroll=math.max(0,math.min(s.scroll,math.max(0,#rows-slots)))
  for slot=1,slots do
    local idx=s.scroll+slot;local line=rows[idx]
    if line then
      local y=5+(slot-1)*2
      Widgets.action(g,t,2,y,w-4,2,line.label,line.detail,idx==s.index)
      s.hits[#s.hits+1]={x=2,y=y,w=w-4,h=2,row=idx}
    end
  end
  local hint=s.tab==1 and 'ENTER/CLICK START-STOP OPTIONAL SERVICES' or '1-5 TABS / ARROWS SCROLL'
  g:text(2,h-2,hint..'  [BACK] or [HOME]',t.muted,t.bg,w-3)
end
local function selectTab(s,index)
  s.tab=index;s.index=1;s.scroll=0
end
local function operate(ctx)
  local s=ui(ctx)
  if s.tab~=1 then return false end
  local row=getRows(ctx)[s.index];if not row then return false end
  local service=ctx.services.items[row.id]
  if not service then return false end
  local ok,why
  if service.status=='RUNNING' then ok,why=ctx.services:deactivate(service.id,ctx)
  else ok,why=ctx.services:activate(service.id,ctx,ctx.now()) end
  ctx.notify(ok and ('Service '..service.id..': '..service.status) or tostring(why),ok and 'info' or 'warn')
  return true
end
function M.input(a,ctx)
  local s=ui(ctx)
  if a.kind=='char' and (a.value or ''):match('^[1-5]$') then selectTab(s,tonumber(a.value));return true end
  if a.kind=='left' then selectTab(s,s.tab==1 and 5 or s.tab-1);return true end
  if a.kind=='right' then selectTab(s,s.tab==5 and 1 or s.tab+1);return true end
  if a.kind=='up' then s.index=math.max(1,s.index-1);return true end
  if a.kind=='down' then s.index=math.min(#getRows(ctx),s.index+1);return true end
  if a.kind=='enter' then return operate(ctx) end
  if a.kind=='touch' then
    for _,hit in ipairs(s.hits) do
      if a.x>=hit.x and a.x<hit.x+hit.w and a.y>=hit.y and a.y<hit.y+(hit.h or 1) then
        if hit.tab then selectTab(s,hit.tab) else
          s.index=hit.row;if s.tab==1 then operate(ctx) end
        end
        return true
      end
    end
  end
  return false
end
return M
