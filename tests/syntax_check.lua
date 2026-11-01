package.path='./src/?.lua;'..package.path
for _,file in ipairs({'nexus.main','nexus.core.config','nexus.core.logger','nexus.core.services','nexus.core.session','nexus.core.recovery','nexus.core.performance','nexus.core.diagnostics','nexus.apps.control'}) do
 local ok,err=pcall(require,file)
 assert(ok,file..' => '..tostring(err))
end
print('MODULE LOAD PASS')
