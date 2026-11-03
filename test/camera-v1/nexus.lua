-- DEVELOPMENT CANDIDATE: camera-v1-d03a202-08105053e8f4; physical validation pending; official version remains 0.6.5
-- NEXUS OS Core v0.6.5 | GitHub Update Center | OpenOS (Lua 5.3)
-- NEXUS-DISTRIBUTION: 1
-- NEXUS-VERSION: 0.6.5
-- Modular source layout: see README.md
-- Single-file distribution: startup remains opt-in; never edits boot files.

package.preload["nexus.apps.about"] = function(...)
local Widgets=require('nexus.ui.widgets')
local M={id='about',name='About NEXUS',description='Version and architecture'}
function M.draw(ctx)
  local g,t=ctx.gfx,ctx.theme
  local w,h=g:size()
  Widgets.frame(ctx,'ABOUT / NEXUS',true)
  if Widgets.rich(ctx) then
    local lw=math.floor((w-6)*0.65);local rx=lw+4;local rw=w-rx
    Widgets.outline(g,t,2,4,lw,h-9,'ABOUT / NEXUS')
    g:text(4,6,'NEXUS OS',t.accent,t.bg,lw-4)
    g:text(4,7,'Core v0.6.5  /  OpenOS',t.text,t.bg,lw-4)
    local lines={'Graphical environment for OpenComputers.',
      'Runs on OpenOS, without BIOS modifications.',
      'One foreground application; no multitasking.',
      'File Manager, Terminal, and System Monitor.'}
    for i,line in ipairs(lines) do g:text(4,9+i,line,t.text,t.bg,lw-4) end
    Widgets.outline(g,t,rx,4,rw,13,'CONTROLS')
    for i,line in ipairs({'1-9  Quick launch','TAB  Select other apps',
      '[BACK] / [HOME]  Navigate','[EXIT]  Confirm OpenOS return',
      'Autostart is opt-in'}) do g:text(rx+2,5+i*2,line,t.muted,t.bg,rw-4) end
    local hs=ctx.hardware:snapshot()
    Widgets.outline(g,t,rx,19,rw,10,'DISPLAY')
    g:text(rx+2,21,'RESOLUTION  '..w..'x'..h,t.text,t.bg,rw-4)
    g:text(rx+2,23,'DEPTH       '..tostring(hs.depth or '?')..' bit',t.text,t.bg,rw-4)
    local simulated=tostring(hs.gpuAddress or ''):match('^sim%-')~=nil
    if simulated then g:text(rx+2,25,'SIMULATED HARDWARE',t.accent,t.bg,rw-4) end
    g:text(3,h-2,'[BACK] or [HOME] return to desktop',t.muted,t.bg,w-5)
    return
  end
  local lines={
    'NEXUS OS',
    'Core v0.6.5  |  GitHub Update Center',
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

package.preload["nexus.apps.camera"] = function(...)
local W=require('nexus.ui.widgets')
local Device=require('nexus.core.camera_device')
local Scan=require('nexus.core.camera_scan')
local Config=require('nexus.core.camera_config')
local Depth=require('nexus.ui.camera_depth')
local Text=require('nexus.core.vault').text
local M={id='camera',name='CAMERA CENTER',description='Computronics raycast depth monitor'}
local settings={'CAMERA NAME','SCAN QUALITY','RAYCAST ZOOM','DEPTH PALETTE','REFRESH MODE','DISTANCE SHADE SCALE','GRID LAYOUT','VIEW DIRECTION','RESET THIS CAMERA'}
local refreshNames={'MANUAL','PERIODIC 10s','PERIODIC 30s','PERIODIC 60s'}
local intervals={0,10,30,60}
local function st(c) return c.state.camera end
local function selected(s) return s.engine.order[s.index] end
local function pref(s,cam) return cam and Config.clean(s.prefs[cam.address]) or Config.defaults() end
local function name(s,cam) return pref(s,cam).name or ('CAM '..cam.address:sub(1,8)..'..'..cam.address:sub(-4)) end
local function changed(s) s.full=true end
local function persist(c)
 local s=st(c);local ok,err=Config.save(s.prefs,c.cameraStore);s.selectionDirty=false;s.message=ok and 'Camera preferences saved' or ('SAVE FAILED: '..tostring(err));if not ok and c.notify then c.notify(s.message,'error') end;changed(s)
end
local function choose(c,index)
 local s=st(c);s.index=math.max(1,math.min(index,#s.engine.order));s.details=false
 local cam=selected(s);if cam then s.prefs._selected=cam.address;s.selectionDirty=true end;changed(s)
end
local function gridCount(c,s)
 local p=pref(s,selected(s));local w,h=c.gfx:size()
 if p.grid==2 or (p.grid==1 and #s.engine.order<=2) or w<100 or h<35 then return 2 end;return 4
end
local function visible(c)
 local s=st(c);local list=s.engine.order
 if s.mode~='grid' then local cam=selected(s);return cam and {cam} or {} end
 local count=gridCount(c,s);local result={};local first=math.floor((s.index-1)/count)*count+1
 for i=first,math.min(#list,first+count-1) do result[#result+1]=list[i] end
 return result
end
local function scan(c)
 local s=st(c);for _,cam in ipairs(visible(c)) do
  local ok,why=s.engine:start(cam.address,pref(s,cam),s.mode=='grid')
  if not ok then s.message=why end
 end;changed(s)
end
function M.open(c)
 local prefs=Config.load(c.cameraStore)
 c.cameraEngine=c.cameraEngine or Scan.new(Device.new(c.deviceControl.component),c.now,function() return c.hardware:snapshot().freeMemory end)
 local e=c.cameraEngine;e:discover(prefs)
 c.state.camera={engine=e,prefs=prefs,index=1,tab=1,mode='console',setting=1,hits={},full=true,paint={},paused=true,message=e.error or '',lastPaint=c.now()}
 local s=st(c);for i,cam in ipairs(e.order) do if cam.address==prefs._selected then s.index=i end end
 -- Periodic mode is saved, but each foreground session starts paused for safety.
end
function M.close(c)
 local s=st(c);if not s then return end;s.engine:cancel()
 for _,cam in pairs(s.engine.devices) do if cam.snapshot or cam.partial then cam.stale=true end end
 if s.selectionDirty then local ok,why=Config.save(s.prefs,c.cameraStore);if not ok and c.notify then c.notify('Camera selection save failed: '..tostring(why),'error') end end
 c.state.camera=nil
end
function M.hardwareEvent(c,event,address,kind)
 local s=st(c);if not s or kind~='camera' then return end
 if event=='component_removed' then s.engine:remove(address) elseif event=='component_added' then s.engine:discover(s.prefs) end
 choose(c,s.index);s.message=s.engine.error or (event=='component_removed' and 'Camera disconnected; cached data is old' or 'Camera network updated')
end
function M.tick(c)
 local s=st(c);local e=s.engine;local before=#e.jobs
 if not s.paused and s.tab==1 then
  for _,cam in ipairs(visible(c)) do
   local p=pref(s,cam);local delay=intervals[p.refresh]
   if delay>0 and cam.available and not cam.work and not cam.error and c.now()>=(cam.nextScan or 0) then
    cam.refreshDelay=delay;e:start(cam.address,p,s.mode=='grid');cam.nextScan=c.now()+delay
   end
  end
 end
 local cam=selected(s);local work=e:step(cam and cam.address)
 if work and (c.now()-s.lastPaint>=0.5 or #e.jobs~=before) then s.lastPaint=c.now();return true end
 return false
end
local function changeSetting(c,delta)
 local s=st(c);local cam=selected(s);if not cam then s.message='No camera selected';return end
 local p=pref(s,cam);local k=s.setting
 if k==1 then s.rename=p.name or '';s.renameAddress=cam.address
 elseif k==9 then s.prefs[cam.address]=Config.defaults();s.paused=true;persist(c);return
 else
  local key=({[2]='quality',[3]='zoom',[4]='palette',[5]='refresh',[6]='scale',[7]='grid'})[k]
  if key then local max=({quality=3,zoom=3,palette=7,refresh=4,scale=4,grid=3})[key];p[key]=(p[key]-1+delta)%max+1
  elseif k==8 then
   local methods={};for _,m in ipairs({'distance','distanceUp','distanceDown'}) do if cam.methods[m] then methods[#methods+1]=m end end
   if #methods>0 then local at=1;for i,m in ipairs(methods) do if m==p.method then at=i end end;p.method=methods[(at-1+delta)%#methods+1] end
  end
  s.prefs[cam.address]=p;persist(c)
 end;changed(s)
end
local function act(c,id)
 local s=st(c)
 if id==1 or id==2 then s.tab=id;s.details=false;changed(s)
 elseif id=='scan' then scan(c)
 elseif id=='discover' then s.engine:discover(s.prefs);s.message=s.engine.error or 'Camera network refreshed';choose(c,s.index)
 elseif id=='cancel' then s.engine:cancel();s.paused=true;changed(s)
 elseif id=='single' or id=='grid' or id=='console' then s.mode=id;s.tab=1;s.details=false;changed(s)
 elseif id=='prev' then choose(c,s.index-1)
 elseif id=='next' then choose(c,s.index+1)
 elseif id=='pageprev' then choose(c,s.index-gridCount(c,s))
 elseif id=='pagenext' then choose(c,s.index+gridCount(c,s))
 elseif id=='details' then s.details=not s.details;changed(s)
 elseif id=='pause' then s.paused=not s.paused;s.message=s.paused and 'Periodic scans paused' or 'Periodic scans resumed (per-camera settings)';changed(s)
 elseif id=='rename' then s.setting=1;changeSetting(c,1)
 elseif id=='settingprev' then changeSetting(c,-1)
 elseif id=='settingnext' then changeSetting(c,1)
 end
end
local function wrap(value,width)
 local rows,part,n={},'',0;value=Text(tostring(value or '')) or ''
 for _,cp in utf8.codes(value) do part=part..utf8.char(cp);n=n+1;if n==width then rows[#rows+1]=part;part='';n=0 end end
 if part~='' then rows[#rows+1]=part end;return rows
end
function M.draw(c)
 local s=st(c);local g,t=c.gfx,c.theme;local w,h=g:size();local cam=selected(s)
 local signature=table.concat({w,h,t.name or '',s.tab,s.mode,s.index,tostring(s.details),tostring(c.state.exitPending),tostring(c.display.pending~=nil),s.rename or ''},'|')
 local full=s.full or s.signature~=signature
 if full then W.frame(c,'CAMERA CENTER / COMPUTRONICS DEPTH MONITOR',true);s.signature=signature;s.full=false;s.paint={};s.depthPaint={} end
 local function put(x,y,text,width,color,bg)
  if y<1 or y>h-1 or width<1 then return end
  local line=wrap(text,width)[1] or '';local key=x..':'..y;local sig=line..':'..tostring(color)..':'..tostring(bg)
  if s.paint[key]~=sig then g:fill(x,y,width,1,bg or t.bg);g:text(x,y,line,color or t.text,bg or t.bg,#line);s.paint[key]=sig end
 end
 local function button(x,y,label,id)
  put(x,y,label,#label,t.accent);s.hits[#s.hits+1]={x=x,y=y,w=#label,id=id}
 end
 s.hits={};button(2,3,'[1:CAMERAS]',1);button(15,3,'[2:SETTINGS]',2)
 if w<60 or h<22 then put(2,5,'Camera Center: use 80x25 or larger.',w-3,t.warn);return end
 local connected=0;local simulated=false;for _,v in ipairs(s.engine.order) do if v.available then connected=connected+1 end;if v.address:match('^sim%-') then simulated=true end end
 local image=s.engine:image(cam)
 put(2,4,(simulated and 'SIMULATED / ' or '')..'DEPTH ONLY / '..connected..' CAMERAS / '..(cam and cam.status or 'NO CAMERA')..' / '..s.mode:upper(),w-3,t.good)
 button(2,5,'[SCAN]','scan');button(10,5,'[REDISCOVER]','discover');button(24,5,'[CANCEL]','cancel');button(34,5,s.paused and '[RESUME]' or '[PAUSE]','pause');button(45,5,'[INFO]','details')
 if s.details and cam then
  if full then g:fill(3,7,w-6,h-12,t.bg);W.outline(g,t,3,7,w-6,h-12,'FULL CAMERA INFORMATION') end
  local lines={name(s,cam),cam.address,cam.status..(cam.stale and ' / OLD SNAPSHOT' or ''),'SAMPLES '..(image and image.done..' / '..image.total or '0')..' / '..(image and image.method or 'distance'),'CENTER '..(image and image.center~=nil and tostring(image.center)..' blocks (-1 = no hit)' or 'unavailable'),'Last successful scan: '..tostring(cam.lastSuccess or 'none')..' s uptime','NO HARDWARE CONTROLS EXPOSED',cam.error or ''}
  local y=9;for _,line in ipairs(lines) do for _,part in ipairs(wrap(line,w-10)) do if y<h-7 then put(5,y,part,w-10);y=y+1 end end end
  button(5,h-7,'[CLOSE INFO]','details')
 elseif s.tab==2 then
  put(3,7,'SOFTWARE VIEW SETTINGS / '..(cam and name(s,cam) or 'No camera selected'),w-6,t.accent)
  local p=pref(s,cam);local values={p.name or 'Default address label',Scan.QUALITY[p.quality].name..' / '..Scan.QUALITY[p.quality].w..'x'..Scan.QUALITY[p.quality].h,({'1x window','2x digital','4x digital'})[p.zoom],Depth.PALETTES[p.palette],refreshNames[p.refresh],Depth.SCALES[p.scale]..' blocks (shade scale)',({'AUTO','1x2','2x2'})[p.grid],p.method,'Restore only this camera'}
  for i,label in ipairs(settings) do
   local y=8+i;local bg=s.setting==i and t.activeBg or t.bg;local fg=s.setting==i and t.activeText or t.text
   put(3,y,string.format('%-23s',label)..'  '..values[i],w>=120 and 84 or w-6,fg,bg);s.hits[#s.hits+1]={x=3,y=y,w=w-6,setting=i}
  end
  if w>=120 then
   if full then W.outline(g,t,91,7,w-92,h-13,'VERIFIED CAPABILITIES') end
   local lines=cam and {'COMPONENT TYPE: camera','ADDRESS',cam.address,'READ CALLBACKS',cam.methods.distance and 'distance(x, y)' or 'distance unavailable',cam.methods.distanceUp and 'distanceUp(x, y)' or '',cam.methods.distanceDown and 'distanceDown(x, y)' or '',cam.capabilitiesKnown and 'Method metadata inspected' or 'Method metadata unavailable','NO HARDWARE CONTROLS EXPOSED','LOW: 91 rays / BALANCED: 325','HIGH: 861 / THUMBNAIL: 45','Conservative scan budget; no video FPS.','Periodic intervals start after completion.','Refresh begins paused on app entry.'} or {'Connect a camera and REDISCOVER.'}
   local y=9;for _,line in ipairs(lines) do for _,part in ipairs(wrap(line,w-97)) do if y<h-9 then put(93,y,part,w-97);y=y+1 end end end
  end
  button(3,19,'[CHANGE -]','settingprev');button(16,19,'[CHANGE +]','settingnext');button(29,19,'[PREV CAM]','prev');button(42,19,'[NEXT CAM]','next')
  if h>=28 then put(3,22,'NO HARDWARE CONTROLS EXPOSED',w>=120 and 84 or w-6,t.warn);put(3,24,'Zoom, quality and palettes are software settings.',w>=120 and 84 or w-6,t.muted);put(3,25,'False color shows distance, not temperature.',w>=120 and 84 or w-6,t.muted)
  else put(3,h-4,'NO HARDWARE CONTROLS EXPOSED',w-6,t.warn) end
 elseif s.mode=='grid' then
  local count=gridCount(c,s);local cols=count==4 and 2 or 2;local rows=count==4 and 2 or 1
  local cellW=math.floor((w-3)/cols);local cellH=math.floor((h-12)/rows)
  local list=visible(c);local first=math.floor((s.index-1)/count)*count+1
  for j=1,count do
   local v=list[j];local x=2+(j-1)%cols*cellW;local y=7+math.floor((j-1)/cols)*cellH
   if full then W.outline(g,t,x,y,cellW-1,cellH,v and name(s,v) or 'NO CAMERA') end
   if v then
    local im=s.engine:image(v);local p=pref(s,v)
    put(x+2,y+1,v.status..(v.stale and ' / OLD SNAPSHOT' or '')..' / '..(im and im.done..'/'..im.total or 'not scanned'),cellW-5,v.available and t.text or t.warn)
    local rect={x=x+2,y=y+3,w=cellW-5,h=cellH-5};s.depthPaint[j]=Depth.draw(g,t,rect,im,p,s.depthPaint[j])
    s.hits[#s.hits+1]={x=x+1,y=y+2,w=cellW-3,h=cellH-3,camera=first+j-1,open=true}
   end
  end
  button(2,h-4,'[PREV PAGE]','pageprev');button(15,h-4,'[NEXT PAGE]','pagenext');button(28,h-4,'[CONSOLE]','console');button(40,h-4,'[SINGLE]','single')
 elseif s.mode=='single' then
  if full then W.outline(g,t,2,7,w-3,h-12,cam and name(s,cam) or 'NO CAMERA') end
  put(4,8,(cam and cam.status or 'NO CAMERA')..(cam and cam.stale and ' / OLD SNAPSHOT' or '')..' / '..(image and image.w..'x'..image.h..' / '..image.done..'/'..image.total..' rays' or 'Press SCAN')..' / '..Depth.PALETTES[pref(s,cam).palette],w-7,t.muted)
  s.depthPaint[1]=Depth.draw(g,t,{x=4,y=9,w=w-7,h=h-16},image,pref(s,cam),s.depthPaint[1])
  button(2,h-5,'[PREV CAM]','prev');button(14,h-5,'[NEXT CAM]','next');button(26,h-5,'[CONSOLE]','console');button(37,h-5,'[GRID]','grid');button(45,h-5,'[SETTINGS]',2)
 else
  local rich=w>=120;local console=s.mode=='console' and rich
  local lx=2;local lw=console and 30 or 0;local dx=rich and w-35 or 0
  local vx=console and 34 or 2;local vw=(rich and dx-2 or w-1)-vx;local vh=h-13
  if console then
   if full then W.outline(g,t,lx,7,lw,h-12,'CAMERA NETWORK') end
   local capacity=math.max(1,math.floor((h-16)/3));local first=math.max(1,s.index-capacity+1)
   for j=1,capacity do local idx=first+j-1;local v=s.engine.order[idx];if v then
    local y=8+(j-1)*3;local bg=idx==s.index and t.activeBg or t.bg
    put(3,y,string.format('%02d ',idx)..name(s,v),lw-2,idx==s.index and t.activeText or t.text,bg)
    put(4,y+1,v.address:sub(1,9)..'..'..v.address:sub(-4)..' / '..v.status,lw-4,t.muted)
    s.hits[#s.hits+1]={x=3,y=y,w=lw-2,h=2,camera=idx}
   end end
  end
  if full then W.outline(g,t,vx,7,vw,vh,'RAYCAST VIEW') end
  put(vx+2,8,cam and name(s,cam) or 'No camera detected',vw-4,t.accent)
  put(vx+2,9,image and (image.w..'x'..image.h..' / '..image.done..'/'..image.total..' rays / '..image.method..(cam.stale and ' / OLD' or '')) or 'Select a camera and press SCAN',vw-4,t.muted)
  s.depthPaint[1]=Depth.draw(g,t,{x=vx+2,y=11,w=vw-4,h=math.max(1,vh-6)},image,pref(s,cam),s.depthPaint[1])
  if rich then
   if full then W.outline(g,t,dx,7,34,h-12,'CAMERA INFORMATION') end
   local lines=cam and {'NAME',name(s,cam),'STATUS '..cam.status..(cam.stale and ' / OLD' or ''),'TYPE camera / Computronics','FULL COMPONENT ADDRESS',cam.address,'CALLBACKS',table.concat((function() local a={};for _,m in ipairs({'distance','distanceUp','distanceDown'}) do if cam.methods[m] then a[#a+1]=m end end;return a end)(),', '),'CENTER '..(image and image.center~=nil and (image.center==-1 and 'NO HIT' or string.format('%.2f blocks',image.center)) or 'unavailable'),'SAMPLED '..(image and image.done..' / '..image.total or '0'),'VALID '..(image and image.valid or 0)..' / NO HIT '..(image and image.nohit or 0),'ERRORS '..(image and image.errors or 0),'LAST SUCCESS '..tostring(cam.lastSuccess or 'none')..' s uptime','SCAN ELAPSED '..(image and string.format('%.1f s',image.elapsed or c.now()-image.started) or 'none'),'SHADE SCALE '..Depth.SCALES[pref(s,cam).scale]..' blocks',pref(s,cam).palette==6 and 'NEAR RED / FAR BLUE' or 'NEAR BRIGHT / FAR DARK','BLACK = NO HIT','. = UNSAMPLED / ? = FAILED',cam.error or ''} or {'No cameras found.','Connect a Computronics Camera','and choose REDISCOVER.'}
   local y=9;for _,line in ipairs(lines) do for _,part in ipairs(wrap(line,30)) do if y<h-8 then put(dx+2,y,part,30);y=y+1 end end end
  end
  button(2,h-5,'[PREV CAM]','prev');button(14,h-5,'[NEXT CAM]','next');button(26,h-5,'[SINGLE]','single');button(36,h-5,'[GRID]','grid');button(44,h-5,'[CONSOLE]','console');button(55,h-5,'[SETTINGS]',2)
 end
 put(2,h-3,s.message~='' and s.message or 'DEPTH SNAPSHOT / '..Depth.PALETTES[pref(s,cam).palette]..' / black: no hit / no RGB video',w-3,t.warn)
 put(2,h-2,'1/2 tabs | Arrows select | Enter single | S scan | G grid | C console',w-3,t.muted)
 -- Clear any expired global toast. Widgets.toast draws the active one afterward.
 g:fill(1,h-1,w,1,t.bg)
 if s.rename~=nil then
  local dw=math.min(70,w-4);local x=math.floor((w-dw)/2)+1
  g:fill(x,8,dw,7,t.surface);g:border(x,8,dw,7,t.accent,t.surface)
  put(x+2,9,'RENAME CAMERA / ENTER saves',dw-4,t.accent,t.surface)
  put(x+2,11,s.rename..'_',dw-4,t.text,t.surface)
  button(x+2,13,'[SAVE]','saveName');button(x+11,13,'[CANCEL]','cancelName')
 end
end
function M.input(a,c)
 local s=st(c)
 local function hit()
  for i=#s.hits,1,-1 do local h=s.hits[i];if a.x>=h.x and a.x<h.x+h.w and a.y>=h.y and a.y<h.y+(h.h or 1) then return h end end
 end
 if s.rename~=nil then
  local id=a.kind=='touch' and (hit() or {}).id
  if a.kind=='back' or id=='cancelName' then s.rename=nil;changed(s)
  elseif a.kind=='enter' or id=='saveName' then local p=Config.clean(s.prefs[s.renameAddress]);p.name=s.rename~='' and s.rename or nil;s.prefs[s.renameAddress]=p;s.rename=nil;persist(c)
  elseif a.kind=='char' or a.kind=='paste' then s.rename=s.rename..(Text(a.value) or (type(a.value)=='string' and a.value:gsub('[%c]',' ') or ''));while #s.rename>120 do s.rename=s.rename:sub(1,(utf8.offset(s.rename,-1) or 1)-1) end;changed(s)
  elseif a.kind=='backspace' then s.rename=s.rename:sub(1,(utf8.offset(s.rename,-1) or 1)-1);changed(s) end
  return true
 end
 if a.kind=='touch' then
  local h=hit();if h then
   if h.camera then choose(c,h.camera);if h.open then act(c,'single') end
   elseif h.setting then s.setting=h.setting;changeSetting(c,1)
   else act(c,h.id) end
  end
 elseif a.kind=='char' then
  if a.value=='1' or a.value=='2' then act(c,tonumber(a.value))
  else local keys={s='scan',g='grid',c='console',r='discover',p='pause',d='details',n='rename'};act(c,keys[a.value:lower()]) end
 elseif a.kind=='up' or a.kind=='down' or a.kind=='scroll' then
  local delta=a.kind=='up' and -1 or a.kind=='down' and 1 or ((a.delta or 0)>0 and -1 or 1)
  if s.tab==2 then s.setting=(s.setting-1+delta)%#settings+1;changed(s) else choose(c,s.index+delta) end
 elseif a.kind=='left' or a.kind=='right' then
  if s.tab==2 then changeSetting(c,a.kind=='left' and -1 or 1) else choose(c,s.index+(a.kind=='left' and -1 or 1)) end
 elseif a.kind=='enter' then if s.tab==2 then changeSetting(c,1) else act(c,'single') end
 elseif a.kind=='back' then if s.details then act(c,'details') elseif s.mode~='console' then act(c,'console') else return false end
 end
 return true
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
local function richControl(ctx,rows)
  local g,t,s=ctx.gfx,ctx.theme,ui(ctx);local w,h=g:size()
  local lw=math.floor((w-6)*0.65);local rx=lw+4;local rw=w-rx
  s.index=math.max(1,math.min(#rows,s.index))
  local slots=math.max(1,math.floor((h-12)/3))
  if s.index<s.scroll+1 then s.scroll=s.index-1 end
  if s.index>s.scroll+slots then s.scroll=s.index-slots end
  s.scroll=math.max(0,math.min(s.scroll,math.max(0,#rows-slots)))
  local key=table.concat({w,h,ctx.config.data.theme,ctx.config.data.layout,s.tab,
    tostring(ctx.state.exitPending),tostring(ctx.display.pending~=nil)},':')
  local full=not s.paint or s.paint.key~=key
  if full then s.paint={key=key,regions={}} end
  local cache=s.paint.regions
  local function region(id,signature,draw)
    signature=tostring(signature)
    if full or cache[id]~=signature then draw();cache[id]=signature end
  end
  local tabHits={};local x=2
  for i,name in ipairs(tabs) do
    local label='['..i..':'..name..']'
    if x+#label<=w-1 then
      tabHits[#tabHits+1]={x=x,y=3,w=#label,tab=i,label=label};x=x+#label+1
    end
  end
  region('structure','static',function()
    Widgets.frame(ctx,'SYSTEM CENTER / '..tabs[s.tab],true)
    for _,hit in ipairs(tabHits) do
      g:text(hit.x,3,hit.label,hit.tab==s.tab and t.activeText or t.accent,
        hit.tab==s.tab and t.activeBg or t.bg,hit.w)
    end
    Widgets.outline(g,t,2,5,lw,h-10,tabs[s.tab])
    Widgets.outline(g,t,rx,5,rw,12,'SELECTED ENTRY')
    Widgets.outline(g,t,rx,19,rw,11,'CONTROLS')
    local help=s.tab==1 and {'UP / DOWN  Select service','ENTER / TOUCH  Start or stop',
      'Core services cannot be stopped.'} or {'UP / DOWN  Select entry','1-5  Switch tabs','[BACK] or [HOME]  Return'}
    for i,line in ipairs(help) do g:text(rx+2,20+i*2,line,t.muted,t.bg,rw-4) end
    local hint=s.tab==1 and 'ENTER/CLICK START-STOP OPTIONAL SERVICES' or '1-5 TABS / ARROWS SCROLL'
    g:text(2,h-2,hint..'  [BACK] or [HOME]',t.muted,t.bg,w-3)
  end)
  s.hits={}
  for _,hit in ipairs(tabHits) do s.hits[#s.hits+1]={x=hit.x,y=hit.y,w=hit.w,tab=hit.tab} end
  local chosen=rows[s.index]
  region('selected',chosen and (tostring(chosen.label)..'|'..tostring(chosen.detail)) or '',function()
    g:fill(rx+1,6,rw-2,10,t.bg)
    if chosen then
      g:text(rx+2,7,chosen.label,t.accent,t.bg,rw-4)
      g:text(rx+2,9,chosen.detail,t.text,t.bg,rw-4)
    else g:text(rx+2,7,'No entries available.',t.muted,t.bg,rw-4) end
  end)
  for slot=1,slots do
    local idx=s.scroll+slot;local line=rows[idx];local y=7+(slot-1)*3
    local signature=line and (tostring(idx==s.index)..'|'..tostring(line.label)..'|'..tostring(line.detail)) or ''
    region('row'..slot,signature,function()
      if line then Widgets.action(g,t,4,y,lw-4,2,line.label,line.detail,idx==s.index)
      else g:fill(4,y,lw-4,2,t.bg) end
    end)
    if line then s.hits[#s.hits+1]={x=4,y=y,w=lw-4,h=2,row=idx} end
  end
  local toast=ctx.notices and ctx.notices.current
  region('toast',toast and (tostring(toast.item.kind)..':'..toast.item.message) or '',function()
    g:fill(1,h-1,w,1,t.bg)
  end)
end
function M.draw(ctx)
  local g,t,s=ctx.gfx,ctx.theme,ui(ctx)
  local w,h=g:size()
  if Widgets.rich(ctx) then richControl(ctx,getRows(ctx));return end
  s.paint=nil;Widgets.frame(ctx,'SYSTEM CENTER / '..tabs[s.tab],true)
  s.hits={};local x=2;local compactNames={'SV','L','D','SE','R'}
  for i,name in ipairs(tabs) do
    local label='['..i..':'..(w<=40 and compactNames[i] or name)..']'
    if x+#label-1<=w then
      g:text(x,3,label,i==s.tab and t.activeText or t.accent,i==s.tab and t.activeBg or t.bg,#label)
      s.hits[#s.hits+1]={x=x,y=3,w=#label,tab=i};x=x+#label+1
    end
  end
  local rows=getRows(ctx)
  s.index=math.max(1,math.min(#rows,s.index))
  local slots=math.max(1,math.floor((h-9)/2))
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
  if w<=40 then hint=s.tab==1 and 'ENTER: SERVICE  [BACK]' or 'ARROWS SCROLL  [BACK]'
  else hint=hint..'  [BACK] or [HOME]' end
  g:text(2,h-2,hint,t.muted,t.bg,w-3)
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
  if a.kind=='scroll' then
    if not a.delta or a.delta==0 then return true end
    local delta=(a.delta or 0)>0 and -1 or 1
    s.index=math.max(1,math.min(#getRows(ctx),s.index+delta));return true
  end
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
    preview={},previewScroll=0,clip=nil,hitboxes={},toolbar={},toolbarPage=1}
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
  elseif kind=='more' then s.toolbarPage=s.toolbarPage%4+1
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
local compactButtons={
  {{'OPEN','open'},{'UP','up'},{'COPY','copy'},{'MORE','more'}},
  {{'MOVE','move'},{'PASTE','paste'},{'MORE','more'}},
  {{'RENAME','rename'},{'DELETE','delete'},{'MORE','more'}},
  {{'NEW DIR','mkdir'},{'MORE','more'}}}
function M.draw(ctx)
  local g,t,s=ctx.gfx,ctx.theme,selfState(ctx)
  local w,h=g:size()
  Widgets.frame(ctx,'FILES / '..s.cwd,true)
  local rich=Widgets.rich(ctx)
  g:text(2,3,'PATH  '..s.cwd,t.accent,t.bg,w-3)
  local info=s.ops:info(s.cwd)
  if w>=58 and type(info.spaceTotal)=='number' and type(info.spaceUsed)=='number' then
    local access=info.isReadOnly==true and 'READ ONLY' or info.isReadOnly==false and 'WRITABLE' or 'ACCESS UNKNOWN'
    g:text(2,4,string.format('DISK %dK/%dK   %s',math.floor(info.spaceUsed/1024),
      math.floor(info.spaceTotal/1024),access),t.muted,t.bg,w-3)
  else g:text(2,4,'DIRS FIRST  /  '..#s.items..(s.truncated and '+' or '')..' ENTRIES',t.muted,t.bg,w-3) end
  s.hitboxes={};s.toolbar={};s.dialogHits={}
  if s.mode=='preview' then
    if rich then Widgets.outline(g,t,1,5,w,h-8,'VIEW / '..s.previewName)
    else g:text(2,5,'VIEW '..s.previewName..' / max 3 KiB',t.accent,t.bg,w-3) end
    local count=math.max(1,h-(rich and 11 or 9))
    for i=1,count do
      local v=s.preview[i+s.previewScroll]
      if v then g:text(rich and 3 or 2,5+i,v,t.text,t.bg,w-(rich and 5 or 3)) end
    end
    g:text(2,h-2,'UP/DOWN SCROLL  [BACK] RETURN',t.muted,t.bg,w-3)
    return
  end
  if rich then
    local count=#s.items..(s.truncated and '+' or '')..' ENTRIES'
    local title='FILES / '..s.cwd;local limit=w-#count-10
    if #title>limit then title=title:sub(1,math.max(0,limit-3))..'...' end
    Widgets.outline(g,t,1,5,w,h-9,title)
    g:text(4,6,'TYPE   NAME',t.muted,t.bg,w-24)
    g:text(w-8,6,'SIZE',t.muted,t.bg,7)
    g:text(w-#count-2,5,count,t.accent,t.bg,#count)
  end
  local maxRows=math.max(1,h-(rich and 12 or 11))
  if s.selected<s.scroll+1 then s.scroll=s.selected-1 end
  if s.selected>s.scroll+maxRows then s.scroll=s.selected-maxRows end
  s.scroll=math.max(0,math.min(s.scroll,math.max(0,#s.items-maxRows)))
  if #s.items==0 then g:text(3,rich and 8 or 7,'(Empty folder)',t.muted,t.bg,w-5) end
  for j=1,maxRows do
    local index=j+s.scroll;local item=s.items[index]
    if item then
      local y=(rich and 6 or 5)+j;local marked=index==s.selected
      local bg=marked and t.activeBg or t.bg
      local fg=marked and t.activeText or t.text
      g:fill(2,y,w-3,1,bg)
      local typeName=item.dir and '[DIR]' or '[FILE]'
      local suffix=not item.dir and ('  '..math.floor(item.size/1024+0.5)..'K') or ''
      g:text(3,y,typeName..' '..item.name,fg,bg,math.max(4,w-11-#suffix))
      if w>=24 then g:text(w-8,y,suffix,marked and t.activeText or t.muted,bg,7) end
      s.hitboxes[#s.hitboxes+1]={x=2,y=y,w=w-3,index=index}
    end
  end
  local barY=h-4;local x=2
  local shown=w<65 and compactButtons[s.toolbarPage] or buttons
  for _,b in ipairs(shown) do
    local label='['..b[1]..']'
    if x+#label<=w then
      g:text(x,barY,label,t.accent,t.bg,#label)
      s.toolbar[#s.toolbar+1]={x=x,y=barY,w=#label,id=b[2]}
      x=x+#label+1
    end
  end
  if w<65 then g:text(w-3,barY,s.toolbarPage..'/4',t.muted,t.bg,3) end
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
      if w>=24 then
        g:text(x+2,y+4,'[YES] [NO] Y/N',t.text,t.surface,pw-4)
        s.dialogHits={{x=x+2,y=y+4,w=5,id='yes'},{x=x+8,y=y+4,w=4,id='no'}}
      else g:text(x+2,y+4,'Y confirm  N/[BACK] cancel',t.text,t.surface,pw-4) end
    else
      local first=math.max(1,s.cursor-(pw-6))
      local value=w>=24 and (s.text:sub(first,s.cursor-1)..'|'..s.text:sub(s.cursor)) or s.text..'_'
      g:text(x+2,y+2,value,t.text,t.surface,pw-4)
      if w>=24 then
        g:text(x+2,y+4,'[SAVE] [CANCEL] ENTER/BACK',t.muted,t.surface,pw-4)
        s.dialogHits={{x=x+2,y=y+4,w=6,id='save'},{x=x+9,y=y+4,w=8,id='cancel'}}
      else g:text(x+2,y+4,'ENTER save / [BACK] cancel',t.muted,t.surface,pw-4) end
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
  if k=='touch' and (s.mode=='delete' or s.mode=='rename' or s.mode=='mkdir') then
    for _,hit in ipairs(s.dialogHits or {}) do
      if a.y==hit.y and a.x>=hit.x and a.x<hit.x+hit.w then
        if hit.id=='yes' then a={kind='char',value='y'}
        elseif hit.id=='no' then a={kind='char',value='n'}
        elseif hit.id=='save' then a={kind='enter'}
        else a={kind='back'} end
        k=a.kind;break
      end
    end
  end
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
local function rsChoice(ctx,listed)
  local s=current(ctx);local list=listed or redstones(ctx)
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
local function workWidth(ctx)
  local w=select(1,ctx.gfx:size())
  return Widgets.rich(ctx) and math.floor(w*0.65) or w
end
local function screenTitle(ctx)
  local t,s=ctx.theme,current(ctx)
  local w,h=ctx.gfx:size()
  Widgets.frame(ctx,'HARDWARE / '..({'DEVICES','REDSTONE','AUTOMATION','EVENTS','DIAGNOSTICS'})[s.tab],true)
  s.hits={}
  local titles=h<15 and {'[1:DV]','[2:RS]','[3:A]','[4:E]','[5:D]'} or tabs
  local x=2
  for idx,title in ipairs(titles) do
    if x+#title-1>w then break end
    ctx.gfx:text(x,3,title,idx==s.tab and t.activeText or t.accent,idx==s.tab and t.activeBg or t.bg,#title)
    s.hits[#s.hits+1]={x=x,y=3,w=#title,h=1,tab=idx}
    x=x+#title+1
  end
end
local function drawConfirmation(ctx,w,h)
  local s=current(ctx);local g,t=ctx.gfx,ctx.theme
  if not s.confirm then return end
  g:fill(2,h-7,w-4,5,t.surface)
  g:border(2,h-7,w-4,5,t.warn,t.surface)
  local label=s.confirm.kind=='write' and ('WRITE OUTPUT '..s.confirm.level..' TO SIDE '..s.confirm.side) or
      (s.confirm.kind=='mirror' and 'ENABLE LIVE MIRROR?' or 'RESTORE ALL OWNED OUTPUTS?')
  if w<50 then
    label=s.confirm.kind=='write' and ('OUT '..s.confirm.level..' SIDE '..s.confirm.side) or
      (s.confirm.kind=='mirror' and 'ENABLE MIRROR?' or 'RESTORE OUTPUTS?')
  end
  g:text(4,h-6,'CONFIRM: '..label,t.warn,t.surface,w-8)
  g:text(4,h-4,'[YES] [NO]   /   Y or N',t.text,t.surface,w-8)
  s.hits[#s.hits+1]={x=4,y=h-4,w=5,h=1,answer=true}
  s.hits[#s.hits+1]={x=10,y=h-4,w=4,h=1,answer=false}
end
local function compactHardware(ctx,w,h)
  local s=current(ctx);local g,t=ctx.gfx,ctx.theme
  local function text(y,value,color) g:text(2,y,value,color or t.text,t.bg,w-3) end
  local function compactRows(rows)
    local slots=math.max(1,h-7)
    if s.index<=s.scroll then s.scroll=s.index-1 end
    if s.index>s.scroll+slots then s.scroll=s.index-slots end
    s.scroll=math.max(0,math.min(s.scroll,math.max(0,#rows-slots)))
    for slot=1,slots do
      local i=s.scroll+slot;local row=rows[i]
      if row then
        local y=4+slot;local active=i==s.index
        g:fill(2,y,w-3,1,active and t.activeBg or t.bg)
        g:text(3,y,(active and '> ' or '  ')..row,active and t.activeText or t.text,active and t.activeBg or t.bg,w-5)
        s.hits[#s.hits+1]={x=2,y=y,w=w-3,h=1,act=i}
      end
    end
  end
  if s.tab==1 then
    local list,err=devices(ctx);text(4,'DEVICES '..#list..' / ENTER',t.accent)
    if #list==0 then text(5,err or 'No components',t.warn)
    else
      s.deviceIndex=math.max(1,math.min(s.deviceIndex,#list))
      local chosen=list[s.deviceIndex]
      if s.inspect then
        text(5,'DEVICE '..chosen.kind,t.accent);text(6,chosen.address,t.text)
        local methods,why=ctx.deviceControl:methods(chosen.address)
        text(7,methods and ('METHODS '..#methods) or tostring(why),t.muted)
        if methods then for i=1,math.min(#methods,math.max(0,h-10)) do text(7+i,methods[i],t.text) end end
      else
        local slots=math.max(1,h-7)
        if s.deviceIndex<=s.scroll then s.scroll=s.deviceIndex-1 end
        if s.deviceIndex>s.scroll+slots then s.scroll=s.deviceIndex-slots end
        s.scroll=math.max(0,math.min(s.scroll,math.max(0,#list-slots)))
        for slot=1,slots do
          local i=s.scroll+slot;local item=list[i]
          if item then
            local y=4+slot;local active=i==s.deviceIndex
            g:fill(2,y,w-3,1,active and t.activeBg or t.bg)
            g:text(3,y,(active and '> ' or '  ')..item.kind..' '..item.address,active and t.activeText or t.text,active and t.activeBg or t.bg,w-5)
            s.hits[#s.hits+1]={x=2,y=y,w=w-3,h=1,dev=i}
          end
        end
      end
    end
  elseif s.tab==2 then
    local rs,n=rsChoice(ctx);local read=rs and ctx.deviceControl:read(rs.address,s.side)
    text(4,rs and ('RS '..s.redIndex..'/'..n..' IN '..(read and read.input or '?')..' OUT '..(read and read.output or '?')) or 'NO REDSTONE DEVICE',rs and t.accent or t.warn)
    compactRows({'CHANGE CARD','SIDE: '..ctx.deviceControl.SIDES[s.side+1],
      'TARGET: '..s.level,'APPLY OUTPUT (CONFIRM)','REFRESH READINGS'})
  elseif s.tab==3 then
    local rs=rsChoice(ctx)
    text(4,'MIRROR '..(ctx.automation.enabled and 'ACTIVE' or 'OFF')..(rs and '' or ' / NO DEVICE'),ctx.automation.enabled and t.good or t.muted)
    compactRows({'CHANGE CARD','INPUT: '..ctx.deviceControl.SIDES[s.inputSide+1],
      'OUTPUT: '..ctx.deviceControl.SIDES[s.outputSide+1],
      'ENABLE MIRROR (CONFIRM)','DISABLE MIRROR','EMERGENCY RESTORE'})
  elseif s.tab==4 then
    text(4,'EVENTS '..#ctx.hwEvents.items,t.accent)
    local slots=math.max(1,h-8)
    s.scroll=math.max(0,math.min(s.scroll,math.max(0,#ctx.hwEvents.items-slots)))
    if #ctx.hwEvents.items==0 then text(5,'No events observed',t.muted) end
    for j=1,slots do
      local ev=ctx.hwEvents.items[s.scroll+j]
      if ev then text(4+j,ev.at..'s '..ev.kind..' '..ev.address,t.text) end
    end
    g:text(2,h-3,'[CLEAR EVENTS]',t.accent,t.bg,w-3)
    s.hits[#s.hits+1]={x=2,y=h-3,w=14,h=1,act=1}
  else
    local list=devices(ctx);local hs=ctx.hardware:snapshot();local rs=redstones(ctx)
    local lines={'DEVICES '..#list..' / REDSTONE '..#rs,
      'GPU '..tostring(hs.gpuAddress or '?'),'SCREEN '..tostring(hs.screen or ctx.hardware.screen or '?'),
      'DISPLAY '..tostring(hs.resolutionW or '?')..'x'..tostring(hs.resolutionH or '?')..' / '..tostring(hs.depth or '?')..' BIT',
      'FREE RAM '..(type(hs.freeMemory)=='number' and math.floor(hs.freeMemory/1024)..' KiB' or '?'),
      'MIRROR '..(ctx.automation.enabled and 'ACTIVE' or 'DISABLED')}
    local grouped={};for _,d in ipairs(list) do grouped[d.kind]=(grouped[d.kind] or 0)+1 end
    local kinds={};for kind,count in pairs(grouped) do kinds[#kinds+1]=kind..' x'..count end
    table.sort(kinds);for _,line in ipairs(kinds) do lines[#lines+1]=line end
    text(4,'LIVE DIAGNOSTICS',t.accent)
    local slots=math.max(1,h-7);s.scroll=math.max(0,math.min(s.scroll,math.max(0,#lines-slots)))
    for i=1,slots do if lines[s.scroll+i] then text(4+i,lines[s.scroll+i],t.text) end end
  end
  if s.message~='' and s.tab~=1 and s.tab~=4 then text(h-2,s.message,t.warn)
  else g:text(2,h-2,'ARROWS / ENTER / BACK',t.muted,t.bg,w-3) end
  drawConfirmation(ctx,w,h)
end
local function drawRows(ctx,rows,startY)
  local s=current(ctx);local g,t=ctx.gfx,ctx.theme;local w,h=g:size()
  w=workWidth(ctx)
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
  local w,h=g:size();local screenW=w;screenTitle(ctx);local rich=Widgets.rich(ctx)
  local listed,listError,listedRedstone,snapshot
  if rich then
    w=workWidth(ctx)
    local rx=w+2;local rw=screenW-rx
    Widgets.outline(g,t,1,4,w,h-7,({'DEVICES','REDSTONE','AUTOMATION','EVENTS','DIAGNOSTICS'})[s.tab])
    Widgets.outline(g,t,rx,4,rw,14,'HARDWARE STATUS')
    snapshot=ctx.hardware:snapshot();listed,listError=devices(ctx);listedRedstone={}
    for _,item in ipairs(listed) do if item.kind=='redstone' then listedRedstone[#listedRedstone+1]=item end end
    if #listed>0 then s.deviceIndex=math.max(1,math.min(s.deviceIndex,#listed)) end
    local selected=listed[s.deviceIndex]
    local status={'COMPONENTS  '..(listError and 'unavailable' or #listed),
      'REDSTONE    '..(listError and 'unavailable' or #listedRedstone),
      'DISPLAY     '..tostring(snapshot.resolutionW or '?')..'x'..tostring(snapshot.resolutionH or '?'),
      'DEPTH       '..tostring(snapshot.depth or '?')..' bit',
      'MIRROR      '..(ctx.automation.enabled and 'ACTIVE' or 'DISABLED')}
    if tostring(snapshot.gpuAddress or ''):match('^sim%-') then status[#status+1]='PROFILE     SIMULATED' end
    if s.tab==1 and selected then
      status[#status+1]='SELECTED    '..selected.kind
      status[#status+1]=selected.address
    elseif s.tab==4 then status[#status+1]='EVENTS      '..#ctx.hwEvents.items end
    for i,line in ipairs(status) do g:text(rx+2,5+i,line,t.text,t.bg,rw-4) end
    Widgets.outline(g,t,rx,20,rw,12,'CONTROLS')
    local help={'1-5  Switch tabs',(s.tab==4 or s.tab==5) and 'UP / DOWN  Scroll' or 'UP / DOWN  Select',
      s.tab==1 and 'ENTER / TOUCH  Inspect' or s.tab==5 and 'READ-ONLY DIAGNOSTICS' or 'ENTER / TOUCH  Activate',
      'Enabling outputs requires confirm.','[BACK] or [HOME]  Return'}
    for i,line in ipairs(help) do g:text(rx+2,20+i*2,line,t.muted,t.bg,rw-4) end
  end
  if w<32 or h<10 then put(ctx,2,5,'Resize to at least 32x10',t.warn,w-3);return end
  if h<15 then compactHardware(ctx,w,h);return end
  if s.tab==1 then
    local list,err=listed,listError
    if not list then list,err=devices(ctx) end
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
            for j=1,math.min(#methods,h-(rich and 15 or 14)) do put(ctx,3,10+j,methods[j],t.text,w-5) end
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
    local rs,n=rsChoice(ctx,listedRedstone)
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
    local rs,n=rsChoice(ctx,listedRedstone)
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
    local list=listed or devices(ctx);local hs=snapshot or ctx.hardware:snapshot();local rs=listedRedstone or redstones(ctx)
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
    for _,line in ipairs(types) do lines[#lines+1]=line end
    local simulated=tostring(hs.gpuAddress or ''):match('^sim%-')~=nil
    put(ctx,2,5,simulated and 'SIMULATED COMPONENTS / LIVE FIXTURE VALUES' or 'LIVE COMPONENTS / READ-ONLY DIAGNOSTICS',t.accent,w-3)
    local slots=math.max(1,h-(rich and 11 or 10))
    s.scroll=math.max(0,math.min(s.scroll,math.max(0,#lines-slots)))
    for i=1,slots do if lines[s.scroll+i] then put(ctx,3,6+i,lines[s.scroll+i],t.text,w-5) end end
  end
  if s.message~='' and s.tab~=1 and s.tab~=4 then put(ctx,2,h-3,s.message,t.warn,w-3) end
  drawConfirmation(ctx,w,h)
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
  if a.kind=='scroll' then
    if not a.delta or a.delta==0 then return true end
    local delta=(a.delta or 0)>0 and -1 or 1
    if s.tab==1 and not s.inspect then s.deviceIndex=math.max(1,math.min(#devices(ctx),s.deviceIndex+delta))
    elseif s.tab==4 or s.tab==5 then s.scroll=math.max(0,s.scroll+delta)
    elseif s.tab==2 or s.tab==3 then s.index=math.max(1,math.min(#actionRows(ctx),s.index+delta)) end
    return true
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
  elseif s.tab==5 then
    if a.kind=='up' then s.scroll=math.max(0,s.scroll-1);return true end
    if a.kind=='down' then s.scroll=s.scroll+1;return true end
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
  ctx.state.monitor={tab=1,history={},last=-100,scroll=0,snapshot={},hits={}}
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
local function richMonitor(ctx)
  local g,t,st=ctx.gfx,ctx.theme,ctx.state.monitor
  local w,h=g:size();local s=st.snapshot
  Widgets.frame(ctx,'SYSTEM MONITOR / '..(st.tab==1 and 'MEMORY' or 'COMPONENTS'),true)
  st.hits={}
  local x=2
  for _,tab in ipairs({{1,'[1:MEMORY]'},{2,'[2:HARDWARE]'}}) do
    local active=st.tab==tab[1]
    g:text(x,3,tab[2],active and t.activeText or t.accent,active and t.activeBg or t.bg,#tab[2])
    st.hits[#st.hits+1]={x=x,w=#tab[2],tab=tab[1]};x=x+#tab[2]+2
  end
  local sampleLabel='[R:SAMPLE]'
  g:text(x,3,sampleLabel,t.accent,t.bg,#sampleLabel)
  st.hits[#st.hits+1]={x=x,w=#sampleLabel,sample=true}
  if st.tab==1 then
    local total,free=s.totalMemory,s.freeMemory
    local available=type(total)=='number' and total>0 and type(free)=='number'
    Widgets.outline(g,t,1,5,w,7,'MEMORY')
    if available then
      local used=math.max(0,total-free)
      g:text(3,7,string.format('FREE   %.1f KiB',free/1024),t.text,t.bg,w-5)
      g:text(3,8,string.format('USED   %.1f KiB',used/1024),t.text,t.bg,w-5)
      g:text(3,9,string.format('TOTAL  %.1f KiB',total/1024),t.text,t.bg,w-5)
    else g:text(3,7,'Memory information unavailable',t.muted,t.bg,w-5) end
    Widgets.outline(g,t,1,13,w,5,'MEMORY UTILIZATION')
    if available then
      local fraction=math.max(0,math.min(1,(total-free)/total))
      local bw=math.min(100,w-20)
      drawBar(g,t,3,15,bw,fraction)
      g:text(4+bw,15,string.format('%d%% USED',math.floor(fraction*100+0.5)),t.accent,t.bg,12)
    else g:text(3,15,'Unavailable',t.muted,t.bg,w-5) end
    Widgets.outline(g,t,1,19,w,h-22,'FREE RAM TREND / PERIODIC + MANUAL SAMPLES')
    if available then
      local left,top,bottom=13,22,h-9
      local plotW=math.min(w-left-4,112)
      g:colors(t.muted,t.bg)
      g:fill(left,top,1,bottom-top+1,t.bg,'|')
      g:fill(left+1,bottom,plotW,1,t.bg,'-')
      g:text(3,top,math.floor(total/1024)..'K',t.muted,t.bg,9)
      g:text(3,math.floor((top+bottom)/2),math.floor(total/2048)..'K',t.muted,t.bg,9)
      g:text(3,bottom,'0',t.muted,t.bg,9)
      local gap=math.max(1,math.floor((plotW-1)/27))
      for i,p in ipairs(st.history) do
        if type(p.free)=='number' then
          -- The vertical axis is the current total, so use the same scale for
          -- earlier readings if memory hardware changed during the session.
          local ratio=math.max(0,math.min(1,p.free/total))
          local y=bottom-math.floor(ratio*(bottom-top)+0.5)
          g:text(left+1+(i-1)*gap,y,'*',t.accent,t.bg,1)
        end
      end
      g:text(left+1,bottom+1,'OLDEST  ->  NEWEST   /   '..#st.history..' OF 28 SAMPLES',t.muted,t.bg,plotW)
    else g:text(3,22,'No memory samples available',t.muted,t.bg,w-5) end
    g:text(3,h-6,'UPTIME '..(type(s.uptime)=='number' and math.floor(s.uptime)..' sec' or 'unavailable'),t.muted,t.bg,w-5)
  else
    Widgets.outline(g,t,1,5,w,h-9,'LIVE COMPONENTS')
    local rows={{'GPU ID',s.gpuAddress},{'Screen',s.screen},
      {'Current resolution',(s.resolutionW or '?')..' x '..(s.resolutionH or '?')},
      {'Max resolution',(s.maxW or '?')..' x '..(s.maxH or '?')},
      {'Color depth',tostring(s.depth or '?')..' bit'},{'Components',s.componentCount},
      {'Graphics cards',s.gpuCount},{'Screens',s.screenCount},
      {'Uptime',type(s.uptime)=='number' and math.floor(s.uptime)..' s' or '?'}}
    for i,row in ipairs(rows) do
      g:text(3,6+i,row[1],t.muted,t.bg,19)
      g:text(23,6+i,tostring(row[2] or '?'),t.text,t.bg,w-26)
    end
  end
  g:text(3,h-2,'1/2 TABS   R SAMPLE   [BACK] or [HOME]',t.muted,t.bg,w-5)
end
function M.draw(ctx)
  local g,t=ctx.gfx,ctx.theme
  local w,h=g:size()
  local st=ctx.state.monitor
  local s=st.snapshot
  if Widgets.rich(ctx) then richMonitor(ctx);return end
  st.hits={}
  Widgets.frame(ctx,'SYSTEM MONITOR / '..(st.tab==1 and 'MEMORY' or 'COMPONENTS'))
  local strip='[1] MEMORY    [2] HARDWARE    [R] SAMPLE'
  g:text(2,3,strip,t.accent,t.bg,w-3)
  for _,entry in ipairs({{'[1] MEMORY',1},{'[2] HARDWARE',2},{'[R] SAMPLE',0}}) do
    local first,last=strip:find(entry[1],1,true)
    if first and last+1<=w-2 then
      st.hits[#st.hits+1]={x=first+1,w=last-first+1,tab=entry[2]~=0 and entry[2] or nil,sample=entry[2]==0}
    end
  end
  if h<19 and st.tab==1 then
    local total,free=s.totalMemory or 0,s.freeMemory or 0
    local values={string.format('FREE   %.1f KiB',free/1024),
      string.format('USED   %.1f KiB',math.max(0,total-free)/1024),string.format('TOTAL  %.1f KiB',total/1024)}
    for i,line in ipairs(values) do if 3+i<h-2 then g:text(2,3+i,line,t.text,t.bg,w-3) end end
    if 8<h-2 then g:text(2,8,'MEMORY UTILIZATION',t.accent,t.bg,w-3) end
    if 9<h-2 then drawBar(g,t,2,9,math.max(1,w-4),total>0 and math.max(0,total-free)/total or 0) end
    if h>=8 then g:text(2,h-2,'1/2 TABS  R SAMPLE  [BACK]',t.muted,t.bg,w-3) end
    return
  end
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
  if a.kind=='touch' then
    for _,hit in ipairs(s.hits or {}) do
      if a.y==3 and a.x>=hit.x and a.x<hit.x+hit.w then
        if hit.tab then s.tab=hit.tab elseif hit.sample then sample(ctx) end
        return true
      end
    end
  end
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
  Widgets.frame(ctx,'NOTIFICATIONS / HISTORY',true)
  local list=ctx.notices.history
  s.notificationHit=nil
  if Widgets.rich(ctx) then
    local lw=math.floor((w-6)*0.65);local rx=lw+4;local rw=w-rx
    Widgets.outline(g,t,2,4,lw,h-9,'RECENT MESSAGES / '..#list..' OF 8')
    local slots=math.max(1,math.floor((h-12)/4))
    s.notificationScroll=math.max(0,math.min(s.notificationScroll,math.max(0,#list-slots)))
    if #list==0 then g:text(4,7,'No messages recorded.',t.muted,t.bg,lw-4) end
    local counts={info=0,warn=0,error=0}
    for _,item in ipairs(list) do
      local kind=item.kind=='error' and 'error' or item.kind=='warn' and 'warn' or 'info'
      counts[kind]=counts[kind]+1
    end
    for j=1,slots do
      local item=list[j+s.notificationScroll]
      if item then
        local y=5+(j-1)*4
        local color=item.kind=='error' and t.bad or item.kind=='warn' and t.warn or t.accent
        g:text(4,y+1,math.floor(item.at)..'s  ['..tostring(item.kind or 'info'):upper()..']',color,t.bg,lw-5)
        local width=lw-7
        g:text(6,y+2,item.message:sub(1,width),t.text,t.bg,width)
        if #item.message>width then g:text(6,y+3,item.message:sub(width+1,width*2),t.text,t.bg,width) end
      end
    end
    Widgets.outline(g,t,rx,4,rw,12,'SESSION SUMMARY')
    for i,line in ipairs({'TOTAL       '..#list..' / 8','INFO / OTHER '..counts.info,
      'WARNINGS    '..counts.warn,'ERRORS      '..counts.error}) do
      g:text(rx+2,5+i*2,line,t.text,t.bg,rw-4)
    end
    Widgets.outline(g,t,rx,18,rw,10,'HISTORY')
    g:text(rx+2,20,'Only this session is shown.',t.muted,t.bg,rw-4)
    g:text(rx+2,22,'[CLEAR HISTORY]',t.accent,t.bg,15)
    s.notificationHit={x=rx+2,y=22,w=15}
    g:text(3,h-2,'UP/DOWN SCROLL   ENTER / [CLEAR HISTORY] CLEAR   [BACK]',t.muted,t.bg,w-5)
    return
  end
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
  if h>=10 then
    g:text(3,h-3,'[CLEAR]  UP/DOWN scroll',t.muted,t.bg,w-5)
    s.notificationHit={x=3,y=h-3,w=7}
  end
end
function M.input(a,ctx)
  local s=ctx.state
  local height=select(2,ctx.gfx:size())
  local visible=Widgets.rich(ctx) and math.max(1,math.floor((height-12)/4)) or math.max(1,height-8)
  if a.kind=='up' then s.notificationScroll=math.max(0,s.notificationScroll-1); return true end
  if a.kind=='down' then s.notificationScroll=math.min(math.max(0,#ctx.notices.history-visible),s.notificationScroll+1); return true end
  if a.kind=='scroll' then
    if not a.delta or a.delta==0 then return true end
    local delta=(a.delta or 0)>0 and -1 or 1
    s.notificationScroll=math.max(0,math.min(math.max(0,#ctx.notices.history-visible),s.notificationScroll+delta));return true
  end
  local hit=s.notificationHit
  if a.kind=='enter' or a.kind=='touch' and hit and a.y==hit.y and a.x>=hit.x and a.x<hit.x+hit.w then
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
function M.open(ctx) ctx.state.settingsPaint=nil end
function M.close(ctx) ctx.state.settingsPaint=nil end
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
  local list=rows(ctx)
  s.settingsSelection=math.max(1,math.min(#list,s.settingsSelection))
  if Widgets.rich(ctx) then
    local lw=math.floor((w-6)*0.63);local rx=lw+4;local rw=w-rx
    local key=table.concat({w,h,ctx.config.data.theme,ctx.config.data.layout,
      tostring(s.exitPending),tostring(ctx.display.pending~=nil)},':')
    local full=not s.settingsPaint or s.settingsPaint.key~=key
    if full then s.settingsPaint={key=key,regions={}} end
    local cache=s.settingsPaint.regions
    local function region(id,signature,draw)
      signature=tostring(signature)
      if full or cache[id]~=signature then draw();cache[id]=signature end
    end
    region('structure','static',function()
      Widgets.frame(ctx,'CONTROL CENTER / SETTINGS',true)
      g:text(2,3,'PREFERENCES   /   saved to disk',t.accent,t.bg,w-4)
      Widgets.outline(g,t,2,5,lw,h-10,'PREFERENCES')
      Widgets.outline(g,t,rx,5,rw,11,'CURRENT CONFIG')
      Widgets.outline(g,t,rx,17,rw,10,'DISPLAY')
      Widgets.outline(g,t,rx,29,rw,h-34,'CONTROLS')
      for i,line in ipairs({'UP / DOWN   Select','LEFT / RIGHT  Change',
        'ENTER / TOUCH  Activate','[BACK] or [HOME]  Return'}) do
        g:text(rx+2,30+i,line,t.muted,t.bg,rw-4)
      end
      g:text(3,h-2,'UP/DOWN SELECT   LEFT/RIGHT CHANGE   ENTER ACTIVATE',t.muted,t.bg,w-5)
    end)
    s.appHitboxes={};s.settingsScroll=0
    for index,item in ipairs(list) do
      local y=7+(index-1)*3
      local selected=index==s.settingsSelection
      region('row'..index,tostring(selected)..':'..item.value,function()
        Widgets.action(g,t,4,y,lw-4,2,item.label,item.value,selected)
      end)
      s.appHitboxes[#s.appHitboxes+1]={x=4,y=y,w=lw-4,h=2,index=index}
    end
    local config=ctx.config.data
    local configRows={'THEME  '..config.theme:upper(),
      'DENSITY  '..(choices[config.layout] or 'Auto'),
      'NOTIFICATIONS  '..(config.notifications and 'ON' or 'OFF'),
      'PERSISTENT LOGS  '..(config.logging and 'ON' or 'OFF'),
      'RAM SERVICE  '..(config.monitorService and 'ENABLED' or 'DISABLED')}
    region('config',table.concat(configRows,'|'),function()
      g:fill(rx+1,6,rw-2,9,t.bg)
      for i,line in ipairs(configRows) do g:text(rx+2,6+i,line,t.text,t.bg,rw-4) end
    end)
    region('display',list[7].value,function()
      g:fill(rx+1,18,rw-2,8,t.bg)
      g:text(rx+2,19,'CURRENT  '..w..'x'..h,t.text,t.bg,rw-4)
      g:text(rx+2,20,'TARGET   '..list[7].value,t.text,t.bg,rw-4)
      g:text(rx+2,22,'Preview requires confirmation.',t.muted,t.bg,rw-4)
      g:text(rx+2,23,'Timeout restores previous size.',t.muted,t.bg,rw-4)
    end)
    local toast=ctx.notices and ctx.notices.current
    region('toast',toast and (tostring(toast.item.kind)..':'..toast.item.message) or '',function()
      g:fill(1,h-1,w,1,t.bg)
    end)
    return
  end
  s.settingsPaint=nil
  Widgets.frame(ctx,'CONTROL CENTER / SETTINGS',true)
  g:text(2,3,'PREFERENCES   /   saved to disk',t.accent,t.bg,w-4)
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
  if a.kind=='scroll' then
    if not a.delta or a.delta==0 then return true end
    local delta=(a.delta or 0)>0 and -1 or 1
    s.settingsSelection=math.max(1,math.min(#list,s.settingsSelection+delta));return true
  end
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
  Widgets.frame(ctx,'SYSTEM / LIVE HARDWARE',true)
  if Widgets.rich(ctx) then
    local left=math.floor((w-5)*0.52);local rx=left+3;local rw=w-rx
    Widgets.outline(g,t,2,4,left,13,'DISPLAY / MEMORY')
    Widgets.outline(g,t,rx,4,rw,13,'COMPONENTS')
    local function field(x,y,label,value,width)
      g:text(x,y,label,t.muted,t.bg,18)
      g:text(x+19,y,value,t.text,t.bg,width-19)
    end
    local primary={{'Display',fmt(s.resolutionW)..' x '..fmt(s.resolutionH)},
      {'Maximum',fmt(s.maxW)..' x '..fmt(s.maxH)},{'Depth',fmt(s.depth)..' bit'},
      {'Free RAM',kb(s.freeMemory)},{'Total RAM',kb(s.totalMemory)}}
    local hardware={{'Components',fmt(s.componentCount)},{'GPU count',fmt(s.gpuCount)},
      {'Active GPU',fmt(s.gpuAddress)},{'Screen count',fmt(s.screenCount)},{'Screen ID',fmt(s.screen)}}
    for i,row in ipairs(primary) do field(4,5+i*2,row[1],row[2],left-4) end
    for i,row in ipairs(hardware) do field(rx+2,5+i*2,row[1],row[2],rw-4) end
    Widgets.outline(g,t,2,19,w-4,7,'SESSION')
    field(4,21,'Uptime',type(s.uptime)=='number' and math.floor(s.uptime)..' s' or '?',w-8)
    local simulated=tostring(s.gpuAddress or ''):match('^sim%-')~=nil
    field(4,23,'Hardware',not s.gpuAddress and 'unavailable' or simulated and 'SIMULATED' or 'OpenComputers',w-8)
    g:text(3,h-2,'LIVE SNAPSHOT   /   [BACK] or [HOME]',t.muted,t.bg,w-5)
    return
  end
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
  local gpu=ctx.hardware and ctx.hardware.gpu
  if gpu and tostring(gpu.address or ''):match('^sim%-') then
    ctx.state.terminal.lines[1]='NEXUS TERMINAL / SIMULATED SHELL'
  end
end
function M.close(ctx) ctx.state.terminal=nil end
function M.draw(ctx)
  local g,t=ctx.gfx,ctx.theme
  local w,h=g:size()
  Widgets.frame(ctx,'TERMINAL / OPENOS',true)
  local rich=Widgets.rich(ctx)
  local s=ctx.state.terminal
  g:text(2,3,'BUILT-INS: help  cd  ls  cat  mem  /  run COMMAND',t.accent,t.bg,w-3)
  if rich then Widgets.outline(g,t,1,4,w,h-6,'NEXUS TERMINAL') end
  local limit=math.max(1,h-(rich and 8 or 7))
  s.outputScroll=math.max(0,math.min(s.outputScroll or 0,math.max(0,#s.lines-limit)))
  local last=math.max(0,#s.lines-s.outputScroll)
  local first=math.max(1,last-limit+1)
  local row=rich and 5 or 4
  for i=first,last do
    g:text(rich and 3 or 2,row,s.lines[i],t.text,t.bg,w-(rich and 5 or 3))
    row=row+1
  end
  g:fill(1,h-2,w,1,t.surface)
  local cwd=s.cwd
  local pathLimit=math.max(4,math.floor(w/2))
  if #cwd>pathLimit then cwd='..'..cwd:sub(-pathLimit+2) end
  local prefix=cwd..' > '
  local avail=math.max(1,w-#prefix-4)
  local start=math.max(1,s.cursor-avail+1)
  local value=s.buffer:sub(start,start+avail-1)
  g:text(2,h-2,prefix,t.accent,t.surface,w-3)
  g:text(math.min(w,2+#prefix),h-2,value,t.text,t.surface,avail)
  if w>=20 then
    local cursor=math.min(w-1,2+#prefix+s.cursor-start)
    local glyph=s.buffer:sub(s.cursor,s.cursor)
    g:text(cursor,h-2,glyph~='' and glyph or ' ',t.activeText,t.activeBg,1)
  end
  g:text(2,h-1,'ENTER RUN  WHEEL/PgUp/Dn OUTPUT  [BACK]',t.muted,t.bg,w-3)
end
function M.input(a,ctx)
  local s=ctx.state.terminal
  if a.kind=='scroll' or a.kind=='pageup' or a.kind=='pagedown' then
    local step=a.kind=='scroll' and ((a.delta or 0)>0 and 1 or -1) or (a.kind=='pageup' and 5 or -5)
    s.outputScroll=math.max(0,math.min(#s.lines,(s.outputScroll or 0)+step));return true
  end
  if a.kind=='enter' then
    s.outputScroll=0
    local input=s.buffer;s.buffer='';s.cursor=1
    s:execute(input,ctx)
    return true
  end
  return s:key(a)
end
return M
end

package.preload["nexus.apps.updatecenter"] = function(...)
-- NEXUS Update Center: GitHub Raw stable channel + legacy Pastebin,
-- and OpenOS .shrc autostart management. No automatic remote code execution.
local Widgets=require('nexus.ui.widgets')
local Update=require('nexus.core.update')
local M={id='updatecenter',name='Update Center',description='Updates and startup settings'}
local function data(ctx) return ctx.state.updateCenter end
local function items(ctx)
  if data(ctx).tab==1 then
    return {
      {title='CHECK GITHUB UPDATES',detail='Read stable NEXUS manifest from GitHub Raw',id='checkgithub'},
      {title='DOWNLOAD GITHUB RELEASE',detail='SHA-256 verify before staging',id='downloadgithub'},
      {title='INSTALL STAGED RELEASE',detail='Back up OS, switch release, restart NEXUS',id='install'},
      {title='ROLL BACK LAST RELEASE',detail='Restore previous.lua if available',id='rollback'},
      {title='DOWNLOAD FROM PASTEBIN',detail='Legacy: trusted pastebin.com ID',id='download'},
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
  if s.diskReady~=nil then s.diskReady=false end
  s.staged=ctx.updater:stagedVersion()
  s.backup=ctx.updater.fs.exists(Update.BACKUP)
  s.autostart=ctx.startup:status()
  s.guard=ctx.startup.fs.exists(ctx.startup.GUARD or '/home/nexus/startup.guard')
end
function M.open(ctx)
  ctx.state.updateCenter={tab=1,index=1,scroll=0,hits={},mode=nil,buffer='',confirm=nil,message='',staged=nil,online=nil,history={}}
  refresh(ctx)
end
function M.close(ctx) ctx.state.updateCenter=nil end
local function message(ctx,str,kind)
  local s=data(ctx);s.logRevision=(s.logRevision or 0)+1;s.logScroll=0;s.message=tostring(str or ''):sub(1,150)
  s.history[#s.history+1]={at=math.floor(ctx.now and ctx.now() or 0),message=s.message,kind=kind or 'info'}
  if #s.history>12 then table.remove(s.history,1) end
  ctx.notify(s.message,kind or 'info')
end
local function act(ctx,id)
  local s=data(ctx)
  if id=='refresh' then refresh(ctx);message(ctx,'Update status refreshed');return end
  if id=='checkgithub' then
    s.phase='checking';s.message='Checking GitHub...';M.draw(ctx)
    local ok,result=ctx.updater:checkGitHub()
    if ok then
      s.phase='ready';s.online=result
      message(ctx,result.newer and ('GitHub v'..result.version..' available') or ('GitHub v'..result.version..' is not newer'),'info')
    else
      s.phase='error';s.online=nil
      message(ctx,'GitHub check failed: '..tostring(result),'error')
    end
    -- An OpenOS shell transport may have drawn outside our owned regions.
    if type(ctx.updater.shellExecute)=='function' then s.paint=nil end
    if ctx.gfx then ctx.gfx.foreground=nil;ctx.gfx.background=nil end
    if ctx.state then ctx.state.dirty=true end
    refresh(ctx);return
  end
  if id=='downloadgithub' then
    s.phase='downloading';s.verification='PENDING';s.message='Downloading and checking SHA-256...';M.draw(ctx)
    local ok,ver,bytes=ctx.updater:stageGitHub(s.online)
    s.phase=ok and 'ready' or 'error';s.verification=ok and 'VERIFIED' or (tostring(ver):find('SHA%-256 mismatch') and 'FAILED' or 'NOT VERIFIED')
    message(ctx,ok and ('SHA-256 verified GitHub v'..ver..' ('..bytes..' bytes)') or ver,ok and 'success' or 'error')
    -- An OpenOS shell transport may have drawn outside our owned regions.
    if type(ctx.updater.shellExecute)=='function' then s.paint=nil end
    if ctx.gfx then ctx.gfx.foreground=nil;ctx.gfx.background=nil end
    if ctx.state then ctx.state.dirty=true end
    refresh(ctx);return
  end
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
-- Dedicated Updates dashboard. Autostart and shared widgets retain their layout.
local function dashboard(ctx)
  local g,base,s=ctx.gfx,ctx.theme,data(ctx)
  local w,h=g:size()
  local t={bg=0x080C10,surface=0x20282E,text=base.text,muted=base.muted,
    accent=base.accent,activeBg=base.activeBg,activeText=base.activeText,warn=base.warn,good=base.good}
  local wide=w>=120 and h>=42
  local left=wide and 27 or 0
  local right=wide and 30 or 0
  local cx,cw=left+2,w-left-right-2
  s.hits={}
  g:fill(1,1,w,h,t.bg)
  local function text(x,y,str,color,width,bg)
    g:text(x,y,str,color or t.text,bg or t.bg,width)
  end
  local function box(x,y,bw,bh,title)
    g:fill(x,y,bw,bh,t.bg);g:border(x,y,bw,bh,t.accent,t.bg)
    text(x+2,y,title,t.accent,bw-4)
  end
  local function lines(x,y,width,values)
    for i,line in ipairs(values) do text(x,y+i-1,line,t.muted,width) end
  end
  box(1,1,w,3,'NEXUS  //  RELEASE CONTROL')
  text(3,2,'MODULAR / VERIFIED / MANUAL INSTALL',t.muted,math.max(1,w-32))
  text(w-27,2,'v'..ctx.updater.version..' / OpenOS API',t.accent,25)
  local tabs={{'[1:UPDATES]',1},{'[2:AUTOSTART]',2}}
  local x=3
  for _,tab in ipairs(tabs) do
    g:text(x,4,tab[1],tab[2]==1 and t.activeText or t.accent,tab[2]==1 and t.activeBg or t.bg,#tab[1])
    s.hits[#s.hits+1]={x=x,y=4,w=#tab[1],h=1,tab=tab[2]};x=x+#tab[1]+2
  end
  if wide then text(w-29,4,'SHA-256 / STABLE CHANNEL',t.muted,27) end
  local status=s.staged and 'STAGED' or s.online and (s.online.newer and 'UPDATE AVAILABLE' or 'UP TO DATE') or 'NOT CHECKED'
  box(cx,6,cw,h-(wide and 10 or 8),'NEXUS / WORKSPACE / UPDATE CENTER')
  text(cx+2,7,'ACTIVE '..(ctx.updater.current or Update.CORE)..' v'..ctx.updater.version,t.text,cw-4)
  text(cx+2,8,'STAGED '..(s.staged or 'none')..'  /  BACKUP '..(s.backup and 'YES' or 'NO'),t.muted,cw-4)
  text(cx+2,9,'GITHUB / STABLE / '..status,s.online and t.good or t.muted,cw-4)
  local rows=items(ctx)
  local start,step=wide and 11 or 10,wide and 3 or 2
  for i,row in ipairs(rows) do
    local y=start+(i-1)*step
    Widgets.action(g,t,cx+2,y,cw-4,2,row.title,row.detail,i==s.index)
    s.hits[#s.hits+1]={x=cx+2,y=y,w=cw-4,h=2,row=i}
  end
  local logY=start+6*step+1
  -- At 80x25 keep one bounded log line; larger screens show a history panel.
  if not wide then logY=h-6 end
  if wide then
    box(cx+1,logY,cw-2,h-5-logY,'UPDATE LOG / RECENT EVENTS')
    local wrapped={}
    for _,entry in ipairs(s.history or {}) do
      local str=entry.at..'s '..entry.message
      while #str>0 do wrapped[#wrapped+1]=str:sub(1,cw-8);str=str:sub(cw-7) end
    end
    local last=s.history and s.history[#s.history]
    local pending=(not last or last.message~=s.message) and s.message or ''
    if #wrapped==0 and pending=='' then pending='Ready. Check the release manifest to begin.' end
    while #pending>0 do wrapped[#wrapped+1]=pending:sub(1,cw-8);pending=pending:sub(cw-7) end
    local capacity=math.max(0,h-7-logY)
    for i=math.max(1,#wrapped-capacity+1),#wrapped do
      text(cx+3,logY+1+i-math.max(1,#wrapped-capacity+1),wrapped[i],t.muted,cw-6)
    end
  else
    -- Last action ends at row 22 on tall screens; on 25 rows use a tighter list.
    text(cx+2,h-3,'LOG > '..(s.message~='' and s.message or 'Ready. Check manifest to begin.'),t.muted,cw-4)
  end
  if wide then
    local hs=ctx.hardware and ctx.hardware:snapshot() or {}
    local simulated=tostring(hs.gpuAddress or ''):match('^sim%-')~=nil
    box(1,6,left,13,'SYSTEM STATUS')
    lines(3,8,left-4,{'RUNTIME  OpenOS API','NEXUS    v'..ctx.updater.version,
      'HARDWARE '..(simulated and 'SIMULATED' or 'DETECTED'),
      'UPTIME   '..math.floor(ctx.now and ctx.now() or 0)..' s',
      'GPU      '..tostring(hs.depth or '?')..' bit',
      'DISPLAY  '..w..' x '..h,'ARCH     unavailable','HOST     unavailable','USER     unavailable'})
    box(1,20,left,9,'RESOURCES')
    local free,total=hs.freeMemory,hs.totalMemory
    if type(free)=='number' and type(total)=='number' and total>0 then
      text(3,22,'RAM '..math.floor((total-free)/1024)..'/'..math.floor(total/1024)..' KiB',t.text,left-4)
      local n=math.max(0,math.min(left-6,math.floor((total-free)/total*(left-6))))
      g:fill(3,24,left-4,1,t.surface);text(3,24,string.rep('#',n),t.accent,left-4,t.surface)
      text(3,26,'FREE   '..math.floor(free/1024)..' KiB',t.muted,left-4)
    else text(3,22,'Memory unavailable',t.muted,left-4) end
    box(1,30,left,h-34,'UPDATE TRANSPORT')
    lines(3,32,left-4,{'FEED  GitHub Raw','MANIFEST '..(s.online and 'LOADED' or 'NOT LOADED'),
      'VERIFY   SHA-256','INSTALL  confirmation'})
    local rx=w-right+1
    box(rx,6,right,13,'RELEASE INFO')
    lines(rx+2,8,right-4,{'CURRENT  v'..ctx.updater.version,'LATEST   '..(s.online and ('v'..s.online.version) or 'unknown'),
      'CHANNEL  stable','SIZE     '..(s.online and s.online.size and (s.online.size..' B') or 'unknown'),
      'STATUS   '..status,'PUBLISHED unavailable','COMMIT    unavailable'})
    if s.online and s.online.sha256 then text(rx+2,16,'SHA '..s.online.sha256:sub(1,right-9),t.accent,right-4) end
    box(rx,20,right,6,'CHANGELOG')
    text(rx+2,22,'No changelog loaded',t.muted,right-4)
    box(rx,27,right,10,'QUICK ACTIONS')
    for i,label in ipairs({'[U] Check updates','[D] Download release','[I] Install staged','[R] Roll back','[P] Pastebin download','[S] Refresh status'}) do
      text(rx+2,28+i,label,t.accent,right-4)
      s.hits[#s.hits+1]={x=rx+2,y=28+i,w=right-4,h=1,row=i}
    end
    if h>=50 then
      box(rx,38,right,h-42,'HELP')
      lines(rx+2,40,right-4,{'ARROWS select / ENTER run','MOUSE activates a row','1 / 2 switch tabs','[BACK] cancel / return'})
    end
  end
  -- Modal input owns all touches: retain only its buttons in the hit map.
  if s.mode or s.confirm then
    local pw=math.min(cw-4,68);local px=cx+math.floor((cw-pw)/2)
    local py=math.max(10,math.floor(h/2)-3)
    box(px,py,pw,7,s.confirm and ('CONFIRM '..s.confirm:upper()) or 'PASTEBIN DOWNLOAD')
    if s.confirm then
      text(px+2,py+2,'Apply this operation? Y / N',t.warn,pw-4)
      text(px+2,py+4,'[YES] [NO]',t.accent,pw-4)
      s.hits={{x=px+2,y=py+4,w=5,h=1,answer=true},{x=px+8,y=py+4,w=4,h=1,answer=false}}
    else
      text(px+2,py+2,'ID > '..s.buffer..'_',t.text,pw-4)
      text(px+2,py+4,'ENTER download / BACK cancel',t.muted,pw-4)
      s.hits={}
    end
  end
  text(2,h-2,'U CHECK / D DOWNLOAD / I INSTALL / R ROLLBACK / P PASTE / S REFRESH',t.accent,w-3)
  Widgets.taskbar(ctx)
end

-- Tier 3 renderer: region signatures retain static screen content without VRAM.
local function tier3(ctx)
  local g,s=ctx.gfx,data(ctx)
  local w,h=g:size()
  -- These cyan/cube/grayscale colors have distinct roles after Tier 3 quantization.
  local c={bg=0x000000,panel=0x0F0F0F,title=0x002424,edge=0x006D80,
    accent=0x00FFFF,text=0xE1E1E1,muted=0x969696,surface=0x2D2D2D,
    selected=0x00DBBF,ink=0x000000,good=0x33DB80,warn=0xFFDB40,bad=0xFF4940}
  local overlay=tostring(ctx.state.exitPending)..tostring(ctx.display and ctx.display.pending~=nil)
  local key=w..':'..h..':'..tostring(ctx.config.data.theme)..':'..overlay
  local full=not s.paint or s.paint.key~=key
  if full then
    ctx.state.screenMode=Widgets.mode(w,h,ctx.config.data.layout)
    Widgets.taskbar(ctx) -- unchanged global navigation, without a redundant screen clear
    g:fill(1,1,w,h-1,c.bg)
    s.paint={key=key,regions={}}
  end
  local cache=s.paint.regions
  local function region(id,signature,draw)
    signature=tostring(signature)
    if full or cache[id]~=signature then draw();cache[id]=signature end
  end
  local function text(x,y,value,color,width,bg)
    g:text(x,y,value,color or c.text,bg or c.panel,width)
  end
  local function clear(x,y,rw,rh,bg) g:fill(x,y,rw,rh,bg or c.panel) end
  local function panel(x,y,pw,ph,title)
    -- Draw the frame with glyph strokes instead of solid-colour cell borders.
    clear(x,y,pw,ph)
    g:colors(c.edge,c.panel)
    g:fill(x,y+1,1,ph-2,c.panel,'|');g:fill(x+pw-1,y+1,1,ph-2,c.panel,'|')
    local rule='+'..string.rep('-',pw-2)..'+'
    text(x,y,rule,c.edge,pw,c.panel);text(x,y+ph-1,rule,c.edge,pw,c.panel)
    text(x+2,y,'[ '..title..' ]',c.accent,pw-5,c.panel)
  end
  local lx,lw=2,28
  local cx,cw=32,w-63
  local rx,rw=w-29,28
  local logY,logH=31,h-34
  local function label(x,y,name,value,color,width)
    text(x,y,string.format('%-9s: ',name),c.muted,11)
    text(x+11,y,tostring(value),color or c.text,width-11)
  end
  local clock=ctx.now and ctx.now() or 0
  local hs=ctx.hardware and ctx.hardware:snapshot() or {}
  local simulated=tostring(hs.gpuAddress or ''):match('^sim%-')~=nil
  local current=ctx.updater.current or Update.CORE
  local status=s.phase=='checking' and 'CHECKING' or s.phase=='downloading' and 'DOWNLOADING' or
    s.phase=='error' and 'ERROR' or s.staged and 'STAGED' or
    s.online and (s.online.newer and 'UPDATE AVAILABLE' or 'UP TO DATE') or 'NOT CHECKED'
  local verify=(s.staged and ctx.updater:stagedSource()~='github-sha256') and 'NOT VERIFIED' or s.verification or (s.staged and ctx.updater:stagedSource()=='github-sha256' and 'VERIFIED' or 'NOT VERIFIED')
  local signature=table.concat({status,verify,s.staged or '',tostring(s.backup),s.online and s.online.version or '',s.online and s.online.sha256 or '',tostring(s.online and s.online.size or '')},'|')
  region('structure','static',function()
    -- A narrow four-row wordmark leaves breathing room for the real version.
    clear(1,1,w,4,c.title)
    local glyphs={{'1001','1101','1011','1001'},{'111','100','110','111'},
      {'101','010','010','101'},{'101','101','101','111'},{'111','110','011','111'}}
    local starts={3,8,12,16,20}
    for letter,glyph in ipairs(glyphs) do
      for y,bits in ipairs(glyph) do
        for start,run in bits:gmatch('()(1+)') do clear(starts[letter]+start-1,y,#run,1,0x0091BF) end
      end
    end
    text(25,1,'NEXUS v'..ctx.updater.version,c.accent,30,c.title)
    text(25,2,'OpenOS / RELEASE CONTROL',c.text,32,c.title)
    text(25,3,'MODULAR / VERIFIED / MANUAL',c.muted,32,c.title)
    text(w-39,1,'TIER 3 DISPLAY / 160x50 TARGET',c.accent,37,c.title)
    text(w-39,2,'8-BIT / 256-COLOR TEXT GRAPHICS',c.muted,37,c.title)
    text(w-39,3,simulated and 'SIMULATED HARDWARE / ISOLATED' or 'OPENCOMPUTERS / GPU API',c.text,37,c.title)
    clear(1,5,w,1,c.surface)
    text(3,5,'[1: UPDATES]',c.ink,13,c.selected)
    text(19,5,'[2: AUTOSTART]',c.accent,15,c.surface)
    text(w-31,5,'STABLE CHANNEL / SHA-256',c.muted,29,c.surface)
    panel(lx,7,lw,13,'SYSTEM STATUS')
    panel(lx,21,lw,9,'RESOURCES')
    panel(lx,31,lw,h-34,'UPDATE TRANSPORT')
    panel(cx,7,cw,h-10,'NEXUS / WORKSPACE')
    text(cx+2,8,'SYSTEM / UPDATE CENTER',c.text,cw-4)
    clear(cx+2,9,cw-4,1,c.title)
    panel(cx+1,logY,cw-2,logH,'UPDATE LOG / ELAPSED TIME')
    panel(rx,7,rw,13,'RELEASE INFO')
    panel(rx,21,rw,7,'CHANGELOG')
    text(rx+2,23,'No changelog loaded',c.muted,rw-4)
    text(rx+2,25,'Manifest has no notes.',c.muted,rw-4)
    panel(rx,29,rw,9,'QUICK ACTIONS')
    panel(rx,39,rw,h-42,'HELP')
    for i,line in ipairs({'ARROWS / ENTER select','MOUSE / TOUCH activate','1 / 2 switch tabs',
                         'BACK cancel / return','HOME open desktop'}) do text(rx+2,40+i,line,c.muted,rw-4) end
  end)
  region('system',math.floor(clock)..':'..tostring(hs.depth),function()
    clear(lx+1,8,lw-2,11)
    label(lx+2,9,'RUNTIME','OpenOS API',c.text,lw-4)
    label(lx+2,10,'NEXUS','v'..ctx.updater.version,c.accent,lw-4)
    label(lx+2,11,'GPU',tostring(hs.depth or '?')..' bit',c.text,lw-4)
    label(lx+2,12,'DISPLAY',w..'x'..h,c.text,lw-4)
    label(lx+2,13,'UPTIME',math.floor(clock)..' s',c.text,lw-4)
    label(lx+2,15,'HARDWARE',simulated and 'SIMULATED' or 'DETECTED',c.accent,lw-4)
    label(lx+2,16,'HOST','unavailable',c.muted,lw-4)
    label(lx+2,17,'USER','unavailable',c.muted,lw-4)
    label(lx+2,18,'ARCH','unavailable',c.muted,lw-4)
  end)
  local free,total=hs.freeMemory,hs.totalMemory
  -- Query the mounted filesystem only on entry or an explicit updater refresh,
  -- not on each keypress. A missing/unsupported proxy is a normal fallback.
  if not s.diskReady then
    s.diskReady=true;s.diskTotal=nil;s.diskUsed=nil
    if ctx.fs and type(ctx.fs.get)=='function' then
      local ok,drive=pcall(ctx.fs.get,'/home')
      if ok and type(drive)=='table' and type(drive.spaceTotal)=='function' and type(drive.spaceUsed)=='function' then
        local totalOk,capacity=pcall(drive.spaceTotal);local usedOk,used=pcall(drive.spaceUsed)
        if totalOk and usedOk and type(capacity)=='number' and type(used)=='number' and
           capacity>0 and capacity<math.huge and used>=0 and used<math.huge then
          s.diskTotal=capacity;s.diskUsed=used
        end
      end
    end
  end
  local diskDisplay=s.diskTotal and table.concat({math.floor(s.diskUsed/1024),math.floor(s.diskTotal/1024),
    math.floor(math.max(0,math.min(1,s.diskUsed/s.diskTotal))*100+0.5)},':') or 'unavailable'
  local function meter(y,ratio)
    for i=0,9 do clear(lx+2+i*2,y,1,1,i<math.floor(ratio*10+0.5) and c.accent or c.surface) end
    text(lx+22,y,math.floor(ratio*100+0.5)..'%',c.accent,4)
  end
  region('ram',tostring(free)..':'..tostring(total),function()
    clear(lx+1,22,lw-2,3)
    if type(free)=='number' and type(total)=='number' and total>0 then
      local used=math.max(0,total-free);local ratio=math.max(0,math.min(1,used/total))
      text(lx+2,22,'RAM '..math.floor(used/1024)..' / '..math.floor(total/1024)..' KiB',c.text,lw-4)
      meter(23,ratio)
      text(lx+2,24,'FREE '..math.floor(free/1024)..' KiB',c.muted,lw-4)
    else text(lx+2,23,'Memory unavailable',c.muted,lw-4) end
  end)
  region('disk',diskDisplay,function()
    clear(lx+1,26,lw-2,2)
    if s.diskTotal then
      text(lx+2,26,'DISK '..math.floor(s.diskUsed/1024)..' / '..math.floor(s.diskTotal/1024)..' KiB',c.text,lw-4)
      meter(27,math.max(0,math.min(1,s.diskUsed/s.diskTotal)))
    else text(lx+2,26,'Disk space unavailable',c.muted,lw-4) end
  end)
  region('summary',signature,function()
    clear(cx+1,10,cw-2,3)
    text(cx+2,10,'ACTIVE '..current..'  v'..ctx.updater.version,c.text,cw-4)
    text(cx+2,11,'STAGED '..(s.staged or 'none')..'  /  BACKUP '..(s.backup and 'AVAILABLE' or 'NONE'),c.muted,cw-4)
    text(cx+2,12,'GITHUB '..status..'  /  SHA-256 '..verify,
      s.phase=='error' and c.bad or s.staged and c.good or c.accent,cw-4)
  end)
  region('release',signature,function()
    clear(rx+1,8,rw-2,11)
    label(rx+2,9,'CURRENT','v'..ctx.updater.version,c.accent,rw-4)
    label(rx+2,10,'LATEST',s.online and 'v'..s.online.version or 'unknown',c.accent,rw-4)
    label(rx+2,11,'CHANNEL','stable',c.text,rw-4)
    label(rx+2,12,'SIZE',s.online and s.online.size and (s.online.size..' B') or 'unknown',c.text,rw-4)
    label(rx+2,13,'VERIFY',verify,verify=='VERIFIED' and c.good or verify=='FAILED' and c.bad or c.muted,rw-4)
    label(rx+2,14,'BACKUP',s.backup and 'available' or 'none',c.text,rw-4)
    text(rx+2,16,'SHA '..(s.online and s.online.sha256 and s.online.sha256:sub(1,rw-9) or 'unavailable'),c.muted,rw-4)
    local statusColor=s.phase=='error' and c.bad or s.staged and c.good or
      (s.phase=='checking' or s.phase=='downloading') and c.warn or
      s.online and (s.online.newer and c.accent or c.good) or c.muted
    clear(rx+2,18,1,1,statusColor);text(rx+4,18,status,statusColor,rw-6)
  end)
  region('transport',signature..tostring(s.confirm),function()
    clear(lx+1,32,lw-2,h-36)
    for i,line in ipairs({'FEED  GitHub Raw','MANIFEST '..(s.online and 'LOADED' or 'NOT LOADED'),
      'CHANNEL stable','VERIFY SHA-256','INSTALL confirmation','NETWORK unavailable'}) do text(lx+2,32+i,line,c.muted,lw-4) end
    text(lx+2,h-10,'UPDATE PROGRESS',c.accent,lw-4)
    local steps={{'CHECK',s.phase=='checking',s.online~=nil,s.phase=='error' and not s.online},
      {'DOWNLOAD',s.phase=='downloading',s.staged~=nil,s.phase=='error' and s.online and verify~='FAILED'},
      {'VERIFY',false,verify=='VERIFIED',verify=='FAILED'},
      {'INSTALL',s.confirm=='install',false,false}}
    for i,step in ipairs(steps) do
      local color=step[4] and c.bad or step[2] and c.accent or step[3] and c.good or c.muted
      local marker=step[4] and '! ' or step[2] and '> ' or step[3] and '+ ' or '- '
      local state=step[4] and 'ERROR' or step[2] and 'ACTIVE' or step[3] and 'DONE' or 'WAIT'
      clear(lx+1,h-10+i,1,1,color)
      text(lx+2,h-10+i,marker..step[1]..string.rep(' ',11-#step[1])..state,color,lw-4)
    end
    text(lx+2,h-5,simulated and '[SIMULATED]' or '[MANUAL]',c.accent,lw-4)
  end)
  local modalKey=(s.confirm or s.mode or '')..':'..s.buffer
  if not full and s.paint.modalKey and s.paint.modalKey~=modalKey then
    clear(cx+1,21,cw-2,9)
    for i=4,6 do cache['action'..i]=nil end
    cache.modal=nil
  end
  s.paint.modalKey=modalKey
  local rows=items(ctx)
  local notes={'READ MANIFEST',verify=='VERIFIED' and 'SHA-256 VERIFIED' or verify=='FAILED' and 'VERIFY FAILED' or
    s.phase=='downloading' and 'DOWNLOAD IN PROGRESS' or 'VERIFY BEFORE STAGING',s.staged and 'READY / CONFIRM' or 'NO STAGED RELEASE',
    s.backup and 'BACKUP AVAILABLE' or 'NO BACKUP', 'TRUSTED ID ONLY','LOCAL STATUS'}
  s.hits={{x=3,y=5,w=13,h=1,tab=1},{x=19,y=5,w=15,h=1,tab=2}}
  local shortcuts={'U','D','I','R','P','S'}
  for i,row in ipairs(rows) do
    local y=13+(i-1)*3
    local selected=i==s.index
    region('action'..i,tostring(selected)..notes[i],function()
      local bg=selected and c.selected or c.surface
      clear(cx+2,y,cw-4,2,bg)
      local unavailable=(i==3 and not s.staged) or (i==4 and not s.backup)
      text(cx+3,y,(selected and '> ' or '  ')..row.title,selected and c.ink or unavailable and c.muted or c.text,cw-6,bg)
      text(cx+5,y+1,row.detail,selected and c.ink or c.muted,cw-9,bg)
      local noteColor=(i==2 and verify=='FAILED') and c.bad or
        ((i==2 and verify=='VERIFIED') or (i==3 and s.staged) or (i==4 and s.backup)) and c.good or c.muted
      if cw>=90 then text(cx+cw-25,y,notes[i],selected and c.ink or noteColor,22,bg) end
    end)
    region('quick'..i,selected,function()
      clear(rx+1,29+i,rw-2,1,selected and c.title or c.panel)
      text(rx+2,29+i,'['..shortcuts[i]..'] '..({'Check updates','Download release','Install staged','Roll back','Pastebin download','Refresh status'})[i],
        selected and c.accent or c.muted,rw-4,selected and c.title or c.panel)
    end)
    s.hits[#s.hits+1]={x=cx+2,y=y,w=cw-4,h=2,row=i}
    s.hits[#s.hits+1]={x=rx+1,y=29+i,w=rw-2,h=1,row=i}
  end
  local logKey=(s.logRevision or 0)..':'..s.message..':'..#s.history..':'..(s.history[#s.history] and s.history[#s.history].at or '')..':'..(s.logScroll or 0)..':'..signature
  region('log',logKey,function()
    clear(cx+2,logY+1,cw-4,logH-2)
    local wrapped={}
    for _,entry in ipairs(s.history) do
      local kind=entry.kind or 'info'
      local prefix=string.format('[%6ss] [%-7s] ',entry.at or '?',kind:upper())
      local rest=entry.message
      repeat
        wrapped[#wrapped+1]={text=prefix..rest:sub(1,cw-29),kind=kind}
        rest=rest:sub(cw-28);prefix=string.rep(' ',23)
      until rest==''
    end
    if s.phase=='checking' or s.phase=='downloading' then wrapped[#wrapped+1]={text='[PENDING] '..s.message,kind='warn'} end
    text(cx+3,logY+1,'STATUS: '..status..'  /  SHA-256: '..verify,c.accent,cw-6)
    if #wrapped==0 then
      local empty='No update events yet.';local hint='Press U to read the release manifest.'
      local ey=logY+math.floor(logH/2)
      text(cx+math.floor((cw-#empty)/2),ey,empty,c.muted,cw-6)
      text(cx+math.floor((cw-#hint)/2),ey+1,hint,c.text,cw-6)
    end
    local count=logH-3;s.logMaximum=math.max(0,#wrapped-count)
    s.logScroll=math.min(s.logMaximum,s.logScroll or 0)
    local finish=math.max(1,#wrapped-s.logScroll)
    local first=math.max(1,finish-count+1)
    for i=first,math.min(#wrapped,first+count-1) do
      local line=wrapped[i];text(cx+3,logY+2+i-first,line.text,
        line.kind=='error' and c.bad or line.kind=='success' and c.good or line.kind=='warn' and c.warn or c.text,cw-6)
    end
  end)
  -- A modal is an overlay; invalidate underlying regions once when it changes.
  if s.mode or s.confirm then
    local pw=math.min(cw-6,68);local px=cx+math.floor((cw-pw)/2);local py=math.floor(h/2)-3
    local modal=(s.confirm or s.mode)..':'..s.buffer
    region('modal',modal,function()
      clear(px+1,py+1,pw,7,c.bg);panel(px,py,pw,7,s.confirm and ('CONFIRM '..s.confirm:upper()) or 'PASTEBIN DOWNLOAD')
      text(px+2,py+2,s.confirm and 'Apply this operation? Y / N' or ('ID > '..s.buffer..'_'),c.warn,pw-4)
      text(px+2,py+4,s.confirm and '[YES] [NO]' or 'ENTER download / BACK cancel',c.accent,pw-4)
    end)
    s.hits=s.confirm and {{x=px+2,y=py+4,w=5,h=1,answer=true},{x=px+8,y=py+4,w=4,h=1,answer=false}} or {}
  end
  local toast=ctx.notices and ctx.notices.current
  region('footer',toast and toast.item.message or '',function()
    clear(1,h-2,w,2,c.title)
    text(3,h-2,'GITHUB RAW / SHA-256 / MANUAL INSTALL   |   PGUP/PGDN LOG   |   [BACK] [HOME]',c.muted,w-5,c.title)
  end)
end

-- Autostart shares the industrial skin, but retains its existing startup
-- operations and confirmation path. The Updates dashboard above is untouched.
local function autostartDashboard(ctx)
  local g,t,s=ctx.gfx,ctx.theme,data(ctx)
  local w,h=g:size();Widgets.frame(ctx,'SYSTEM / UPDATE CENTER',true)
  s.hits={}
  local x=2
  for _,tab in ipairs({{1,'[1:UPDATES]'},{2,'[2:AUTOSTART]'}}) do
    local active=tab[1]==2
    g:text(x,3,tab[2],active and t.activeText or t.accent,active and t.activeBg or t.bg,#tab[2])
    s.hits[#s.hits+1]={x=x,y=3,w=#tab[2],h=1,tab=tab[1]};x=x+#tab[2]+2
  end
  local lw=math.floor((w-6)*0.65);local rx=lw+4;local rw=w-rx
  Widgets.outline(g,t,2,5,lw,h-10,'OPENOS AUTOSTART')
  g:text(4,7,'AUTOSTART  '..tostring(s.autostart),s.autostart=='ENABLED' and t.good or t.muted,t.bg,lw-4)
  g:text(4,8,'STARTUP GUARD  '..(s.guard and 'ACTIVE' or 'CLEAR'),s.guard and t.warn or t.muted,t.bg,lw-4)
  local rows=items(ctx)
  for i,row in ipairs(rows) do
    local y=10+(i-1)*4
    Widgets.action(g,t,4,y,lw-4,2,row.title,row.detail,i==s.index)
    s.hits[#s.hits+1]={x=4,y=y,w=lw-4,h=2,row=i}
  end
  if s.message~='' then g:text(4,h-7,s.message,t.muted,t.bg,lw-4) end
  Widgets.outline(g,t,rx,5,rw,13,'STARTUP STATUS')
  for i,line in ipairs({'STATUS   '..tostring(s.autostart),
    'GUARD    '..(s.guard and 'ACTIVE' or 'CLEAR'),
    'SHELL    OpenOS interactive',
    'ENTRY    /home/osv4.lua'}) do g:text(rx+2,6+i*2,line,t.text,t.bg,rw-4) end
  Widgets.outline(g,t,rx,20,rw,11,'CONTROLS')
  for i,line in ipairs({'UP / DOWN  Select','ENTER / TOUCH  Activate',
    'Changes require confirmation.','[BACK] or [HOME]  Return'}) do
    g:text(rx+2,21+i*2,line,t.muted,t.bg,rw-4)
  end
  g:text(3,h-2,'OPENOS .shrc  /  1-2 TABS  /  [BACK] [HOME]',t.muted,t.bg,w-5)
  if s.confirm then
    local pw=math.min(lw-6,60);local px=math.floor((lw-pw)/2)+2;local py=math.floor(h/2)-3
    g:fill(px,py,pw,7,t.surface);g:border(px,py,pw,7,t.warn,t.surface)
    g:text(px+2,py+1,'CONFIRM '..s.confirm:upper()..'?',t.warn,t.surface,pw-4)
    g:text(px+2,py+3,'Apply this operation? Y / N',t.text,t.surface,pw-4)
    g:text(px+2,py+5,'[YES] [NO]',t.accent,t.surface,pw-4)
    s.hits={{x=px+2,y=py+5,w=5,h=1,answer=true},{x=px+8,y=py+5,w=4,h=1,answer=false}}
  end
end

function M.draw(ctx)
  local g,t,s=ctx.gfx,ctx.theme,data(ctx)
  local w,h=g:size()
  if s.tab==1 and w>=140 and h>=48 and h<=50 and g.gpu.getDepth()>=8 then tier3(ctx);return end
  if s.tab==2 and Widgets.rich(ctx) then s.paint=nil;autostartDashboard(ctx);return end
  s.paint=nil
  Widgets.frame(ctx,'SYSTEM / UPDATE CENTER')
  if s.tab==1 and w>=70 and h>=25 then dashboard(ctx);return end
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
    if not compact then
      g:text(2,6,'STAGED '..(s.staged and ('v'..s.staged) or 'none')..' ('..ctx.updater:stagedSource()..')   BACKUP '..(s.backup and 'YES' or 'NO'),t.muted,t.bg,w-3)
      g:text(2,7,s.online and ('GITHUB  v'..s.online.version..(s.online.newer and '  NEW VERSION' or '  UP TO DATE')) or 'GITHUB  not checked',s.online and (s.online.newer and t.good or t.muted) or t.muted,t.bg,w-3)
    end
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
  g:text(2,h-2,'GITHUB RAW / SHA-256 / MANUAL INSTALL / [BACK] [HOME]',t.muted,t.bg,w-3)
end
function M.input(a,ctx)
  local s=data(ctx)
  if s.tab==1 and (a.kind=='pageup' or a.kind=='pagedown') and not s.confirm and not s.mode then
    s.logScroll=math.max(0,math.min(s.logMaximum or 24,(s.logScroll or 0)+(a.kind=='pageup' and 3 or -3)));return true
  end
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
      -- An OpenOS shell transport may have drawn outside our owned regions.
    if type(ctx.updater.shellExecute)=='function' then s.paint=nil end
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
  if s.tab==1 and a.kind=='char' then
    local shortcuts={u=1,d=2,i=3,r=4,p=5,s=6}
    local row=shortcuts[a.value:lower()]
    if row then s.index=row;act(ctx,items(ctx)[row].id);return true end
  end
  if s.tab==1 and a.kind=='scroll' then
    s.index=math.max(1,math.min(#items(ctx),s.index+(a.delta>0 and -1 or 1)));return true
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

package.preload["nexus.apps.vault"] = function(...)
local W=require('nexus.ui.widgets')
local V=require('nexus.core.vault')
local Config=require('nexus.core.vault_config')
local M={id='vault',name='VAULT',description='Read-only Transposer storage'}
local tabs={'OVERVIEW','STORAGE','ITEMS','SEARCH','CONFIG'}
local sorts={'name','name-desc','quantity','quantity-desc','registry','chest','slot'}
local sourceSorts={'name','type','address','side','slots','occupied','status'}
local function state(c) return c.state.vault end
local function title(s,v) return (s.prefs[v.id] or {}).alias or (V.SIDES[v.side+1]..' / '..v.address:sub(1,8)..'..'..v.address:sub(-4)) end
local function invalidate(s) s.cache=nil end
local function save(c)
  local s=state(c);local ok,err=Config.save(s.prefs);s.message=ok and 'Preferences saved' or ('Save failed: '..tostring(err));invalidate(s)
end
function M.open(c)
  c.vaultEngine=c.vaultEngine or V.new(c.deviceControl.component,c.now)
  c.state.vault={engine=c.vaultEngine,prefs=Config.load(),tab=1,index=1,scroll=0,sourceIndex=1,sort=1,sourceSort=1,query='',hits={},message='',detailScroll=0}
  local s=state(c);s.sort=math.max(1,math.min(#sorts,s.prefs._sort or 1))
  for id,p in pairs(s.prefs) do if type(p)=='table' and not c.vaultEngine.sources[id] then local a,side=id:match('^vault://(.+)/([0-5])$');if a then c.vaultEngine.sources[id]={id=id,address=a,side=tonumber(side),status='DISCONNECTED',stale=true} end end end
  c.vaultEngine:start()
end
function M.close(c) if state(c) then state(c).engine:cancel() end;c.state.vault=nil end
function M.tick(c) local s=state(c);local changed=s.engine:step(8);if changed then invalidate(s) end;return changed end
local function sources(s) return s.engine:sourcesList(s.prefs,sourceSorts[s.sourceSort],s.online) end
local function selected(s) return sources(s)[s.sourceIndex] end
local function rows(s)
  if s.cache then return s.cache end
  if s.tab==3 then s.cache=s.engine:catalog(s.prefs);V.sort(s.cache,sorts[s.sort],s.prefs)
  else s.cache=s.engine:query(s.prefs,s.tab==4 and s.query or '',sorts[s.sort],s.tab==2 and selected(s) and selected(s).id or nil,s.empty) end
  return s.cache
end
local function action(c,id)
  local s=state(c);local src=selected(s)
  if type(id)=='number' then s.tab=id;s.index=1;s.scroll=0;s.details=false;s.focus=id==4;invalidate(s)
  elseif id=='refresh' then s.engine:start()
  elseif id=='selected' and src then s.engine:start(src.id)
  elseif id=='cancel' then s.engine:cancel()
  elseif id=='sort' then s.sort=s.sort%#sorts+1;s.prefs._sort=s.sort;save(c)
  elseif id=='sourceSort' then s.sourceSort=s.sourceSort%#sourceSorts+1;invalidate(s)
  elseif id=='filter' then s.online=not s.online;s.sourceIndex=1;invalidate(s)
  elseif id=='empty' then s.empty=not s.empty;invalidate(s)
  elseif id=='rename' and src then s.rename=(s.prefs[src.id] or {}).alias or '';s.renameId=src.id
  elseif id=='reset' and src then s.prefs[src.id]=s.prefs[src.id] or {};s.prefs[src.id].alias=nil;save(c)
  elseif id=='exclude' and src then s.prefs[src.id]=s.prefs[src.id] or {};s.prefs[src.id].excluded=not s.prefs[src.id].excluded;save(c)
  elseif id=='detailNext' then s.detailScroll=s.detailScroll+5
  elseif id=='detailPrev' then s.detailScroll=math.max(0,s.detailScroll-5)
  elseif id=='details' then s.details=not s.details;s.detailScroll=0
  elseif id=='search' then s.focus=not s.focus
  elseif id=='open' then
    local row=rows(s)[s.index]
    if row then
      if row.locations then s.locations=not s.locations;s.locationIndex=1;s.details=true
      else for i,srcRow in ipairs(sources(s)) do if srcRow.id==row.source then s.sourceIndex=i end end;s.tab=2;invalidate(s);for i,v in ipairs(rows(s)) do if v.source==row.source and v.slot==row.slot then s.index=i end end;s.details=true end
    end
  elseif id=='nextLocation' then local row=rows(s)[s.index];if row and row.locations then s.locationIndex=(s.locationIndex or 1)%#row.locations+1 end
  elseif id=='location' then
    local row=rows(s)[s.index];local item=row and row.locations and row.locations[s.locationIndex or 1]
    if item then for i,v in ipairs(sources(s)) do if v.id==item.source then s.sourceIndex=i end end;s.tab=2;s.locations=false;invalidate(s);for i,v in ipairs(rows(s)) do if v.slot==item.slot then s.index=i end end;s.details=true end
  end
end
-- UTF-8-safe chunks before the existing ASCII-width Graphics clipping boundary.
local function chunks(value,width)
  local result,part,n={},'',0
  value=V.text(tostring(value)) or ''
  for _,cp in utf8.codes(value) do part=part..utf8.char(cp);n=n+1;if n>=width then result[#result+1]=part;part='';n=0 end end
  if part~='' then result[#result+1]=part end;return result
end
function M.draw(c)
  local s=state(c);local e=s.engine;local g,t=c.gfx,c.theme;local w,h=g:size()
  W.frame(c,'VAULT / '..tabs[s.tab],true);s.hits={}
  local function put(x,y,text,width,color,bg)
    local line=chunks(text,math.max(1,width))[1] or '';g:text(x,y,line,color or t.text,bg or t.bg,#line)
  end
  local function button(x,y,label,id)
    put(x,y,label,#label,t.accent);s.hits[#s.hits+1]={x=x,y=y,w=#label,id=id}
  end
  local x=2;for i,name in ipairs(tabs) do local label=i..':'..name;if x+#label<w then button(x,3,label,i);x=x+#label+2 end end
  if w<52 or h<20 then put(2,5,'Vault requires 52x20; use 80x25.',w-3,t.warn);return end
  local sim=false;for _,d in ipairs(e.transposers) do if d.address:match('^sim%-') then sim=true end end
  put(2,4,(sim and 'SIMULATED / ' or '')..'READ ONLY / '..e.state..' / '..e.done..' slots inspected',w-3,t.good)
  button(2,5,'[REFRESH]','refresh');button(13,5,'[CANCEL]','cancel');button(23,5,'[DETAILS]','details')
  local src=selected(s);local list=sources(s)
  local large=w>=120;local left=large and 32 or 0;local right=large and 48 or 0
  local cx=large and 35 or 2;local cw=w-cx-right-2;local bottom=h-5
  if s.tab==1 then
    local totals={slots=0,occupied=0,empty=0,unknown=0,qty=0,online=0}
    for _,v in ipairs(list) do if not v.stale then totals.slots=totals.slots+(v.total or 0);totals.occupied=totals.occupied+(v.occupied or 0);totals.empty=totals.empty+(v.empty or 0);totals.unknown=totals.unknown+(v.unknown or 0);if v.status=='ONLINE' then totals.online=totals.online+1 end end end
    for _,v in ipairs(e:catalog(s.prefs)) do totals.qty=totals.qty+v.size end
    W.outline(g,t,2,7,math.floor(w/2)-2,h-13,'STORAGE TELEMETRY')
    local lines={'TRANSPOSERS       '..#e.transposers,'INVENTORY VIEWS    '..#list,'ONLINE            '..totals.online,'INSPECTED SLOTS   '..totals.slots,'OCCUPIED / FREE   '..totals.occupied..' / '..totals.empty,'UNKNOWN SLOTS     '..totals.unknown,'KNOWN QUANTITY    '..totals.qty,'IDENTITIES        '..#e:catalog(s.prefs),'LAST REFRESH      '..tostring(e.finished or 'pending')..' s'}
    for i,line in ipairs(lines) do if 8+i<bottom then put(4,8+i,line,math.floor(w/2)-7) end end
    local xx=math.floor(w/2)+2
    W.outline(g,t,xx,7,w-xx-1,h-13,'SOURCE UTILIZATION')
    if #list==0 then put(xx+2,9,'No adjacent inventories found.',w-xx-5,t.warn);put(xx+2,11,'Connect a Transposer beside a chest.',w-xx-5) end
    for i,v in ipairs(list) do if 8+i*2<bottom then put(xx+2,7+i*2,title(s,v),w-xx-5,t.accent);put(xx+2,8+i*2,v.status..' / '..tostring(v.occupied or '?')..' of '..tostring(v.total)..' slots',w-xx-5) end end
    button(2,h-5,'[STORAGE]',2);button(13,h-5,'[ITEMS]',3);button(22,h-5,'[SEARCH]',4);button(32,h-5,'[CONFIG]',5)
  elseif s.tab==5 then
    local lines={'SOURCE: '..(src and title(s,src) or 'Select a source in Storage'),
      'Aliases remain saved when devices disconnect.','Excluded views stay visible in Storage and Search.',
      'Exclusion removes a known duplicate from item totals.','Physical chest equivalence cannot be detected.',
      'V1 provides inspection only. No inventory writes.'}
    for i,line in ipairs(lines) do put(3,7+i,line,w-6) end
    button(3,16,'[RENAME]','rename');button(14,16,'[RESET NAME]','reset');button(29,16,'[EXCLUDE / INCLUDE]','exclude')
  else
    local data=rows(s)
    if large then
      W.outline(g,t,2,7,left,h-12,'STORAGE SOURCES')
      for j=1,math.min(#list,h-15) do
        local i=math.max(0,s.sourceIndex-(h-15))+j;local v=list[i]
        if v then local bg=i==s.sourceIndex and t.activeBg or t.bg
          g:fill(3,8+j,left-2,1,bg);put(4,8+j,title(s,v),left-4,i==s.sourceIndex and t.activeText or t.text,bg)
          s.hits[#s.hits+1]={x=3,y=8+j,w=left-2,source=i}
        end
      end
    end
    if s.tab==2 then
      put(cx,7,src and title(s,src)..' / '..src.status..(src.stale and ' / STALE' or '') or 'No storage found',cw,t.accent)
      button(cx,8,'[PREV]','prev');button(cx+8,8,'[NEXT]','next');button(cx+16,8,'[RENAME]','rename');button(cx+26,8,'[EMPTY]','empty')
    elseif s.tab==4 then
      button(cx,7,(s.focus and '> ' or '')..'SEARCH: '..s.query,'search');put(cx,8,'Enter: finish typing / open result',cw,t.muted)
    else put(cx,7,'ALL ITEMS / '..#data..' identities',cw,t.accent);button(cx,8,'[NEXT LOCATION]','nextLocation');button(cx+17,8,'[OPEN LOCATION]','location') end
    button(cx,9,'SORT: '..sorts[s.sort],'sort');if s.tab==3 then button(cx+24,9,'[OPEN LOCATION]','location') end
    put(cx,10,s.tab==3 and 'ITEM / TOTAL / LOCATIONS' or 'SLOT   ITEM / QUANTITY',cw,t.muted)
    local count=math.max(1,bottom-11);s.index=math.max(1,math.min(s.index,#data));s.scroll=math.max(0,math.min(s.scroll,math.max(0,#data-count)))
    if s.index<=s.scroll then s.scroll=s.index-1 end;if s.index>s.scroll+count then s.scroll=s.index-count end
    for j=1,count do local i=s.scroll+j;local row=data[i];if row then
      local y=10+j;local bg=i==s.index and t.activeBg or t.bg;g:fill(cx,y,cw,1,bg)
      local suffix=tostring(row.size or (row.display=='Empty slot' and '-' or '?'))..(row.locations and (' / '..#row.locations) or '')
      local prefix=row.slot and string.format('%04d ',row.slot) or ''
      if s.tab==4 then local vs=e.sources[row.source];prefix=string.format('%04d ',row.slot)..title(s,vs)..' / '..vs.status..(vs.stale and ' STALE' or '')..' / ' end
      put(cx+1,y,prefix..row.display,math.max(1,cw-#suffix-3),i==s.index and t.activeText or t.text,bg)
      put(cx+cw-#suffix-1,y,suffix,#suffix,i==s.index and t.activeText or t.text,bg)
      s.hits[#s.hits+1]={x=cx,y=y,w=cw,row=i}
    end end
    if #data==0 then put(cx,12,e.worker and 'Scanning inventories...' or 'No matching items / contents unavailable',cw,t.warn) end
    if s.tab==2 then button(cx,h-5,'[SCAN SOURCE]','selected');button(cx+15,h-5,'[SOURCE SORT]','sourceSort');button(cx+30,h-5,'[ONLINE]','filter') end
    local row=data[s.index]
    if large or s.details then
      local dx=large and w-right or 2;local dw=large and right-1 or w-3;local dy=large and 7 or 6
      g:fill(dx,dy,dw,h-dy-5,t.bg);W.outline(g,t,dx,dy,dw,h-dy-5,'DETAILS / '..((s.details or s.tab~=2) and 'ITEM' or 'SOURCE'))
      local lines={}
      if (s.details or s.tab~=2) and row then
        lines={'ITEM',row.display,'REGISTRY',row.name or 'Unavailable','QUANTITY '..tostring(row.size or '?')}
        if row.locations then
          src=row.locations[s.locationIndex or 1] and e.sources[row.locations[s.locationIndex or 1].source] or src
          lines[#lines+1]='LOCATIONS / ENTER TO EXPAND'
          for i,v in ipairs(row.locations) do local vsrc=e.sources[v.source];lines[#lines+1]=(i==(s.locationIndex or 1) and '> ' or '')..title(s,vsrc)..' # '..v.slot..' x '..tostring(v.size or '?') end
        else
          lines[#lines+1]='STACK LIMIT '..tostring(row.maxSize or '?');lines[#lines+1]='DAMAGE '..tostring(row.damage or '?')..' / '..tostring(row.maxDamage or '?')
          lines[#lines+1]='TAG '..tostring(row.hasTag)..' / NBT unavailable';lines[#lines+1]='SLOT '..row.slot
          src=e.sources[row.source]
        end
      end
      if src then for _,v in ipairs({'SOURCE',title(s,src),src.type or 'Inventory type unavailable','TRANSPOSER',src.address,'SIDE '..V.SIDES[src.side+1]..' / '..src.side,'LOGICAL VAULT ID',src.id,'SLOTS '..tostring(src.total)..' / USED '..tostring(src.occupied or '?'),'FREE '..tostring(src.empty or '?')..' / UNKNOWN '..tostring(src.unknown or '?'),src.status..(src.stale and ' / STALE' or ''),'LAST SUCCESS '..tostring(src.lastSuccess or 'none')..' s',(s.prefs[src.id] or {}).excluded and 'EXCLUDED FROM TOTALS' or 'INCLUDED IN TOTALS',src.error or ''}) do lines[#lines+1]=v end end
      local wrapped={};for _,line in ipairs(lines) do for _,part in ipairs(chunks(line,dw-4)) do wrapped[#wrapped+1]=part end end
      s.detailScroll=math.max(0,math.min(s.detailScroll,math.max(0,#wrapped-(h-dy-8))))
      for j=1,h-dy-8 do if wrapped[j+s.detailScroll] then put(dx+2,dy+j,wrapped[j+s.detailScroll],dw-4) end end
      button(dx+2,h-7,'[PREV]','detailPrev');button(dx+10,h-7,'[MORE]','detailNext');if not large then button(dx+18,h-7,'[CLOSE DETAILS]','details') end
    end
  end
  put(2,h-3,'TOTALS: known views; physical duplicates possible. '..(s.message or ''),w-3,t.warn)
  put(2,h-2,'1-5 tabs | Arrows select | Enter inspect | R refresh | S sort | D details | PgUp/Dn details',w-3,t.muted)
  if #e.errors>0 then put(2,h-4,e.errors[#e.errors],w-3,t.warn) end
  if s.rename~=nil then
    g:fill(3,8,w-6,7,t.surface);g:border(3,8,w-6,7,t.accent,t.surface)
    put(5,9,'RENAME STORAGE / Enter saves / Back cancels',w-10,t.accent,t.surface)
    put(5,11,s.rename..'_',w-10,t.text,t.surface)
    button(5,13,'[SAVE]','saveName');button(14,13,'[CANCEL]','cancelName')
  end
end
function M.input(a,c)
  local s=state(c)
  local function edit(value,limit)
    if a.kind=='char' then return value..a.value elseif a.kind=='paste' then return value..(V.text(a.value) or '')
    elseif a.kind=='backspace' then return value:sub(1,(utf8.offset(value,-1) or 1)-1) end
    return value
  end
  if s.rename~=nil then
    if a.kind=='back' then s.rename=nil;return true end
    local id
    if a.kind=='touch' then for _,hit in ipairs(s.hits) do if hit.y==a.y and a.x>=hit.x and a.x<hit.x+hit.w then id=hit.id end end end
    if a.kind=='enter' or id=='saveName' then s.prefs[s.renameId]=s.prefs[s.renameId] or {};s.prefs[s.renameId].alias=s.rename~='' and s.rename or nil;s.rename=nil;save(c)
    elseif id=='cancelName' then s.rename=nil else s.rename=edit(s.rename);while #s.rename>160 do s.rename=s.rename:sub(1,(utf8.offset(s.rename,-1) or 1)-1) end end;return true
  end
  if s.focus then
    if a.kind=='enter' or a.kind=='tab' or a.kind=='back' then s.focus=false
    elseif a.kind~='touch' then s.query=edit(s.query);while #s.query>256 do s.query=s.query:sub(1,(utf8.offset(s.query,-1) or 1)-1) end;s.index=1;s.scroll=0;invalidate(s);return true end
    if a.kind~='touch' then return true end
  end
  if a.kind=='touch' then
    for _,hit in ipairs(s.hits) do if hit.y==a.y and a.x>=hit.x and a.x<hit.x+hit.w then
      if hit.row then s.index=hit.row;s.details=true;s.detailScroll=0
      elseif hit.source then s.sourceIndex=hit.source;s.index=1;invalidate(s)
      elseif hit.id=='prev' or hit.id=='next' then local n=#sources(s);if n>0 then s.sourceIndex=(s.sourceIndex+(hit.id=='next' and 0 or -2))%n+1;s.index=1;invalidate(s) end
      else action(c,hit.id) end;return true end end
  elseif a.kind=='char' then
    if a.value:match('^[1-5]$') then action(c,tonumber(a.value))
    else local keys={r='refresh',s='sort',d='details',n='rename',e='empty',l='location'};if keys[a.value:lower()] then action(c,keys[a.value:lower()]) end end
  elseif a.kind=='up' or a.kind=='down' or a.kind=='scroll' then
    local delta=a.kind=='up' and -1 or a.kind=='down' and 1 or ((a.delta or 0)>0 and -1 or 1)
    if s.locations then local row=rows(s)[s.index];s.locationIndex=math.max(1,math.min((s.locationIndex or 1)+delta,row and row.locations and #row.locations or 1))
    elseif a.kind=='scroll' and s.details then s.detailScroll=math.max(0,s.detailScroll+delta)
    else s.index=math.max(1,math.min(s.index+delta,#rows(s)));s.detailScroll=0 end
  elseif a.kind=='left' or a.kind=='right' then local n=#sources(s);if n>0 then s.sourceIndex=(s.sourceIndex+(a.kind=='right' and 0 or -2))%n+1;s.index=1;invalidate(s) end
  elseif a.kind=='pageup' or a.kind=='pagedown' then s.detailScroll=math.max(0,s.detailScroll+(a.kind=='pageup' and -5 or 5))
  elseif a.kind=='enter' then action(c,'open')
  elseif a.kind=='back' then if s.details then s.details=false;return true end;return false
  end
  return true
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

package.preload["nexus.core.camera_config"] = function(...)
-- Isolated bounded non-executable camera preferences, atomic NEXUS persistence.
local M={path='/home/nexus/camera-v1.cfg'}
local function hex(s) return (s:gsub('.',function(c) return string.format('%02x',c:byte()) end)) end
local function unhex(s) if #s%2~=0 or s:find('[^%x]') then return nil end;return (s:gsub('..',function(c) return string.char(tonumber(c,16)) end)) end
function M.defaults() return {quality=1,zoom=1,palette=1,refresh=1,scale=2,grid=1,method='distance'} end
local limits={quality=3,zoom=3,palette=7,refresh=4,scale=4,grid=3}
function M.clean(p)
 local v=M.defaults();if type(p)~='table' then return v end
 for k,max in pairs(limits) do local n=p[k];if type(n)=='number' and n%1==0 and n>=1 and n<=max then v[k]=n end end
 if p.method=='distanceUp' or p.method=='distanceDown' then v.method=p.method end
 if type(p.name)=='string' and #p.name<=120 and p.name:match('%S') and utf8.len(p.name) then v.name=p.name:gsub('[%c]',' ') end
 return v
end
function M.encode(p)
 local lines={'NEXUS-CAMERA-1'}
 if type(p._selected)=='string' then lines[#lines+1]='selected='..hex(p._selected) end
 local keys={};for a,v in pairs(p) do if type(v)=='table' then keys[#keys+1]=a end end;table.sort(keys)
 for _,a in ipairs(keys) do local v=M.clean(p[a]);local row={hex(a),hex(v.name or '')}
  for _,k in ipairs({'quality','zoom','palette','refresh','scale','grid'}) do row[#row+1]=v[k] end
  row[#row+1]=v.method;lines[#lines+1]=table.concat(row,'|')
 end
 local data=table.concat(lines,'\n')..'\n';if #data>131072 then return nil,'Camera configuration exceeds 128 KiB' end;return data
end
function M.parse(data)
 if type(data)~='string' or #data>131072 or not data:match('^NEXUS%-CAMERA%-1\n') then return nil end
 local p={};p._selected=unhex(data:match('\nselected=(%x+)') or '')
 for a,name,q,z,pal,r,s,g,method in data:gmatch('([^\n|]+)|([^\n|]*)|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|([%a]+)\n') do
  a=unhex(a);name=unhex(name)
  if a and #a>0 and #a<=160 and not a:find('[%c]') and name then p[a]=M.clean({name=name,quality=tonumber(q),zoom=tonumber(z),palette=tonumber(pal),refresh=tonumber(r),scale=tonumber(s),grid=tonumber(g),method=method}) end
 end;return p
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


function M.load(store)
 if store then local ok,raw=pcall(store.read);return M.parse(ok and raw or nil) or {} end
 for _,path in ipairs({M.path,M.path..'.bak'}) do local f=io.open(path,'r');if f then local raw=f:read(131073);f:close();local p=M.parse(raw);if p then return p end end end
 return {}
end
function M.save(p,store)
 local data,why=M.encode(p);if not data then return false,why end
 local ok,a,b=pcall(store and store.write or writeDefault,data);if not ok then return false,tostring(a) end;return a,b
end
return M
end

package.preload["nexus.core.camera_device"] = function(...)
-- Computronics rangefinder adapter. Only verified read callbacks may be invoked.
local M={READ={distance=true,distanceUp=true,distanceDown=true}}
local function finite(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
M.finite=finite
function M.normalize(v)
  if finite(v) and (v>=0 or v==-1) then return v end
  return nil,'Invalid distance response (expected finite >=0 or -1)'
end
function M.new(component) return setmetatable({component=component,calls=0},{__index=M}) end
function M:discover()
  local result={}
  local ok,err=pcall(function()
    for address,kind in self.component.list('camera',true) do
      if type(address)=='string' and kind=='camera' then
        local methods,known={},false
        if type(self.component.methods)=='function' then
          local good,m=pcall(self.component.methods,address)
          if good and type(m)=='table' then known=true;for name in pairs(m) do if M.READ[name] then methods[name]=true end end end
        end
        if not known and type(self.component.proxy)=='function' then
          local good,p=pcall(self.component.proxy,address)
          if good and type(p)=='table' then known=true;for name in pairs(M.READ) do if type(p[name])=='function' then methods[name]=true end end end
        end
        -- Unknown metadata allows a protected attempt at the standard read only.
        if not known then methods.distance=true end
        result[#result+1]={address=address,methods=methods,capabilitiesKnown=known}
      end
    end
  end)
  table.sort(result,function(a,b) return a.address<b.address end)
  if not ok then return nil,'Camera discovery failed: '..tostring(err) end
  return result
end
function M:read(address,method,x,y)
  if not M.READ[method] then return nil,'Unsupported camera read method' end
  if not finite(x) or not finite(y) or math.abs(x)>1 or math.abs(y)>1 then return nil,'Ray directions must be finite within -1..1' end
  local c=self.component;local ok,a,b
  self.calls=self.calls+1
  if type(c.invoke)=='function' then ok,a,b=pcall(c.invoke,address,method,x,y)
  elseif type(c.proxy)=='function' then
    local good,p=pcall(c.proxy,address)
    if not good or type(p)~='table' or type(p[method])~='function' then return nil,'Camera method unavailable' end
    ok,a,b=pcall(p[method],x,y)
  else return nil,'Component invocation unavailable' end
  if not ok then return nil,tostring(a) end
  if a==nil then return nil,tostring(b or 'Camera returned no measurement') end
  return M.normalize(a)
end
return M
end

package.preload["nexus.core.camera_scan"] = function(...)
-- Cooperative bounded scheduler: <=6 ray callbacks/update, <=4 concurrent jobs.
local M={QUALITY={{name='LOW',w=13,h=7},{name='BALANCED',w=25,h=13},{name='HIGH',w=41,h=21}},THUMB={w=9,h=5},BUDGET=6,MAX_JOBS=4,MAX_CACHE=8}
function M.new(adapter,now,memory)
 return setmetatable({adapter=adapter,now=now or os.clock,memory=memory,devices={},order={},jobs={},cursor=0,revision=0,sampleCalls=0},{__index=M})
end
function M:discover(prefs)
 local all,err=self.adapter:discover();if not all then self:cancel();self.error=err;for _,c in pairs(self.devices) do c.stale=true;c.status='ERROR';c.error=err end;return false,err end
 self.error=nil
 for _,c in pairs(self.devices) do c.available=false end
 for _,d in ipairs(all) do
  local c=self.devices[d.address] or {address=d.address,status='IDLE',revision=0}
  c.available=true;c.methods=d.methods;c.capabilitiesKnown=d.capabilitiesKnown
  if c.status=='DISCONNECTED' then c.status='IDLE' end
  if not c.methods.distance then c.status='ERROR';c.error='distance method unavailable' end
  self.devices[d.address]=c
 end
 for address,p in pairs(prefs or {}) do if type(p)=='table' and not self.devices[address] then self.devices[address]={address=address,available=false,status='DISCONNECTED',methods={},revision=0} end end
 for _,c in pairs(self.devices) do if not c.available then self:remove(c.address) end end
 self.order={};for _,c in pairs(self.devices) do self.order[#self.order+1]=c end
 table.sort(self.order,function(a,b) return a.address<b.address end)
 self.revision=self.revision+1;return true
end
function M:remove(address)
 local c=self.devices[address];if not c then return end
 self:cancel(address);c.available=false;c.status='DISCONNECTED';c.stale=true;c.error='Camera disconnected';c.revision=c.revision+1;self.revision=self.revision+1
end
function M:start(address,p,thumbnail)
 local c=self.devices[address]
 if self.memory then local ok,n=pcall(self.memory);if ok and type(n)=='number' and n<16384 then return false,'Insufficient free memory for camera scan' end end
 if not c or not c.available then return false,'Camera unavailable; rediscover devices' end
 if c.work then return false,'Already scanning' end
 if #self.jobs>=M.MAX_JOBS then return false,'Four scans already active' end
 p=p or {};local method=p.method or 'distance'
 if not c.methods[method] then return false,'Requested callback unavailable' end
 local quality=M.QUALITY[p.quality or 1] or M.QUALITY[1]
 local q=thumbnail and M.THUMB or quality;local zoom=({1,0.5,0.25})[p.zoom or 1] or 1
 local good,job=pcall(function() return {address=address,w=q.w,h=q.h,total=q.w*q.h,samples={},done=0,valid=0,nohit=0,errors=0,started=self.now(),zoom=zoom,method=method,thumbnail=thumbnail==true,quality=quality.name} end)
 if not good then c.error='Insufficient memory for scan';c.status='ERROR';return false,c.error end
 c.partial=nil;c.work=job;c.stale=c.snapshot~=nil;c.error=nil;c.status='SCANNING';c.revision=c.revision+1;self.jobs[#self.jobs+1]=job;return true
end
function M:cancel(address)
 for i=#self.jobs,1,-1 do local j=self.jobs[i];if not address or j.address==address then
  local c=self.devices[j.address];c.partial=j.done>0 and j or nil;c.work=nil;c.status='CANCELLED';c.stale=true;c.revision=c.revision+1;table.remove(self.jobs,i)
 end end
 self:trim()
end
function M:trim()
 local cached={};for _,c in pairs(self.devices) do if c.snapshot then cached[#cached+1]=c end end
 table.sort(cached,function(a,b) if a.snapshot.finished==b.snapshot.finished then return a.address<b.address end;return a.snapshot.finished<b.snapshot.finished end)
 for i=1,#cached-M.MAX_CACHE do local c=cached[i];c.snapshot=nil;c.revision=c.revision+1;if not c.work then c.status=c.available and 'IDLE' or 'DISCONNECTED' end end
 -- Cancelled/failed partials count against the same cache bound.
 local partials={};for _,c in pairs(self.devices) do if c.partial then partials[#partials+1]=c end end
 table.sort(partials,function(a,b) return a.partial.started<b.partial.started end)
 for i=1,#partials-M.MAX_CACHE do partials[i].partial=nil end
end
function M:step(selected)
 if #self.jobs==0 then return false end
 for n=1,M.BUDGET do
  if #self.jobs==0 then break end
  local index
  if n%2==1 then for i,j in ipairs(self.jobs) do if j.address==selected then index=i;break end end end
  if not index then self.cursor=self.cursor%#self.jobs+1;index=self.cursor end
  local j=self.jobs[index];local c=self.devices[j.address]
  local k=j.done;local col=k%j.w;local row=math.floor(k/j.w)
  -- canonical ray coordinates: left -x, right +x, top +y, bottom -y.
  local x=(-1+2*col/(j.w-1))*j.zoom;local y=(1-2*row/(j.h-1))*j.zoom
  local value,err=self.adapter:read(j.address,j.method,x,y);self.sampleCalls=self.sampleCalls+1
  j.done=j.done+1
  if value==nil then j.samples[j.done]=false;j.errors=j.errors+1;j.lastError=err;c.error=err
  else j.samples[j.done]=value;j.valid=j.valid+1;if value==-1 then j.nohit=j.nohit+1 end end
  if col==math.floor(j.w/2) and row==math.floor(j.h/2) then j.center=value;j.centerError=err end
  c.revision=c.revision+1
  -- Stop an inaccessible device after a bounded consecutive failure threshold.
  j.consecutive=value==nil and (j.consecutive or 0)+1 or 0
  if j.consecutive>=3 then
   c.partial=j;c.work=nil;c.status=j.valid>0 and 'PARTIAL' or 'ERROR';c.stale=true;table.remove(self.jobs,index)
  elseif j.done==j.total then
   j.finished=self.now();j.elapsed=j.finished-j.started;c.snapshot=j;c.partial=nil;c.work=nil;c.stale=false
   c.nextScan=j.finished+(c.refreshDelay or 0);c.status=j.errors>0 and 'PARTIAL' or 'READY';if j.errors==0 then c.lastSuccess=j.finished end
   table.remove(self.jobs,index)
  end
 end
 self:trim();self.revision=self.revision+1;return true
end
function M:image(c) return c and (c.work or c.partial or c.snapshot) end
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
    self:print('run invokes an available OpenOS shell (not sandboxed).')
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
  local mt=type(iter)=='table' and getmetatable(iter) or nil
  local callable=type(iter)=='function' or (type(mt)=='table' and type(mt.__call)=='function')
  if not ok or not callable then return result,'Unable to enumerate components (invalid iterator)' end
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
  local ok,result=pcall(self.gpu.setResolution,pending.oldW,pending.oldH)
  local read,w,h=pcall(self.gpu.getResolution)
  if not ok or result==false or not read or w~=pending.oldW or h~=pending.oldH then
    return false,'GPU could not restore previous resolution'
  end
  self.pending=nil
  return true
end
function M:tick()
  if self.pending and self.clock()>=self.pending.deadline then
    return self:rollback()
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
  -- Two clipped rectangular operations preserve the side glyphs at any height.
  self:colors(fg,bg)
  self:fill(x,y+1,1,h-2,bg,"|")
  self:fill(x+w-1,y+1,1,h-2,bg,"|")
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
    local mt=type(iterator)=='table' and getmetatable(iterator) or nil
    if ok and (type(iterator)=='function' or (type(mt)=='table' and type(mt.__call)=='function')) then
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

package.preload["nexus.core.sha256"] = function(...)
-- Pure Lua 5.3 streaming SHA-256 for OpenComputers (no Data Card required).
-- Only stores one 64-byte compression block and a bounded read buffer.
local M={}
local MASK=0xffffffff
local K={
  0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
  0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
  0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
  0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
  0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
  0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
  0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
  0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
}
local H0={0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19}
local function ror(x,n) return ((x>>n)|(x<<(32-n))) & MASK end
local function hashBlock(h,block)
  local w={}
  for i=1,16 do
    local a,b,c,d=block:byte(i*4-3,i*4)
    w[i]=((a<<24)|(b<<16)|(c<<8)|d)&MASK
  end
  for i=17,64 do
    local x,y=w[i-15],w[i-2]
    local s0=ror(x,7)~ror(x,18)~(x>>3)
    local s1=ror(y,17)~ror(y,19)~(y>>10)
    w[i]=(w[i-16]+s0+w[i-7]+s1)&MASK
  end
  local a,b,c,d,e,f,g,z=table.unpack(h)
  for i=1,64 do
    local s1=ror(e,6)~ror(e,11)~ror(e,25)
    local ch=(e&f)~((~e)&g)
    local t1=(z+s1+ch+K[i]+w[i])&MASK
    local s0=ror(a,2)~ror(a,13)~ror(a,22)
    local maj=(a&b)~(a&c)~(b&c)
    local t2=(s0+maj)&MASK
    z,g,f,e,d,c,b,a=g,f,e,(d+t1)&MASK,c,b,a,(t1+t2)&MASK
  end
  local values={a,b,c,d,e,f,g,z}
  for i=1,8 do h[i]=(h[i]+values[i])&MASK end
end
local function new()
  local h={table.unpack(H0)}
  local tail=''
  local size=0
  local blocks=0
  local obj={}
  function obj:update(chunk)
    assert(type(chunk)=='string','SHA-256 input must be a string')
    size=size+#chunk
    local data=tail..chunk
    local index=1
    while index+63<=#data do
      hashBlock(h,data:sub(index,index+63))
      index=index+64
      blocks=blocks+1
      -- Yield to OpenComputers occasionally during lengthy verification.
      if blocks%128==0 and type(os.sleep)=='function' then pcall(os.sleep,0) end
    end
    tail=data:sub(index)
  end
  function obj:finish()
    assert(size < 0x20000000,'SHA-256 input too large for NEXUS updater')
    local bitlen=size*8
    local padding='\128'..string.rep('\0',(56-(size+1)%64)%64)
    local high=math.floor(bitlen/4294967296)
    local low=bitlen%4294967296
    local function be32(x)
      return string.char((x>>24)&255,(x>>16)&255,(x>>8)&255,x&255)
    end
    local data=tail..padding..be32(high)..be32(low)
    for index=1,#data,64 do hashBlock(h,data:sub(index,index+63)) end
    return string.format('%08x%08x%08x%08x%08x%08x%08x%08x',table.unpack(h))
  end
  return obj
end
M.new=new
function M.sum(input)
  local h=new();h:update(input);return h:finish()
end
function M.file(path,open,limit)
  local f,reason=(open or io.open)(path,'rb')
  if not f then return nil,'Cannot open SHA file: '..tostring(reason) end
  local h=new();local bytes=0
  local ok,result=pcall(function()
    while true do
      local chunk=f:read(4096)
      if not chunk or chunk=='' then break end
      bytes=bytes+#chunk
      if limit and bytes>limit then error('File exceeds SHA size limit') end
      h:update(chunk)
    end
    return h:finish()
  end)
  pcall(function()f:close()end)
  if not ok then return nil,tostring(result) end
  return result,bytes
end
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
-- NEXUS updates: verified GitHub Raw releases and legacy Pastebin; safe backup/rollback.
-- Never execute downloaded code during staging. Only trusted user-supplied IDs.
local M={}
M.CORE='/home/osv4.lua'
M.BACKUP='/home/nexus/updates/previous.lua'
M.TEMP='/home/nexus/updates/download.part'
M.STAGED='/home/nexus/updates/staged.lua'
M.META='/home/nexus/updates/staged.meta'
M.TXN='/home/nexus/updates/transaction'
M.VERSION='0.6.5'
M.GITHUB_MANIFEST='/home/nexus/updates/github-manifest.part'
M.GITHUB_URL='https://raw.githubusercontent.com/truemisk/NEXUS_OS/main/update.nxs'
M.GITHUB_RELEASE='https://raw.githubusercontent.com/truemisk/NEXUS_OS/main/dist/nexus.lua'
M.MANIFEST_LIMIT=2048
M.MAX_BYTES=300000
local SHA=require('nexus.core.sha256')
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
    limit=opts.limit or M.MAX_BYTES,
    -- Prefer OpenOS's proven pastebin client when no test fetch is injected.
    shellExecute=opts.shellExecute or (opts.fetch==nil and os and os.execute)},{__index=M})
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
-- A trial update is considered ready only after the new desktop has rendered.
-- Do not silently accept a different or corrupted active release.
function M:acknowledgeRunning()
  if not self.fs.exists(M.TXN) then return false,'No trial transaction' end
  local marker=self.read(M.TXN,128)
  local target=type(marker)=='string' and marker:match('^trial=(%d+%.%d+%.%d+)')
  if target~=self.version then return false,'Trial version does not match running OS' end
  local ver,why=self:validate(self.current,true)
  if ver~=self.version then return false,'Active release could not be verified: '..tostring(why or ver) end
  local ok,err=self:finish()
  if not ok then return false,'Cannot finalize trial: '..tostring(err) end
  return true
end
-- Run the same OpenOS Pastebin command that works from the user's terminal.
-- The ID has already been validated as strictly alphanumeric. The returned
-- file must still pass all NEXUS header, size, version and syntax checks.
function M:fetchShell(id)
  if type(self.shellExecute)~='function' then return false,'OpenOS shell unavailable' end
  pcall(self.fs.remove,M.TEMP)
  local cmd='pastebin get '..id..' '..M.TEMP
  local launched,a,b=pcall(self.shellExecute,cmd)
  if not launched then return false,'Pastebin command crashed: '..tostring(a):sub(1,100) end
  if not self.fs.exists(M.TEMP) then
    return false,'OpenOS pastebin did not save a file: '..tostring(b or a):sub(1,85)
  end
  local bytes=self.fs.size(M.TEMP)
  if type(bytes)~='number' or bytes<100 or bytes>self.limit then
    pcall(self.fs.remove,M.TEMP)
    return false,'Pastebin file size invalid: '..tostring(bytes)
  end
  return true,bytes
end
-- Streaming fallback for systems without the OpenOS pastebin command.
-- Keep iterator handling compatible with function and callable-table results.
function M:fetchInternet(id)
  local request=self.fetch
  if not request then
    local found,internet=pcall(require,'internet')
    if not found or type(internet.request)~='function' then return false,'Internet Card / API unavailable' end
    request=internet.request
  end
  local started,iter,reason=pcall(request,'https://pastebin.com/raw/'..id)
  if not started then return false,'Internet request: '..tostring(iter):sub(1,95) end
  local kind=type(iter)
  local mt=kind=='table' and getmetatable(iter) or nil
  local callable=kind=='function' or (kind=='table' and type(mt)=='table' and type(mt.__call)=='function')
  if not callable then
    if kind=='table' then return false,'Internet API returned a non-callable table' end
    return false,'HTTP iterator unavailable: '..(type(reason)=='string' and reason:sub(1,85) or kind)
  end
  pcall(self.fs.remove,M.TEMP)
  local f,err=self.open(M.TEMP,'wb')
  if not f then return false,'Staging file: '..tostring(err) end
  local bytes=0
  local transferred,problem=pcall(function()
    for block in iter do
      if type(block)~='string' then error('Invalid HTTP chunk') end
      bytes=bytes+#block
      if bytes>self.limit then error('Update too large') end
      assert(f:write(block))
    end
    assert(f:flush())
  end)
  pcall(function() f:close() end)
  if not transferred or bytes<100 then
    pcall(self.fs.remove,M.TEMP)
    return false,transferred and 'Empty/short HTTP response' or tostring(problem):sub(1,95)
  end
  return true,bytes
end
-- GitHub manifest is a small, strict key/value file. Remote URLs are pinned to
-- this project's exact Raw download path to avoid redirects to foreign hosts.
function M:parseGitHubManifest(content)
  if type(content)~='string' or #content>M.MANIFEST_LIMIT then return nil,'Manifest missing or too large' end
  local fields={}
  for line in (content..'\n'):gmatch('(.-)\n') do
    line=line:gsub('\r$','')
    if line~='' and not line:match('^#') then
      local key,value=line:match('^([a-z0-9_]+)=([^\r\n]+)$')
      if not key or fields[key] then return nil,'Malformed or duplicate manifest field' end
      if not ({channel=true,version=true,url=true,sha256=true,size=true})[key] then
        return nil,'Unknown manifest field: '..key
      end
      fields[key]=value
    end
  end
  if fields.channel~='stable' then return nil,'Non-stable update channel' end
  if not numbers(fields.version) then return nil,'Invalid manifest version' end
  if fields.url~=M.GITHUB_RELEASE then return nil,'Untrusted GitHub download URL' end
  if type(fields.sha256)~='string' or #fields.sha256~=64 or not fields.sha256:match('^[0-9a-f]+$') then
    return nil,'Invalid SHA-256 checksum'
  end
  local size=tonumber(fields.size)
  if not size or size%1~=0 or size<100 or size>self.limit then return nil,'Invalid release size in manifest' end
  fields.size=size
  return fields
end
-- Prefer the OpenOS wget command proven on the user's Minecraft machine.
-- For unsupported shells, use the bounded OpenComputers internet iterator.
function M:fetchURL(url,path,limit)
  limit=limit or self.limit
  if url~=M.GITHUB_URL and url~=M.GITHUB_RELEASE then return false,'Untrusted download URL' end
  pcall(self.fs.remove,path)
  local shellError
  if type(self.shellExecute)=='function' then
    local launched,a,b=pcall(self.shellExecute,'wget "'..url..'" '..path)
    if launched and self.fs.exists(path) then
      local count=self.fs.size(path)
      if type(count)=='number' and count>0 and count<=limit then return true,count end
      shellError='wget response size invalid: '..tostring(count)
    else shellError='wget did not save file: '..tostring(launched and (b or a) or a):sub(1,80) end
    pcall(self.fs.remove,path)
  end
  local request=self.fetch
  if not request then
    local found,internet=pcall(require,'internet')
    if not found or type(internet.request)~='function' then
      return false,(shellError or 'Network unavailable')..' / Internet Card unavailable'
    end
    request=internet.request
  end
  local started,iter,reason=pcall(request,url)
  if not started then return false,(shellError or '')..' / '..tostring(iter):sub(1,100) end
  local kind=type(iter)
  local mt=kind=='table' and getmetatable(iter) or nil
  if kind~='function' and not (kind=='table' and type(mt)=='table' and type(mt.__call)=='function') then
    return false,(shellError or '')..' / HTTP iterator missing: '..tostring(reason or kind):sub(1,90)
  end
  local f,err=self.open(path,'wb')
  if not f then return false,'Cannot open download: '..tostring(err) end
  local count=0
  local transferred,problem=pcall(function()
    for block in iter do
      if type(block)~='string' then error('Invalid HTTP chunk') end
      count=count+#block
      if count>limit then error('Download exceeds size limit') end
      assert(f:write(block))
    end
    assert(f:flush())
  end)
  pcall(function() f:close() end)
  if not transferred or count==0 then
    pcall(self.fs.remove,path)
    return false,transferred and 'Empty response' or tostring(problem):sub(1,100)
  end
  return true,count
end
function M:checkGitHub()
  local ok,reason=self:ensure()
  if not ok then return false,reason end
  local downloaded,err=self:fetchURL(M.GITHUB_URL,M.GITHUB_MANIFEST,M.MANIFEST_LIMIT)
  if not downloaded then return false,err end
  local content=self.read(M.GITHUB_MANIFEST,M.MANIFEST_LIMIT+1)
  pcall(self.fs.remove,M.GITHUB_MANIFEST)
  local manifest,why=self:parseGitHubManifest(content)
  if not manifest then return false,why end
  local a,b=numbers(manifest.version),numbers(self.version)
  manifest.newer=false
  for i=1,3 do
    if a[i]~=b[i] then manifest.newer=a[i]>b[i];break end
  end
  return true,manifest
end
function M:verifyGitHubFile(path,manifest)
  local size=self.fs.size(path)
  if type(size)~='number' or size~=manifest.size then return false,'GitHub file size mismatch' end
  local digest,reason=SHA.file(path,self.open,self.limit)
  if not digest then return false,'SHA-256 failed: '..tostring(reason) end
  if digest~=manifest.sha256 then return false,'SHA-256 mismatch: download does not match manifest' end
  local ver,why=self:validate(path)
  if not ver then return false,why end
  if ver~=manifest.version then return false,'Downloaded version differs from manifest' end
  return true
end
function M:stageGitHub(manifest)
  if self.fs.exists(M.TXN) then
    local accepted,reason=self:acknowledgeRunning()
    if not accepted then return false,'Pending update transaction: '..tostring(reason) end
  end
  -- Refetch the manifest before downloading so the installed candidate and
  -- its hash always refer to the same release metadata.
  local ok,latest=self:checkGitHub()
  if not ok then return false,latest end
  if not latest.newer then return false,'GitHub has no newer stable version' end
  if manifest and manifest.version~=latest.version then
    return false,'GitHub version changed; check updates again'
  end
  local downloaded,bytes=self:fetchURL(M.GITHUB_RELEASE,M.TEMP,self.limit)
  if not downloaded then return false,bytes end
  local verified,reason=self:verifyGitHubFile(M.TEMP,latest)
  if not verified then pcall(self.fs.remove,M.TEMP);return false,reason end
  -- Existing staged data remains intact if downloading or verification fails.
  local previous=M.STAGED..'.old'
  pcall(self.fs.remove,previous)
  if self.fs.exists(M.STAGED) then
    local moved,why=self.fs.rename(M.STAGED,previous)
    if not moved then pcall(self.fs.remove,M.TEMP);return false,'Cannot preserve old staged file: '..tostring(why) end
  end
  local placed,why=self.fs.rename(M.TEMP,M.STAGED)
  if not placed then
    if self.fs.exists(previous) then self.fs.rename(previous,M.STAGED) end
    return false,'Cannot stage GitHub release: '..tostring(why)
  end
  local meta='source=github\nversion='..latest.version..'\nsize='..latest.size..'\nsha256='..latest.sha256..'\n'
  local saved,saveError=self.write(M.META,meta)
  if not saved then
    pcall(self.fs.remove,M.STAGED)
    if self.fs.exists(previous) then self.fs.rename(previous,M.STAGED) end
    return false,'Cannot save checksum metadata: '..tostring(saveError)
  end
  pcall(self.fs.remove,previous)
  return true,latest.version,bytes
end
function M:stagedSource()
  local m=self.read(M.META,256)
  if not self.fs.exists(M.STAGED) then return 'none' end
  if m and m:find('^source=github\n') then return 'github-sha256' end
  return 'manual/legacy'
end
function M:stage(id)
  if type(id)~='string' or not id:match('^[%w]+$') or #id<6 or #id>16 then
    return false,'Pastebin ID must be 6-16 letters/digits'
  end
  local ok,why=self:ensure();if not ok then return false,why end
  if self.fs.exists(M.TXN) then
    local accepted,reason=self:acknowledgeRunning()
    if not accepted then return false,'Pending update transaction: '..tostring(reason) end
  end
  local success,bytesOrError,otherError
  if type(self.shellExecute)=='function' then
    success,bytesOrError=self:fetchShell(id)
    if not success then otherError='OpenOS pastebin: '..tostring(bytesOrError) end
  end
  if not success then
    success,bytesOrError=self:fetchInternet(id)
    if not success then
      return false,(otherError and (otherError..' / ') or '')..tostring(bytesOrError)
    end
  end
  local bytes=bytesOrError
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
  local meta=self.read(M.META,256)
  if meta and meta:find('^source=github\n') then
    local v=meta:match('\nversion=([^\n]+)')
    local digest=meta:match('\nsha256=([0-9a-f]+)')
    local size=tonumber(meta:match('\nsize=(%d+)'))
    if v~=ver or not digest or #digest~=64 or not size then
      return false,'GitHub checksum metadata invalid'
    end
    local calculated,whySHA=SHA.file(M.STAGED,self.open,self.limit)
    if not calculated then return false,'GitHub checksum read failed: '..tostring(whySHA) end
    if calculated~=digest or self.fs.size(M.STAGED)~=size then
      return false,'GitHub candidate changed since download (SHA-256 mismatch)'
    end
  end
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

package.preload["nexus.core.vault"] = function(...)
-- Read-only inventory controller. No hardware mutation callbacks are reachable.
local M={SIDES={'DOWN','UP','NORTH','SOUTH','WEST','EAST'}}
local function number(v) if type(v)=='number' and v==v and v>=0 and v<math.huge and v%1==0 then return v end end
local function str(v) if type(v)=='string' and v:match('%S') then
  local out={};for _,c in utf8.codes((utf8.len(v) and v or v:gsub('[\128-\255]','?'))) do out[#out+1]=utf8.char(c) end
  return table.concat(out):gsub('[%c]',' ')
end end
M.text=str
function M.normalize(raw,id,slot,count)
  raw=type(raw)=='table' and raw or {}
  local item={source=id,slot=slot,name=str(raw.name),label=str(raw.label),size=number(raw.size) or number(count),
    maxSize=number(raw.maxSize),damage=number(raw.damage),maxDamage=number(raw.maxDamage),hasTag=type(raw.hasTag)=='boolean' and raw.hasTag or nil}
  if raw.hasTag==false then item.hasTag=false end
  item.display=item.label or item.name or 'Unknown item'
  -- Unknown tags/damage/registry: retain source+slot, never guess equivalence.
  item.identity=(item.name and item.damage and item.hasTag==false) and
    (item.name..'|'..item.damage..'|'..tostring(item.maxDamage)..'|'..tostring(item.maxSize)) or (id..'#'..slot)
  return item
end
function M.new(component,now)
  return setmetatable({component=component,now=now or os.clock,sources={},transposers={},state='IDLE',revision=0,calls=0,done=0,errors={}}, {__index=M})
end
local READ={getInventorySize=true,getInventoryName=true,getStackInSlot=true,getSlotStackSize=true}
function M:call(address,method,...)
  if not READ[method] then return nil,'Read-only Vault callback denied' end
  self.calls=self.calls+1
  local c=self.component
  local ok,a,b
  if type(c.invoke)=='function' then ok,a,b=pcall(c.invoke,address,method,...)
  else
    local good,p=pcall(c.proxy,address)
    if not good or type(p)~='table' or type(p[method])~='function' then return nil,'Unsupported '..method end
    ok,a,b=pcall(p[method],...)
  end
  if not ok then return nil,tostring(a) end
  return a,b
end
function M:start(only)
  if self.worker then self:cancel() end
  self.state='DISCOVERING';self.done=0;self.errors={};self.started=self.now();self.calls=0
  self.worker=coroutine.create(function()
    local list={}
    local ok,why=pcall(function() for address,kind in self.component.list('transposer',true) do
      if kind=='transposer' and type(address)=='string' then list[#list+1]=address end
    end end)
    if not ok then error('Discovery failed: '..tostring(why)) end
    table.sort(list);self.discoveryDuration=self.now()-self.started;self.transposers={}
    local connected={};for _,a in ipairs(list) do connected[a]=true;self.transposers[#self.transposers+1]={address=a,status='SCANNING',available=true,sides={},errors={}} end
    for _,s in pairs(self.sources) do if not only or only==s.id then s.stale=true;s.status=connected[s.address] and 'SCANNING' or 'DISCONNECTED' end end
    coroutine.yield()
    self.state='SCANNING'
    for _,device in ipairs(self.transposers) do
      local address=device.address
      for side=0,5 do
        local id='vault://'..address..'/'..side
        if not only or only==id then
          local size,err=self:call(address,'getInventorySize',side)
          coroutine.yield()
          if number(size) and size>0 and size<=65536 then
            local s=self.sources[id] or {id=id,address=address,side=side};self.sources[id]=s
            s.status='SCANNING';s.stale=true;s.total=size;s.error=nil;device.sides[#device.sides+1]=side
            s.type=str(self:call(address,'getInventoryName',side));coroutine.yield()
            local items,empty,occupied,unknown={},0,0,0
            for slot=1,size do
              local raw,whyStack=self:call(address,'getStackInSlot',side,slot)
              coroutine.yield()
              if type(raw)=='table' and number(raw.size) and raw.size>0 then
                items[#items+1]=M.normalize(raw,id,slot);occupied=occupied+1
              else
                local count,whyCount=self:call(address,'getSlotStackSize',side,slot);coroutine.yield()
                if number(count) and count==0 then empty=empty+1
                elseif number(count) and count>0 then items[#items+1]=M.normalize(raw,id,slot,count);occupied=occupied+1
                else unknown=unknown+1;s.error=tostring(whyStack or whyCount or 'Contents unavailable') end
              end
              self.done=self.done+1
            end
            s.items=items;s.empty=empty;s.occupied=occupied;s.unknown=unknown;s.stale=false
            s.status=unknown>0 and 'PARTIAL' or 'ONLINE';s.scanned=self.now()
            if unknown>0 then device.errors[#device.errors+1]=id..': '..tostring(s.error) end
            if unknown==0 then s.lastSuccess=s.scanned end
          elseif size==nil and (err==nil or tostring(err):lower():find('no inventory',1,true)) then
            if self.sources[id] then self.sources[id].status='UNAVAILABLE' end
          else
            device.errors[#device.errors+1]=tostring(err or 'Invalid inventory size')
            self.errors[#self.errors+1]=address..' / '..M.SIDES[side+1]..': '..tostring(err or 'Invalid inventory size')
            if self.sources[id] then self.sources[id].status='ERROR';self.sources[id].error=tostring(err) end
          end
        end
      end
      device.status=#device.errors>0 and 'PARTIAL' or 'READY';device.lastScan=self.now();if device.status=='READY' then device.lastSuccess=device.lastScan end
    end
    self.state=#self.errors>0 and 'PARTIAL' or 'READY'
    for _,s in pairs(self.sources) do if s.stale or s.status~='ONLINE' then self.state='PARTIAL' end end
    self.finished=self.now();self.duration=self.finished-self.started;self.revision=self.revision+1
  end)
end
function M:step(budget)
  if not self.worker then return false end
  for _=1,budget or 8 do
    local ok,err=coroutine.resume(self.worker)
    if not ok then self.state='ERROR';self.errors[#self.errors+1]=tostring(err);self.worker=nil;self.revision=self.revision+1;return true end
    if coroutine.status(self.worker)=='dead' then self.worker=nil;return true end
  end
  return true
end
function M:cancel() self.worker=nil;self.state='CANCELLED';self.revision=self.revision+1 end
function M:sourcesList(prefs,sort,filter)
  local rows={};for _,s in pairs(self.sources) do if not filter or s.status=='ONLINE' then rows[#rows+1]=s end end
  local function value(s)
    return sort=='type' and (s.type or '') or sort=='address' and s.address or sort=='side' and s.side or sort=='slots' and s.total or sort=='occupied' and s.occupied or sort=='status' and s.status or ((prefs[s.id] or {}).alias or s.id)
  end
  table.sort(rows,function(a,b) local x,y=value(a),value(b);x=x or 0;y=y or 0;if x==y then return a.id<b.id end;return x<y end);return rows
end
function M:catalog(prefs)
  local groups,rows={},{}
  for _,s in ipairs(self:sourcesList(prefs)) do
    if not s.stale and s.status=='ONLINE' or not s.stale and s.status=='PARTIAL' then
      if not (prefs[s.id] or {}).excluded then for _,item in ipairs(s.items or {}) do
        local g=groups[item.identity]
        if not g then g={display=item.display,name=item.name,identity=item.identity,size=0,known=true,locations={}};groups[item.identity]=g;rows[#rows+1]=g end
        if item.size then g.size=g.size+item.size else g.known=false end
        g.locations[#g.locations+1]=item
      end end
    end
  end
  return rows
end
function M:query(prefs,query,sort,source,empty)
  local rows={};query=(query or ''):lower()
  for _,s in ipairs(self:sourcesList(prefs)) do
    if not source or source==s.id then
      local slots={};for _,v in ipairs(s.items or {}) do slots[v.slot]=v end
      for slot=1,s.total or 0 do
        local v=slots[slot]
        if not v and empty then v={source=s.id,slot=slot,display=(s.stale or s.unknown~=0) and 'Unknown slot' or 'Empty slot'} end
        if v then
          local hay=table.concat({v.display,v.name or '',(prefs[s.id] or {}).alias or '',s.type or '',s.address},' '):lower()
          if hay:find(query,1,true) then rows[#rows+1]=v end
        end
      end
    end
  end
  M.sort(rows,sort,prefs);return rows
end
function M.sort(rows,mode,prefs)
  prefs=prefs or {}
  local function key(v)
    if mode=='quantity' or mode=='quantity-desc' then return v.size or -1 end
    if mode=='registry' then return v.name or '' end
    if mode=='chest' then return (prefs[v.source] or {}).alias or v.source or '' end
    if mode=='slot' then return v.slot or 0 end
    return v.display:lower()
  end
  table.sort(rows,function(a,b)
    local x,y=key(a),key(b)
    if x~=y then if mode=='quantity-desc' or mode=='name-desc' then return x>y end;return x<y end
    return (a.name or '')..'|'..(a.source or a.identity or '')..string.format('%08d',a.slot or 0)<(b.name or '')..'|'..(b.source or b.identity or '')..string.format('%08d',b.slot or 0)
  end)
end
return M
end

package.preload["nexus.core.vault_config"] = function(...)
-- Separate, non-executable Vault preferences; uses NEXUS atomic temp/backup pattern.
local M={path='/home/nexus/vault-v1.cfg'}
local function hex(s) return (s:gsub('.',function(c) return string.format('%02x',c:byte()) end)) end
local function unhex(s) if #s%2~=0 or s:find('[^%x]') then return nil end;return (s:gsub('..',function(c) return string.char(tonumber(c,16)) end)) end
function M.parse(raw)
  local p={};if type(raw)~='string' or #raw>131072 then return p end
  p._sort=tonumber(raw:match('sort=(%d+)'))
  for id,alias,excluded in raw:gmatch('([^\n ]+) ([^\n ]*) ([01])\n') do
    id=unhex(id);alias=unhex(alias)
    if id and id:match('^vault://[^/%c]+/[0-5]$') and alias and #alias<=160 then p[id]={alias=alias~='' and alias or nil,excluded=excluded=='1'} end
  end;return p
end
function M.encode(p)
  local rows={'sort='..tostring(p._sort or 1)};for id,v in pairs(p) do if type(v)=='table' then rows[#rows+1]=hex(id)..' '..hex(v.alias or '')..' '..(v.excluded and '1' or '0') end end
  table.sort(rows);return table.concat(rows,'\n')..'\n'
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

function M.load()
  for _,path in ipairs({M.path,M.path..'.bak'}) do local f=io.open(path,'r');if f then local raw=f:read(131073);f:close();return M.parse(raw) end end
  return {}
end
function M.save(p) local ok,a,b=pcall(writeDefault,M.encode(p));if not ok then return false,tostring(a) end;return a,b end
return M
end

package.preload["nexus.main"] = function(...)
-- NEXUS OS v0.6.5 | Phase 5B | one foreground app, no boot modifications.
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
local Vault=require('nexus.apps.vault')
local Camera=require('nexus.apps.camera')
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
  manager:register(Vault)
  manager:register(Camera)
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
  logger:log('INFO','core','NEXUS v0.6.5 launched')
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
        local reverted,why=display:rollback();ctx.notify(reverted and 'Resolution reverted' or why,reverted and 'warn' or 'error')
      elseif kind=='touch' then
        -- Only explicit preview controls may accept a resolution.
        for _,hit in ipairs(state.previewButtons or {}) do
          if action.x>=hit.x and action.x<hit.x+hit.w and action.y==hit.y then
            if hit.id=='keep' then display:confirm();ctx.notify('Resolution confirmed (session only)','info')
            else local reverted,why=display:rollback();ctx.notify(reverted and 'Resolution reverted' or why,reverted and 'warn' or 'error') end
            state.dirty=true;return
          end
        end
        for _,hit in ipairs(state.navboxes or {}) do
          if hit.id=='back' and action.x>=hit.x and action.x<hit.x+hit.w and action.y==hit.y then
            local reverted,why=display:rollback();ctx.notify(reverted and 'Resolution reverted' or why,reverted and 'warn' or 'error');break
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
    local readyAcknowledged=false
    if type(term.setCursorBlink)=='function' then pcall(term.setCursorBlink,false) end
    if config.data.splash then
      local w,h=gfx:size()
      gfx:fill(1,1,w,h,ctx.theme.bg)
      gfx:center(math.max(2,math.floor(h/2)),'NEXUS OS / v0.6.5',ctx.theme.accent,ctx.theme.bg)
      -- Pull once; forward this event to dispatch so no input is dropped.
      local e,a,b,c,d=event.pull(0.2)
      dispatch(Input.decode(e,a,b,c,hardware,keys,d))
    end
    while state.running do
      if state.dirty then redraw() end
      -- Only clear an update transaction after the new GUI actually renders.
      -- This permits another Update Center download during the same session.
      if not readyAcknowledged and state.redraws>0 then
        readyAcknowledged=true
        if type(updater.acknowledgeRunning)=='function' then
          local accepted,reason=updater:acknowledgeRunning()
          if accepted then logger:log('INFO','update','Running release verified; trial finalized')
          elseif updater.fs and updater.fs.exists and updater.fs.exists(Updater.TXN) then
            logger:log('WARN','update','Trial not finalized: '..tostring(reason)) end
        end
      end
      local e,a,b,c,d=event.pull(0.5)
      if hwEvents:push(computer.uptime(),e,a,b,c,d) then
        if manager.active and manager.active.id=='hardwarecenter' then state.dirty=true end
      end
      if manager.active and manager.active.id=='camera' and (e=='component_added' or e=='component_removed') then Camera.hardwareEvent(ctx,e,a,b);state.dirty=true end
      dispatch(Input.decode(e,a,b,c,hardware,keys,d))
      local changed,appError=manager:tick(ctx)
      if appError then recovery:report('app.tick',appError);session:home();ctx.notify('App update: '..tostring(appError),'error')
      elseif changed then state.dirty=true end
      local now=computer.uptime()
      local reverted,restoreError=display:tick()
      if reverted then ctx.notify('Resolution preview timed out; reverted','warn')
      elseif restoreError and restoreError~=state.displayError then
        state.displayError=restoreError;ctx.notify(restoreError,'error')
      end
      if not display.pending then state.displayError=nil end
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

package.preload["nexus.ui.camera_depth"] = function(...)
-- Depth-only renderer. No component calls; color runs and unchanged-row caching.
local M={PALETTES={'THEME DEPTH','CYAN DEPTH','MONOCHROME','GREEN DEPTH','AMBER DEPTH','FALSE COLOR DEPTH','ASCII'},SCALES={16,32,64,128}}
local ramps={cyan={0x003030,0x004040,0x005050,0x006060,0x007070,0x008888,0x009999,0x00AAAA,0x00BBBB,0x33CCCC,0x66DDDD,0xAAFFFF},
 green={0x002000,0x003000,0x004000,0x005500,0x006600,0x007700,0x008800,0x009900,0x00BB00,0x33CC33,0x66DD66,0xAAFFAA},
 amber={0x302000,0x403000,0x504000,0x605000,0x706000,0x887000,0x998000,0xAA8800,0xBB9900,0xCCAA33,0xDDBB66,0xFFDD99},
 mono={0x181818,0x282828,0x383838,0x484848,0x585858,0x686868,0x808080,0x989898,0xB0B0B0,0xC8C8C8,0xE0E0E0,0xFFFFFF},
 falsecolor={0x001040,0x002080,0x0033BB,0x0055CC,0x0088CC,0x00AAAA,0x00AA55,0x44BB00,0xAAAA00,0xDD9900,0xEE5500,0xFF2200}}
function M.bucket(v,scale)
 if v==nil then return -2 end;if v==false then return -3 end;if v==-1 then return 0 end
 if type(v)~='number' or v~=v or v<0 or v==math.huge then return -3 end
 scale=type(scale)=='number' and scale>0 and scale or 32
 return math.max(1,math.min(12,12-math.floor(math.min(1,v/scale)*11)))
end
function M.ramp(palette,theme)
 if palette==1 then return ramps[theme] or ramps.mono end
 return ramps[({[2]='cyan',[3]='mono',[4]='green',[5]='amber',[6]='falsecolor',[7]='mono'})[palette]] or ramps.cyan
end
function M.draw(g,t,rect,image,p,cache)
 cache=cache or {};p=p or {};local palette=p.palette or 1;local ramp=M.ramp(palette,t.name);local scale=M.SCALES[p.scale or 2] or 32
 -- A frontal square cone fits a 2:1 character rectangle (terminal cells ~1:2).
 local height=math.min(rect.h,math.floor(rect.w/2));local width=height*2
 local x0=rect.x+math.floor((rect.w-width)/2);local y0=rect.y+math.floor((rect.h-height)/2)
 local shape=table.concat({rect.x,rect.y,rect.w,rect.h,palette,scale,t.name or ''},':')
 if cache.shape~=shape then g:fill(rect.x,rect.y,rect.w,rect.h,t.bg);cache.shape=shape;cache.rows={} end
 local codes={}
 for y=1,height do
  local row={};local iy=image and math.min(image.h,math.floor((y-1)*image.h/height)+1)
  for x=1,width do
   local ix=image and math.min(image.w,math.floor((x-1)*image.w/width)+1)
   local value=image and image.samples[(iy-1)*image.w+ix]
   row[x]=M.bucket(value,scale)
  end
  local key=table.concat(row,',')
  if cache.rows[y]~=key then
   local start=1
   while start<=width do
    local code=row[start];local last=start;while last<width and row[last+1]==code do last=last+1 end
    local color=code>0 and ramp[code] or code==-3 and t.warn or code==-2 and 0x202C30 or 0x000000
    local glyph=code==-3 and '?' or code==-2 and '.' or palette==7 and (code>0 and ('.,:;-~=+*#%@'):sub(code,code) or ' ') or ' '
    if palette==7 or code<0 then g:text(x0+start-1,y0+y-1,string.rep(glyph,last-start+1),code>0 and color or color,t.bg,last-start+1)
    else g:fill(x0+start-1,y0+y-1,last-start+1,1,color) end
    start=last+1
   end
   cache.rows[y]=key
  end
 end
 return cache
end
return M
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
  Widgets.frame(ctx,'DESKTOP / APPLICATIONS',true)
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
    -- The large display has room for a framed launcher without changing any
    -- tile coordinates or the compact/standard interaction model.
    local rich=withPanel and Widgets.rich(ctx)
    if rich then
      local fh=math.min(h-9,math.ceil(#entries/2)*tileH+2)
      Widgets.outline(g,t,2,6,tileW+2,fh,'APPLICATIONS')
      Widgets.outline(g,t,3+tileW+gap-1,6,tileW+2,fh)
    end
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
      if rich then
        g:fill(px,7,pw,12,t.bg)
        Widgets.outline(g,t,px,7,pw,12,'LIVE / STATUS')
      end
      local rows={
        'GPU  '..tostring(hs.gpuAddress or '?'):sub(1,8),
        'RAM  '..(type(hs.freeMemory)=='number' and math.floor(hs.freeMemory/1024)..' KiB' or '?'),
        'SIZE '..tostring(hs.resolutionW or '?')..'x'..tostring(hs.resolutionH or '?'),
        'DEPTH '..tostring(hs.depth or '?')..' bit',
        'UP '..(type(hs.uptime)=='number' and math.floor(hs.uptime)..' s' or '?'),
        'THEME '..ctx.config.data.theme:upper()
      }
      for j,line in ipairs(rows) do g:text(px+2,8+j,line,t.text,rich and t.bg or t.surface,pw-4) end
    end
  else
    local count=math.max(1,math.floor((h-5)/2))
    if s.selection<s.scroll+1 then s.scroll=s.selection-1 end
    if s.selection>s.scroll+count then s.scroll=s.selection-count end
    s.scroll=math.max(0,math.min(s.scroll,math.max(0,#entries-count)))
    local range=#entries>count and ((s.scroll+1)..'-'..math.min(#entries,s.scroll+count)..'/'..#entries) or ''
    g:text(2,3,'APPS / '..ctx.config.data.theme:upper()..' / 1-9',t.accent,t.bg,
      math.max(1,w-3-(range~='' and #range+1 or 0)))
    for slot=1,count do
      local i=s.scroll+slot; local entry=entries[i]
      if entry then
        local y=4+(slot-1)*2
        Widgets.action(g,t,2,y,w-4,2,tostring(i)..'  '..entry.name,entry.description,i==s.selection)
        s.hitboxes[#s.hitboxes+1]={x=2,y=y,w=w-4,h=2,id=entry.id,index=i}
      end
    end
    if range~='' then g:text(w-#range,3,range,t.muted,t.bg,#range) end
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
  if mode=='standard' then g:text(math.max(2,w-14),1,'v0.6.5 OPENOS',t.muted,t.surface,14) end
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
-- The detailed skin is deliberately restricted to the Tier 3 viewport.  The
-- original compact renderers and update dashboard retain their own layouts.
function M.rich(ctx)
  local w,h=ctx.gfx:size()
  if w<140 or h<48 then return false end
  local gpu=ctx.gfx.gpu
  if not gpu or type(gpu.getDepth)~='function' then return false end
  local ok,depth=pcall(gpu.getDepth)
  return ok and type(depth)=='number' and depth>=8
end
function M.outline(g,t,x,y,w,h,title)
  if w<3 or h<2 then return end
  local edge=({cyan=0x006D80,green=0x006D40,amber=0x806D00})[t.name] or t.border or t.accent
  g:colors(edge,t.bg)
  g:fill(x,y+1,1,h-2,t.bg,'|');g:fill(x+w-1,y+1,1,h-2,t.bg,'|')
  local rule='+'..string.rep('-',w-2)..'+'
  g:text(x,y,rule,edge,t.bg,w);g:text(x,y+h-1,rule,edge,t.bg,w)
  if title then g:text(x+2,y,'[ '..title..' ]',t.accent,t.bg,w-4) end
end
function M.frame(ctx,title,industrial)
  local g,t=ctx.gfx,ctx.theme
  local w,h=g:size()
  ctx.state.screenMode=M.mode(w,h,ctx.config.data.layout)
  g:fill(1,1,w,h,t.bg)
  if industrial and M.rich(ctx) then
    local bg=t.name=='cyan' and 0x002424 or t.surface
    g:fill(1,1,w,2,bg)
    g:text(2,1,'NEXUS / WORKSPACE',t.accent,bg,w-20)
    g:text(2,2,title or 'DESKTOP',t.text,bg,w-4)
    g:text(w-14,1,'v0.6.5 OPENOS',t.muted,bg,14)
  else M.header(g,t,w,title,ctx.state.screenMode) end
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
  ctx.state.previewButtons={}
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
  g:text(x+2,y+4,'[KEEP] [REVERT]',t.good,t.surface,pw-4)
  ctx.state.previewButtons={{x=x+2,y=y+4,w=6,id='keep'},{x=x+9,y=y+4,w=8,id='revert'}}
  g:text(x+2,y+5,'ENTER keep / timeout reverts',t.warn,t.surface,pw-4)
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
