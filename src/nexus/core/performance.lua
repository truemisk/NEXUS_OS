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
