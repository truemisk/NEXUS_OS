local Widgets=require('nexus.ui.widgets')
local M={}
function M.entries(manager)
  local items={}
  for _,app in ipairs(manager.items) do items[#items+1]={id=app.id,name=app.name,description=app.description or 'Application'} end
  items[#items+1]={id='__exit',name='Exit NEXUS',description='Return safely to OpenOS'}
  return items
end
function M.draw(ctx)
  local g,t,s=ctx.gfx,ctx.theme,ctx.state
  local w,h=g:size()
  Widgets.frame(ctx,'DESKTOP / APPLICATIONS')
  s.hitboxes={}
  if w<20 or h<8 then g:text(1,3,'Enlarge screen',t.bad,t.bg); return end
  local entries=M.entries(ctx.manager)
  s.selection=math.max(1,math.min(#entries,s.selection))
  local standard=s.screenMode=='standard'
  if standard then
    local hs=ctx.hardware:snapshot()
    g:text(3,4,'SYSTEM READY',t.good,t.bg)
    g:text(3,5,'OPEN WITH ENTER / TOUCH   |   1-9 DIRECT LAUNCH',t.muted,t.bg,w-6)
    local withPanel=w>=100
    local left=withPanel and math.floor(w*0.64) or w-3
    local gap=2
    local tileW=math.floor((left-3*2-gap)/2)
    local tileH=h>=29 and 3 or 2
    for i,entry in ipairs(entries) do
      local col=(i-1)%2; local row=math.floor((i-1)/2)
      local x=3+col*(tileW+gap)
      local y=7+row*tileH
      if y+tileH-1<h-1 and tileW>=10 then
        Widgets.action(g,t,x,y,tileW,tileH,tostring(i)..'  '..entry.name,entry.description,i==s.selection)
        s.hitboxes[#s.hitboxes+1]={x=x,y=y,w=tileW,h=tileH,id=entry.id,index=i}
      end
    end
    if withPanel then
      local px=left+2; local pw=w-px-2
      Widgets.panel(g,t,px,7,pw,12,'LIVE / STATUS')
      local rows={
        'GPU  '..tostring(hs.gpuAddress or '?'):sub(1,8),
        'RAM  '..(type(hs.freeMemory)=='number' and math.floor(hs.freeMemory/1024)..' KiB' or '?'),
        'SIZE '..tostring(hs.resolutionW or '?')..'x'..tostring(hs.resolutionH or '?'),
        'DEPTH '..tostring(hs.depth or '?')..' bit',
        'UP '..(type(hs.uptime)=='number' and math.floor(hs.uptime)..' s' or '?'),
        'THEME '..ctx.config.data.theme:upper()
      }
      for j,line in ipairs(rows) do g:text(px+2,8+j,line,t.text,t.surface,pw-4) end
    end
  else
    g:text(2,3,'APPLICATIONS / 1-9  / '..ctx.config.data.theme:upper(),t.accent,t.bg,w-3)
    local count=math.max(1,math.floor((h-5)/2))
    if s.selection<s.scroll+1 then s.scroll=s.selection-1 end
    if s.selection>s.scroll+count then s.scroll=s.selection-count end
    s.scroll=math.max(0,math.min(s.scroll,math.max(0,#entries-count)))
    for slot=1,count do
      local i=s.scroll+slot; local entry=entries[i]
      if entry then
        local y=4+(slot-1)*2
        Widgets.action(g,t,2,y,w-4,2,tostring(i)..'  '..entry.name,entry.description,i==s.selection)
        s.hitboxes[#s.hitboxes+1]={x=2,y=y,w=w-4,h=2,id=entry.id,index=i}
      end
    end
    if #entries>count then g:text(w-7,3,(s.scroll+1)..'-'..math.min(#entries,s.scroll+count)..'/'..#entries,t.muted,t.bg,7) end
  end
end
return M
