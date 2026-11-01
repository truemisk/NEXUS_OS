package.path="./src/?.lua;./tests/?.lua;"..package.path
local Mock=require("mock_components")
local GPU=require("mock_gpu")
local Run=require("nexus.main")
local snapshots={}
for _,size in ipairs({{32,12},{80,25}}) do
  local w,h=table.unpack(size)
  local gpu=GPU.new(w,h)
  local cp=Mock.new({gpu})
  local events=Mock.events({{"key_down","keyboard-01",0,1}},gpu)
  assert(Run({component=cp,term=Mock.term(gpu),computer=Mock.computer(),event=events,keys={esc=1}}))
  snapshots[#snapshots+1]=string.format("NEXUS Desktop %dx%d (simulated ASCII text, without GPU colors)\n",w,h)..events.snaps[1]
end
local file=assert(io.open("docs/UI_PREVIEW.txt","w"))
file:write(table.concat(snapshots,"\n\n"),"\n")
file:close()
print("Wrote docs/UI_PREVIEW.txt")
