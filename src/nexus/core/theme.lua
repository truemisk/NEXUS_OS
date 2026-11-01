-- RGB targets; OpenComputers GPU quantizes to the configured color depth.
local M = {}
M.names = {"cyan", "green", "amber"}
local palettes = {
  cyan  = {bg=0x10151D,surface=0x202C3A,muted=0x91A5B9,border=0x394C61,text=0xE5ECF4,accent=0x48CBDC,activeBg=0x48CBDC,activeText=0x10151D,good=0x64DAA0,bad=0xF16B6B,warn=0xF5C76D},
  green = {bg=0x08120C,surface=0x19281B,muted=0x80A78A,border=0x37563B,text=0xD6F4D8,accent=0x68E596,activeBg=0x68E596,activeText=0x08120C,good=0x68E596,bad=0xF17878,warn=0xF3C56C},
  amber = {bg=0x19130B,surface=0x302619,muted=0xB9A183,border=0x655136,text=0xF3E2C3,accent=0xF5BD66,activeBg=0xF5BD66,activeText=0x19130B,good=0xB2D88E,bad=0xEF877B,warn=0xF5BD66}
}
function M.select(depth, name)
  if type(depth) ~= 'number' or depth <= 1 then
    return {bg=0x000000,surface=0x000000,muted=0xFFFFFF,border=0xFFFFFF,text=0xFFFFFF,accent=0xFFFFFF,activeBg=0xFFFFFF,activeText=0x000000,good=0xFFFFFF,bad=0xFFFFFF,warn=0xFFFFFF,monochrome=true,name='mono'}
  end
  local chosen = palettes[name] and name or 'cyan'
  local t = {}
  for k,v in pairs(palettes[chosen]) do t[k]=v end
  t.name=chosen
  return t
end
function M.next(name)
  for i,n in ipairs(M.names) do
    if n==name then return M.names[i % #M.names + 1] end
  end
  return M.names[1]
end
return M
