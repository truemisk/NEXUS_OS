package.path='./tests/?.lua;'..package.path
local Mock=require('mock_components')
local GPU=require('mock_gpu')
local MockFs=require('mock_fs')
local gpu=GPU.new(80,25)
local deps={term=Mock.term(gpu),component=Mock.new({gpu}),computer=Mock.computer()}
deps.event=Mock.events({{'key_down','keyboard-01',113,16},{'key_down','keyboard-01',121,21}},gpu)
package.loaded.filesystem=MockFs.new()
package.loaded.term=deps.term
package.loaded.component=deps.component
package.loaded.computer=deps.computer
package.loaded.event=deps.event
package.loaded.keyboard={keys={up=200,down=208,left=203,right=205,enter=28,esc=1}}
local ok,runOK,result=pcall(dofile,'./dist/nexus.lua')
assert(ok,tostring(runOK))
assert(runOK==true,tostring(result))
assert(not gpu.snapshot():find('%S'),'Distribution did not restore terminal display')
assert(deps.term.blink==true)
assert(gpu.calls.set>0)
print('PASS single-file bundle launch, menu, quit confirmation, terminal restore')
