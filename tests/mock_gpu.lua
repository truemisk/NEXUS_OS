local M={}
function M.new(w,h,options)
  options=options or {}
  local current={w=w,h=h,fg=0xFFFFFF,bg=0x000000,depth=options.depth or 4}
  local buffer, history={},{}
  local gpu={address=options.address or "gpu-01",history=history,calls={fill=0,set=0}}
  local function clear()
    buffer={}
    for y=1,current.h do buffer[y]=string.rep(" ",current.w) end
  end
  clear()
  local function validate(x,y)
    assert(type(x)=="number" and type(y)=="number")
    assert(x>=1 and x<=current.w and y>=1 and y<=current.h,"GPU out of bounds: "..x..","..y)
  end
  local function setline(y,x,str)
    local line=buffer[y]
    buffer[y]=line:sub(1,x-1)..str..line:sub(x+#str)
  end
  function gpu.getResolution() return current.w,current.h end
  function gpu.maxResolution() return options.maxW or 80,options.maxH or 25 end
  function gpu.setResolution(a,b)
    assert(a>=1 and a<=(options.maxW or 80) and b>=1 and b<=(options.maxH or 25))
    current.w,current.h=a,b; clear(); return true
  end
  function gpu.getScreen() return options.screen or "screen-01" end
  function gpu.getDepth() return current.depth end
  function gpu.setDepth(value) current.depth=value; return true end
  function gpu.getBackground() return current.bg,false end
  function gpu.getForeground() return current.fg,false end
  function gpu.setBackground(value) current.bg=value; return true end
  function gpu.setForeground(value) current.fg=value; return true end
  function gpu.fill(x,y,width,height,ch)
    assert(width>0 and height>0)
    validate(x,y);validate(x+width-1,y+height-1)
    gpu.calls.fill=gpu.calls.fill+1
    for py=y,y+height-1 do setline(py,x,string.rep(ch,width)) end
  end
  function gpu.set(x,y,s)
    validate(x,y)
    assert(x+#s-1<=current.w,"GPU text out of bounds")
    gpu.calls.set=gpu.calls.set+1
    history[#history+1]={op="set",x=x,y=y,text=s,fg=current.fg,bg=current.bg}
    setline(y,x,s)
  end
  function gpu.snapshot() return table.concat(buffer,"\n") end
  function gpu.resize(w2,h2) current.w,current.h=w2,h2;clear() end
  return gpu
end
return M
