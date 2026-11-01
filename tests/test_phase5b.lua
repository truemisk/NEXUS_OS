package.path='./src/?.lua;./tests/?.lua;'..package.path
local Device=require('nexus.core.devicecontrol')
local Auto=require('nexus.core.automation')
local Events=require('nexus.core.hwevents')
local count=0
local function test(name,fn)
 local ok,why=pcall(fn)
 if not ok then error('FAIL '..name..': '..tostring(why),0) end
 count=count+1;print('PASS '..name)
end
local function machine()
 local state={inputs={0,0,0,0,0,0},outputs={0,0,0,0,0,0},calls={},allowWrite=true,live=true}
 local proxy={address='red-0001',type='redstone'}
 function proxy.getInput(side)
  if not state.live then error('removed') end
  return state.inputs[side+1]
 end
 function proxy.getOutput(side)
  if not state.live then error('removed') end
  return state.outputs[side+1]
 end
 function proxy.setOutput(side,value)
  if not state.allowWrite then error('blocked') end
  local prior=state.outputs[side+1]
  state.outputs[side+1]=value
  state.calls[#state.calls+1]={side,value}
  return prior
 end
 local component={}
 function component.list()
  local items={{'red-0001','redstone'},{'gpu-0002','gpu'},{'screen-1','screen'}, {'file-1','filesystem'}}
  local i=0;return function()i=i+1;if items[i]then return items[i][1],items[i][2]end end
 end
 function component.proxy(addr)if addr=='red-0001' then return proxy end;return {address=addr} end
 function component.invoke(addr,method,...)
  if addr~='red-0001' then error('not found') end
  return proxy[method](...)
 end
 local logs={}
 local logger={log=function(_,severity,service,msg) logs[#logs+1]={severity,service,msg} end}
 return Device.new(component,logger),state,logs,component
end
test('read-only inventory lists actual components',function()
 local d=machine();local all=d:list()
 assert(#all==4 and all[1].kind=='filesystem')
 assert(#d:redstones()==1)
end)
test('empty component list is handled safely',function()
 local d=Device.new({list=function()return function()end end});assert(#d:list()==0);assert(#d:redstones()==0)
end)
test('invalid side and out of range output do not write',function()
 local d,state=machine()
 assert(not d:read('red-0001',6));assert(not d:write('red-0001',-1,15));assert(not d:write('red-0001',1,16))
 assert(#state.calls==0)
end)
test('input and output read real values',function()
 local d,state=machine();state.inputs[2]=7;state.outputs[2]=9
 local v=d:read('red-0001',1);assert(v.input==7 and v.output==9)
end)
test('manual output writes track original and restore on shutdown',function()
 local d,state=machine();state.outputs[4]=3
 assert(d:write('red-0001',3,15));assert(state.outputs[4]==15)
 assert(d:restoreAll());assert(state.outputs[4]==3);assert(#state.calls==2)
end)
test('manual output already correct is not considered owned',function()
 local d,state=machine();assert(d:write('red-0001',3,0));assert(#state.calls==0)
 assert(next(d.owned)==nil)
end)
test('two writes on same output preserve first original',function()
 local d,state=machine();state.outputs[1]=4
 assert(d:write('red-0001',0,15));assert(d:write('red-0001',0,0));assert(d:restoreAll())
 assert(state.outputs[1]==4)
end)
test('never overwrite output changed externally',function()
 local d,state=machine();assert(d:write('red-0001',0,15));state.outputs[1]=8
 local ok,why=d:restoreAll();assert(not ok);assert(why:find('externally',1,true))
 assert(state.outputs[1]==8)
end)
test('failed hardware write is not counted as a successful operation',function()
 local d,state=machine();state.allowWrite=false
 local ok=d:write('red-0001',0,15);assert(not ok);assert(state.outputs[1]==0)
end)
test('no redstone hardware does not throw',function()
 local d=Device.new({list=function()return function() end end})
 assert(not d:read('none',0));assert(not d:write('none',0,15))
end)
test('automation disabled by default and has no writes',function()
 local d,state=machine();local a=Auto.new(d)
 assert(not a.enabled);assert(not a:tick(10));assert(#state.calls==0)
end)
test('mirror refuses same input and output side',function()
 local d,state=machine();local a=Auto.new(d)
 assert(not a:enable('red-0001',1,1));assert(#state.calls==0)
end)
test('mirror requires explicit enable and reads actual input',function()
 local d,state=machine();local a=Auto.new(d)
 state.inputs[1]=11
 assert(a:enable('red-0001',0,1));assert(a:tick(1));assert(state.outputs[2]==15)
 assert(not a:tick(1.5));assert(#state.calls==1)
 state.inputs[1]=0;assert(a:tick(2));assert(state.outputs[2]==0)
end)
test('disable mirror restores previous level',function()
 local d,state=machine();local a=Auto.new(d)
 state.outputs[2]=4;state.inputs[1]=11
 assert(a:enable('red-0001',0,1));assert(a:tick(1));assert(state.outputs[2]==15)
 assert(a:disable());assert(state.outputs[2]==4);assert(not a.enabled)
end)
test('emergency stop restores manual and automated owned outputs',function()
 local d,state=machine();local a=Auto.new(d)
 assert(d:write('red-0001',5,15));state.inputs[1]=15
 assert(a:enable('red-0001',0,1));assert(a:tick(1))
 local ok,why,count=a:emergencyStop();assert(ok,tostring(why));assert(count==2)
 assert(state.outputs[6]==0 and state.outputs[2]==0 and not a.enabled)
end)
test('removed device suspends mirror and raises error',function()
 local d,state=machine();local a=Auto.new(d)
 assert(a:enable('red-0001',0,1));state.live=false
 assert(a:tick(1));assert(not a.enabled and a.error)
end)
test('method inspection is read-only and optional',function()
 local d,state,log,component=machine()
 component.methods=function(addr) return addr=='red-0001' and {getInput=true,setOutput=false,getOutput=true} or {} end
 local list=d:methods('red-0001');assert(#list==3 and list[1]=='getInput')
 assert(#state.calls==0)
end)
test('event monitor records only real relevant signal categories',function()
 local events=Events.new(5)
 assert(not events:push(1,'random','x'))
 assert(events:push(2,'component_added','redstone',nil,nil,nil))
 assert(events:push(3,'redstone_changed','red-0001',2,0,15))
 assert(#events.items==2 and events.items[1].side==2 and events.items[1].new==15)
end)
test('event history remains bounded',function()
 local e=Events.new(5)
 for i=1,100 do e:push(i,'component_added','redstone') end
 assert(#e.items==5 and e.items[1].at==100 and e.items[5].at==96)
 e:clear();assert(#e.items==0)
end)
print('PHASE 5B CORE: '..count..' passed, 0 failed')
