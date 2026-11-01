-- Shared foreground application lifecycle. Errors never crash NEXUS desktop.
local M={}
function M.new() return setmetatable({items={},byId={},active=nil,error=nil},{__index=M}) end
function M:register(spec)
  assert(type(spec)=='table' and type(spec.id)=='string' and spec.id~='')
  assert(type(spec.name)=='string' and type(spec.draw)=='function')
  assert(not self.byId[spec.id],'Duplicate app ID: '..spec.id)
  self.items[#self.items+1]=spec;self.byId[spec.id]=spec
end
function M:home(ctx)
  if self.active and self.active.close then pcall(self.active.close,ctx) end
  self.active=nil
end
function M:open(id,ctx)
  local app=self.byId[id]
  if not app then return false,'Unknown app: '..tostring(id) end
  self:home(ctx)
  if app.open then
    local ok,err=pcall(app.open,ctx)
    if not ok then
      if app.close then pcall(app.close,ctx) end
      self.error=tostring(err);return false,self.error
    end
  end
  self.active=app
  return true
end
function M:draw(ctx)
  if not self.active then return true end
  local ok,err=pcall(self.active.draw,ctx)
  if not ok then self.error=tostring(err);self:home(ctx);return false,self.error end
  return true
end
function M:input(action,ctx)
  if not self.active or not self.active.input then return false end
  local ok,handled=pcall(self.active.input,action,ctx)
  if not ok then self.error=tostring(handled);self:home(ctx);return false,self.error end
  return handled==true
end
function M:tick(ctx)
  if not self.active or not self.active.tick then return false end
  local ok,changed=pcall(self.active.tick,ctx)
  if not ok then self.error=tostring(changed);self:home(ctx);return false,self.error end
  return changed==true
end
return M
