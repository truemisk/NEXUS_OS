package.path='./src/?.lua;./tests/?.lua;'..package.path
local Mock=require('mock_components')
local GPU=require('mock_gpu')
local Fs=require('mock_fs')
local Main=require('nexus.main')
local count=0
local function key(v) return {'key_down','keyboard-01',string.byte(v),0} end
local function spec(scan) return {'key_down','keyboard-01',0,scan} end
local function start(events,withCard,width,height)
 local gpu=GPU.new(width or 80,height or 25)
 local comp=Mock.new({gpu})
 local originalList=comp.list
 local originalProxy=comp.proxy
 local rs={address='red-01',type='redstone',inputs={},outputs={},writes=0}
 function rs.getInput(side) return rs.inputs[side] or 0 end
 function rs.getOutput(side) return rs.outputs[side] or 0 end
 function rs.setOutput(side,value) local old=rs.outputs[side] or 0;rs.outputs[side]=value;rs.writes=rs.writes+1;return old end
 if withCard then
  function comp.list(filter)
   local old=originalList(filter)
   local extra=not filter or filter=='redstone';local sent=false
   return function()
    local a,b=old();if a then return a,b end
    if extra and not sent then sent=true;return rs.address,'redstone' end
   end
  end
  function comp.proxy(address) if address==rs.address then return rs end;return originalProxy(address) end
  function comp.invoke(address,method,...)
   if address==rs.address then return rs[method](...) end
   error('no invoke for '..tostring(address))
  end
 end
 local deps={component=comp,term=Mock.term(gpu),computer=Mock.computer(),fs=Fs.new(),
  persistence={read=function()return '' end,write=function()return true end},
  logStore={ensure=function()return true end,size=function()return 0 end,append=function()return true end,rotate=function()return true end},
  recoveryStore={exists=function()return false end,mark=function()return true end,clear=function()return true end}}
 deps.keys={up=200,down=208,left=203,right=205,enter=28,tab=15,backspace=14}
 deps.event=Mock.events(events,gpu)
 local ok,reason=Main(deps)
 assert(ok,tostring(reason))
 assert(not gpu.snapshot():find('%S'),'Failed to restore OpenOS screen')
 return table.concat(deps.event.snaps,'\n'),rs
end
local function test(name,fn)
 local ok,why=pcall(fn)
 if not ok then error('FAIL '..name..': '..tostring(why),0) end
 count=count+1;print('PASS '..name)
end
test('80-column taskbar exposes both UPD and HW controls',function()
 local screens=start({key('q'),key('y')},false)
 assert(screens:find('[HW]',1,true) and screens:find('[UPD]',1,true))
end)
test('Hardware Center opens without Redstone Card, no fake data',function()
 local screens=start({key('9'),key('2'),{'touch','screen-01',3,25},key('q'),key('y')},false)
 assert(screens:find('HARDWARE',1,true))
 assert(screens:find('No Redstone Card detected',1,true))
end)
test('device inspection preserves desktop and handles unavailable metadata',function()
 local screens=start({key('9'),spec(28),{'touch','screen-01',3,25},key('q'),key('y')},false)
 assert(screens:find('METHOD',1,true) or screens:find('Method inspection unavailable',1,true) or screens:find('metadata unavailable',1,true))
end)
test('real Redstone device can be inspected read-only',function()
 local screens,rs=start({key('9'),key('2'),{'touch','screen-01',3,25},key('q'),key('y')},true)
 assert(screens:find('CARD 1/1',1,true))
 assert(rs.writes==0)
end)
test('explicit confirmed write is restored during EXIT',function()
 local screens,rs=start({key('9'),key('2'),spec(208),spec(208),spec(208),spec(28),key('y'),
  {'touch','screen-01',3,25},key('q'),key('y')},true)
 assert(screens:find('CONFIRM: WRITE OUTPUT',1,true))
 assert(rs.writes==2 and rs.outputs[0]==0,'Expected 15 then 0 restore')
end)
test('declining output confirmation makes no physical write',function()
 local screens,rs=start({key('9'),key('2'),spec(208),spec(208),spec(208),spec(28),key('n'),
  {'touch','screen-01',3,25},key('q'),key('y')},true)
 assert(rs.writes==0)
end)
test('event monitor shows actual OC signals',function()
 local screens=start({key('9'),key('4'),{'component_added','disk-xx','filesystem'},
  {'redstone_changed','red-01',2,0,15},{'touch','screen-01',3,25},key('q'),key('y')},true)
 assert(screens:find('component_added',1,true))
 assert(screens:find('redstone_changed',1,true))
end)
test('Hardware Center renders in compact 40x18 mode and exits',function()
 local screens=start({key('9'),key('5'),{'touch','screen-01',3,18},key('q'),key('y')},false,40,18)
 assert(screens:find('HARDWARE',1,true))
end)
print('PHASE 5B GUI: '..count..' passed, 0 failed')
