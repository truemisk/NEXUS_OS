from pathlib import Path
root=Path(__file__).resolve().parent.parent
parts=['-- NEXUS MAINTENANCE v0.5.0 | safe CLI fallback']
for name in ['update','startup']:
    src=(root/'src/nexus/core'/f'{name}.lua').read_text()
    parts.extend([f'package.preload["nexus.core.{name}"] = function(...)', src, 'end'])
parts += [r'''
local Up=require('nexus.core.update').new()
local St=require('nexus.core.startup').new()
local args={...}
local op=args[1] or 'status'
if op=='status' then
  print('NEXUS autostart: '..St:status())
  print('Core: '..(St.fs.exists('/home/osv4.lua') and 'installed' or 'missing'))
  print('Guard: '..(St.fs.exists('/home/nexus/startup.guard') and 'present' or 'clear'))
  print('Staged: '..tostring(Up:stagedVersion() or 'none'))
  print('Previous release: '..(Up.fs.exists(Up.BACKUP) and 'available' or 'none'))
elseif op=='enable' then
  if args[2]~='YES' then print('Use: nexus-maint.lua enable YES');return end
  local ok,err=St:enable();print(ok and 'Autostart enabled' or tostring(err))
elseif op=='disable' then
  local ok,err=St:disable();print(ok and 'Autostart disabled' or tostring(err))
elseif op=='recover' then
  local ok,err=St:recover();print(ok and 'Guard cleared' or tostring(err))
elseif op=='rollback' then
  if args[2]~='YES' then print('Use: nexus-maint.lua rollback YES');return end
  local ok,err=Up:rollback();print(ok and 'Previous OS restored. Launch /home/osv4.lua' or tostring(err))
else
 print('Usage: nexus-maint.lua status | enable YES | disable | recover | rollback YES')
end
''']
(root/'dist'/'nexus-maint.lua').write_text('\n'.join(parts)+'\n')
print('built maintenance CLI', (root/'dist'/'nexus-maint.lua').stat().st_size)
