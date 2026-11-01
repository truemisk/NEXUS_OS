-- OpenComputers hardware access. No implicit writes, no primary changes.
local M={}
M.SIDES={'BOTTOM','TOP','BACK','FRONT','RIGHT','LEFT'}
local function validSide(side) return type(side)=='number' and side==math.floor(side) and side>=0 and side<=5 end
local function validLevel(level) return type(level)=='number' and level==math.floor(level) and level>=0 and level<=15 end
function M.new(component,logger)
  return setmetatable({component=component,logger=logger,owned={},lastError=nil,diagnostic=''}, {__index=M})
end
function M:call(address,method,...)
  if type(address)~='string' or address=='' then return nil,'Invalid component address' end
  local comp=self.component
  if type(comp.invoke)=='function' then
    local ok,a,b=pcall(comp.invoke,address,method,...)
    if ok then
      if a==nil then return nil,tostring(b or (method..' unavailable')) end
      return a,b
    end
    -- Some OpenOS test shims have proxy methods but no working invoke.
    self.lastError=tostring(a)
  end
  if type(comp.proxy)=='function' then
    local ok,proxy=pcall(comp.proxy,address)
    if ok and type(proxy)=='table' and type(proxy[method])=='function' then
      local good,a,b=pcall(proxy[method],...)
      if good and a~=nil then return a,b end
      return nil,tostring(a or b)
    end
  end
  return nil,self.lastError or ('Unsupported component method '..method)
end
function M:list()
  local result={}
  if type(self.component.list)~='function' then return result,'component.list missing' end
  local ok,iter=pcall(self.component.list)
  local mt=type(iter)=='table' and getmetatable(iter) or nil
  local callable=type(iter)=='function' or (type(mt)=='table' and type(mt.__call)=='function')
  if not ok or not callable then return result,'Unable to enumerate components (invalid iterator)' end
  local worked,err=pcall(function()
    for address,kind in iter do
      if type(address)=='string' and type(kind)=='string' then
        result[#result+1]={address=address,kind=kind}
        if #result>=96 then break end
      end
    end
  end)
  if not worked then return result,tostring(err) end
  table.sort(result,function(a,b)
    if a.kind==b.kind then return a.address<b.address end
    return a.kind<b.kind
  end)
  return result
end
function M:methods(address)
  if type(self.component.methods)~='function' then return nil,'Method metadata unavailable' end
  local ok,items=pcall(self.component.methods,address)
  if not ok or type(items)~='table' then return nil,'Method inspection unavailable' end
  local result={}
  for method in pairs(items) do if type(method)=='string' then result[#result+1]=method end end
  table.sort(result)
  return result
end
function M:redstones()
  local all=self:list();local found={}
  for _,d in ipairs(all) do if d.kind=='redstone' then found[#found+1]=d end end
  return found
end
function M:read(address,side)
  if not validSide(side) then return nil,'Side must be 0-5' end
  local a,err=self:call(address,'getInput',side)
  if type(a)~='number' then return nil,'Input: '..tostring(err or a) end
  local b,why=self:call(address,'getOutput',side)
  if type(b)~='number' then return nil,'Output: '..tostring(why or b) end
  return {input=a,output=b,side=side}
end
local function key(addr,side) return addr..':'..tostring(side) end
function M:write(address,side,level)
  if not validSide(side) or not validLevel(level) then return false,'Side 0-5, level 0-15 only' end
  local known=false
  for _,item in ipairs(self:redstones()) do if item.address==address then known=true;break end end
  if not known then return false,'Not a detected redstone component' end
  local before,err=self:read(address,side)
  if not before then return false,err end
  if before.output==level then return true,'Already '..level end
  local k=key(address,side)
  local old=self.owned[k]
  local original=old and old.original or before.output
  -- Record intent before write, so even partial hardware failures can be restored.
  self.owned[k]={address=address,side=side,original=original,last=level}
  local returned,why=self:call(address,'setOutput',side,level)
  if returned==nil then
    local actual=self:call(address,'getOutput',side)
    if actual~=level then
      if type(actual)=='number' and actual~=original then
        self.owned[k].last=actual
        self:restore(address,side) -- Best-effort revert after partial write.
      elseif not old then self.owned[k]=nil else self.owned[k]=old end
      return false,'Hardware refused output change: '..tostring(why)
    end
  end
  local verified=self:call(address,'getOutput',side)
  if type(verified)=='number' and verified~=level then
    self.owned[k].last=verified
    return false,'Output verification failed (actual '..verified..')'
  end
  if self.logger then self.logger:log('WARN','hardware','User/automation changed redstone '..address:sub(1,8)..' side '..side..' to '..level) end
  return true,'Output '..level
end
function M:restore(address,side)
  local k=key(address,side)
  local own=self.owned[k]
  if not own then return true,'Nothing to restore' end
  local current,err=self:call(address,'getOutput',side)
  if type(current)~='number' then return false,tostring(err) end
  if current~=own.last then
    self.owned[k]=nil
    return false,'Output changed externally; not overwriting'
  end
  if current~=own.original then
    local result,why=self:call(address,'setOutput',side,own.original)
    if result==nil then
      local readback=self:call(address,'getOutput',side)
      if readback~=own.original then return false,tostring(why) end
    end
    local verified=self:call(address,'getOutput',side)
    if type(verified)=='number' and verified~=own.original then return false,'Restore verify failed' end
  end
  self.owned[k]=nil
  return true,'Restored '..tostring(own.original)
end
function M:restoreAll()
  local failed={};local count=0
  local keys={};for k in pairs(self.owned) do keys[#keys+1]=k end
  table.sort(keys)
  for _,k in ipairs(keys) do
    local own=self.owned[k]
    if own then
      local ok,why=self:restore(own.address,own.side)
      if ok then count=count+1 else failed[#failed+1]=k..' '..tostring(why) end
    end
  end
  if self.logger then self.logger:log(#failed>0 and 'ERROR' or 'INFO','hardware','Restored '..count..' outputs; failures '..#failed) end
  return #failed==0,table.concat(failed,'; '),count
end
return M
