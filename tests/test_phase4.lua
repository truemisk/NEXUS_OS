package.path='./src/?.lua;./tests/?.lua;'..package.path
local Logger=require('nexus.core.logger')
local Services=require('nexus.core.services')
local Recovery=require('nexus.core.recovery')
local Session=require('nexus.core.session')
local Performance=require('nexus.core.performance')
local Diagnostics=require('nexus.core.diagnostics')
local Config=require('nexus.core.config')
local Path=require('nexus.core.path')
local Control=require('nexus.apps.control')
local GPU=require('mock_gpu')
local Mock=require('mock_components')
local MockFs=require('mock_fs')
local Run=require('nexus.main')
local count,bad=0,0
local function check(title,fn)
 local yes,why=pcall(fn)
 if yes then count=count+1;print('PASS '..title)
 else bad=bad+1;print('FAIL '..title..' :: '..tostring(why)) end
end
local function logging()
 local now=1;local saved={};local rotations=0;local size=0
 local store={ensure=function()return true end,size=function()return size end,
 append=function(_,str)saved[#saved+1]=str;size=size+#str;return true end,
 rotate=function()rotations=rotations+1;size=0;return true end}
 return Logger.new(store,function() return now end),saved,function()return rotations end
end
check('logger records in memory and on disk',function()
 local log,saved=logging();assert(log:log('INFO','core','hello'))
 assert(#log.rows==1 and #saved==1 and saved[1]:find('hello',1,true))
 assert(log.diskStatus=='PERSISTENT')
end)
check('logger bounds memory rows',function()
 local log=logging();for i=1,70 do log:log('INFO','test',i) end
 assert(#log.rows==50 and log.rows[1].message=='70')
end)
check('logger escapes newline in log entry',function()
 local log,saved=logging();log:log('WARN','core','line\nINJECT')
 assert(not saved[1]:find('line\nINJECT',1,true))
end)
check('logger rotates at byte budget',function()
 local log,saved,rot=logging();log.maxBytes=150
 for i=1,15 do log:log('INFO','core','1234567890') end
 assert(rot()>0)
end)
check('logger remains functional when filesystem unwritable',function()
 local log=Logger.new({ensure=function()return false,'read-only' end},function()return 0 end)
 assert(not log:log('ERROR','disk','no disk'))
 assert(#log.rows==1 and log.diskStatus:find('RAM ONLY'))
end)
check('logger disabled persistence still keeps RAM notices',function()
 local log,saved=logging();log.enabled=false
 assert(log:log('INFO','x','local'));assert(#saved==0 and #log.rows==1)
end)
check('services run on interval, not every render',function()
 local log=logging();local services=Services.new(log);local n=0
 services:register({id='test',interval=3,tick=function()n=n+1 end})
 services:activateDefaults({},10,false)
 services:tick({},10);services:tick({},11);services:tick({},12);services:tick({},13)
 assert(n==2)
end)
check('essential service cannot be stopped',function()
 local services=Services.new(logging());services:register({id='core',interval=1,essential=true,tick=function()end})
 services:activateDefaults({},0,false);assert(not services:deactivate('core',{}))
 assert(services.items.core.status=='RUNNING')
end)
check('optional service manual stop and restart',function()
 local services=Services.new(logging());services:register({id='m',interval=2,tick=function()end})
 services:activateDefaults({},0,false)
 assert(services:deactivate('m',{}));assert(services.items.m.status=='STOPPED')
 assert(services:activate('m',{},3));assert(services.items.m.status=='RUNNING')
end)
check('repeated service errors disable only offending service',function()
 local services=Services.new(logging())
 services:register({id='bug',interval=1,tick=function() error('broken') end})
 services:register({id='good',interval=1,essential=true,tick=function()end})
 services:activateDefaults({},0,false)
 services:tick({},1);services:tick({},2);services:tick({},3)
 assert(services.items.bug.status=='FAILED' and services.items.good.status=='RUNNING')
end)
check('service safe-mode excludes optional services',function()
 local services=Services.new(logging())
 services:register({id='core',interval=1,essential=true,tick=function()end})
 services:register({id='user',interval=1,tick=function()end})
 services:activateDefaults({},1,true)
 assert(services.items.core.status=='RUNNING' and services.items.user.status=='STOPPED')
end)
check('service shutdown clears active services',function()
 local services=Services.new(logging());local stopped=0
 services:register({id='a',interval=2,tick=function()end,stop=function()stopped=stopped+1 end})
 services:activateDefaults({},0,false);services:shutdown({})
 assert(services.items.a.status=='STOPPED' and stopped==1)
end)
check('recovery warns on unclean preceding session',function()
 local was=true;local rec=Recovery.new({exists=function()return was end,
 mark=function()was=true;return true end,clear=function()was=false;return true end},logging())
 assert(rec:begin() and rec.armed);rec:finish();assert(not was)
end)
check('recovery records bounded errors',function()
 local rec=Recovery.new({exists=function()return false end,mark=function()return true end,clear=function()return true end},logging())
 for i=1,20 do rec:report('app','bad '..i) end
 assert(#rec.recent==12 and rec.recent[1].message=='bad 20')
end)
check('recovery leaves marker after failed clean-up',function()
 local rec=Recovery.new({exists=function()return false end,mark=function()return true end,clear=function()return false end},logging())
 rec:begin();assert(not rec:finish() and rec.armed)
end)
check('session tracks view and opens',function()
 local s=Session.new(5);s:open('files');s:home();assert(s.current=='desktop' and s.lastApp=='files')
 assert(s.opened==1 and s.transitions==2)
end)
check('performance samples bounded and low-memory alerts are throttled',function()
 local log=logging();local notes=0
 local ctx={hardware={snapshot=function()return {freeMemory=15000,totalMemory=200000}end},
 notify=function()notes=notes+1 end}
 local p=Performance.new();for i=1,55 do p:sample(ctx,i) end
 assert(#p.samples==30 and p.lowMemory and notes==2)
end)
check('diagnostics based on supplied hardware, not invented values',function()
 local log=logging();log.diskStatus='PERSISTENT'
 local svc=Services.new(log);svc:register({id='core',essential=true,interval=1,tick=function()end})
 local ctx={hardware={snapshot=function()return {gpuAddress='gpu-a',depth=8,resolutionW=80,resolutionH=25,
 freeMemory=100000,totalMemory=200000,componentCount=4}end},
 logger=log,services=svc,fs={get=function()return {isReadOnly=function()return false end}end}}
 local rows=Diagnostics.run(ctx)
 assert(#rows>=7 and rows[1].ok and rows[2].ok)
 assert(rows[4].detail:find('97',1,true))
end)
check('diagnostics rejects missing GPU without claiming success',function()
 local log=logging();local rows=Diagnostics.run({hardware={snapshot=function()return {} end},
 logger=log,services={ordered={}}})
 assert(rows[1].ok==false and rows[2].ok==false)
end)
check('config migrates phase2 boolean values and uses new defaults',function()
 local c=Config.new({read=function()return 'theme=green\nlayout=compact\nnotifications=false\n' end,
 write=function()return true end})
 assert(c.data.theme=='green' and not c.data.notifications and c.data.monitorService==true)
 assert(c:set('logging',false));assert(c:save())
end)
check('file manager protects new NEXUS boot and config files',function()
 assert(not Path.mutable('/home/nexus40.lua'))
 assert(not Path.mutable('/home/nexus40-bootstrap.lua'))
 assert(not Path.mutable('/home/.shrc'))
end)
check('config rejects malformed values',function()
 local c=Config.new({read=function()return 'logging=yes\nmonitorService=x\ntheme=hack\n' end,
 write=function()return true end})
 assert(c.data.logging and c.data.monitorService and c.data.theme=='cyan')
 assert(not c:set('logging','DANGEROUS'))
end)
check('config round-trip retains phase4 settings',function()
 local encoded=Config.encode({theme='amber',layout='auto',notifications=true,splash=false,logging=false,monitorService=false})
 local parsed=Config.parse(encoded)
 assert(parsed.theme=='amber' and not parsed.logging and not parsed.monitorService)
end)
check('system center service tab and navigation',function()
 local log=logging();local svc=Services.new(log)
 svc:register({id='sample',interval=2,tick=function()end})
 svc:activateDefaults({},0,false)
 local ctx={state={},services=svc,logger=log,now=function()return 8 end,
 session=Session.new(0),performance=Performance.new(),recovery=Recovery.new(nil,log),notify=function()end}
 Control.open(ctx)
 assert(Control.input({kind='char',value='2'},ctx))
 assert(ctx.state.control.tab==2)
 Control.input({kind='char',value='1'},ctx)
 Control.input({kind='enter'},ctx)
 assert(svc.items.sample.status=='STOPPED')
 Control.close(ctx);assert(ctx.state.control==nil)
end)
local function key(scan,char)return {'key_down','keyboard-01',char or 0,scan or 0}end
local function smoke(w,h,seq)
 local gpu=GPU.new(w,h,{maxW=math.max(w,80),maxH=math.max(h,25)})
 local fs=MockFs.new()
 local rflag=false
 local deps={term=Mock.term(gpu),component=Mock.new({gpu}),computer=Mock.computer(),
 fs=fs,persistence={read=function()return '' end,write=function()return true end},
 logStore={ensure=function()return true end,size=function()return 0 end,rotate=function()return true end,append=function()return true end},
 recoveryStore={exists=function()return rflag end,mark=function()rflag=true;return true end,
 clear=function()rflag=false;return true end}}
 deps.event=Mock.events(seq,gpu);deps.keys={up=200,down=208,left=203,right=205,enter=28,esc=1,tab=15}
 local ok,res=Run(deps)
 assert(ok,tostring(res));assert(not rflag and deps.term.blink==true)
 assert(not gpu.snapshot():find('%S'))
 return table.concat(deps.event.snaps,'\n'),res
end
check('v4 desktop exit confirmation via keyboard Y',function()
 local captures=smoke(80,25,{key(21,113),key(21,121)})
 assert(captures:find('EXIT NEXUS',1,true))
end)
check('v4 mouse back and exit no ESC or F-keys',function()
 local captures=smoke(80,25,{key(2,49),{'touch','screen-01',12,25,0},
 {'touch','screen-01',19,25,0},key(21,121)})
 assert(captures:find('FILES',1,true) and captures:find('EXIT NEXUS',1,true))
end)
check('system center launches via desktop number 7',function()
 local captures=smoke(80,25,{key(8,55),key(2,49),key(1),key(21,113),key(21,121)})
 assert(captures:find('SYSTEM CENTER',1,true))
end)
check('UI compact screen renders and exits safely without ESC',function()
 local captures=smoke(30,11,{key(21,113),key(21,121)})
 assert(captures:find('APPLICATIONS',1,true))
end)
check('resolution preview can be canceled using clickable BACK',function()
 local seq={key(6,53)} -- Settings from desktop
 for i=1,6 do seq[#seq+1]=key(208) end -- select resolution target
 seq[#seq+1]=key(28) -- choose Compact
 seq[#seq+1]=key(208) -- select PREVIEW DISPLAY
 seq[#seq+1]=key(28) -- start 12-second preview
 seq[#seq+1]={'touch','screen-01',12,16,0} -- BACK on compact 50x16 taskbar
 seq[#seq+1]={'touch','screen-01',4,25,0} -- HOME after rollback
 seq[#seq+1]={'touch','screen-01',19,25,0} -- EXIT
 seq[#seq+1]=key(21,121) -- confirm
 local capture=smoke(80,25,seq)
 assert(capture:find('CONFIRM RESOLUTION',1,true))
end)
print(string.format('PHASE4: %d passed, %d failed',count,bad))
if bad>0 then os.exit(1) end
