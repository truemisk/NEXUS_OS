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
