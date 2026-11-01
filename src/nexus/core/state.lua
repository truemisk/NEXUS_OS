local M={}
function M.new()
  return {running=true,selection=1,scroll=0,settingsSelection=1,
    notificationScroll=0,displayIndex=1,dirty=true,hitboxes={},appHitboxes={},
    navboxes={},lastStatus=-1,lastPreview=-1,redraws=0,screenMode='compact'}
end
return M
