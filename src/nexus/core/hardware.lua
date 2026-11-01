-- NEXUS: read-only GPU discovery, with direct-proxy/invoke compatibility.
-- Never binds GPUs, changes OpenOS terminal devices or changes EEPROM.
local M = {}

local function attempt(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b = pcall(fn, ...)
  if ok then return a, b end
end

-- OpenComputers supports invoking component methods either through a proxy
-- or by component.invoke(address, method, ...). Some proxy/wrapper variants
-- can expose a missing or failing proxy method even when invocation works.
-- Only use the invocation fallback on a failed direct call.
local function wrapGpu(component, raw)
  if not raw or type(raw.address) ~= "string" then return nil end
  local address = raw.address
  local adapter = {address = address}
  local methods = {
    "getScreen", "getResolution", "maxResolution", "getDepth", "setDepth",
    "getForeground", "getBackground", "setForeground", "setBackground",
    "set", "fill", "setResolution"
  }
  for _, name in ipairs(methods) do
    local methodName = name
    adapter[methodName] = function(...)
      local direct = raw[methodName]
      local reason = "proxy method unavailable"
      if type(direct) == "function" then
        local ok, a, b, c = pcall(direct, ...)
        -- A successful call returning no resolution is also unusable.
        -- Try the low-level invocation before rejecting the GPU.
        if ok and (methodName ~= "getResolution" or
            (type(a) == "number" and type(b) == "number" and a > 0 and b > 0)) then
          return a, b, c
        end
        if ok then
          reason = "invalid resolution " .. tostring(a) .. " x " .. tostring(b)
        else
          reason = tostring(a)
        end
      end
      if component and type(component.invoke) == "function" then
        -- If this call also fails, preserve the API error for the caller.
        return component.invoke(address, methodName, ...)
      end
      error("GPU " .. methodName .. " failed: " .. reason, 2)
    end
  end
  return adapter
end

local function screenOf(gpu)
  if not gpu then return nil end
  local screen = attempt(gpu.getScreen)
  if type(screen) == "string" and screen ~= "" then return screen end
end

local function checkResolution(gpu)
  if not gpu then return nil, "GPU proxy unavailable" end
  local ok, w, h = pcall(gpu.getResolution)
  if not ok then return nil, "getResolution: " .. tostring(w) end
  if type(w) ~= "number" or type(h) ~= "number" or w < 1 or h < 1 then
    return nil, "getResolution returned " .. tostring(w) .. " x " .. tostring(h)
  end
  return true
end

function M.new(component, computer, term)
  local self = {component=component, computer=computer, term=term}
  local terminalRaw = attempt(term and term.gpu)
  local terminalScreen = attempt(term and term.screen)
  local terminalGpu = wrapGpu(component, terminalRaw)
  if type(terminalScreen) ~= "string" or terminalScreen == "" then
    terminalScreen = screenOf(terminalGpu)
  end

  local gpu, screen
  local failures = {}
  local function consider(candidate, label, knownScreen)
    if not candidate then return false end
    local boundScreen = screenOf(candidate)
    local target = knownScreen or boundScreen
    if not target then
      failures[#failures+1] = label .. ": no bound screen"
      return false
    end
    -- Never select an unrelated display when a terminal screen is known.
    if knownScreen and boundScreen and boundScreen ~= knownScreen then
      failures[#failures+1] = label .. ": different screen"
      return false
    end
    local usable, why = checkResolution(candidate)
    if not usable then
      failures[#failures+1] = label .. ": " .. why
      return false
    end
    gpu, screen = candidate, target
    return true
  end

  -- The functioning OpenOS terminal is authoritative. No GPU rebinding.
  consider(terminalGpu, "terminal GPU", terminalScreen)

  if not gpu and component and type(component.list) == "function" then
    local iterator = attempt(component.list, "gpu", true)
    if type(iterator) == "function" then
      local fallbackGpu, fallbackScreen
      for address in iterator do
        local raw = attempt(component.proxy, address)
        local candidate = wrapGpu(component, raw)
        if candidate and (not terminalGpu or candidate.address ~= terminalGpu.address) then
          local candidateScreen = screenOf(candidate)
          if candidateScreen and (not terminalScreen or candidateScreen == terminalScreen) then
            local usable, why = checkResolution(candidate)
            if usable then
              fallbackGpu, fallbackScreen = candidate, candidateScreen
              break
            else
              failures[#failures+1] = address:sub(1, 8) .. ": " .. why
            end
          end
        end
      end
      if fallbackGpu then gpu, screen = fallbackGpu, fallbackScreen end
    else
      failures[#failures+1] = "GPU enumeration unavailable"
    end
  end

  if not gpu then
    local addr = terminalGpu and terminalGpu.address or "none"
    local why = table.concat(failures, "; ")
    if why == "" then why = "no usable bound GPU found" end
    return nil, "No usable GPU/screen pair (GPU " .. tostring(addr)
      .. ", screen " .. tostring(terminalScreen) .. "). " .. why
      .. ". No GPU bindings were changed."
  end
  self.gpu = gpu
  self.screen = screen
  self.keyboard = attempt(term and term.keyboard)
  self.keyboards = {}
  if type(self.keyboard) == "string" and self.keyboard ~= "no_system_keyboard" then
    self.keyboards[self.keyboard] = true
  end
  local screenProxy = attempt(component and component.proxy, self.screen)
  if screenProxy and type(screenProxy.getKeyboards) == "function" then
    local attached = attempt(screenProxy.getKeyboards)
    if type(attached) == "table" then
      for _, address in pairs(attached) do self.keyboards[address] = true end
    end
  end
  return setmetatable(self, {__index=M})
end

function M:resolution()
  local w, h = attempt(self.gpu.getResolution)
  if type(w) ~= "number" or type(h) ~= "number" then
    return nil, nil
  end
  return math.floor(w), math.floor(h)
end

function M:snapshot()
  local w, h = self:resolution()
  local maxW, maxH = attempt(self.gpu.maxResolution)
  local n = 0
  local gpus, screens = 0, 0
  if self.component and type(self.component.list) == "function" then
    local ok, iterator = pcall(self.component.list)
    local mt=type(iterator)=='table' and getmetatable(iterator) or nil
    if ok and (type(iterator)=='function' or (type(mt)=='table' and type(mt.__call)=='function')) then
      for _, kind in iterator do
        n = n + 1
        if kind == "gpu" then gpus = gpus + 1 end
        if kind == "screen" then screens = screens + 1 end
      end
    end
  end
  return {
    resolutionW = w, resolutionH = h,
    maxW = maxW, maxH = maxH,
    depth = attempt(self.gpu.getDepth),
    freeMemory = attempt(self.computer and self.computer.freeMemory),
    totalMemory = attempt(self.computer and self.computer.totalMemory),
    uptime = attempt(self.computer and self.computer.uptime),
    componentCount = n,
    gpuCount = gpus, screenCount = screens,
    screen = self.screen,
    gpuAddress = self.gpu.address or "unknown"
  }
end

function M:acceptKeyboard(address)
  if type(address) ~= "string" then return false end
  if next(self.keyboards) == nil then
    -- When screen keyboard enumeration is unavailable, accept keyboard signals.
    return true
  end
  return self.keyboards[address] == true
end

return M
