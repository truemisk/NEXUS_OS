-- ASCII-only clipped renderer; avoids invalid GPU coordinates.
local M = {}
function M.new(gpu)
  local self = {gpu=gpu, foreground=nil, background=nil}
  return setmetatable(self, {__index=M})
end
function M:size()
  local w, h = self.gpu.getResolution()
  assert(type(w)=="number" and type(h)=="number" and w>=1 and h>=1, "Invalid display resolution")
  return math.floor(w), math.floor(h)
end
function M:colors(fg, bg)
  if fg ~= nil and fg ~= self.foreground then
    self.gpu.setForeground(fg)
    self.foreground = fg
  end
  if bg ~= nil and bg ~= self.background then
    self.gpu.setBackground(bg)
    self.background = bg
  end
end
function M:fill(x, y, width, height, bg, char)
  local sw, sh = self:size()
  x, y, width, height = math.floor(x), math.floor(y), math.floor(width), math.floor(height)
  if width<=0 or height<=0 then return end
  local x1, y1 = math.max(1, x), math.max(1, y)
  local x2, y2 = math.min(sw, x+width-1), math.min(sh, y+height-1)
  if x1>x2 or y1>y2 then return end
  self:colors(nil, bg)
  self.gpu.fill(x1,y1,x2-x1+1,y2-y1+1,char or " ")
end
function M:text(x, y, value, fg, bg, maxWidth)
  local sw, sh = self:size()
  x, y = math.floor(x), math.floor(y)
  if y<1 or y>sh or x>sw then return end
  local s = tostring(value or ""):gsub("[\r\n\t]", " ")
  local trimmed = math.max(0, 1-x)
  if trimmed>0 then s=s:sub(trimmed+1); x=1 end
  local capacity = sw-x+1
  if maxWidth ~= nil then capacity = math.min(capacity, math.floor(maxWidth)-trimmed) end
  if capacity<=0 then return end
  s=s:sub(1, capacity)
  if s=="" then return end
  self:colors(fg, bg)
  self.gpu.set(x,y,s)
end
function M:center(y, value, fg, bg)
  local w = self:size()
  local str = tostring(value or "")
  self:text(math.max(1, math.floor((w-#str)/2)+1),y,str,fg,bg)
end
function M:border(x,y,w,h,fg,bg)
  if w<2 or h<2 then return end
  self:text(x,y,"+"..string.rep("-",math.max(0,math.floor(w)-2)).."+",fg,bg)
  self:text(x,y+h-1,"+"..string.rep("-",math.max(0,math.floor(w)-2)).."+",fg,bg)
  for dy=1,h-2 do
    self:text(x,y+dy,"|",fg,bg)
    self:text(x+w-1,y+dy,"|",fg,bg)
  end
end
return M
