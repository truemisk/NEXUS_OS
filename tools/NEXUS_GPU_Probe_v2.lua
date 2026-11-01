-- NEXUS GPU probe v2 - read-only. No GPU binds or screen writes.
local component = require("component")
local term = require("term")
local computer = require("computer")
local function show(label, fn)
  local ok, a, b = pcall(fn)
  if ok then
    print(label .. ": " .. tostring(a) .. (b ~= nil and (", " .. tostring(b)) or ""))
  else
    print(label .. ": ERROR " .. tostring(a))
  end
end
local g = term.gpu()
print("NEXUS GPU PROBE v2 (READ-ONLY)")
print("Terminal GPU: " .. tostring(g and g.address))
show("Terminal screen", function() return term.screen() end)
if g then
  print("Methods getResolution/set/fill: " .. type(g.getResolution) .. "/" .. type(g.set) .. "/" .. type(g.fill))
  if type(g.getResolution) == "function" then
    show("Terminal proxy resolution", function() return g.getResolution() end)
  end
  if type(component.invoke) == "function" and type(g.address) == "string" then
    show("Terminal invoke resolution", function() return component.invoke(g.address, "getResolution") end)
    show("Terminal invoke screen", function() return component.invoke(g.address, "getScreen") end)
  end
end
for address in component.list("gpu", true) do
  local gpu = component.proxy(address)
  print("GPU " .. address:sub(1,8))
  show("  screen", function() return gpu.getScreen() end)
  if type(gpu.getResolution) == "function" then
    show("  proxy resolution", function() return gpu.getResolution() end)
  else
    print("  proxy getResolution type: " .. type(gpu.getResolution))
  end
  if type(component.invoke) == "function" then
    show("  invoke resolution", function() return component.invoke(address, "getResolution") end)
  end
end
show("Free memory KiB", function() return math.floor(computer.freeMemory()/1024) end)
print("END - NO SETTINGS CHANGED")
