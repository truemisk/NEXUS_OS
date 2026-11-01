package.path='./src/?.lua;./tests/?.lua;'..package.path
local Mock=require('mock_components')
local GPU=require('mock_gpu')
local Fs=require('mock_fs')
local Main=require('nexus.main')
local function key(char,scan)return {'key_down','keyboard-01',string.byte(char),scan or 0}end
local function launch(w,h,events)
 local gpu=GPU.new(w,h)
 local fs=Fs.new()
 local deps={fs=fs,term=Mock.term(gpu),component=Mock.new({gpu}),computer=Mock.computer(),
  persistence={read=function()return '' end,write=function()return true end},
  logStore={ensure=function()return true end,size=function()return 0 end,append=function()return true end,rotate=function()return true end},
  recoveryStore={exists=function()return false end,mark=function()return true end,clear=function()return true end}}
 deps.keys={up=200,down=208,left=203,right=205,enter=28,tab=15,backspace=14}
 deps.event=Mock.events(events,gpu)
 local ok,why=Main(deps)
 assert(ok,tostring(why))
 assert(not gpu.snapshot():find('%S'))
 return table.concat(deps.event.snaps,'\n')
end
-- Open Update Center via #8, then Autostart tab #2, HOME via clickable taskbar,
-- Exit on desktop with Q/Y. Never send F keys or ESC.
local seq={key('8'),key('2'),{'touch','screen-01',3,25,0},key('q'),key('y')}
local screens=launch(80,25,seq)
assert(screens:find('UPDATE CENTER',1,true),'Update Center missing')
assert(screens:find('AUTOSTART',1,true),'Autostart tab missing')
print('PASS v0.5.0 integrated Update Center navigation and terminal restoration')
local small=launch(30,11,{key('8'),key('2'),{'touch','screen-01',3,11,0},key('q'),key('y')})
assert(small:find('UPDATE CENTER',1,true),'Compact Update Center missing')
print('PASS compact Update Center display')
