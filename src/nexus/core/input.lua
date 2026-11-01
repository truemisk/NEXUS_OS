-- Minecraft-safe defaults: no F1-F12 shortcuts (Minecraft captures them).
local M={}
local keyMap={up='up',down='down',left='left',right='right',enter='enter',
 numpadenter='enter',esc='back',tab='tab',backspace='backspace',delete='delete',
 home='linehome',['end']='lineend',pageUp='pageup',pageDown='pagedown',prior='pageup',next='pagedown'}
local fallback={up=200,down=208,left=203,right=205,enter=28,numpadenter=156,
 esc=1,tab=15,backspace=14,delete=211,home=199,['end']=207,pageUp=201,pageDown=209,prior=201,next=209}
function M.decode(kind,a,b,c,hardware,keys,d)
  if kind=='screen_resized' or kind=='screen_resize' then
    return a==hardware.screen and {kind='resize'} or nil
  end
  if kind=='touch' then
    if a==hardware.screen and type(b)=='number' and type(c)=='number' then
      return {kind='touch',x=math.floor(b),y=math.floor(c)}
    end
    return nil
  end
  if kind=='scroll' and a==hardware.screen then
    return {kind='scroll',x=math.floor(b or 1),y=math.floor(c or 1),delta=tonumber(d) or 0}
  end
  if kind=='interrupted' then return {kind='quit'} end
  if kind=='clipboard' and hardware:acceptKeyboard(a) and type(b)=='string' then
    return {kind='paste',value=b:sub(1,512)}
  end
  if kind~='key_down' or not hardware:acceptKeyboard(a) then return nil end
  for key,action in pairs(keyMap) do
    if c==((keys or {})[key] or fallback[key]) then return {kind=action} end
  end
  if type(b)=='number' and b>=32 and b<=126 then return {kind='char',value=string.char(b)} end
  return nil
end
return M
