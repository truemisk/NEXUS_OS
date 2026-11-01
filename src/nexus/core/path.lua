-- Absolute, lexical paths; does not follow links. Never evaluate user input.
local M={}
function M.normalize(p,cwd)
  if type(p)~='string' or p=='' or #p>512 or p:find('%z') or p:find('[\r\n]') then
    return nil,'Invalid path'
  end
  if p:sub(1,1)~='/' then p=(cwd or '/home')..'/'..p end
  local parts={}
  for part in p:gmatch('[^/]+') do
    if part=='..' then if #parts>0 then table.remove(parts) end
    elseif part~='.' and part~='' then parts[#parts+1]=part end
  end
  return '/'..table.concat(parts,'/')
end
function M.parent(p)
  if p=='/' then return '/' end
  return p:match('^(.+)/[^/]+$') or '/'
end
function M.name(p)
  if p=='/' then return '/' end
  return p:match('([^/]+)$') or '/'
end
function M.join(a,b) return M.normalize(a..'/'..b) end
-- Prevent accidental damage to the OS, NEXUS executable and settings.
local protected={'/boot','/bin','/lib','/etc','/dev','/mnt','/usr','/tmp','/init.lua',
  '/home/nexus', '/home/nexus11.lua','/home/nexus12.lua','/home/nexus20.lua',
  '/home/nexus30.lua','/home/nexus40.lua','/home/nexus-startup.lua',
  '/home/nexus40-bootstrap.lua','/home/osv4.lua','/home/nexus-boot.lua','/home/nexus-startup.lua','/home/.shrc','/home/.shrc.nexus-prev',
  '/home/nexusOS.lua','/home/nexusOS-opt.lua'}
function M.mutable(path)
  if path=='/' then return false,'Root is protected' end
  for _,base in ipairs(protected) do
    if path==base or path:sub(1,#base+1)==base..'/' then
      return false,'Protected system/NEXUS path'
    end
  end
  return true
end
function M.simpleName(s)
  return type(s)=='string' and #s>0 and #s<=100
    and s~='.' and s~='..' and not s:find('[/\\%z\r\n]') and not s:find('[%c]')
end
return M
