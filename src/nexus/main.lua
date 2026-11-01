-- NEXUS OS v0.6.4 | Phase 5B | one foreground app, no boot modifications.
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
  logger:log('INFO','core','NEXUS v0.6.4 launched')
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
    local readyAcknowledged=false
    if type(term.setCursorBlink)=='function' then pcall(term.setCursorBlink,false) end
    if config.data.splash then
      local w,h=gfx:size()
      gfx:fill(1,1,w,h,ctx.theme.bg)
      gfx:center(math.max(2,math.floor(h/2)),'NEXUS OS / v0.6.4',ctx.theme.accent,ctx.theme.bg)
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
