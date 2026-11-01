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
  self.pending=nil
  pcall(self.gpu.setResolution,pending.oldW,pending.oldH)
  return true
end
function M:tick()
  if self.pending and self.clock()>=self.pending.deadline then
    self:rollback()
    return true
  end
  return false
end
return M
