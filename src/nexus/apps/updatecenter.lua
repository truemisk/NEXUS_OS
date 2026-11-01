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
      if ctx.gfx then ctx.gfx.foreground=nil;ctx.gfx.background=nil end
      if ctx.state then ctx.state.dirty=true end
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
