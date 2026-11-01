-- Bounded runtime event history; records real signals only.
local M={}
function M.new(limit)
  return setmetatable({limit=math.max(5,math.min(40,limit or 24)),items={}}, {__index=M})
end
function M:push(at,kind,address,side,old,new)
  if kind~='component_added' and kind~='component_removed' and kind~='redstone_changed' and
      kind~='component_available' and kind~='component_unavailable' then return false end
  local info={at=math.floor(tonumber(at) or 0),kind=kind,address=tostring(address or ''):sub(1,8),
    side=type(side)=='number' and side or nil,old=old,new=new}
  table.insert(self.items,1,info)
  if #self.items>self.limit then table.remove(self.items) end
  return true
end
function M:clear() self.items={} end
return M
