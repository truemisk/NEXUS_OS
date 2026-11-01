-- Cooperative NEXUS services. These are NOT OpenOS background processes.
local M={}
function M.new(logger)
  return setmetatable({items={},ordered={},logger=logger,runCount=0},{__index=M})
end
function M:register(def)
  assert(type(def)=='table' and type(def.id)=='string' and not self.items[def.id])
  assert(type(def.tick)=='function' and type(def.interval)=='number' and def.interval>=0.5)
  local s={id=def.id,title=def.title or def.id,interval=def.interval,
    essential=def.essential==true,enabled=def.enabled~=false,status='STOPPED',
    failures=0,runs=0,nextAt=0,start=def.start,stop=def.stop,tickFn=def.tick,lastError=nil}
  self.items[s.id]=s;self.ordered[#self.ordered+1]=s;return s
end
function M:activate(id,ctx,now)
  local s=self.items[id];if not s then return false,'unknown service' end
  if s.status=='RUNNING' then return true end
  if s.start then
    local ok,err=pcall(s.start,ctx)
    if not ok then s.status='FAILED';s.lastError=tostring(err);self.logger:log('ERROR',id,err);return false,err end
  end
  s.enabled=true;s.status='RUNNING';s.failures=0;s.nextAt=now or 0;s.lastError=nil
  self.logger:log('INFO','service','Started '..id)
  return true
end
function M:deactivate(id,ctx)
  local s=self.items[id];if not s then return false,'unknown service' end
  if s.essential then return false,'core service cannot be stopped' end
  if s.status=='RUNNING' and s.stop then
    local ok,err=pcall(s.stop,ctx)
    if not ok then self.logger:log('WARN',id,'Stop error: '..tostring(err)) end
  end
  s.enabled=false;s.status='STOPPED'
  self.logger:log('INFO','service','Stopped '..id)
  return true
end
function M:activateDefaults(ctx,now,safeMode)
  for _,s in ipairs(self.ordered) do
    if s.enabled and (not safeMode or s.essential) then self:activate(s.id,ctx,now)
    elseif safeMode and not s.essential then s.enabled=false end
  end
end
function M:tick(ctx,now)
  local changed=false
  for _,s in ipairs(self.ordered) do
    if s.status=='RUNNING' and now>=s.nextAt then
      -- Set deadline BEFORE calling service, to avoid runaway re-entrancy.
      s.nextAt=now+s.interval
      local ok,result=pcall(s.tickFn,ctx,now)
      if ok then
        s.runs=s.runs+1;self.runCount=self.runCount+1
        if result then changed=true end
      else
        s.failures=s.failures+1;s.lastError=tostring(result)
        self.logger:log('ERROR',s.id,result)
        if s.failures>=3 then
          s.status='FAILED';s.enabled=false
          self.logger:log('WARN','service',s.id..' disabled after 3 errors')
        end
        changed=true
      end
    end
  end
  return changed
end
function M:shutdown(ctx)
  for i=#self.ordered,1,-1 do
    local s=self.ordered[i]
    if s.status=='RUNNING' then
      if s.stop then pcall(s.stop,ctx) end
      s.status='STOPPED'
    end
  end
end
return M
