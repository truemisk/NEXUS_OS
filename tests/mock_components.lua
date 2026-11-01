local M={}
function M.new(gpus,options)
  options=options or {}
  local proxies={}
  for _,gpu in ipairs(gpus or {}) do proxies[gpu.address]=gpu end
  local screens=options.screens or {"screen-01"}
  for _,screen in ipairs(screens) do
    proxies[screen]={getKeyboards=function() return options.keyboards or {"keyboard-01"} end}
  end
  local components={}
  function components.proxy(address)
    assert(proxies[address],"Unknown component: "..tostring(address))
    return proxies[address]
  end
  function components.list(filter)
    local records={}
    for _,gpu in ipairs(gpus or {}) do records[#records+1]={gpu.address,"gpu"} end
    for _,s in ipairs(screens) do records[#records+1]={s,"screen"} end
    for _,kind in ipairs(options.extra or {}) do records[#records+1]={kind.."-01",kind} end
    local i=0
    return function()
      repeat
        i=i+1
        if not records[i] then return nil end
      until not filter or records[i][2]==filter
      return records[i][1],records[i][2]
    end
  end
  return components
end
function M.computer()
  local uptime=0
  return {
    freeMemory=function() return 204800 end,
    totalMemory=function() return 393216 end,
    uptime=function() uptime=uptime+0.25; return uptime end
  }
end
function M.term(gpu)
  local term={cursor={1,1},blink=true}
  function term.gpu() return gpu end
  function term.screen() return gpu and gpu.getScreen() or nil end
  function term.keyboard() return "keyboard-01" end
  function term.setCursor(x,y) term.cursor={x,y} end
  function term.setCursorBlink(b) term.blink=b end
  function term.getCursorBlink() return term.blink end
  return term
end
function M.events(sequence, gpu)
  local i=0
  local snaps={}
  return {
    snaps=snaps,
    pull=function(_)
      snaps[#snaps+1]=gpu.snapshot()
      i=i+1
      if i>1000 then error("Too many events") end
      local item=sequence[i]
      if not item then error("Mock event queue exhausted; the OS did not exit") end
      if type(item)=="function" then item(); return nil end
      return table.unpack(item)
    end
  }
end
return M
