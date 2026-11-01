-- Bounded in-memory messages; no persistent logs in Phase 2.
local M={}
function M.new()
  return setmetatable({history={},current=nil,maximum=8,enabled=true}, {__index=M})
end
function M:push(message,kind,now)
  local item={message=tostring(message or ''):sub(1,90),kind=kind or 'info',at=type(now)=='number' and now or 0}
  table.insert(self.history,1,item)
  if #self.history>self.maximum then table.remove(self.history) end
  if self.enabled then self.current={item=item,untilTime=item.at+4} end
  return item
end
function M:tick(now)
  if self.current and now>=self.current.untilTime then self.current=nil; return true end
  return false
end
return M
