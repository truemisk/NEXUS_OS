-- Detect unclean NEXUS sessions; no boot files/BIOS changes.
local M={}
local function defaultStore()
  local path='/home/nexus/session.lock'
  return {
    exists=function()
      local f=io.open(path,'r');if f then f:close();return true end;return false
    end,
    mark=function()
      local ok,fs=pcall(require,'filesystem')
      if not ok then return false end
      if not fs.exists('/home/nexus') then fs.makeDirectory('/home/nexus') end
      local f=io.open(path,'w');if not f then return false end
      f:write('NEXUS v0.4.0 session running\n');f:close();return true
    end,
    clear=function()
      local ok,fs=pcall(require,'filesystem');if not ok then return false end
      if fs.exists(path) then return fs.remove(path) end
      return true
    end
  }
end
function M.new(store,logger)
  return setmetatable({store=store or defaultStore(),logger=logger,
    unclean=false,armed=false,recent={},limit=12},{__index=M})
end
function M:begin()
  local ok,result=pcall(self.store.exists)
  self.unclean=ok and result==true
  local markOk,marked=pcall(self.store.mark)
  self.armed=markOk and marked==true
  if self.unclean then self.logger:log('WARN','recovery','Previous NEXUS session ended without a clean exit') end
  return self.unclean
end
function M:report(area,reason)
  local item={area=tostring(area),message=tostring(reason):sub(1,160)}
  table.insert(self.recent,1,item);if #self.recent>self.limit then table.remove(self.recent) end
  self.logger:log('ERROR',area,reason)
end
function M:finish()
  if not self.armed then return true end
  local ok,result=pcall(self.store.clear)
  if ok and result then self.armed=false;return true end
  self.logger:log('WARN','recovery','Could not clear session lock')
  return false
end
return M
