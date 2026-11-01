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
