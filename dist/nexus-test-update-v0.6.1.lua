-- NEXUS OS Core v0.6.1 | Phase 5B | OpenOS (Lua 5.3)
-- NEXUS-DISTRIBUTION: 1
-- NEXUS-VERSION: 0.6.1
-- Modular source layout: see README.md
-- Single-file distribution: startup remains opt-in; never edits boot files.

package.preload["nexus.apps.about"] = function(...)
local Widgets=require('nexus.ui.widgets')
local M={id='about',name='About NEXUS',description='Version and architecture'}
function M.draw(ctx)
  local g,t=ctx.gfx,ctx.theme
  local w,h=g:size()
  Widgets.frame(ctx,'ABOUT / NEXUS')
  local lines={
    'NEXUS OS',
    'Core v0.6.1  |  Phase 5B: Hardware',
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
end

package.preload["nexus.apps.control"] = function(...)
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
end

package.preload["nexus.apps.files"] = function(...)
-- NEXUS File Manager: real filesystem, explicit confirmation for mutations.
local Widgets=require('nexus.ui.widgets')
local Path=require('nexus.core.path')
local Ops=require('nexus.core.fileops')
local M={id='files',name='File Manager',description='Browse, copy, move and organize'}
local function selfState(ctx) return ctx.state.files end
local function actionResult(ctx,ok,err,verb)
  ctx.notify(ok and (verb..' complete') or (verb..': '..tostring(err or 'failed')),ok and 'info' or 'error')
end
local function refresh(ctx,keep)
  local s=selfState(ctx)
  local items,overflow=s.ops:list(s.cwd)
  if not items then ctx.notify('Browse: '..tostring(overflow),'error');return false end
  local prev=keep and s.items[s.selected] and s.items[s.selected].name
  s.items=items;s.truncated=overflow
  if prev then for i,v in ipairs(items) do if v.name==prev then s.selected=i;break end end end
  s.selected=math.max(1,math.min(#items,s.selected));s.scroll=0
  return true
end
function M.open(ctx)
  local s={cwd='/home',items={},selected=1,scroll=0,mode='browse',text='',cursor=1,
    preview={},previewScroll=0,clip=nil,hitboxes={},toolbar={}}
  local ok,fs=pcall(require,'filesystem')
  fs=(ctx.fs or (ok and fs))
  if not fs then error('OpenOS filesystem library unavailable') end
  s.ops=Ops.new(fs)
  ctx.state.files=s
  refresh(ctx)
end
function M.close(ctx) ctx.state.files=nil end
local function selected(s) return s.items[s.selected] end
local function openItem(ctx)
  local s=selfState(ctx);local item=selected(s)
  if not item then return end
  if item.dir then s.cwd=item.path;s.selected=1;refresh(ctx)
  else
    local lines,err=s.ops:preview(item.path)
    if lines then s.preview=lines;s.previewScroll=0;s.mode='preview';s.previewName=item.name
    else ctx.notify('Preview: '..tostring(err),'warn') end
  end
end
local function goUp(ctx)
  local s=selfState(ctx)
  if s.cwd~='/' then s.cwd=Path.parent(s.cwd);s.selected=1;refresh(ctx) end
end
local function beginRename(ctx)
  local s=selfState(ctx);local item=selected(s)
  if not item then return end
  s.mode='rename';s.text=item.name;s.cursor=#s.text+1
end
local function beginDelete(ctx)
  local s=selfState(ctx);local item=selected(s)
  if not item then return end
  local ok,err=Path.mutable(item.path)
  if not ok then ctx.notify(err,'warn');return end
  s.mode='delete'
end
local function paste(ctx)
  local s=selfState(ctx)
  local clip=s.clip
  if not clip then ctx.notify('Clipboard empty','warn');return end
  local dest=Path.join(s.cwd,Path.name(clip.path))
  local ok,err
  if clip.move then ok,err=s.ops:move(clip.path,dest) else ok,err=s.ops:copy(clip.path,dest) end
  if ok and clip.move then s.clip=nil end
  actionResult(ctx,ok,err,clip.move and 'Move' or 'Copy')
  refresh(ctx)
end
local function operate(ctx,kind)
  local s=selfState(ctx);local item=selected(s)
  if kind=='up' then goUp(ctx)
  elseif kind=='refresh' then refresh(ctx,true)
  elseif kind=='open' then openItem(ctx)
  elseif kind=='copy' or kind=='move' then
    if not item then return end
    if kind=='copy' and item.dir then ctx.notify('Folder copy not available','warn');return end
    s.clip={path=item.path,move=(kind=='move')}
    ctx.notify(kind:upper()..' staged: '..item.name,'info')
  elseif kind=='paste' then paste(ctx)
  elseif kind=='rename' then beginRename(ctx)
  elseif kind=='delete' then beginDelete(ctx)
  elseif kind=='mkdir' then s.mode='mkdir';s.text='';s.cursor=1
  end
end
local buttons={{'OPEN','open'},{'UP','up'},{'COPY','copy'},{'MOVE','move'},
  {'PASTE','paste'},{'RENAME','rename'},{'DELETE','delete'},{'NEW DIR','mkdir'}}
function M.draw(ctx)
  local g,t,s=ctx.gfx,ctx.theme,selfState(ctx)
  local w,h=g:size()
  Widgets.frame(ctx,'FILES / '..s.cwd)
  g:text(2,3,'PATH  '..s.cwd,t.accent,t.bg,w-3)
  local info=s.ops:info(s.cwd)
  if w>=58 and type(info.spaceTotal)=='number' and type(info.spaceUsed)=='number' then
    g:text(2,4,string.format('DISK %dK/%dK   %s',math.floor(info.spaceUsed/1024),
      math.floor(info.spaceTotal/1024),info.isReadOnly and 'READ ONLY' or 'WRITABLE'),t.muted,t.bg,w-3)
  else g:text(2,4,'DIRS FIRST  /  '..#s.items..(s.truncated and '+' or '')..' ENTRIES',t.muted,t.bg,w-3) end
  s.hitboxes={};s.toolbar={}
  if s.mode=='preview' then
    g:text(2,5,'VIEW '..s.previewName..' / max 3 KiB',t.accent,t.bg,w-3)
    local count=math.max(1,h-9)
    for i=1,count do
      local v=s.preview[i+s.previewScroll]
      if v then g:text(2,5+i,v,t.text,t.bg,w-3) end
    end
    g:text(2,h-2,'UP/DOWN SCROLL  [BACK] RETURN',t.muted,t.bg,w-3)
    return
  end
  local maxRows=math.max(1,h-11)
  if s.selected<s.scroll+1 then s.scroll=s.selected-1 end
  if s.selected>s.scroll+maxRows then s.scroll=s.selected-maxRows end
  s.scroll=math.max(0,math.min(s.scroll,math.max(0,#s.items-maxRows)))
  if #s.items==0 then g:text(3,7,'(Empty folder)',t.muted,t.bg,w-5) end
  for j=1,maxRows do
    local index=j+s.scroll;local item=s.items[index]
    if item then
      local y=5+j;local marked=index==s.selected
      local bg=marked and t.activeBg or t.bg
      local fg=marked and t.activeText or t.text
      g:fill(2,y,w-3,1,bg)
      local typeName=item.dir and '[DIR]' or '[FILE]'
      local suffix=not item.dir and ('  '..math.floor(item.size/1024+0.5)..'K') or ''
      g:text(3,y,typeName..' '..item.name,fg,bg,math.max(4,w-11-#suffix))
      if w>=24 then g:text(w-8,y,suffix,t.muted,bg,7) end
      s.hitboxes[#s.hitboxes+1]={x=2,y=y,w=w-3,index=index}
    end
  end
  local barY=h-4;local x=2
  for _,b in ipairs(buttons) do
    local label='['..b[1]..']'
    if x+#label<=w then
      g:text(x,barY,label,t.accent,t.bg,#label)
      s.toolbar[#s.toolbar+1]={x=x,y=barY,w=#label,id=b[2]}
      x=x+#label+1
    end
  end
  if s.clip then g:text(2,h-3,'CLIP: '..(s.clip.move and 'MOVE ' or 'COPY ')..s.clip.path,t.muted,t.bg,w-3) end
  g:text(2,h-2,'ENTER OPEN  BACKSPACE UP  C/X/V/R/D/N  [BACK]',t.muted,t.bg,w-3)
  if s.mode=='delete' or s.mode=='rename' or s.mode=='mkdir' then
    local pw=math.max(15,math.min(w-2,52));local x=math.floor((w-pw)/2)+1
    local y=math.max(3,math.floor(h/2)-2)
    g:fill(x,y,pw,6,t.surface);g:border(x,y,pw,6,t.accent,t.surface)
    local label=s.mode=='delete' and 'DELETE SELECTED ITEM?' or (s.mode=='rename' and 'RENAME ITEM' or 'CREATE FOLDER')
    g:text(x+2,y+1,label,t.accent,t.surface,pw-4)
    if s.mode=='delete' then
      local entry=selected(s)
      g:text(x+2,y+2,entry and entry.name or '(none)',t.warn,t.surface,pw-4)
      g:text(x+2,y+4,'Y confirm  N/[BACK] cancel',t.text,t.surface,pw-4)
    else
      g:text(x+2,y+2,s.text..'_',t.text,t.surface,pw-4)
      g:text(x+2,y+4,'ENTER save / [BACK] cancel',t.muted,t.surface,pw-4)
    end
  end
end
local function editText(s,a)
  if a.kind=='char' or a.kind=='paste' then
    local str=(a.value or ''):gsub('[\r\n]',''):gsub('[%c]','')
    str=str:sub(1,math.max(0,100-#s.text))
    s.text=s.text:sub(1,s.cursor-1)..str..s.text:sub(s.cursor)
    s.cursor=s.cursor+#str
  elseif a.kind=='backspace' and s.cursor>1 then
    s.text=s.text:sub(1,s.cursor-2)..s.text:sub(s.cursor);s.cursor=s.cursor-1
  elseif a.kind=='delete' then s.text=s.text:sub(1,s.cursor-1)..s.text:sub(s.cursor+1)
  elseif a.kind=='left' then s.cursor=math.max(1,s.cursor-1)
  elseif a.kind=='right' then s.cursor=math.min(#s.text+1,s.cursor+1) end
end
function M.input(a,ctx)
  local s=selfState(ctx);local k=a.kind
  if s.mode=='delete' then
    if k=='char' and (a.value=='y' or a.value=='Y') then
      local item=selected(s);local ok,err=s.ops:remove(item.path)
      actionResult(ctx,ok,err,'Delete');s.mode='browse';refresh(ctx)
    elseif k=='back' or k=='char' and (a.value=='n' or a.value=='N') then s.mode='browse' end
    return true
  end
  if s.mode=='rename' or s.mode=='mkdir' then
    if k=='back' then s.mode='browse'
    elseif k=='enter' then
      local ok,err
      if s.mode=='rename' then
        local item=selected(s);ok,err=s.ops:rename(item.path,s.text)
      else ok,err=s.ops:mkdir(s.cwd,s.text) end
      actionResult(ctx,ok,err,s.mode=='rename' and 'Rename' or 'Create directory')
      s.mode='browse';refresh(ctx)
    else editText(s,a) end
    return true
  end
  if s.mode=='preview' then
    if k=='back' then s.mode='browse'
    elseif k=='down' or k=='pagedown' then s.previewScroll=math.min(math.max(0,#s.preview-1),s.previewScroll+(k=='down' and 1 or 8))
    elseif k=='up' or k=='pageup' then s.previewScroll=math.max(0,s.previewScroll-(k=='up' and 1 or 8)) end
    return true
  end
  if k=='up' then s.selected=math.max(1,s.selected-1)
  elseif k=='down' then s.selected=math.min(#s.items,s.selected+1)
  elseif k=='pageup' then s.selected=math.max(1,s.selected-10)
  elseif k=='pagedown' then s.selected=math.min(#s.items,s.selected+10)
  elseif k=='backspace' then goUp(ctx)
  elseif k=='enter' then operate(ctx,'open')
  elseif k=='touch' then
    for _,hit in ipairs(s.toolbar) do
      if a.y==hit.y and a.x>=hit.x and a.x<hit.x+hit.w then operate(ctx,hit.id);return true end
    end
    for _,hit in ipairs(s.hitboxes) do
      if a.y==hit.y and a.x>=hit.x and a.x<hit.x+hit.w then
        if s.selected==hit.index then operate(ctx,'open') else s.selected=hit.index end
        return true
      end
    end
  elseif k=='scroll' then s.selected=math.max(1,math.min(#s.items,s.selected+(a.delta>0 and -3 or 3)))
  elseif k=='char' then
    local letters={c='copy',x='move',v='paste',r='rename',d='delete',n='mkdir',p='open',u='up'}
    local cmd=letters[(a.value or ''):lower()]
    if cmd then operate(ctx,cmd) else return false end
  else return false end
  return true
end
return M
end

package.preload["nexus.apps.hardwarecenter"] = function(...)
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
end

package.preload["nexus.apps.monitor"] = function(...)
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
end

package.preload["nexus.apps.notifications"] = function(...)
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
end

package.preload["nexus.apps.settings"] = function(...)
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
end

package.preload["nexus.apps.system"] = function(...)
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
end

package.preload["nexus.apps.terminal"] = function(...)
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
end

package.preload["nexus.apps.updatecenter"] = function(...)
-- NEXUS Update Center: explicit Pastebin ID, explicit install confirmation,
-- and OpenOS .shrc autostart management. No automatic remote code execution.
local Widgets=require('nexus.ui.widgets')
local Update=require('nexus.core.update')
local M={id='updatecenter',name='Update Center',description='Updates and startup settings'}
local function data(ctx) return ctx.state.updateCenter end
local function items(ctx)
  if data(ctx).tab==1 then
    return {
      {title='DOWNLOAD FROM PASTEBIN',detail='Enter trusted Pastebin release ID',id='download'},
      {title='INSTALL STAGED RELEASE',detail='Back up OS, switch release, restart NEXUS',id='install'},
      {title='ROLL BACK LAST RELEASE',detail='Restore previous.lua if available',id='rollback'},
      {title='REFRESH STATUS',detail='Check staged release and backups',id='refresh'}
    }
  end
  return {
    {title='ENABLE AUTOSTART',detail='Interactive OpenOS shell: /home/osv4.lua',id='enable'},
    {title='DISABLE AUTOSTART',detail='Keep OpenOS shell, remove NEXUS startup block',id='disable'},
    {title='CLEAR FAILED START GUARD',detail='Only after checking why startup failed',id='recover'},
    {title='REFRESH STATUS',detail='Read /home/.shrc and startup guard',id='refresh'}
  }
end
local function refresh(ctx)
  local s=data(ctx)
  s.staged=ctx.updater:stagedVersion()
  s.backup=ctx.updater.fs.exists(Update.BACKUP)
  s.autostart=ctx.startup:status()
  s.guard=ctx.startup.fs.exists(ctx.startup.GUARD or '/home/nexus/startup.guard')
end
function M.open(ctx)
  ctx.state.updateCenter={tab=1,index=1,scroll=0,hits={},mode=nil,buffer='',confirm=nil,message='',staged=nil}
  refresh(ctx)
end
function M.close(ctx) ctx.state.updateCenter=nil end
local function message(ctx,str,kind)
  local s=data(ctx);s.message=tostring(str or ''):sub(1,150)
  ctx.notify(s.message,kind or 'info')
end
local function act(ctx,id)
  local s=data(ctx)
  if id=='refresh' then refresh(ctx);message(ctx,'Update status refreshed');return end
  if id=='download' then
    s.mode='id';s.buffer='';s.message='Pastebin ID (not full URL). Enter to download.';return
  end
  if id=='install' then
    if not s.staged then message(ctx,'No valid staged update','warn');return end
  elseif id=='rollback' then
    if not s.backup then message(ctx,'No previous version available','warn');return end
  end
  s.confirm=id
end
local function proceed(ctx,id)
  local s=data(ctx)
  s.confirm=nil
  if id=='install' or id=='rollback' then
    s.message='Closing UI and applying operation; please do not power off.'
    ctx.state.updateAction=id
    ctx.state.running=false
    return
  end
  if id=='enable' then
    local ok,why=ctx.startup:enable();message(ctx,ok and 'Autostart enabled (next shell startup)' or why,ok and 'info' or 'error')
  elseif id=='disable' then
    local ok,why=ctx.startup:disable();message(ctx,ok and 'Autostart disabled' or why,ok and 'info' or 'error')
  elseif id=='recover' then
    local ok,why=ctx.startup:recover();message(ctx,ok and 'Autostart guard cleared' or why,ok and 'info' or 'error')
  end
  refresh(ctx)
end
function M.draw(ctx)
  local g,t,s=ctx.gfx,ctx.theme,data(ctx)
  local w,h=g:size()
  Widgets.frame(ctx,'SYSTEM / UPDATE CENTER')
  s.hits={}
  local tabs={{'[1:UPDATES]',1},{'[2:AUTOSTART]',2}}
  local x=2
  for _,a in ipairs(tabs) do
    local label,idx=a[1],a[2]
    g:text(x,3,label,idx==s.tab and t.activeText or t.accent,idx==s.tab and t.activeBg or t.bg,#label)
    s.hits[#s.hits+1]={x=x,y=3,w=#label,h=1,tab=idx}
    x=x+#label+2
  end
  local compact=h<19
  if s.tab==1 then
    g:text(2,compact and 4 or 5,'ACTIVE /home/osv4.lua v'..ctx.updater.version,t.text,t.bg,w-3)
    if not compact then g:text(2,6,'STAGED  '..(s.staged and ('v'..s.staged) or 'none')..'    BACKUP '..(s.backup and 'YES' or 'NO'),t.muted,t.bg,w-3) end
  else
    g:text(2,compact and 4 or 5,'AUTOSTART '..s.autostart..'   GUARD '..(s.guard and 'ACTIVE' or 'CLEAR'),t.text,t.bg,w-3)
    if not compact then g:text(2,6,'OPENOS .shrc  /  NO EEPROM CHANGES',t.muted,t.bg,w-3) end
  end
  local rows=items(ctx)
  local y=compact and 5 or 8
  local step=compact and 1 or 3
  local height=compact and 1 or 2
  local slots=math.max(1,math.min(#rows,math.floor((h-3-y)/step)+1))
  if s.index<s.scroll+1 then s.scroll=s.index-1 end
  if s.index>s.scroll+slots then s.scroll=s.index-slots end
  s.scroll=math.max(0,math.min(s.scroll,#rows-slots))
  for slot=1,slots do
    local i=s.scroll+slot;local row=rows[i]
    if row then
      local ry=y+(slot-1)*step
      Widgets.action(g,t,2,ry,w-4,height,row.title,row.detail,i==s.index)
      s.hits[#s.hits+1]={x=2,y=ry,w=w-4,h=height,row=i}
    end
  end
  if s.mode=='id' then
    g:fill(2,h-6,w-4,4,t.surface)
    g:text(4,h-6,'PASTEBIN ID / PRESS ENTER TO DOWNLOAD',t.accent,t.surface,w-8)
    g:text(4,h-5,'> '..s.buffer..'_',t.text,t.surface,w-8)
    g:text(4,h-4,'BACKSPACE erase / CLICK [BACK] cancel',t.muted,t.surface,w-8)
  elseif s.confirm then
    g:fill(2,h-6,w-4,4,t.surface)
    g:text(4,h-6,'CONFIRM '..s.confirm:upper()..'?',t.warn,t.surface,w-8)
    g:text(4,h-5,'[YES] [NO]   or Y / N',t.text,t.surface,w-8)
    s.hits[#s.hits+1]={x=4,y=h-5,w=5,h=1,answer=true}
    s.hits[#s.hits+1]={x=10,y=h-5,w=4,h=1,answer=false}
  elseif s.message~='' then
    g:text(2,h-4,s.message,t.warn,t.bg,w-3)
  end
  g:text(2,h-2,'TRUSTED UPDATES ONLY / BACK and HOME on taskbar',t.muted,t.bg,w-3)
end
function M.input(a,ctx)
  local s=data(ctx)
  if a.kind=='back' and (s.mode or s.confirm) then
    s.mode=nil;s.confirm=nil;s.buffer=''
    return true
  end
  if s.mode=='id' then
    if a.kind=='backspace' then s.buffer=s.buffer:sub(1,-2);return true end
    if a.kind=='paste' then
      local cleaned=(a.value or ''):match('^%s*(%w+)%s*$')
      if cleaned and #cleaned<=16 then s.buffer=cleaned end
      return true
    end
    if a.kind=='char' and a.value:match('^[A-Za-z0-9]$') and #s.buffer<16 then s.buffer=s.buffer..a.value;return true end
    if a.kind=='enter' then
      local id=s.buffer;s.mode=nil;s.message='Downloading...' ;M.draw(ctx)
      local ok,ver,bytes=ctx.updater:stage(id)
      message(ctx,ok and ('Downloaded '..ver..' ('..bytes..' bytes). Review and install.') or ver,ok and 'info' or 'error')
      refresh(ctx);return true
    end
    return true
  end
  if s.confirm then
    if a.kind=='char' and a.value:lower()=='y' then proceed(ctx,s.confirm);return true end
    if a.kind=='char' and a.value:lower()=='n' then s.confirm=nil;return true end
    if a.kind=='touch' then
      for _,hit in ipairs(s.hits) do
        if hit.answer~=nil and a.x>=hit.x and a.x<hit.x+hit.w and a.y==hit.y then
          if hit.answer then proceed(ctx,s.confirm) else s.confirm=nil end
          return true
        end
      end
    end
    return true
  end
  if a.kind=='char' and (a.value=='1' or a.value=='2') then s.tab=tonumber(a.value);s.index=1;s.scroll=0;refresh(ctx);return true end
  if a.kind=='left' or a.kind=='right' then s.tab=3-s.tab;s.index=1;s.scroll=0;refresh(ctx);return true end
  if a.kind=='up' then s.index=math.max(1,s.index-1);return true end
  if a.kind=='down' then s.index=math.min(#items(ctx),s.index+1);return true end
  if a.kind=='enter' then act(ctx,items(ctx)[s.index].id);return true end
  if a.kind=='touch' then
    for _,hit in ipairs(s.hits) do
      if a.x>=hit.x and a.x<hit.x+hit.w and a.y>=hit.y and a.y<hit.y+hit.h then
        if hit.tab then s.tab=hit.tab;s.index=1;s.scroll=0;refresh(ctx)
        elseif hit.row then s.index=hit.row;act(ctx,items(ctx)[s.index].id) end
        return true
      end
    end
  end
  return false
end
return M
end

package.preload["nexus.core.apps"] = function(...)
-- Shared foreground application lifecycle. Errors never crash NEXUS desktop.
local M={}
function M.new() return setmetatable({items={},byId={},active=nil,error=nil},{__index=M}) end
function M:register(spec)
  assert(type(spec)=='table' and type(spec.id)=='string' and spec.id~='')
  assert(type(spec.name)=='string' and type(spec.draw)=='function')
  assert(not self.byId[spec.id],'Duplicate app ID: '..spec.id)
  self.items[#self.items+1]=spec;self.byId[spec.id]=spec
end
function M:home(ctx)
  if self.active and self.active.close then pcall(self.active.close,ctx) end
  self.active=nil
end
function M:open(id,ctx)
  local app=self.byId[id]
  if not app then return false,'Unknown app: '..tostring(id) end
  self:home(ctx)
  if app.open then
    local ok,err=pcall(app.open,ctx)
    if not ok then
      if app.close then pcall(app.close,ctx) end
      self.error=tostring(err);return false,self.error
    end
  end
  self.active=app
  return true
end
function M:draw(ctx)
  if not self.active then return true end
  local ok,err=pcall(self.active.draw,ctx)
  if not ok then self.error=tostring(err);self:home(ctx);return false,self.error end
  return true
end
function M:input(action,ctx)
  if not self.active or not self.active.input then return false end
  local ok,handled=pcall(self.active.input,action,ctx)
  if not ok then self.error=tostring(handled);self:home(ctx);return false,self.error end
  return handled==true
end
function M:tick(ctx)
  if not self.active or not self.active.tick then return false end
  local ok,changed=pcall(self.active.tick,ctx)
  if not ok then self.error=tostring(changed);self:home(ctx);return false,self.error end
  return changed==true
end
return M
end

package.preload["nexus.core.automation"] = function(...)
-- Single opt-in redstone mirror rule. Session-only, bounded one write per tick.
local M={}
function M.new(devices,log)
  return setmetatable({devices=devices,logger=log,enabled=false,address=nil,inputSide=0,outputSide=1,
    lastApplied=nil,lastTick=-1,error=nil,updates=0},{__index=M})
end
function M:enable(address,inSide,outSide)
  if self.enabled then return false,'Disable existing automation first' end
  if type(address)~='string' or address=='' then return false,'Select a redstone card first' end
  if inSide==outSide then return false,'Input and output must use different sides' end
  local first,err=self.devices:read(address,inSide)
  if not first then return false,err end
  local other,why=self.devices:read(address,outSide)
  if not other then return false,why end
  self.enabled=true;self.address=address;self.inputSide=inSide;self.outputSide=outSide
  self.lastApplied=nil;self.lastTick=-1;self.error=nil
  if self.logger then self.logger:log('WARN','automation','Mirror enabled (session only)') end
  return true
end
function M:tick(now)
  if not self.enabled then return false end
  if now-self.lastTick<1 then return false end
  self.lastTick=now
  local read,err=self.devices:read(self.address,self.inputSide)
  if not read then self.error=err;self.enabled=false;self.devices:restore(self.address,self.outputSide);return true end
  local level=read.input>0 and 15 or 0
  local actual,why=self.devices:read(self.address,self.outputSide)
  if not actual then self.error=why;self.enabled=false;self.devices:restore(self.address,self.outputSide);return true end
  if actual.output==level then return false end
  local ok,writeReason=self.devices:write(self.address,self.outputSide,level)
  if not ok then
    self.error=writeReason;self.enabled=false;self.devices:restore(self.address,self.outputSide)
    return true
  end
  self.lastApplied=level;self.updates=self.updates+1
  return true
end
function M:disable()
  if not self.enabled and not self.address then return true,'Already disabled' end
  self.enabled=false
  local addr,side=self.address,self.outputSide
  self.address=nil;self.lastApplied=nil
  if addr then
    local ok,reason=self.devices:restore(addr,side)
    if not ok then return false,reason end
  end
  if self.logger then self.logger:log('INFO','automation','Mirror stopped') end
  return true,'Mirror disabled; previous output restored'
end
function M:emergencyStop()
  self.enabled=false;self.address=nil;self.lastApplied=nil
  return self.devices:restoreAll()
end
return M
end

package.preload["nexus.core.config"] = function(...)
-- Whitelisted scalar settings; never evaluate a configuration file as Lua code.
-- v4 file is separate; loads v2 preferences when no v4 file exists.
local M = {}
M.path = '/home/nexus/settings-v4.cfg'
local defaults={theme='cyan',layout='auto',notifications=true,splash=false,logging=true,monitorService=true}
local choices={theme={cyan=true,green=true,amber=true},layout={auto=true,compact=true,standard=true}}
local function valid(k,v)
  if choices[k] then return choices[k][v] == true end
  if k=='notifications' or k=='splash' or k=='logging' or k=='monitorService' then return v=='true' or v=='false' end
  return false
end
function M.defaults()
  local d={} for k,v in pairs(defaults) do d[k]=v end return d
end
function M.parse(data)
  local settings=M.defaults()
  if type(data)~='string' or #data>4096 then return settings end
  local count=0
  for line in (data..'\n'):gmatch('(.-)\n') do
    local k,v=line:match('^([%a]+)=([%w]+)$')
    if k and valid(k,v) then
      count=count+1
      if k=='notifications' or k=='splash' or k=='logging' or k=='monitorService' then settings[k]=(v=='true')
      else settings[k]=v end
    end
  end
  return settings,count
end
function M.encode(settings)
  local lines={}
  for _,key in ipairs({'theme','layout','notifications','splash','logging','monitorService'}) do
    local value=tostring(settings[key])
    if not valid(key,value) then value=tostring(defaults[key]) end
    lines[#lines+1]=key..'='..value
  end
  return table.concat(lines,'\n')..'\n'
end
local function readDefault()
  local sources={M.path,M.path..'.bak','/home/nexus/settings-v2.cfg'}
  for _,source in ipairs(sources) do
    local f=io.open(source,'r')
    if f then
      local contents=f:read(4097);f:close()
      local _,count=M.parse(contents)
      if count and count>0 then return contents end
    end
  end
  return nil
end
local function writeDefault(data)
  local okFs,fs=pcall(require,'filesystem')
  if not okFs or not fs then return false,'filesystem library unavailable' end
  if not fs.exists('/home/nexus') then
    local ok,why=fs.makeDirectory('/home/nexus')
    if not ok then return false,why or 'cannot create directory' end
  end
  local temp=M.path..'.tmp'
  local backup=M.path..'.bak'
  local f,why=io.open(temp,'w')
  if not f then return false,why or 'cannot open temporary file' end
  local okWrite,writeError=pcall(function() assert(f:write(data)); assert(f:flush()) end)
  f:close()
  if not okWrite then pcall(fs.remove,temp); return false,tostring(writeError) end
  -- Preserve the prior version until the new one is installed.
  pcall(fs.remove,backup)
  local had=fs.exists(M.path)
  if had then
    local okOld,whyOld=fs.rename(M.path,backup)
    if not okOld then fs.remove(temp); return false,whyOld or 'cannot back up settings' end
  end
  local okNew,whyNew=fs.rename(temp,M.path)
  if not okNew then
    if had then pcall(fs.rename,backup,M.path) end
    return false,whyNew or 'cannot install settings'
  end
  -- Keep .bak to allow recovery from a later corrupted current file.
  return true
end
function M.new(persistence)
  persistence=persistence or {read=readDefault,write=writeDefault}
  local ok,raw=pcall(persistence.read)
  local self={data=M.parse(ok and raw or nil),store=persistence}
  return setmetatable(self,{__index=M})
end
function M:set(key,value)
  local normalized=tostring(value)
  if not valid(key,normalized) then return false,'invalid setting' end
  self.data[key]=value
  return true
end
function M:save()
  local ok,result,why=pcall(self.store.write,M.encode(self.data))
  if not ok then return false,tostring(result) end
  if result~=true then return false,tostring(why or 'write failed') end
  return true
end
function M:reset()
  self.data=M.defaults()
  return self:save()
end
return M
end

package.preload["nexus.core.console"] = function(...)
-- Bounded command history and read-only built-in commands; external commands
-- run via real OpenOS shell.execute in an explicit screen handoff.
local Path=require('nexus.core.path')
local M={}
function M.new(fs)
  return setmetatable({cwd='/home',buffer='',cursor=1,history={},histIndex=0,
    lines={'NEXUS TERMINAL / OpenOS shell bridge','Type help for commands.'},fs=fs}, {__index=M})
end
function M:print(line)
  for segment in (tostring(line or '')..'\n'):gmatch('(.-)\n') do
    self.lines[#self.lines+1]=segment:sub(1,240)
    if #self.lines>80 then table.remove(self.lines,1) end
  end
end
function M:insert(str)
  if type(str)~='string' then return end
  str=str:gsub('[\r\n]',' '):gsub('[%c]',''):sub(1,256)
  local remain=256-#self.buffer
  str=str:sub(1,math.max(0,remain))
  self.buffer=self.buffer:sub(1,self.cursor-1)..str..self.buffer:sub(self.cursor)
  self.cursor=self.cursor+#str
end
function M:key(action)
  local k=action.kind
  if k=='char' or k=='paste' then self:insert(action.value);return true end
  if k=='backspace' then
    if self.cursor>1 then self.buffer=self.buffer:sub(1,self.cursor-2)..self.buffer:sub(self.cursor);self.cursor=self.cursor-1 end
  elseif k=='delete' then
    if self.cursor<=#self.buffer then self.buffer=self.buffer:sub(1,self.cursor-1)..self.buffer:sub(self.cursor+1) end
  elseif k=='left' then self.cursor=math.max(1,self.cursor-1)
  elseif k=='right' then self.cursor=math.min(#self.buffer+1,self.cursor+1)
  elseif k=='linehome' then self.cursor=1
  elseif k=='lineend' then self.cursor=#self.buffer+1
  elseif k=='up' or k=='down' then
    local max=#self.history+1
    self.histIndex=math.max(1,math.min(max,(self.histIndex==0 and max or self.histIndex)+(k=='up' and -1 or 1)))
    self.buffer=self.history[self.histIndex] or ''
    self.cursor=#self.buffer+1
  else return false end
  return true
end
function M:execute(command,ctx)
  self:print(self.cwd..' $ '..command)
  command=command:match('^%s*(.-)%s*$')
  if command=='' then return end
  self.history[#self.history+1]=command
  if #self.history>16 then table.remove(self.history,1) end
  self.histIndex=#self.history+1
  local cmd,arg=command:match('^(%S+)%s*(.*)$')
  if cmd=='help' then
    self:print('help, pwd, cd PATH, ls [PATH], cat FILE, clear')
    self:print('mem, uptime, components, exit, run COMMAND')
    self:print('run executes a REAL OpenOS command (not sandboxed).')
  elseif cmd=='pwd' then self:print(self.cwd)
  elseif cmd=='clear' then self.lines={}
  elseif cmd=='exit' then ctx.manager:home(ctx);if ctx.session then ctx.session:home() end
  elseif cmd=='cd' then
    local p=Path.normalize(arg~='' and arg or '/home',self.cwd)
    if p and self.fs.exists(p) and self.fs.isDirectory(p) then self.cwd=p
    else self:print('Directory not found') end
  elseif cmd=='ls' then
    local p=Path.normalize(arg~='' and arg or '.',self.cwd)
    if not p then self:print('Invalid path');return end
    local ok,it=pcall(self.fs.list,p)
    if not ok or not it then self:print('Cannot list '..p);return end
    local count=0
    local function add(name)
      if count>=48 then return end
      count=count+1; self:print(name)
    end
    if type(it)=='function' then for name in it do add(name) end
    elseif type(it)=='table' then for _,name in ipairs(it) do add(name) end end
    if count>=48 then self:print('[Listing limited to 48 entries]') end
  elseif cmd=='cat' then
    local p=Path.normalize(arg,self.cwd)
    if not p or self.fs.isDirectory(p) then self:print('Expected a file');return end
    local f=io.open(p,'rb')
    if not f then self:print('Cannot read file');return end
    local data=f:read(2049) or ''; f:close()
    if data:find('%z') then self:print('Binary file');return end
    for line in (data:sub(1,2048)..'\n'):gmatch('(.-)\n') do self:print(line) end
    if #data>2048 then self:print('[Truncated to 2048 bytes]') end
  elseif cmd=='mem' then
    local s=ctx.hardware:snapshot()
    self:print('Free: '..tostring(s.freeMemory or '?')..' B / Total: '..tostring(s.totalMemory or '?')..' B')
  elseif cmd=='uptime' then self:print(tostring(math.floor(ctx.now()))..' seconds')
  elseif cmd=='components' then
    local s=ctx.hardware:snapshot();self:print('Components: '..tostring(s.componentCount)..' GPUs: '..tostring(s.gpuCount))
  elseif cmd=='run' then
    if arg=='' then self:print('Usage: run COMMAND');return end
    local ok,why=ctx.runShell(arg,self.cwd)
    self:print(ok and 'OpenOS command finished.' or ('OpenOS error: '..tostring(why)))
  else self:print('Unknown built-in. Use run '..cmd..' for OpenOS commands.') end
end
return M
end

package.preload["nexus.core.devicecontrol"] = function(...)
-- OpenComputers hardware access. No implicit writes, no primary changes.
local M={}
M.SIDES={'BOTTOM','TOP','BACK','FRONT','RIGHT','LEFT'}
local function validSide(side) return type(side)=='number' and side==math.floor(side) and side>=0 and side<=5 end
local function validLevel(level) return type(level)=='number' and level==math.floor(level) and level>=0 and level<=15 end
function M.new(component,logger)
  return setmetatable({component=component,logger=logger,owned={},lastError=nil,diagnostic=''}, {__index=M})
end
function M:call(address,method,...)
  if type(address)~='string' or address=='' then return nil,'Invalid component address' end
  local comp=self.component
  if type(comp.invoke)=='function' then
    local ok,a,b=pcall(comp.invoke,address,method,...)
    if ok then
      if a==nil then return nil,tostring(b or (method..' unavailable')) end
      return a,b
    end
    -- Some OpenOS test shims have proxy methods but no working invoke.
    self.lastError=tostring(a)
  end
  if type(comp.proxy)=='function' then
    local ok,proxy=pcall(comp.proxy,address)
    if ok and type(proxy)=='table' and type(proxy[method])=='function' then
      local good,a,b=pcall(proxy[method],...)
      if good and a~=nil then return a,b end
      return nil,tostring(a or b)
    end
  end
  return nil,self.lastError or ('Unsupported component method '..method)
end
function M:list()
  local result={}
  if type(self.component.list)~='function' then return result,'component.list missing' end
  local ok,iter=pcall(self.component.list)
  if not ok or type(iter)~='function' then return result,'Unable to enumerate components' end
  local worked,err=pcall(function()
    for address,kind in iter do
      if type(address)=='string' and type(kind)=='string' then
        result[#result+1]={address=address,kind=kind}
        if #result>=96 then break end
      end
    end
  end)
  if not worked then return result,tostring(err) end
  table.sort(result,function(a,b)
    if a.kind==b.kind then return a.address<b.address end
    return a.kind<b.kind
  end)
  return result
end
function M:methods(address)
  if type(self.component.methods)~='function' then return nil,'Method metadata unavailable' end
  local ok,items=pcall(self.component.methods,address)
  if not ok or type(items)~='table' then return nil,'Method inspection unavailable' end
  local result={}
  for method in pairs(items) do if type(method)=='string' then result[#result+1]=method end end
  table.sort(result)
  return result
end
function M:redstones()
  local all=self:list();local found={}
  for _,d in ipairs(all) do if d.kind=='redstone' then found[#found+1]=d end end
  return found
end
function M:read(address,side)
  if not validSide(side) then return nil,'Side must be 0-5' end
  local a,err=self:call(address,'getInput',side)
  if type(a)~='number' then return nil,'Input: '..tostring(err or a) end
  local b,why=self:call(address,'getOutput',side)
  if type(b)~='number' then return nil,'Output: '..tostring(why or b) end
  return {input=a,output=b,side=side}
end
local function key(addr,side) return addr..':'..tostring(side) end
function M:write(address,side,level)
  if not validSide(side) or not validLevel(level) then return false,'Side 0-5, level 0-15 only' end
  local known=false
  for _,item in ipairs(self:redstones()) do if item.address==address then known=true;break end end
  if not known then return false,'Not a detected redstone component' end
  local before,err=self:read(address,side)
  if not before then return false,err end
  if before.output==level then return true,'Already '..level end
  local k=key(address,side)
  local old=self.owned[k]
  local original=old and old.original or before.output
  -- Record intent before write, so even partial hardware failures can be restored.
  self.owned[k]={address=address,side=side,original=original,last=level}
  local returned,why=self:call(address,'setOutput',side,level)
  if returned==nil then
    local actual=self:call(address,'getOutput',side)
    if actual~=level then
      if type(actual)=='number' and actual~=original then
        self.owned[k].last=actual
        self:restore(address,side) -- Best-effort revert after partial write.
      elseif not old then self.owned[k]=nil else self.owned[k]=old end
      return false,'Hardware refused output change: '..tostring(why)
    end
  end
  local verified=self:call(address,'getOutput',side)
  if type(verified)=='number' and verified~=level then
    self.owned[k].last=verified
    return false,'Output verification failed (actual '..verified..')'
  end
  if self.logger then self.logger:log('WARN','hardware','User/automation changed redstone '..address:sub(1,8)..' side '..side..' to '..level) end
  return true,'Output '..level
end
function M:restore(address,side)
  local k=key(address,side)
  local own=self.owned[k]
  if not own then return true,'Nothing to restore' end
  local current,err=self:call(address,'getOutput',side)
  if type(current)~='number' then return false,tostring(err) end
  if current~=own.last then
    self.owned[k]=nil
    return false,'Output changed externally; not overwriting'
  end
  if current~=own.original then
    local result,why=self:call(address,'setOutput',side,own.original)
    if result==nil then
      local readback=self:call(address,'getOutput',side)
      if readback~=own.original then return false,tostring(why) end
    end
    local verified=self:call(address,'getOutput',side)
    if type(verified)=='number' and verified~=own.original then return false,'Restore verify failed' end
  end
  self.owned[k]=nil
  return true,'Restored '..tostring(own.original)
end
function M:restoreAll()
  local failed={};local count=0
  local keys={};for k in pairs(self.owned) do keys[#keys+1]=k end
  table.sort(keys)
  for _,k in ipairs(keys) do
    local own=self.owned[k]
    if own then
      local ok,why=self:restore(own.address,own.side)
      if ok then count=count+1 else failed[#failed+1]=k..' '..tostring(why) end
    end
  end
  if self.logger then self.logger:log(#failed>0 and 'ERROR' or 'INFO','hardware','Restored '..count..' outputs; failures '..#failed) end
  return #failed==0,table.concat(failed,'; '),count
end
return M
end

package.preload["nexus.core.diagnostics"] = function(...)
local M={}
function M.run(ctx)
  local result={}
  local function check(id,condition,value)
    result[#result+1]={id=id,ok=condition==true,detail=tostring(value or ''):sub(1,85)}
  end
  local ok,hw=pcall(ctx.hardware.snapshot,ctx.hardware)
  hw=ok and hw or {}
  check('GPU',type(hw.gpuAddress)=='string' and hw.gpuAddress~='',hw.gpuAddress)
  check('DISPLAY',type(hw.resolutionW)=='number' and hw.resolutionW>0 and type(hw.resolutionH)=='number' and hw.resolutionH>0,
    tostring(hw.resolutionW or '?')..' x '..tostring(hw.resolutionH or '?'))
  check('GPU DEPTH',type(hw.depth)=='number' and hw.depth>=1,tostring(hw.depth or '?')..' bit')
  check('MEMORY',type(hw.freeMemory)=='number' and hw.freeMemory>0 and type(hw.totalMemory)=='number' and hw.totalMemory>0,
    tostring(math.floor((hw.freeMemory or 0)/1024))..' / '..tostring(math.floor((hw.totalMemory or 0)/1024))..' KiB free/total')
  check('COMPONENTS',type(hw.componentCount)=='number' and hw.componentCount>=2,hw.componentCount)
  local fs=ctx.fs
  if not fs then local okFs,obj=pcall(require,'filesystem');fs=okFs and obj or nil end
  local writable=nil
  if fs and type(fs.get)=='function' then
    local okDisk,disk=pcall(fs.get,'/home')
    if okDisk and disk and type(disk.isReadOnly)=='function' then
      local worked,ro=pcall(disk.isReadOnly);if worked then writable=not ro end
    end
  end
  check('HOME STORAGE',writable==true,writable==nil and 'not checked' or (writable and 'writable' or 'read-only'))
  check('LOGGER',ctx.logger.diskStatus=='PERSISTENT',ctx.logger.diskStatus)
  local failures=0
  for _,s in ipairs(ctx.services.ordered) do if s.status=='FAILED' then failures=failures+1 end end
  check('SERVICES',failures==0,failures..' failed')
  return result
end
return M
end

package.preload["nexus.core.display"] = function(...)
-- Explicit temporary resolution preview, with 12-second automatic rollback.
local M={}
function M.new(gpu,clock)
  return setmetatable({gpu=gpu,clock=clock,pending=nil}, {__index=M})
end
function M:presets(nativeW,nativeH,maxW,maxH)
  local list={{id='original',title='OpenOS original',w=nativeW,h=nativeH}}
  if type(maxW)=='number' and type(maxH)=='number' then
    local cw,ch=math.min(50,maxW),math.min(16,maxH)
    if cw>=20 and ch>=8 and (cw~=nativeW or ch~=nativeH) then
      list[#list+1]={id='compact',title='Compact',w=cw,h=ch}
    end
    if maxW>=20 and maxH>=8 and (maxW~=nativeW or maxH~=nativeH) then
      list[#list+1]={id='maximum',title='Maximum',w=maxW,h=maxH}
    end
  end
  return list
end
function M:preview(w,h)
  if self.pending then return false,'finish current preview first' end
  local ok,oldW,oldH=pcall(self.gpu.getResolution)
  if not ok or not oldW or not oldH then return false,'cannot read current resolution' end
  if w==oldW and h==oldH then return false,'already at this resolution' end
  local changed,success=pcall(self.gpu.setResolution,w,h)
  if not changed or success==false then return false,'GPU rejected resolution' end
  local read,newW,newH=pcall(self.gpu.getResolution)
  if not read or newW~=w or newH~=h then
    pcall(self.gpu.setResolution,oldW,oldH)
    return false,'resolution verification failed'
  end
  self.pending={oldW=oldW,oldH=oldH,newW=w,newH=h,deadline=self.clock()+12}
  return true
end
function M:confirm()
  if not self.pending then return false end
  self.pending=nil
  return true
end
function M:rollback()
  local pending=self.pending
  if not pending then return false end
  self.pending=nil
  pcall(self.gpu.setResolution,pending.oldW,pending.oldH)
  return true
end
function M:tick()
  if self.pending and self.clock()>=self.pending.deadline then
    self:rollback()
    return true
  end
  return false
end
return M
end

package.preload["nexus.core.fileops"] = function(...)
-- Filesystem operations with collision checks and bounded reads.
-- No recursive deletion, no overwrite; the OS filesystem API is authoritative.
local Path=require('nexus.core.path')
local M={}
function M.new(fs,openFn)
  assert(type(fs)=='table' and type(fs.list)=='function','OpenOS filesystem required')
  return setmetatable({fs=fs,open=openFn or io.open},{__index=M})
end
function M:list(path)
  local fs=self.fs
  if not fs.exists(path) or not fs.isDirectory(path) then return nil,'Not a directory' end
  local it,err=fs.list(path)
  if type(it)~='function' and type(it)~='table' then return nil,err or 'Cannot list directory' end
  local out,overflow={},false
  local function add(v)
    if type(v)~='string' then return end
    if #out>=128 then overflow=true;return end
    local name=v:gsub('/+$','')
    if not Path.simpleName(name) then return end
    local full=Path.join(path,name)
    out[#out+1]={name=name,path=full,dir=fs.isDirectory(full),size=fs.size(full) or 0}
  end
  if type(it)=='table' then for _,v in ipairs(it) do add(v) end
  else for v in it do add(v) end end
  table.sort(out,function(a,b)
    if a.dir~=b.dir then return a.dir end
    return a.name:lower()<b.name:lower()
  end)
  return out,overflow
end
function M:info(path)
  local fs=self.fs
  local result={}
  if type(fs.get)~='function' then return result end
  local ok,proxy=pcall(fs.get,path)
  if not ok or type(proxy)~='table' then return result end
  for _,method in ipairs({'spaceTotal','spaceUsed','isReadOnly'}) do
    if type(proxy[method])=='function' then
      local yes,value=pcall(proxy[method])
      if yes then result[method]=value end
    end
  end
  return result
end
function M:preview(path,maxBytes,maxLines)
  local fs=self.fs
  if not fs.exists(path) or fs.isDirectory(path) then return nil,'Not a file' end
  local limit=math.min(4096,maxBytes or 3072)
  local f,err=self.open(path,'rb')
  if not f then return nil,err or 'Cannot open file' end
  local ok,data=pcall(function() return f:read(limit+1) or '' end)
  pcall(function() f:close() end)
  if not ok then return nil,tostring(data) end
  local more=#data>limit
  data=data:sub(1,limit)
  if data:find('%z') then return nil,'Binary file (preview unavailable)' end
  local lines={}
  for line in (data..'\n'):gmatch('(.-)\n') do
    if #lines>=math.min(80,maxLines or 64) then more=true;break end
    lines[#lines+1]=line:gsub('[%c]',' '):sub(1,240)
  end
  return lines,more
end
local function validDestination(fs,path)
  local allowed,why=Path.mutable(path)
  if not allowed then return false,why end
  if fs.exists(path) then return false,'Target already exists (no overwrite)' end
  if not fs.exists(Path.parent(path)) or not fs.isDirectory(Path.parent(path)) then
    return false,'Destination folder missing'
  end
  return true
end
function M:copy(src,dst)
  if not self.fs.exists(src) then return false,'Source missing' end
  if self.fs.isDirectory(src) then return false,'Folder copy not supported' end
  local ok,why=validDestination(self.fs,dst)
  if not ok then return false,why end
  return self.fs.copy(src,dst)
end
function M:move(src,dst)
  if not self.fs.exists(src) then return false,'Source missing' end
  local ok,why=Path.mutable(src)
  if not ok then return false,why end
  ok,why=validDestination(self.fs,dst)
  if not ok then return false,why end
  if self.fs.isDirectory(src) and dst:sub(1,#src+1)==src..'/' then return false,'Cannot move into itself' end
  return self.fs.rename(src,dst)
end
function M:rename(src,newName)
  if not Path.simpleName(newName) then return false,'Invalid name' end
  return self:move(src,Path.join(Path.parent(src),newName))
end
function M:remove(src)
  local ok,why=Path.mutable(src)
  if not ok then return false,why end
  if not self.fs.exists(src) then return false,'File not found' end
  if self.fs.isDirectory(src) then
    local items,err=self:list(src)
    if not items then return false,err end
    if #items>0 then return false,'Folder not empty (recursive delete disabled)' end
  end
  return self.fs.remove(src)
end
function M:mkdir(folder,name)
  if not Path.simpleName(name) then return false,'Invalid folder name' end
  local dest=Path.join(folder,name)
  local ok,why=validDestination(self.fs,dest)
  if not ok then return false,why end
  return self.fs.makeDirectory(dest)
end
return M
end

package.preload["nexus.core.graphics"] = function(...)
-- ASCII-only clipped renderer; avoids invalid GPU coordinates.
local M = {}
function M.new(gpu)
  local self = {gpu=gpu, foreground=nil, background=nil}
  return setmetatable(self, {__index=M})
end
function M:size()
  local w, h = self.gpu.getResolution()
  assert(type(w)=="number" and type(h)=="number" and w>=1 and h>=1, "Invalid display resolution")
  return math.floor(w), math.floor(h)
end
function M:colors(fg, bg)
  if fg ~= nil and fg ~= self.foreground then
    self.gpu.setForeground(fg)
    self.foreground = fg
  end
  if bg ~= nil and bg ~= self.background then
    self.gpu.setBackground(bg)
    self.background = bg
  end
end
function M:fill(x, y, width, height, bg, char)
  local sw, sh = self:size()
  x, y, width, height = math.floor(x), math.floor(y), math.floor(width), math.floor(height)
  if width<=0 or height<=0 then return end
  local x1, y1 = math.max(1, x), math.max(1, y)
  local x2, y2 = math.min(sw, x+width-1), math.min(sh, y+height-1)
  if x1>x2 or y1>y2 then return end
  self:colors(nil, bg)
  self.gpu.fill(x1,y1,x2-x1+1,y2-y1+1,char or " ")
end
function M:text(x, y, value, fg, bg, maxWidth)
  local sw, sh = self:size()
  x, y = math.floor(x), math.floor(y)
  if y<1 or y>sh or x>sw then return end
  local s = tostring(value or ""):gsub("[\r\n\t]", " ")
  local trimmed = math.max(0, 1-x)
  if trimmed>0 then s=s:sub(trimmed+1); x=1 end
  local capacity = sw-x+1
  if maxWidth ~= nil then capacity = math.min(capacity, math.floor(maxWidth)-trimmed) end
  if capacity<=0 then return end
  s=s:sub(1, capacity)
  if s=="" then return end
  self:colors(fg, bg)
  self.gpu.set(x,y,s)
end
function M:center(y, value, fg, bg)
  local w = self:size()
  local str = tostring(value or "")
  self:text(math.max(1, math.floor((w-#str)/2)+1),y,str,fg,bg)
end
function M:border(x,y,w,h,fg,bg)
  if w<2 or h<2 then return end
  self:text(x,y,"+"..string.rep("-",math.max(0,math.floor(w)-2)).."+",fg,bg)
  self:text(x,y+h-1,"+"..string.rep("-",math.max(0,math.floor(w)-2)).."+",fg,bg)
  for dy=1,h-2 do
    self:text(x,y+dy,"|",fg,bg)
    self:text(x+w-1,y+dy,"|",fg,bg)
  end
end
return M
end

package.preload["nexus.core.hardware"] = function(...)
-- NEXUS: read-only GPU discovery, with direct-proxy/invoke compatibility.
-- Never binds GPUs, changes OpenOS terminal devices or changes EEPROM.
local M = {}

local function attempt(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b = pcall(fn, ...)
  if ok then return a, b end
end

-- OpenComputers supports invoking component methods either through a proxy
-- or by component.invoke(address, method, ...). Some proxy/wrapper variants
-- can expose a missing or failing proxy method even when invocation works.
-- Only use the invocation fallback on a failed direct call.
local function wrapGpu(component, raw)
  if not raw or type(raw.address) ~= "string" then return nil end
  local address = raw.address
  local adapter = {address = address}
  local methods = {
    "getScreen", "getResolution", "maxResolution", "getDepth", "setDepth",
    "getForeground", "getBackground", "setForeground", "setBackground",
    "set", "fill", "setResolution"
  }
  for _, name in ipairs(methods) do
    local methodName = name
    adapter[methodName] = function(...)
      local direct = raw[methodName]
      local reason = "proxy method unavailable"
      if type(direct) == "function" then
        local ok, a, b, c = pcall(direct, ...)
        -- A successful call returning no resolution is also unusable.
        -- Try the low-level invocation before rejecting the GPU.
        if ok and (methodName ~= "getResolution" or
            (type(a) == "number" and type(b) == "number" and a > 0 and b > 0)) then
          return a, b, c
        end
        if ok then
          reason = "invalid resolution " .. tostring(a) .. " x " .. tostring(b)
        else
          reason = tostring(a)
        end
      end
      if component and type(component.invoke) == "function" then
        -- If this call also fails, preserve the API error for the caller.
        return component.invoke(address, methodName, ...)
      end
      error("GPU " .. methodName .. " failed: " .. reason, 2)
    end
  end
  return adapter
end

local function screenOf(gpu)
  if not gpu then return nil end
  local screen = attempt(gpu.getScreen)
  if type(screen) == "string" and screen ~= "" then return screen end
end

local function checkResolution(gpu)
  if not gpu then return nil, "GPU proxy unavailable" end
  local ok, w, h = pcall(gpu.getResolution)
  if not ok then return nil, "getResolution: " .. tostring(w) end
  if type(w) ~= "number" or type(h) ~= "number" or w < 1 or h < 1 then
    return nil, "getResolution returned " .. tostring(w) .. " x " .. tostring(h)
  end
  return true
end

function M.new(component, computer, term)
  local self = {component=component, computer=computer, term=term}
  local terminalRaw = attempt(term and term.gpu)
  local terminalScreen = attempt(term and term.screen)
  local terminalGpu = wrapGpu(component, terminalRaw)
  if type(terminalScreen) ~= "string" or terminalScreen == "" then
    terminalScreen = screenOf(terminalGpu)
  end

  local gpu, screen
  local failures = {}
  local function consider(candidate, label, knownScreen)
    if not candidate then return false end
    local boundScreen = screenOf(candidate)
    local target = knownScreen or boundScreen
    if not target then
      failures[#failures+1] = label .. ": no bound screen"
      return false
    end
    -- Never select an unrelated display when a terminal screen is known.
    if knownScreen and boundScreen and boundScreen ~= knownScreen then
      failures[#failures+1] = label .. ": different screen"
      return false
    end
    local usable, why = checkResolution(candidate)
    if not usable then
      failures[#failures+1] = label .. ": " .. why
      return false
    end
    gpu, screen = candidate, target
    return true
  end

  -- The functioning OpenOS terminal is authoritative. No GPU rebinding.
  consider(terminalGpu, "terminal GPU", terminalScreen)

  if not gpu and component and type(component.list) == "function" then
    local iterator = attempt(component.list, "gpu", true)
    if type(iterator) == "function" then
      local fallbackGpu, fallbackScreen
      for address in iterator do
        local raw = attempt(component.proxy, address)
        local candidate = wrapGpu(component, raw)
        if candidate and (not terminalGpu or candidate.address ~= terminalGpu.address) then
          local candidateScreen = screenOf(candidate)
          if candidateScreen and (not terminalScreen or candidateScreen == terminalScreen) then
            local usable, why = checkResolution(candidate)
            if usable then
              fallbackGpu, fallbackScreen = candidate, candidateScreen
              break
            else
              failures[#failures+1] = address:sub(1, 8) .. ": " .. why
            end
          end
        end
      end
      if fallbackGpu then gpu, screen = fallbackGpu, fallbackScreen end
    else
      failures[#failures+1] = "GPU enumeration unavailable"
    end
  end

  if not gpu then
    local addr = terminalGpu and terminalGpu.address or "none"
    local why = table.concat(failures, "; ")
    if why == "" then why = "no usable bound GPU found" end
    return nil, "No usable GPU/screen pair (GPU " .. tostring(addr)
      .. ", screen " .. tostring(terminalScreen) .. "). " .. why
      .. ". No GPU bindings were changed."
  end
  self.gpu = gpu
  self.screen = screen
  self.keyboard = attempt(term and term.keyboard)
  self.keyboards = {}
  if type(self.keyboard) == "string" and self.keyboard ~= "no_system_keyboard" then
    self.keyboards[self.keyboard] = true
  end
  local screenProxy = attempt(component and component.proxy, self.screen)
  if screenProxy and type(screenProxy.getKeyboards) == "function" then
    local attached = attempt(screenProxy.getKeyboards)
    if type(attached) == "table" then
      for _, address in pairs(attached) do self.keyboards[address] = true end
    end
  end
  return setmetatable(self, {__index=M})
end

function M:resolution()
  local w, h = attempt(self.gpu.getResolution)
  if type(w) ~= "number" or type(h) ~= "number" then
    return nil, nil
  end
  return math.floor(w), math.floor(h)
end

function M:snapshot()
  local w, h = self:resolution()
  local maxW, maxH = attempt(self.gpu.maxResolution)
  local n = 0
  local gpus, screens = 0, 0
  if self.component and type(self.component.list) == "function" then
    local ok, iterator = pcall(self.component.list)
    if ok and type(iterator) == "function" then
      for _, kind in iterator do
        n = n + 1
        if kind == "gpu" then gpus = gpus + 1 end
        if kind == "screen" then screens = screens + 1 end
      end
    end
  end
  return {
    resolutionW = w, resolutionH = h,
    maxW = maxW, maxH = maxH,
    depth = attempt(self.gpu.getDepth),
    freeMemory = attempt(self.computer and self.computer.freeMemory),
    totalMemory = attempt(self.computer and self.computer.totalMemory),
    uptime = attempt(self.computer and self.computer.uptime),
    componentCount = n,
    gpuCount = gpus, screenCount = screens,
    screen = self.screen,
    gpuAddress = self.gpu.address or "unknown"
  }
end

function M:acceptKeyboard(address)
  if type(address) ~= "string" then return false end
  if next(self.keyboards) == nil then
    -- When screen keyboard enumeration is unavailable, accept keyboard signals.
    return true
  end
  return self.keyboards[address] == true
end

return M
end

package.preload["nexus.core.hwevents"] = function(...)
-- Bounded runtime event history; records real signals only.
local M={}
function M.new(limit)
  return setmetatable({limit=math.max(5,math.min(40,limit or 24)),items={}}, {__index=M})
end
function M:push(at,kind,address,side,old,new)
  if kind~='component_added' and kind~='component_removed' and kind~='redstone_changed' and
      kind~='component_available' and kind~='component_unavailable' then return false end
  local info={at=math.floor(tonumber(at) or 0),kind=kind,address=tostring(address or ''):sub(1,8),
    side=type(side)=='number' and side or nil,old=old,new=new}
  table.insert(self.items,1,info)
  if #self.items>self.limit then table.remove(self.items) end
  return true
end
function M:clear() self.items={} end
return M
end

package.preload["nexus.core.input"] = function(...)
-- Minecraft-safe defaults: no F1-F12 shortcuts (Minecraft captures them).
local M={}
local keyMap={up='up',down='down',left='left',right='right',enter='enter',
 numpadenter='enter',esc='back',tab='tab',backspace='backspace',delete='delete',
 home='linehome',['end']='lineend',pageUp='pageup',pageDown='pagedown',prior='pageup',next='pagedown'}
local fallback={up=200,down=208,left=203,right=205,enter=28,numpadenter=156,
 esc=1,tab=15,backspace=14,delete=211,home=199,['end']=207,pageUp=201,pageDown=209,prior=201,next=209}
function M.decode(kind,a,b,c,hardware,keys,d)
  if kind=='screen_resized' or kind=='screen_resize' then
    return a==hardware.screen and {kind='resize'} or nil
  end
  if kind=='touch' then
    if a==hardware.screen and type(b)=='number' and type(c)=='number' then
      return {kind='touch',x=math.floor(b),y=math.floor(c)}
    end
    return nil
  end
  if kind=='scroll' and a==hardware.screen then
    return {kind='scroll',x=math.floor(b or 1),y=math.floor(c or 1),delta=tonumber(d) or 0}
  end
  if kind=='interrupted' then return {kind='quit'} end
  if kind=='clipboard' and hardware:acceptKeyboard(a) and type(b)=='string' then
    return {kind='paste',value=b:sub(1,512)}
  end
  if kind~='key_down' or not hardware:acceptKeyboard(a) then return nil end
  for key,action in pairs(keyMap) do
    if c==((keys or {})[key] or fallback[key]) then return {kind=action} end
  end
  if type(b)=='number' and b>=32 and b<=126 then return {kind='char',value=string.char(b)} end
  return nil
end
return M
end

package.preload["nexus.core.logger"] = function(...)
-- Persistent, bounded OpenOS log. Any disk error degrades to RAM-only mode.
local M={}
local function safeText(value)
  return tostring(value or ''):gsub('[\r\n%z]',' '):sub(1,170)
end
local function defaultIO()
  return {
    append=function(path,line)
      local f,err=io.open(path,'a');if not f then return false,err end
      local ok,why=pcall(function() assert(f:write(line));assert(f:flush()) end)
      f:close();return ok,why
    end,
    size=function(path)
      local f=io.open(path,'r');if not f then return 0 end
      local s=f:seek('end') or 0;f:close();return s
    end,
    rotate=function(path)
      local ok,fs=pcall(require,'filesystem');if not ok then return false,'filesystem unavailable' end
      pcall(fs.remove,path..'.old')
      return fs.rename(path,path..'.old')
    end,
    ensure=function()
      local ok,fs=pcall(require,'filesystem');if not ok then return false,'filesystem unavailable' end
      if not fs.exists('/home/nexus') then local yes,why=fs.makeDirectory('/home/nexus');if not yes then return false,why end end
      if not fs.exists('/home/nexus/logs') then return fs.makeDirectory('/home/nexus/logs') end
      return true
    end
  }
end
function M.new(store,clock)
  return setmetatable({rows={},limit=50,maxBytes=32768,path='/home/nexus/logs/system.log',
    store=store or defaultIO(),clock=clock or function() return 0 end,enabled=true,
    diskStatus='UNTESTED',_ready=false},{__index=M})
end
function M:log(level,category,message)
  local row={at=math.floor(tonumber(self.clock()) or 0),level=safeText(level):sub(1,8),
    category=safeText(category):sub(1,18),message=safeText(message)}
  table.insert(self.rows,1,row)
  if #self.rows>self.limit then table.remove(self.rows) end
  if not self.enabled then return true end
  if not self._ready then
    local ok,success,reason=pcall(self.store.ensure)
    if not ok or not success then self.diskStatus='RAM ONLY: '..safeText(reason or success);return false end
    self._ready=true
  end
  local line=string.format('%d | %s | %s | %s\n',row.at,row.level,row.category,row.message)
  local okSize,size=pcall(self.store.size,self.path)
  if okSize and type(size)=='number' and size+#line>self.maxBytes then
    local okRotate,success=pcall(self.store.rotate,self.path)
    if not okRotate or not success then self.diskStatus='ROTATE FAILED';return false end
  end
  local ok,success=pcall(self.store.append,self.path,line)
  self.diskStatus=(ok and success) and 'PERSISTENT' or 'RAM ONLY: WRITE ERROR'
  return ok and success or false
end
return M
end

package.preload["nexus.core.notices"] = function(...)
-- Bounded in-memory messages; no persistent logs in Phase 2.
local M={}
function M.new()
  return setmetatable({history={},current=nil,maximum=8,enabled=true}, {__index=M})
end
function M:push(message,kind,now)
  local item={message=tostring(message or ''):sub(1,90),kind=kind or 'info',at=type(now)=='number' and now or 0}
  table.insert(self.history,1,item)
  if #self.history>self.maximum then table.remove(self.history) end
  if self.enabled then self.current={item=item,untilTime=item.at+4} end
  return item
end
function M:tick(now)
  if self.current and now>=self.current.untilTime then self.current=nil; return true end
  return false
end
return M
end

package.preload["nexus.core.path"] = function(...)
-- Absolute, lexical paths; does not follow links. Never evaluate user input.
local M={}
function M.normalize(p,cwd)
  if type(p)~='string' or p=='' or #p>512 or p:find('%z') or p:find('[\r\n]') then
    return nil,'Invalid path'
  end
  if p:sub(1,1)~='/' then p=(cwd or '/home')..'/'..p end
  local parts={}
  for part in p:gmatch('[^/]+') do
    if part=='..' then if #parts>0 then table.remove(parts) end
    elseif part~='.' and part~='' then parts[#parts+1]=part end
  end
  return '/'..table.concat(parts,'/')
end
function M.parent(p)
  if p=='/' then return '/' end
  return p:match('^(.+)/[^/]+$') or '/'
end
function M.name(p)
  if p=='/' then return '/' end
  return p:match('([^/]+)$') or '/'
end
function M.join(a,b) return M.normalize(a..'/'..b) end
-- Prevent accidental damage to the OS, NEXUS executable and settings.
local protected={'/boot','/bin','/lib','/etc','/dev','/mnt','/usr','/tmp','/init.lua',
  '/home/nexus', '/home/nexus11.lua','/home/nexus12.lua','/home/nexus20.lua',
  '/home/nexus30.lua','/home/nexus40.lua','/home/nexus-startup.lua',
  '/home/nexus40-bootstrap.lua','/home/osv4.lua','/home/nexus-boot.lua','/home/nexus-startup.lua','/home/.shrc','/home/.shrc.nexus-prev',
  '/home/nexusOS.lua','/home/nexusOS-opt.lua'}
function M.mutable(path)
  if path=='/' then return false,'Root is protected' end
  for _,base in ipairs(protected) do
    if path==base or path:sub(1,#base+1)==base..'/' then
      return false,'Protected system/NEXUS path'
    end
  end
  return true
end
function M.simpleName(s)
  return type(s)=='string' and #s>0 and #s<=100
    and s~='.' and s~='..' and not s:find('[/\\%z\r\n]') and not s:find('[%c]')
end
return M
end

package.preload["nexus.core.performance"] = function(...)
local M={}
function M.new()return setmetatable({samples={},limit=30,lastFree=nil,lowMemory=false,lastWarning=-1000},{__index=M}) end
function M:sample(ctx,now)
  local ok,snap=pcall(ctx.hardware.snapshot,ctx.hardware)
  if not ok then return false end
  local free,total=snap.freeMemory,snap.totalMemory
  if type(free)~='number' or type(total)~='number' or total<=0 then return false end
  self.lastFree=free
  self.lowMemory=free<math.max(64*1024,total*0.12)
  self.samples[#self.samples+1]={time=now,free=free}
  if #self.samples>self.limit then table.remove(self.samples,1) end
  if self.lowMemory and now-self.lastWarning>=30 then
    self.lastWarning=now
    ctx.notify('Low free RAM: '..math.floor(free/1024)..' KiB','warn')
    return true
  end
  return false
end
return M
end

package.preload["nexus.core.recovery"] = function(...)
-- Detect unclean NEXUS sessions; no boot files/BIOS changes.
local M={}
local function defaultStore()
  local path='/home/nexus/session.lock'
  return {
    exists=function()
      local f=io.open(path,'r');if f then f:close();return true end;return false
    end,
    mark=function()
      local ok,fs=pcall(require,'filesystem')
      if not ok then return false end
      if not fs.exists('/home/nexus') then fs.makeDirectory('/home/nexus') end
      local f=io.open(path,'w');if not f then return false end
      f:write('NEXUS v0.4.0 session running\n');f:close();return true
    end,
    clear=function()
      local ok,fs=pcall(require,'filesystem');if not ok then return false end
      if fs.exists(path) then return fs.remove(path) end
      return true
    end
  }
end
function M.new(store,logger)
  return setmetatable({store=store or defaultStore(),logger=logger,
    unclean=false,armed=false,recent={},limit=12},{__index=M})
end
function M:begin()
  local ok,result=pcall(self.store.exists)
  self.unclean=ok and result==true
  local markOk,marked=pcall(self.store.mark)
  self.armed=markOk and marked==true
  if self.unclean then self.logger:log('WARN','recovery','Previous NEXUS session ended without a clean exit') end
  return self.unclean
end
function M:report(area,reason)
  local item={area=tostring(area),message=tostring(reason):sub(1,160)}
  table.insert(self.recent,1,item);if #self.recent>self.limit then table.remove(self.recent) end
  self.logger:log('ERROR',area,reason)
end
function M:finish()
  if not self.armed then return true end
  local ok,result=pcall(self.store.clear)
  if ok and result then self.armed=false;return true end
  self.logger:log('WARN','recovery','Could not clear session lock')
  return false
end
return M
end

package.preload["nexus.core.services"] = function(...)
-- Cooperative NEXUS services. These are NOT OpenOS background processes.
local M={}
function M.new(logger)
  return setmetatable({items={},ordered={},logger=logger,runCount=0},{__index=M})
end
function M:register(def)
  assert(type(def)=='table' and type(def.id)=='string' and not self.items[def.id])
  assert(type(def.tick)=='function' and type(def.interval)=='number' and def.interval>=0.5)
  local s={id=def.id,title=def.title or def.id,interval=def.interval,
    essential=def.essential==true,enabled=def.enabled~=false,status='STOPPED',
    failures=0,runs=0,nextAt=0,start=def.start,stop=def.stop,tickFn=def.tick,lastError=nil}
  self.items[s.id]=s;self.ordered[#self.ordered+1]=s;return s
end
function M:activate(id,ctx,now)
  local s=self.items[id];if not s then return false,'unknown service' end
  if s.status=='RUNNING' then return true end
  if s.start then
    local ok,err=pcall(s.start,ctx)
    if not ok then s.status='FAILED';s.lastError=tostring(err);self.logger:log('ERROR',id,err);return false,err end
  end
  s.enabled=true;s.status='RUNNING';s.failures=0;s.nextAt=now or 0;s.lastError=nil
  self.logger:log('INFO','service','Started '..id)
  return true
end
function M:deactivate(id,ctx)
  local s=self.items[id];if not s then return false,'unknown service' end
  if s.essential then return false,'core service cannot be stopped' end
  if s.status=='RUNNING' and s.stop then
    local ok,err=pcall(s.stop,ctx)
    if not ok then self.logger:log('WARN',id,'Stop error: '..tostring(err)) end
  end
  s.enabled=false;s.status='STOPPED'
  self.logger:log('INFO','service','Stopped '..id)
  return true
end
function M:activateDefaults(ctx,now,safeMode)
  for _,s in ipairs(self.ordered) do
    if s.enabled and (not safeMode or s.essential) then self:activate(s.id,ctx,now)
    elseif safeMode and not s.essential then s.enabled=false end
  end
end
function M:tick(ctx,now)
  local changed=false
  for _,s in ipairs(self.ordered) do
    if s.status=='RUNNING' and now>=s.nextAt then
      -- Set deadline BEFORE calling service, to avoid runaway re-entrancy.
      s.nextAt=now+s.interval
      local ok,result=pcall(s.tickFn,ctx,now)
      if ok then
        s.runs=s.runs+1;self.runCount=self.runCount+1
        if result then changed=true end
      else
        s.failures=s.failures+1;s.lastError=tostring(result)
        self.logger:log('ERROR',s.id,result)
        if s.failures>=3 then
          s.status='FAILED';s.enabled=false
          self.logger:log('WARN','service',s.id..' disabled after 3 errors')
        end
        changed=true
      end
    end
  end
  return changed
end
function M:shutdown(ctx)
  for i=#self.ordered,1,-1 do
    local s=self.ordered[i]
    if s.status=='RUNNING' then
      if s.stop then pcall(s.stop,ctx) end
      s.status='STOPPED'
    end
  end
end
return M
end

package.preload["nexus.core.session"] = function(...)
local M={}
function M.new(now)
  return setmetatable({started=now or 0,opened=0,lastApp='none',current='desktop',transitions=0},{__index=M})
end
function M:open(id) self.current=id;self.lastApp=id;self.opened=self.opened+1;self.transitions=self.transitions+1 end
function M:home() if self.current~='desktop' then self.transitions=self.transitions+1 end;self.current='desktop' end
return M
end

package.preload["nexus.core.startup"] = function(...)
-- Manage OpenOS interactive shell startup; user confirmation required for enable.
local M={}
M.CORE='/home/osv4.lua'
M.BOOT='/home/nexus-boot.lua'
M.SHRC='/home/.shrc'
M.GUARD='/home/nexus/startup.guard'
local BEGIN='# NEXUS-STARTUP BEGIN'
local END='# NEXUS-STARTUP END'
local BOOT_SOURCE=[=[
-- NEXUS-BOOT API 1 owned by NEXUS OS. Do not edit OpenOS /boot.
local fs=require('filesystem')
local core='/home/osv4.lua'
local guard='/home/nexus/startup.guard'
local txn='/home/nexus/updates/transaction'
local backup='/home/nexus/updates/previous.lua'
if fs.exists(txn) then
  if not fs.exists(backup) then
    io.write('NEXUS update recovery: backup missing; OpenOS shell available.\n');return
  end
  local failed='/home/nexus/updates/failed.lua'
  if fs.exists(failed) then fs.remove(failed) end
  if fs.exists(core) then
    local moved=fs.rename(core,failed)
    if not moved then io.write('NEXUS update recovery: cannot isolate candidate.\n');return end
  end
  local ok=fs.rename(backup,core)
  if not ok then io.write('NEXUS update recovery FAILED; use recovery helper.\n');return end
  fs.remove(txn)
  io.write('NEXUS: incomplete update rolled back.\n')
end
if fs.exists(guard) then
  io.write('NEXUS autostart paused after previous unclean run. OpenOS available.\n')
  return
end
local f,why=io.open(guard,'w')
if not f then io.write('NEXUS autostart guard unavailable: '..tostring(why)..'\n');return end
f:write('running\n');f:close()
local ok,result,detail=pcall(dofile,core)
if ok and result==true then fs.remove(guard)
else io.write('NEXUS autostart failed; skipping next startup. '..tostring(detail or result)..'\n') end
]=]
M.BOOT_SOURCE=BOOT_SOURCE
local function defaultRead(p)
  local f=io.open(p,'rb');if not f then return nil end
  local s=f:read(32769);f:close();return s
end
local function defaultWrite(p,s)
  local f,why=io.open(p,'wb');if not f then return false,why end
  local ok,e=pcall(function() assert(f:write(s));assert(f:flush()) end)
  f:close();return ok,e
end
function M.new(opts)
  opts=opts or {}
  return setmetatable({fs=opts.fs or require('filesystem'),read=opts.read or defaultRead,
    write=opts.write or defaultWrite,core=opts.core or M.CORE},{__index=M})
end
function M:status()
  local s=self.read(M.SHRC) or ''
  local b=s:find(BEGIN,1,true)
  local e=s:find(END,1,true)
  if b and e and e>b then
    local block=s:sub(b,e+#END-1)
    return block:find(M.BOOT,1,true) and 'ENABLED' or 'LEGACY'
  end
  if b or e then return 'BROKEN' end
  return 'DISABLED'
end
function M:atomic(path,data)
  local tmp=path..'.nexus-temp';local backup=path..'.nexus-prev'
  local ok,why=self.write(tmp,data);if not ok then return false,why end
  if self.fs.exists(backup) then
    local del,err=self.fs.remove(backup);if not del then self.fs.remove(tmp);return false,err end
  end
  local had=self.fs.exists(path)
  if had then
    local moved,err=self.fs.rename(path,backup)
    if not moved then self.fs.remove(tmp);return false,err end
  end
  local applied,err=self.fs.rename(tmp,path)
  if not applied then
    if had then self.fs.rename(backup,path) end
    return false,err
  end
  return true
end
function M:enable()
  if not self.fs.exists('/home/nexus') then
    local made,why=self.fs.makeDirectory('/home/nexus')
    if not made then return false,why or 'Cannot create /home/nexus' end
  end
  if not self.fs.exists(self.core) then return false,'Missing '..self.core end
  local stat=self:status()
  if stat=='ENABLED' then return true,'Already enabled' end
  if stat=='BROKEN' then return false,'Invalid .shrc markers; manual review required' end
  local original=self.read(M.SHRC) or ''
  if #original>8192 then return false,'.shrc too large; manual review required' end
  if stat=='LEGACY' then
    local b=original:find(BEGIN,1,true)
    local e=original:find(END,1,true)
    local block=original:sub(b,e+#END-1)
    if not block:find('nexus40%-bootstrap%.lua') then
      return false,'Unknown existing NEXUS startup block'
    end
    local endpos=e+#END-1
    if original:sub(endpos+1,endpos+1)=='\n' then endpos=endpos+1 end
    original=original:sub(1,b-1)..original:sub(endpos+1)
  end
  if self.fs.exists(M.BOOT) then
    local old=self.read(M.BOOT)
    if not old or not old:find('NEXUS-BOOT API 1',1,true) then return false,'Unrecognized existing boot helper' end
  end
  local ok,why=self.write(M.BOOT,BOOT_SOURCE)
  if not ok then return false,'Cannot write boot helper: '..tostring(why) end
  if #original>0 and original:sub(-1)~='\n' then original=original..'\n' end
  return self:atomic(M.SHRC,original..BEGIN..'\n'..M.BOOT..'\n'..END..'\n')
end
function M:disable()
  local stat=self:status()
  if stat=='DISABLED' then return true,'Already disabled' end
  if stat=='BROKEN' then return false,'Invalid markers; manual review required' end
  local raw=self.read(M.SHRC) or ''
  local b,e=raw:find(BEGIN,1,true),raw:find(END,1,true)
  if not b or not e or e<=b then return false,'Malformed .shrc' end
  local after=e+#END-1
  if raw:sub(after+1,after+1)=='\n' then after=after+1 end
  return self:atomic(M.SHRC,raw:sub(1,b-1)..raw:sub(after+1))
end
function M:recover()
  if not self.fs.exists(M.GUARD) then return true,'Guard is clear' end
  return self.fs.remove(M.GUARD)
end
return M
end

package.preload["nexus.core.state"] = function(...)
local M={}
function M.new()
  return {running=true,selection=1,scroll=0,settingsSelection=1,
    notificationScroll=0,displayIndex=1,dirty=true,hitboxes={},appHitboxes={},
    navboxes={},lastStatus=-1,lastPreview=-1,redraws=0,screenMode='compact'}
end
return M
end

package.preload["nexus.core.theme"] = function(...)
-- RGB targets; OpenComputers GPU quantizes to the configured color depth.
local M = {}
M.names = {"cyan", "green", "amber"}
local palettes = {
  cyan  = {bg=0x10151D,surface=0x202C3A,muted=0x91A5B9,border=0x394C61,text=0xE5ECF4,accent=0x48CBDC,activeBg=0x48CBDC,activeText=0x10151D,good=0x64DAA0,bad=0xF16B6B,warn=0xF5C76D},
  green = {bg=0x08120C,surface=0x19281B,muted=0x80A78A,border=0x37563B,text=0xD6F4D8,accent=0x68E596,activeBg=0x68E596,activeText=0x08120C,good=0x68E596,bad=0xF17878,warn=0xF3C56C},
  amber = {bg=0x19130B,surface=0x302619,muted=0xB9A183,border=0x655136,text=0xF3E2C3,accent=0xF5BD66,activeBg=0xF5BD66,activeText=0x19130B,good=0xB2D88E,bad=0xEF877B,warn=0xF5BD66}
}
function M.select(depth, name)
  if type(depth) ~= 'number' or depth <= 1 then
    return {bg=0x000000,surface=0x000000,muted=0xFFFFFF,border=0xFFFFFF,text=0xFFFFFF,accent=0xFFFFFF,activeBg=0xFFFFFF,activeText=0x000000,good=0xFFFFFF,bad=0xFFFFFF,warn=0xFFFFFF,monochrome=true,name='mono'}
  end
  local chosen = palettes[name] and name or 'cyan'
  local t = {}
  for k,v in pairs(palettes[chosen]) do t[k]=v end
  t.name=chosen
  return t
end
function M.next(name)
  for i,n in ipairs(M.names) do
    if n==name then return M.names[i % #M.names + 1] end
  end
  return M.names[1]
end
return M
end

package.preload["nexus.core.update"] = function(...)
-- NEXUS update transactions: bounded Pastebin downloads, validate, backup and rollback.
-- Never execute downloaded code during staging. Only trusted user-supplied IDs.
local M={}
M.CORE='/home/osv4.lua'
M.BACKUP='/home/nexus/updates/previous.lua'
M.TEMP='/home/nexus/updates/download.part'
M.STAGED='/home/nexus/updates/staged.lua'
M.META='/home/nexus/updates/staged.meta'
M.TXN='/home/nexus/updates/transaction'
M.VERSION='0.6.1'
M.MAX_BYTES=300000
local function fsDefault() return require('filesystem') end
local function read(path,max)
  local f=io.open(path,'rb');if not f then return nil end
  local x=f:read(max or 1024);f:close();return x
end
local function write(path,s)
  local f,why=io.open(path,'wb');if not f then return false,why end
  local ok,err=pcall(function() assert(f:write(s));assert(f:flush()) end)
  f:close();return ok,err
end
local function parseVersion(head)
  if type(head)~='string' or not head:find('NEXUS%-DISTRIBUTION: 1') then return nil end
  local ver=head:match('NEXUS%-VERSION: (%d+%.%d+%.%d+)')
  return ver
end
local function numbers(ver)
  local a,b,c
  if ver then a,b,c=ver:match('^(%d+)%.(%d+)%.(%d+)$') end
  if not a then return nil end
  return {tonumber(a),tonumber(b),tonumber(c)}
end
function M.new(opts)
  opts=opts or {}
  return setmetatable({fs=opts.fs or fsDefault(),fetch=opts.fetch,read=opts.read or read,
    write=opts.write or write,open=opts.open or io.open,compile=opts.compile or loadfile,
    current=opts.current or M.CORE,version=opts.version or M.VERSION,
    limit=opts.limit or M.MAX_BYTES},{__index=M})
end
function M:ensure()
  for _,p in ipairs({'/home/nexus','/home/nexus/updates'}) do
    if not self.fs.exists(p) then
      local ok,err=self.fs.makeDirectory(p)
      if not ok then return false,err or ('Cannot create '..p) end
    end
  end
  return true
end
function M:validate(path,allowSame)
  local head=self.read(path,512)
  local ver=parseVersion(head)
  if not ver then return nil,'Not a NEXUS Phase 5A+ release (missing release header)' end
  local a,b=numbers(ver),numbers(self.version)
  if not a or not b then return nil,'Bad version number' end
  for i=1,3 do
    if a[i]>b[i] then break end
    if a[i]<b[i] then return nil,'Downgrade blocked; use rollback' end
    if i==3 and not allowSame then return nil,'Same version; no update needed' end
  end
  local size=self.fs.size(path)
  if type(size)=='number' and (size<100 or size>self.limit) then return nil,'Invalid release file size' end
  local chunk,why=self.compile(path,'t')
  if not chunk then return nil,'Lua syntax invalid: '..tostring(why):sub(1,120) end
  return ver
end
function M:stagedVersion()
  if not self.fs.exists(M.STAGED) then return nil end
  local ver=self:validate(M.STAGED)
  if ver then return ver end
  return nil
end
function M:stage(id)
  if type(id)~='string' or not id:match('^[%w]+$') or #id<6 or #id>16 then
    return false,'Pastebin ID must be 6-16 letters/digits'
  end
  local ok,why=self:ensure();if not ok then return false,why end
  if self.fs.exists(M.TXN) then return false,'Unresolved update transaction; recover first' end
  local request=self.fetch
  if not request then
    local found,internet=pcall(require,'internet')
    if not found or type(internet.request)~='function' then return false,'Internet Card / OpenOS internet API unavailable' end
    request=internet.request
  end
  local url='https://pastebin.com/raw/'..id
  local started,iter,reason=pcall(request,url)
  if not started then return false,'Network error: '..tostring(iter):sub(1,120) end
  -- OpenOS internet.request() returns a callable table (__call), not a Lua function.
  -- Both callable tables and ordinary function iterators work in generic for loops.
  local kind=type(iter)
  local mt=kind=='table' and getmetatable(iter) or nil
  local callable=kind=='function' or (kind=='table' and type(mt)=='table' and type(mt.__call)=='function')
  if not callable then
    if kind=='table' then return false,'Internet API returned a non-callable table' end
    return false,'Download unavailable: '..tostring(reason or iter)
  end
  local f,err=self.open(M.TEMP,'wb');if not f then return false,'Cannot create staging file: '..tostring(err) end
  local bytes=0
  local transferred,problem=pcall(function()
    for block in iter do
      if type(block)~='string' then error('Invalid network response') end
      bytes=bytes+#block
      if bytes>self.limit then error('Update exceeds '..self.limit..' bytes') end
      assert(f:write(block))
    end
    assert(f:flush())
  end)
  pcall(function() f:close() end)
  if not transferred or bytes<100 then
    pcall(self.fs.remove,M.TEMP)
    return false,transferred and 'Empty/short download' or tostring(problem):sub(1,120)
  end
  local ver,whyValid=self:validate(M.TEMP)
  if not ver then pcall(self.fs.remove,M.TEMP);return false,whyValid end
  if self.fs.exists(M.STAGED) then
    local removed,errRemove=self.fs.remove(M.STAGED)
    if not removed then self.fs.remove(M.TEMP);return false,errRemove end
  end
  local moved,whyMove=self.fs.rename(M.TEMP,M.STAGED)
  if not moved then self.fs.remove(M.TEMP);return false,whyMove end
  -- Metadata is advisory; never run or evaluate it.
  local wrote,whyWrite=self.write(M.META,'id='..id..'\nversion='..ver..'\nbytes='..bytes..'\n')
  if not wrote then self.fs.remove(M.STAGED);return false,whyWrite end
  return true,ver,bytes
end
function M:commit()
  if not self.fs.exists(M.STAGED) then return false,'No staged update' end
  local ver,why=self:validate(M.STAGED)
  if not ver then return false,why end
  if not self.fs.exists(self.current) then return false,'Active OS missing: '..self.current end
  if self.fs.exists(M.TXN) then return false,'Unresolved update transaction' end
  local ok,err=self:ensure();if not ok then return false,err end
  if self.fs.exists(M.BACKUP) then
    local removed,whyRemove=self.fs.remove(M.BACKUP)
    if not removed then return false,whyRemove end
  end
  local moved,whyMove=self.fs.rename(self.current,M.BACKUP)
  if not moved then return false,'Cannot back up OS: '..tostring(whyMove) end
  local mark,whyMark=self.write(M.TXN,'trial='..ver..'\n')
  if not mark then self.fs.rename(M.BACKUP,self.current);return false,whyMark end
  local installed,whyInstalled=self.fs.rename(M.STAGED,self.current)
  if not installed then
    self.fs.rename(M.BACKUP,self.current)
    self.fs.remove(M.TXN)
    return false,'Cannot install candidate: '..tostring(whyInstalled)
  end
  pcall(self.fs.remove,M.META)
  return true,ver
end
function M:rollback()
  if not self.fs.exists(M.BACKUP) then return false,'No previous OS backup' end
  -- Keep the bad new release for diagnosis (only one copy).
  local failed='/home/nexus/updates/failed.lua'
  if self.fs.exists(failed) then self.fs.remove(failed) end
  if self.fs.exists(self.current) then
    local ok,err=self.fs.rename(self.current,failed)
    if not ok then return false,'Cannot move failed release: '..tostring(err) end
  end
  local ok,err=self.fs.rename(M.BACKUP,self.current)
  if not ok then
    if self.fs.exists(failed) and not self.fs.exists(self.current) then self.fs.rename(failed,self.current) end
    return false,'Rollback failed: '..tostring(err)
  end
  if self.fs.exists(M.TXN) then self.fs.remove(M.TXN) end
  return true
end
function M:finish()
  if self.fs.exists(M.TXN) then return self.fs.remove(M.TXN) end
  return true
end
function M:recoverInterrupted()
  if not self.fs.exists(M.TXN) then return false end
  return self:rollback()
end
return M
end

package.preload["nexus.main"] = function(...)
-- NEXUS OS v0.6.1 | Phase 5B | one foreground app, no boot modifications.
local Hardware=require('nexus.core.hardware')
local Graphics=require('nexus.core.graphics')
local Theme=require('nexus.core.theme')
local Input=require('nexus.core.input')
local Apps=require('nexus.core.apps')
local State=require('nexus.core.state')
local Config=require('nexus.core.config')
local Notices=require('nexus.core.notices')
local Display=require('nexus.core.display')
local Widgets=require('nexus.ui.widgets')
local Desktop=require('nexus.ui.desktop')
local About=require('nexus.apps.about')
local System=require('nexus.apps.system')
local Settings=require('nexus.apps.settings')
local Notifications=require('nexus.apps.notifications')
local Files=require('nexus.apps.files')
local Terminal=require('nexus.apps.terminal')
local Monitor=require('nexus.apps.monitor')
local Control=require('nexus.apps.control')
local UpdateCenter=require('nexus.apps.updatecenter')
local HardwareCenter=require('nexus.apps.hardwarecenter')
local DeviceControl=require('nexus.core.devicecontrol')
local Automation=require('nexus.core.automation')
local HwEvents=require('nexus.core.hwevents')
local Updater=require('nexus.core.update')
local Startup=require('nexus.core.startup')
local Logger=require('nexus.core.logger')
local Recovery=require('nexus.core.recovery')
local Session=require('nexus.core.session')
local Services=require('nexus.core.services')
local Performance=require('nexus.core.performance')

local function capture(gpu,term)
  local snap={}
  local function get(name)
    if type(gpu[name])=='function' then
      local ok,a,b=pcall(gpu[name]); if ok then return a,b end
    end
  end
  snap.fg,snap.fgPalette=get('getForeground')
  snap.bg,snap.bgPalette=get('getBackground')
  snap.w,snap.h=get('getResolution')
  snap.depth=get('getDepth')
  if term and type(term.getCursorBlink)=='function' then
    local ok,v=pcall(term.getCursorBlink); if ok then snap.blink=v end
  end
  return snap
end
local function restore(gpu,term,snap)
  if not gpu then return end
  if snap then
    if snap.depth and type(gpu.setDepth)=='function' then pcall(gpu.setDepth,snap.depth) end
    if snap.w and snap.h and type(gpu.setResolution)=='function' then
      local ok,w,h=pcall(gpu.getResolution)
      if not ok or w~=snap.w or h~=snap.h then pcall(gpu.setResolution,snap.w,snap.h) end
    end
    if snap.bg and type(gpu.setBackground)=='function' then pcall(gpu.setBackground,snap.bg,snap.bgPalette==true) end
    if snap.fg and type(gpu.setForeground)=='function' then pcall(gpu.setForeground,snap.fg,snap.fgPalette==true) end
  end
  if type(gpu.getResolution)=='function' and type(gpu.fill)=='function' then
    local ok,w,h=pcall(gpu.getResolution)
    if ok and type(w)=='number' and type(h)=='number' then
      pcall(gpu.fill,1,1,w,h,' ')
    end
  end
  if term and type(term.setCursor)=='function' then pcall(term.setCursor,1,1) end
  if snap and snap.blink~=nil and term and type(term.setCursorBlink)=='function' then
    pcall(term.setCursorBlink,snap.blink)
  end
end
local function run(deps)
  deps=deps or {}
  local component=deps.component or require('component')
  local computer=deps.computer or require('computer')
  local event=deps.event or require('event')
  local term=deps.term or require('term')
  local keys=deps.keys or require('keyboard').keys
  local hardware,reason=Hardware.new(component,computer,term)
  if not hardware then return false,reason end
  local gpu=hardware.gpu
  local original=capture(gpu,term)
  local state=State.new()
  local config=Config.new(deps.persistence)
  local notices=Notices.new()
  notices.enabled=config.data.notifications
  local manager=Apps.new()
  manager:register(Files);manager:register(Terminal);manager:register(Monitor)
  manager:register(System);manager:register(Settings);manager:register(Notifications)
  manager:register(Control)
  manager:register(UpdateCenter)
  manager:register(HardwareCenter)
  manager:register(About)
  local gfx=Graphics.new(gpu)
  local display=Display.new(gpu,function() return computer.uptime() end)
  local logger=Logger.new(deps.logStore,function() return computer.uptime() end)
  logger.enabled=config.data.logging~=false
  local recovery=Recovery.new(deps.recoveryStore,logger)
  local wasUnclean=recovery:begin()
  local services=Services.new(logger)
  local session=Session.new(computer.uptime())
  local performance=Performance.new()
  local updater=deps.updater or Updater.new({fs=deps.fs})
  local startup=deps.startup or Startup.new({fs=deps.fs})
  local deviceControl=DeviceControl.new(component,logger)
  local automation=Automation.new(deviceControl,logger)
  local hwEvents=HwEvents.new(24)
  local ctx={gfx=gfx,theme=Theme.select(hardware:snapshot().depth,config.data.theme),
    hardware=hardware,state=state,manager=manager,config=config,notices=notices,
    display=display,native=original,now=function() return computer.uptime() end,
    fs=deps.fs,logger=logger,recovery=recovery,services=services,
    session=session,performance=performance,safeMode=wasUnclean,
    updater=updater,startup=startup,deviceControl=deviceControl,automation=automation,hwEvents=hwEvents}
  state.settingsScroll=0
  state.exitPending=false
  state.exitButtons={}
  services:register({id='core',title='Session heartbeat',essential=true,interval=4,
    tick=function() return false end})
  services:register({id='notices',title='Notification expiry',essential=true,interval=1,
    tick=function(_,now) return notices:tick(now) end})
  services:register({id='memory',title='Memory sampling',interval=4,
    enabled=config.data.monitorService~=false,
    tick=function(c,now) return performance:sample(c,now) end})
  services:register({id='hardware-mirror',title='Session redstone automation',interval=1,
    tick=function(_,now) return automation:tick(now) end,
    stop=function() if automation.enabled then automation:disable() end end})
  services:activateDefaults(ctx,computer.uptime(),wasUnclean)
  if wasUnclean then notices:push('Previous session ended unexpectedly. Open System Center / Recovery.','warn',computer.uptime()) end
  logger:log('INFO','core','NEXUS v0.6.1 launched')
  function ctx.notify(text,kind)
    notices:push(text,kind,computer.uptime())
    state.dirty=true
  end
  function ctx.changeSetting(k,value)
    local ok,why=config:set(k,value)
    if not ok then ctx.notify(why,'error'); return end
    if k=='theme' then ctx.theme=Theme.select(hardware:snapshot().depth,config.data.theme) end
    if k=='notifications' then notices.enabled=value; if not value then notices.current=nil end end
    if k=='logging' then logger.enabled=value end
    if k=='monitorService' then
      if value then services:activate('memory',ctx,ctx.now()) else services:deactivate('memory',ctx) end
    end
    local saved,err=config:save()
    if not saved then ctx.notify('Setting not saved: '..tostring(err),'error')
    else ctx.notify('Saved '..k..' = '..tostring(value),'info') end
  end
  function ctx.resetSettings()
    local saved,err=config:reset()
    notices.enabled=config.data.notifications
    ctx.theme=Theme.select(hardware:snapshot().depth,config.data.theme)
    logger.enabled=config.data.logging
    if config.data.monitorService then services:activate('memory',ctx,ctx.now())
    else services:deactivate('memory',ctx) end
    if saved then ctx.notify('Preferences restored to defaults','info')
    else ctx.notify('Reset not saved: '..tostring(err),'error') end
  end
  function ctx.beginResolution()
    -- Read the real maximum independently: never rely on a stale hardcoded value.
    local ok,mw,mh=pcall(gpu.maxResolution)
    if not ok then ctx.notify('Display capabilities unavailable','error'); return end
    local options=display:presets(original.w,original.h,mw,mh)
    local choice=options[state.displayIndex]
    if not choice then return end
    local applied,err=display:preview(choice.w,choice.h)
    if not applied then ctx.notify('Display: '..tostring(err),'warn')
    else state.dirty=true end
  end

  -- External OpenOS commands run only on explicit "run COMMAND". They may
  -- temporarily take control of the entire screen. Never execute untrusted commands.
  function ctx.runShell(command,cwd)
    if deps.runShell then return deps.runShell(command,cwd) end
    local okShell,shell=pcall(require,'shell')
    if not okShell or type(shell.execute)~='function' then return false,'OpenOS shell unavailable' end
    local w,h=gfx:size()
    gfx:fill(1,1,w,h,0x000000)
    gfx:colors(0xffffff,0x000000)
    if type(term.setCursor)=='function' then pcall(term.setCursor,1,1) end
    if type(term.setCursorBlink)=='function' then pcall(term.setCursorBlink,true) end
    local oldDir
    if type(shell.getWorkingDirectory)=='function' then
      local yes,v=pcall(shell.getWorkingDirectory);if yes then oldDir=v end
    end
    if type(shell.setWorkingDirectory)=='function' then pcall(shell.setWorkingDirectory,cwd) end
    local done,a,b=pcall(shell.execute,command)
    if oldDir and type(shell.setWorkingDirectory)=='function' then pcall(shell.setWorkingDirectory,oldDir) end
    if type(term.setCursorBlink)=='function' then pcall(term.setCursorBlink,false) end
    -- Input is optional on a mocked console; real OpenOS has term.read.
    if type(term.read)=='function' then
      pcall(function() io.write('\nPress ENTER to return to NEXUS...');io.flush();term.read() end)
    end
    gfx.foreground=nil;gfx.background=nil -- shell may have changed GPU colors
    state.dirty=true
    if not done then return false,tostring(a) end
    if a==false then return false,tostring(b) end
    return true
  end
  local function openSelected(id)
    if id=='__exit' then state.exitPending=true;state.dirty=true;return end
    local ok,err=manager:open(id,ctx)
    if not ok then recovery:report('app.open',err);ctx.notify('App: '..tostring(err),'error')
    else session:open(id);logger:log('INFO','app','Opened '..id) end
    state.dirty=true
  end
  local function activate()
    local entry=Desktop.entries(manager)[state.selection]
    if entry then openSelected(entry.id) end
  end
  local function navigate(kind)
    if kind=='home' then manager:home(ctx);session:home();state.dirty=true
    elseif kind=='back' then
      if manager.active then
        local handled,err=manager:input({kind='back'},ctx)
        if err then recovery:report('app.back',err) end
        if not handled or err then manager:home(ctx);session:home() end
      else state.exitPending=true end
      state.dirty=true
    elseif kind=='exit' then state.exitPending=true;state.dirty=true
    elseif kind=='control' then openSelected('control')
    elseif kind=='updatecenter' then openSelected('updatecenter')
    elseif kind=='hardwarecenter' then openSelected('hardwarecenter')
    elseif kind=='settings' or kind=='system' or kind=='notifications' or kind=='files' or kind=='terminal' or kind=='monitor' then openSelected(kind)
    elseif kind=='theme' then ctx.changeSetting('theme',Theme.next(config.data.theme))
    elseif kind=='refresh' then state.dirty=true end
  end
  local function touch(x,y)
    for _,hit in ipairs(state.navboxes or {}) do
      if x>=hit.x and y>=hit.y and x<hit.x+hit.w and y<hit.y+1 then navigate(hit.id); return end
    end
    if manager.active then
      local handled,err=manager:input({kind='touch',x=x,y=y},ctx)
      if err then ctx.notify('App input: '..tostring(err),'error')
      elseif handled then state.dirty=true end
    else
      for _,hit in ipairs(state.hitboxes) do
        if x>=hit.x and y>=hit.y and x<hit.x+hit.w and y<hit.y+hit.h then
          state.selection=hit.index;openSelected(hit.id);return
        end
      end
    end
  end
  local function dispatch(action)
    if not action then return end
    local kind=action.kind
    if kind=='quit' then state.exitPending=true;state.dirty=true;return end
    if state.exitPending then
      if kind=='char' and (action.value=='y' or action.value=='Y') then state.running=false
      elseif kind=='char' and (action.value=='n' or action.value=='N') or kind=='back' then
        state.exitPending=false;state.dirty=true
      elseif kind=='touch' then
        for _,b in ipairs(state.exitButtons) do
          if action.x>=b.x and action.x<b.x+b.w and action.y==b.y then
            if b.id=='yes' then state.running=false else state.exitPending=false;state.dirty=true end
            break
          end
        end
      end
      return
    end
    if display.pending then
      if kind=='enter' then
        display:confirm();ctx.notify('Resolution confirmed (session only)','info')
      elseif kind=='back' then
        display:rollback();ctx.notify('Resolution reverted','warn')
      elseif kind=='touch' then
        -- Only the visible BACK control is allowed to cancel a display preview.
        -- An arbitrary click must never silently accept a new resolution.
        for _,hit in ipairs(state.navboxes or {}) do
          if hit.id=='back' and action.x>=hit.x and action.x<hit.x+hit.w and action.y==hit.y then
            display:rollback();ctx.notify('Resolution reverted','warn');break
          end
        end
      end
      state.dirty=true
      return
    end
    if kind=='resize' then state.dirty=true; return end
    if kind=='touch' then touch(action.x,action.y);return end
    if kind=='home' or kind=='back' or kind=='exit' or kind=='control' or kind=='settings' or kind=='system' or kind=='notifications' or kind=='files' or kind=='terminal' or kind=='monitor' or kind=='theme' or kind=='refresh' or kind=='updatecenter' or kind=='hardwarecenter' then
      navigate(kind);return
    end
    if manager.active then
      local handled,err=manager:input(action,ctx)
      if kind=='back' and not handled and not err then manager:home(ctx);session:home();state.dirty=true;return end
      if err then recovery:report('app.input',err);session:home();ctx.notify('App input: '..tostring(err),'error')
      elseif handled then state.dirty=true end
      return
    end
    local n=#Desktop.entries(manager)
    if kind=='back' or (kind=='char' and action.value=='q') then state.exitPending=true;state.dirty=true
    elseif kind=='char' and (action.value=='h' or action.value=='H') then state.selection=1;state.dirty=true
    elseif kind=='char' and action.value:match('^[1-9]$') then
      local idx=tonumber(action.value)
      local entry=Desktop.entries(manager)[idx]
      if entry then state.selection=idx;openSelected(entry.id) end
    elseif kind=='enter' then activate()
    elseif kind=='tab' or kind=='right' or kind=='down' then
      state.selection=state.selection%n+1;state.dirty=true
    elseif kind=='left' or kind=='up' then
      state.selection=(state.selection-2+n)%n+1;state.dirty=true
    end
  end
  local function redraw()
    local w,h=gfx:size()
    if manager.active then
      local ok,err=manager:draw(ctx)
      if not ok then recovery:report('app.draw',err);session:home();ctx.notify('App draw: '..tostring(err),'error');Desktop.draw(ctx) end
    else
      Desktop.draw(ctx)
    end
    Widgets.toast(ctx)
    Widgets.preview(ctx)
    Widgets.exitDialog(ctx)
    state.dirty=false
    state.redraws=state.redraws+1
  end
  local function loop()
    if type(term.setCursorBlink)=='function' then pcall(term.setCursorBlink,false) end
    if config.data.splash then
      local w,h=gfx:size()
      gfx:fill(1,1,w,h,ctx.theme.bg)
      gfx:center(math.max(2,math.floor(h/2)),'NEXUS OS / v0.6.1',ctx.theme.accent,ctx.theme.bg)
      -- Pull once; forward this event to dispatch so no input is dropped.
      local e,a,b,c,d=event.pull(0.2)
      dispatch(Input.decode(e,a,b,c,hardware,keys,d))
    end
    while state.running do
      if state.dirty then redraw() end
      local e,a,b,c,d=event.pull(0.5)
      if hwEvents:push(computer.uptime(),e,a,b,c,d) then
        if manager.active and manager.active.id=='hardwarecenter' then state.dirty=true end
      end
      dispatch(Input.decode(e,a,b,c,hardware,keys,d))
      local changed,appError=manager:tick(ctx)
      if appError then recovery:report('app.tick',appError);session:home();ctx.notify('App update: '..tostring(appError),'error')
      elseif changed then state.dirty=true end
      local now=computer.uptime()
      if display:tick() then ctx.notify('Resolution preview timed out; reverted','warn') end
      if services:tick(ctx,now) then state.dirty=true end
      if display.pending then
        local remain=math.ceil(display.pending.deadline-now)
        if remain~=state.lastPreview then state.lastPreview=remain;state.dirty=true end
      else state.lastPreview=-1 end
      local rounded=math.floor(now/4)
      if rounded~=state.lastStatus then
        state.lastStatus=rounded
        if not manager.active or manager.active.id=='system' then state.dirty=true end
      end
    end
    manager:home(ctx);session:home()
  end
  local ok,result=xpcall(loop,function(e)
    return debug and debug.traceback and debug.traceback(e,2) or tostring(e)
  end)
  if not ok then recovery:report('core.loop',result) end
  services:shutdown(ctx)
  -- Hardware outputs are session-owned; best-effort restoration after all exits.
  local restored,whyRestore=automation:emergencyStop()
  if not restored then logger:log('ERROR','hardware','Exit restore failed: '..tostring(whyRestore)) end
  display:rollback()
  restore(gpu,term,original)
  if ok then recovery:finish() end
  if not ok then return false,result end
  return true,{redraws=state.redraws,mode=state.screenMode,theme=config.data.theme,services=services.runCount,updateAction=state.updateAction}
end
return run
end

package.preload["nexus.ui.desktop"] = function(...)
local Widgets=require('nexus.ui.widgets')
local M={}
function M.entries(manager)
  local items={}
  for _,app in ipairs(manager.items) do items[#items+1]={id=app.id,name=app.name,description=app.description or 'Application'} end
  items[#items+1]={id='__exit',name='Exit NEXUS',description='Return safely to OpenOS'}
  return items
end
function M.draw(ctx)
  local g,t,s=ctx.gfx,ctx.theme,ctx.state
  local w,h=g:size()
  Widgets.frame(ctx,'DESKTOP / APPLICATIONS')
  s.hitboxes={}
  if w<20 or h<8 then g:text(1,3,'Enlarge screen',t.bad,t.bg); return end
  local entries=M.entries(ctx.manager)
  s.selection=math.max(1,math.min(#entries,s.selection))
  local standard=s.screenMode=='standard'
  if standard then
    local hs=ctx.hardware:snapshot()
    g:text(3,4,'SYSTEM READY',t.good,t.bg)
    g:text(3,5,'OPEN WITH ENTER / TOUCH   |   1-9 DIRECT LAUNCH',t.muted,t.bg,w-6)
    local withPanel=w>=100
    local left=withPanel and math.floor(w*0.64) or w-3
    local gap=2
    local tileW=math.floor((left-3*2-gap)/2)
    local tileH=h>=29 and 3 or 2
    for i,entry in ipairs(entries) do
      local col=(i-1)%2; local row=math.floor((i-1)/2)
      local x=3+col*(tileW+gap)
      local y=7+row*tileH
      if y+tileH-1<h-1 and tileW>=10 then
        Widgets.action(g,t,x,y,tileW,tileH,tostring(i)..'  '..entry.name,entry.description,i==s.selection)
        s.hitboxes[#s.hitboxes+1]={x=x,y=y,w=tileW,h=tileH,id=entry.id,index=i}
      end
    end
    if withPanel then
      local px=left+2; local pw=w-px-2
      Widgets.panel(g,t,px,7,pw,12,'LIVE / STATUS')
      local rows={
        'GPU  '..tostring(hs.gpuAddress or '?'):sub(1,8),
        'RAM  '..(type(hs.freeMemory)=='number' and math.floor(hs.freeMemory/1024)..' KiB' or '?'),
        'SIZE '..tostring(hs.resolutionW or '?')..'x'..tostring(hs.resolutionH or '?'),
        'DEPTH '..tostring(hs.depth or '?')..' bit',
        'UP '..(type(hs.uptime)=='number' and math.floor(hs.uptime)..' s' or '?'),
        'THEME '..ctx.config.data.theme:upper()
      }
      for j,line in ipairs(rows) do g:text(px+2,8+j,line,t.text,t.surface,pw-4) end
    end
  else
    g:text(2,3,'APPLICATIONS / 1-9  / '..ctx.config.data.theme:upper(),t.accent,t.bg,w-3)
    local count=math.max(1,math.floor((h-5)/2))
    if s.selection<s.scroll+1 then s.scroll=s.selection-1 end
    if s.selection>s.scroll+count then s.scroll=s.selection-count end
    s.scroll=math.max(0,math.min(s.scroll,math.max(0,#entries-count)))
    for slot=1,count do
      local i=s.scroll+slot; local entry=entries[i]
      if entry then
        local y=4+(slot-1)*2
        Widgets.action(g,t,2,y,w-4,2,tostring(i)..'  '..entry.name,entry.description,i==s.selection)
        s.hitboxes[#s.hitboxes+1]={x=2,y=y,w=w-4,h=2,id=entry.id,index=i}
      end
    end
    if #entries>count then g:text(w-7,3,(s.scroll+1)..'-'..math.min(#entries,s.scroll+count)..'/'..#entries,t.muted,t.bg,7) end
  end
end
return M
end

package.preload["nexus.ui.widgets"] = function(...)
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
  if mode=='standard' then g:text(math.max(2,w-14),1,'v0.6.1 OPENOS',t.muted,t.surface,14) end
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
end

local Update = require("nexus.core.update")
local updater = Update.new()
-- Interrupted replacement after power loss: restore previous release.
if not _G.__nexus_trial and updater.fs.exists(Update.TXN) then
  local repaired, why = updater:recoverInterrupted()
  if not repaired then io.stderr:write("NEXUS recovery: "..tostring(why).."\n"); return false, why end
  if updater.fs.exists(Update.CORE) then return dofile(Update.CORE) end
end
local run = require("nexus.main")
local ok, result = run()
if not ok then io.stderr:write("NEXUS failed: "..tostring(result).."\n"); return false, result end
local action = type(result)=="table" and result.updateAction
if action=="install" or action=="rollback" then
  local changed, why
  if action=="install" then changed,why=updater:commit() else changed,why=updater:rollback() end
  if not changed then io.stderr:write("NEXUS update: "..tostring(why).."\n");return false,why end
  for name in pairs(package.loaded) do if name:match("^nexus%.") then package.loaded[name]=nil end end
  _G.__nexus_trial=true
  local launched, success, detail=pcall(dofile,Update.CORE)
  _G.__nexus_trial=nil
  if launched and success==true then
    if action=="install" then updater:finish() end
    return true,detail
  end
  if action=="install" then
    local restored,whyRollback=updater:rollback()
    io.stderr:write("NEXUS update failed; rollback: "..tostring(whyRollback or restored).."\n")
  end
  return false,tostring(detail or success)
end
return true, result
