-- Persistent, bounded OpenOS log. Any disk error degrades to RAM-only mode.
local M={}
local function safeText(value)
  return tostring(value or ''):gsub('[\r\n%z]',' '):sub(1,170)
end
local function defaultIO()
  return {
    append=function(path,line)
      local f,err=io.open(path,'a');if not f then return false,err end
      local ok,why=pcall(function() assert(f:write(line));assert(f:flush()) end)
      f:close();return ok,why
    end,
    size=function(path)
      local f=io.open(path,'r');if not f then return 0 end
      local s=f:seek('end') or 0;f:close();return s
    end,
    rotate=function(path)
      local ok,fs=pcall(require,'filesystem');if not ok then return false,'filesystem unavailable' end
      pcall(fs.remove,path..'.old')
      return fs.rename(path,path..'.old')
    end,
    ensure=function()
      local ok,fs=pcall(require,'filesystem');if not ok then return false,'filesystem unavailable' end
      if not fs.exists('/home/nexus') then local yes,why=fs.makeDirectory('/home/nexus');if not yes then return false,why end end
      if not fs.exists('/home/nexus/logs') then return fs.makeDirectory('/home/nexus/logs') end
      return true
    end
  }
end
function M.new(store,clock)
  return setmetatable({rows={},limit=50,maxBytes=32768,path='/home/nexus/logs/system.log',
    store=store or defaultIO(),clock=clock or function() return 0 end,enabled=true,
    diskStatus='UNTESTED',_ready=false},{__index=M})
end
function M:log(level,category,message)
  local row={at=math.floor(tonumber(self.clock()) or 0),level=safeText(level):sub(1,8),
    category=safeText(category):sub(1,18),message=safeText(message)}
  table.insert(self.rows,1,row)
  if #self.rows>self.limit then table.remove(self.rows) end
  if not self.enabled then return true end
  if not self._ready then
    local ok,success,reason=pcall(self.store.ensure)
    if not ok or not success then self.diskStatus='RAM ONLY: '..safeText(reason or success);return false end
    self._ready=true
  end
  local line=string.format('%d | %s | %s | %s\n',row.at,row.level,row.category,row.message)
  local okSize,size=pcall(self.store.size,self.path)
  if okSize and type(size)=='number' and size+#line>self.maxBytes then
    local okRotate,success=pcall(self.store.rotate,self.path)
    if not okRotate or not success then self.diskStatus='ROTATE FAILED';return false end
  end
  local ok,success=pcall(self.store.append,self.path,line)
  self.diskStatus=(ok and success) and 'PERSISTENT' or 'RAM ONLY: WRITE ERROR'
  return ok and success or false
end
return M
