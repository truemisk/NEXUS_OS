-- Bounded command history and read-only built-in commands; external commands
-- run via real OpenOS shell.execute in an explicit screen handoff.
local Path=require('nexus.core.path')
local M={}
function M.new(fs)
  return setmetatable({cwd='/home',buffer='',cursor=1,history={},histIndex=0,
    lines={'NEXUS TERMINAL / OpenOS shell bridge','Type help for commands.'},fs=fs}, {__index=M})
end
function M:print(line)
  for segment in (tostring(line or '')..'\n'):gmatch('(.-)\n') do
    self.lines[#self.lines+1]=segment:sub(1,240)
    if #self.lines>80 then table.remove(self.lines,1) end
  end
end
function M:insert(str)
  if type(str)~='string' then return end
  str=str:gsub('[\r\n]',' '):gsub('[%c]',''):sub(1,256)
  local remain=256-#self.buffer
  str=str:sub(1,math.max(0,remain))
  self.buffer=self.buffer:sub(1,self.cursor-1)..str..self.buffer:sub(self.cursor)
  self.cursor=self.cursor+#str
end
function M:key(action)
  local k=action.kind
  if k=='char' or k=='paste' then self:insert(action.value);return true end
  if k=='backspace' then
    if self.cursor>1 then self.buffer=self.buffer:sub(1,self.cursor-2)..self.buffer:sub(self.cursor);self.cursor=self.cursor-1 end
  elseif k=='delete' then
    if self.cursor<=#self.buffer then self.buffer=self.buffer:sub(1,self.cursor-1)..self.buffer:sub(self.cursor+1) end
  elseif k=='left' then self.cursor=math.max(1,self.cursor-1)
  elseif k=='right' then self.cursor=math.min(#self.buffer+1,self.cursor+1)
  elseif k=='linehome' then self.cursor=1
  elseif k=='lineend' then self.cursor=#self.buffer+1
  elseif k=='up' or k=='down' then
    local max=#self.history+1
    self.histIndex=math.max(1,math.min(max,(self.histIndex==0 and max or self.histIndex)+(k=='up' and -1 or 1)))
    self.buffer=self.history[self.histIndex] or ''
    self.cursor=#self.buffer+1
  else return false end
  return true
end
function M:execute(command,ctx)
  self:print(self.cwd..' $ '..command)
  command=command:match('^%s*(.-)%s*$')
  if command=='' then return end
  self.history[#self.history+1]=command
  if #self.history>16 then table.remove(self.history,1) end
  self.histIndex=#self.history+1
  local cmd,arg=command:match('^(%S+)%s*(.*)$')
  if cmd=='help' then
    self:print('help, pwd, cd PATH, ls [PATH], cat FILE, clear')
    self:print('mem, uptime, components, exit, run COMMAND')
    self:print('run executes a REAL OpenOS command (not sandboxed).')
  elseif cmd=='pwd' then self:print(self.cwd)
  elseif cmd=='clear' then self.lines={}
  elseif cmd=='exit' then ctx.manager:home(ctx);if ctx.session then ctx.session:home() end
  elseif cmd=='cd' then
    local p=Path.normalize(arg~='' and arg or '/home',self.cwd)
    if p and self.fs.exists(p) and self.fs.isDirectory(p) then self.cwd=p
    else self:print('Directory not found') end
  elseif cmd=='ls' then
    local p=Path.normalize(arg~='' and arg or '.',self.cwd)
    if not p then self:print('Invalid path');return end
    local ok,it=pcall(self.fs.list,p)
    if not ok or not it then self:print('Cannot list '..p);return end
    local count=0
    local function add(name)
      if count>=48 then return end
      count=count+1; self:print(name)
    end
    if type(it)=='function' then for name in it do add(name) end
    elseif type(it)=='table' then for _,name in ipairs(it) do add(name) end end
    if count>=48 then self:print('[Listing limited to 48 entries]') end
  elseif cmd=='cat' then
    local p=Path.normalize(arg,self.cwd)
    if not p or self.fs.isDirectory(p) then self:print('Expected a file');return end
    local f=io.open(p,'rb')
    if not f then self:print('Cannot read file');return end
    local data=f:read(2049) or ''; f:close()
    if data:find('%z') then self:print('Binary file');return end
    for line in (data:sub(1,2048)..'\n'):gmatch('(.-)\n') do self:print(line) end
    if #data>2048 then self:print('[Truncated to 2048 bytes]') end
  elseif cmd=='mem' then
    local s=ctx.hardware:snapshot()
    self:print('Free: '..tostring(s.freeMemory or '?')..' B / Total: '..tostring(s.totalMemory or '?')..' B')
  elseif cmd=='uptime' then self:print(tostring(math.floor(ctx.now()))..' seconds')
  elseif cmd=='components' then
    local s=ctx.hardware:snapshot();self:print('Components: '..tostring(s.componentCount)..' GPUs: '..tostring(s.gpuCount))
  elseif cmd=='run' then
    if arg=='' then self:print('Usage: run COMMAND');return end
    local ok,why=ctx.runShell(arg,self.cwd)
    self:print(ok and 'OpenOS command finished.' or ('OpenOS error: '..tostring(why)))
  else self:print('Unknown built-in. Use run '..cmd..' for OpenOS commands.') end
end
return M
