-- Hardware & Automation: real OC data, explicit writes, no VAULT inventory logic.
local Widgets=require('nexus.ui.widgets')
local M={id='hardwarecenter',name='Hardware Center',description='Devices, redstone and automation'}
local function current(ctx) return ctx.state.hwCenter end
local tabs={'[1:DEVICES]','[2:REDSTONE]','[3:AUTOMATION]','[4:EVENTS]','[5:DIAGNOSTICS]'}
local function note(ctx,msg,kind)
  local s=current(ctx)
  s.message=tostring(msg or ''):sub(1,110)
  if kind and ctx.notify then ctx.notify(s.message,kind) end
end
local function devices(ctx) return ctx.deviceControl:list() end
local function redstones(ctx) return ctx.deviceControl:redstones() end
local function rsChoice(ctx)
  local s=current(ctx);local list=redstones(ctx)
  if #list==0 then return nil,0 end
  s.redIndex=math.max(1,math.min(s.redIndex,#list))
  return list[s.redIndex],#list
end
function M.open(ctx)
  ctx.state.hwCenter={tab=1,index=1,scroll=0,deviceIndex=1,redIndex=1,side=0,level=15,
    inputSide=0,outputSide=1,confirm=nil,message='',hits={},inspect=false}
end
function M.close(ctx) ctx.state.hwCenter=nil end
local function actionRows(ctx)
  local s=current(ctx)
  if s.tab==2 then return {'CHANGE CARD','SELECT SIDE','SIGNAL 0 / 15','APPLY OUTPUT','REFRESH SIGNAL'} end
  if s.tab==3 then return {'CHANGE CARD','INPUT SIDE','OUTPUT SIDE','ENABLE MIRROR','DISABLE MIRROR','EMERGENCY STOP'} end
  if s.tab==4 then return {'CLEAR EVENT HISTORY','REFRESH EVENTS'} end
  return {}
end
local function doAction(ctx,id)
  local s=current(ctx)
  local rs=rsChoice(ctx)
  if s.tab==2 then
    if id==1 then local _,n=rsChoice(ctx);if n>0 then s.redIndex=s.redIndex%n+1 end
    elseif id==2 then s.side=(s.side+1)%6
    elseif id==3 then s.level=(s.level==0) and 15 or 0
    elseif id==4 then
      if not rs then note(ctx,'No Redstone Card / I/O block found','warn');return end
      if ctx.automation.enabled and ctx.automation.address==rs.address and ctx.automation.outputSide==s.side then
        note(ctx,'Stop mirror before changing its output','warn');return end
      s.confirm={kind='write',address=rs.address,side=s.side,level=s.level}
    elseif id==5 then note(ctx,'Refreshed live input and output') end
  elseif s.tab==3 then
    if id==1 then local _,n=rsChoice(ctx);if n>0 then s.redIndex=s.redIndex%n+1 end
    elseif id==2 then s.inputSide=(s.inputSide+1)%6
    elseif id==3 then s.outputSide=(s.outputSide+1)%6
    elseif id==4 then
      if not rs then note(ctx,'No Redstone device found','warn');return end
      if ctx.automation.enabled then note(ctx,'Disable current mirror first','warn');return end
      if s.inputSide==s.outputSide then note(ctx,'Input and output sides must differ','warn');return end
      s.confirm={kind='mirror',address=rs.address,inputSide=s.inputSide,outputSide=s.outputSide}
    elseif id==5 then local ok,why=ctx.automation:disable();note(ctx,why or 'Mirror disabled',ok and 'info' or 'error')
    elseif id==6 then s.confirm={kind='stop'} end
  elseif s.tab==4 then
    if id==1 then ctx.hwEvents:clear();s.scroll=0;note(ctx,'Event history cleared')
    elseif id==2 then note(ctx,'Live events refreshed') end
  end
end
local function confirm(ctx)
  local s=current(ctx);local pending=s.confirm;s.confirm=nil
  if not pending then return end
  local ok,why
  if pending.kind=='write' then
    ok,why=ctx.deviceControl:write(pending.address,pending.side,pending.level)
  elseif pending.kind=='mirror' then
    ok,why=ctx.automation:enable(pending.address,pending.inputSide,pending.outputSide)
    if ok then why='Mirror ENABLED (session only)' end
  elseif pending.kind=='stop' then
    local restored,err,count=ctx.automation:emergencyStop();ok=restored
    why=restored and ('Stopped; restored '..count..' outputs') or ('Stop incomplete: '..tostring(err))
  end
  note(ctx,why or 'Operation complete',ok and 'info' or 'error')
end
local function put(ctx,x,y,label,color,max)
  local g,t=ctx.gfx,ctx.theme
  g:text(x,y,label,color or t.text,t.bg,max)
end
local function screenTitle(ctx)
  local t,s=ctx.theme,current(ctx)
  local w,h=ctx.gfx:size()
  Widgets.frame(ctx,'HARDWARE / '..({'DEVICES','REDSTONE','AUTOMATION','EVENTS','DIAGNOSTICS'})[s.tab])
  s.hits={}
  local x=2
  for idx,title in ipairs(tabs) do
    if x+#title>=w then break end
    ctx.gfx:text(x,3,title,idx==s.tab and t.activeText or t.accent,idx==s.tab and t.activeBg or t.bg,#title)
    s.hits[#s.hits+1]={x=x,y=3,w=#title,h=1,tab=idx}
    x=x+#title+1
  end
end
local function drawRows(ctx,rows,startY)
  local s=current(ctx);local g,t=ctx.gfx,ctx.theme;local w,h=g:size()
  for i,row in ipairs(rows) do
    local y=startY+(i-1)*2
    if y<=h-5 then
      Widgets.action(g,t,2,y,w-4,1,row,'',s.index==i)
      s.hits[#s.hits+1]={x=2,y=y,w=w-4,h=1,act=i}
    end
  end
end
function M.draw(ctx)
  local s=current(ctx);local g,t=ctx.gfx,ctx.theme
  local w,h=g:size();screenTitle(ctx)
  if w<32 or h<15 then put(ctx,2,5,'Increase display size (min 32x15)',t.warn,w-3);return end
  if s.tab==1 then
    local list,err=devices(ctx)
    local count=#list
    put(ctx,2,5,'DETECTED '..count..' COMPONENTS  /  UP DOWN SELECT  /  R RESCAN',t.accent,w-3)
    if count==0 then put(ctx,2,7,err or 'No components found',t.warn,w-3)
    else
      s.deviceIndex=math.max(1,math.min(s.deviceIndex,count))
      if s.inspect then
        local chosen=list[s.deviceIndex]
        if chosen then
          put(ctx,2,7,'DEVICE '..chosen.kind,t.accent,w-3)
          put(ctx,2,8,'ADDRESS '..chosen.address,t.text,w-3)
          local methods,why=ctx.deviceControl:methods(chosen.address)
          put(ctx,2,10,methods and ('EXPOSED METHODS '..#methods) or tostring(why),t.muted,w-3)
          if methods then
            for j=1,math.min(#methods,h-14) do put(ctx,3,10+j,methods[j],t.text,w-5) end
          end
          put(ctx,2,h-3,'[BACK] returns to hardware list',t.muted,w-3)
        end
        return
      end
      local slots=h-11
      if s.deviceIndex<=s.scroll then s.scroll=s.deviceIndex-1 end
      if s.deviceIndex>s.scroll+slots then s.scroll=s.deviceIndex-slots end
      for j=1,slots do
        local i=s.scroll+j;local d=list[i]
        if d then
          local y=6+j;local selected=i==s.deviceIndex
          g:fill(2,y,w-4,1,selected and t.activeBg or t.bg)
          g:text(3,y,(selected and '> ' or '  ')..d.kind..'  '..d.address:sub(1,18),selected and t.activeText or t.text,selected and t.activeBg or t.bg,w-6)
          s.hits[#s.hits+1]={x=2,y=y,w=w-4,h=1,dev=i}
        end
      end
      local chosen=list[s.deviceIndex]
      if chosen then
        put(ctx,2,h-3,'SELECTED '..chosen.kind..'  '..chosen.address,t.muted,w-3)
      end
    end
  elseif s.tab==2 then
    local rs,n=rsChoice(ctx)
    put(ctx,2,5,'REDSTONE DEVICES: '..n..' / DEFAULT READ ONLY',t.accent,w-3)
    if not rs then put(ctx,2,7,'No Redstone Card detected. Install one to enable controls.',t.warn,w-3)
    else
      put(ctx,2,6,'CARD '..s.redIndex..'/'..n..'  '..rs.address:sub(1,16),t.text,w-3)
      local read,err=ctx.deviceControl:read(rs.address,s.side)
      put(ctx,2,7,'SIDE '..s.side..' '..ctx.deviceControl.SIDES[s.side+1]..'  INPUT '..(read and read.input or '?')..'  OUTPUT '..(read and read.output or '?'),read and t.good or t.warn,w-3)
      if not read then put(ctx,2,8,tostring(err),t.warn,w-3) end
    end
    drawRows(ctx,{'CHANGE CARD','SELECT SIDE: '..ctx.deviceControl.SIDES[s.side+1],
      'TARGET SIGNAL: '..s.level,'APPLY OUTPUT (CONFIRM)','REFRESH READINGS'},9)
  elseif s.tab==3 then
    local rs,n=rsChoice(ctx)
    put(ctx,2,5,'MIRROR INPUT -> OUTPUT / OFF AT BOOT',t.accent,w-3)
    put(ctx,2,6,'STATUS '..(ctx.automation.enabled and 'ACTIVE' or 'DISABLED')..'  WRITES '..ctx.automation.updates,ctx.automation.enabled and t.good or t.muted,w-3)
    put(ctx,2,7,rs and ('CARD '..s.redIndex..'/'..n..' '..rs.address:sub(1,12)) or 'NO REDSTONE DEVICE',rs and t.text or t.warn,w-3)
    if ctx.automation.error then put(ctx,2,8,'LAST ERROR '..tostring(ctx.automation.error),t.warn,w-3) end
    drawRows(ctx,{'CHANGE CARD','INPUT: '..ctx.deviceControl.SIDES[s.inputSide+1],
      'OUTPUT: '..ctx.deviceControl.SIDES[s.outputSide+1],
      'ENABLE MIRROR (CONFIRM)','DISABLE MIRROR','EMERGENCY RESTORE'},9)
  elseif s.tab==4 then
    put(ctx,2,5,'LIVE OC SIGNALS / '..#ctx.hwEvents.items..' IN BUFFER',t.accent,w-3)
    local max=math.max(1,h-11)
    s.scroll=math.min(s.scroll,math.max(0,#ctx.hwEvents.items-max))
    if #ctx.hwEvents.items==0 then put(ctx,2,7,'No events observed during this NEXUS session',t.muted,w-3) end
    for j=1,max do
      local ev=ctx.hwEvents.items[s.scroll+j]
      if ev then
        local suffix=ev.side and (' side '..ev.side) or ''
        if type(ev.new)=='number' then suffix=suffix..' -> '..ev.new end
        put(ctx,2,6+j,ev.at..'s '..ev.kind..' '..ev.address..suffix,t.text,w-3)
      end
    end
    put(ctx,2,h-3,'ARROWS SCROLL / [CLEAR] clears session history',t.muted,w-3)
    g:text(math.max(2,w-13),h-2,'[CLEAR EVENTS]',t.accent,t.bg,14)
    s.hits[#s.hits+1]={x=math.max(2,w-13),y=h-2,w=14,h=1,act=1}
  elseif s.tab==5 then
    local list=devices(ctx);local hs=ctx.hardware:snapshot();local rs=redstones(ctx)
    local grouped={};for _,d in ipairs(list) do grouped[d.kind]=(grouped[d.kind] or 0)+1 end
    local lines={
      'DEVICE COUNT '..#list..'   REDSTONE '..#rs,
      'GPU '..tostring(hs.gpuAddress or '?'):sub(1,23),
      'SCREEN '..tostring(hs.screenAddress or ctx.hardware.screen or '?'):sub(1,22),
      'RESOLUTION '..tostring(hs.resolutionW or '?')..'x'..tostring(hs.resolutionH or '?')..'  DEPTH '..tostring(hs.depth or '?'),
      'FREE RAM '..(type(hs.freeMemory)=='number' and math.floor(hs.freeMemory/1024)..' KiB' or '?'),
      'MIRROR '..(ctx.automation.enabled and 'ENABLED' or 'DISABLED')..'  OWNED OUTPUTS '..(function()local n=0;for _ in pairs(ctx.deviceControl.owned) do n=n+1 end;return n end)(),
    }
    local types={};for name,n in pairs(grouped) do types[#types+1]=name..' x'..n end
    table.sort(types)
    for _,line in ipairs(types) do if #lines<h-9 then lines[#lines+1]=line end end
    put(ctx,2,5,'ACTUAL HARDWARE / NO EMULATED VALUES',t.accent,w-3)
    for i,line in ipairs(lines) do if 6+i<h-3 then put(ctx,3,6+i,line,t.text,w-5) end end
  end
  if s.message~='' and s.tab~=1 and s.tab~=4 then put(ctx,2,h-3,s.message,t.warn,w-3) end
  if s.confirm then
    g:fill(2,h-7,w-4,5,t.surface)
    g:border(2,h-7,w-4,5,t.warn,t.surface)
    local label=s.confirm.kind=='write' and ('WRITE OUTPUT '..s.confirm.level..' TO SIDE '..s.confirm.side) or
        (s.confirm.kind=='mirror' and 'ENABLE LIVE MIRROR?' or 'RESTORE ALL OWNED OUTPUTS?')
    g:text(4,h-6,'CONFIRM: '..label,t.warn,t.surface,w-8)
    g:text(4,h-4,'[YES] [NO]   /   Y or N',t.text,t.surface,w-8)
    s.hits[#s.hits+1]={x=4,y=h-4,w=5,h=1,answer=true}
    s.hits[#s.hits+1]={x=10,y=h-4,w=4,h=1,answer=false}
  end
end
function M.input(a,ctx)
  local s=current(ctx)
  if a.kind=='back' and s.confirm then s.confirm=nil;return true end
  if s.confirm then
    if a.kind=='char' and a.value:lower()=='y' then confirm(ctx);return true end
    if a.kind=='char' and a.value:lower()=='n' then s.confirm=nil;return true end
    if a.kind=='touch' then
      for _,hit in ipairs(s.hits) do
        if hit.answer~=nil and a.x>=hit.x and a.x<hit.x+hit.w and a.y==hit.y then
          if hit.answer then confirm(ctx) else s.confirm=nil end
          return true
        end
      end
    end
    return true
  end
  if a.kind=='char' and a.value:match('^[1-5]$') then
    s.tab=tonumber(a.value);s.index=1;s.scroll=0;s.inspect=false;return true
  end
  if a.kind=='touch' then
    for _,hit in ipairs(s.hits) do
      if a.x>=hit.x and a.x<hit.x+hit.w and a.y>=hit.y and a.y<hit.y+hit.h then
        if hit.tab then s.tab=hit.tab;s.index=1;s.scroll=0;s.inspect=false
        elseif hit.dev then s.deviceIndex=hit.dev;s.inspect=true
        elseif hit.act then s.index=hit.act;doAction(ctx,hit.act) end
        return true
      end
    end
    return false
  end
  if s.tab==1 then
    local ds=devices(ctx)
    if a.kind=='back' and s.inspect then s.inspect=false;return true end
    if a.kind=='enter' and #ds>0 then s.inspect=not s.inspect;return true end
    if a.kind=='up' and not s.inspect then s.deviceIndex=math.max(1,s.deviceIndex-1);return true end
    if a.kind=='down' and not s.inspect then s.deviceIndex=math.min(#ds,s.deviceIndex+1);return true end
    if a.kind=='char' and a.value:lower()=='r' then note(ctx,'Component list refreshed');return true end
  elseif s.tab==4 then
    if a.kind=='up' then s.scroll=math.max(0,s.scroll-1);return true end
    if a.kind=='down' then s.scroll=math.min(#ctx.hwEvents.items,s.scroll+1);return true end
    if a.kind=='enter' then doAction(ctx,1);return true end
  else
    local rows=actionRows(ctx)
    if a.kind=='up' then s.index=math.max(1,s.index-1);return true end
    if a.kind=='down' then s.index=math.min(#rows,s.index+1);return true end
    if a.kind=='enter' and #rows>0 then doAction(ctx,s.index);return true end
  end
  return false
end
return M
