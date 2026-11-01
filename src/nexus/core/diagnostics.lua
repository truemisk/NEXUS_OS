local M={}
function M.run(ctx)
  local result={}
  local function check(id,condition,value)
    result[#result+1]={id=id,ok=condition==true,detail=tostring(value or ''):sub(1,85)}
  end
  local ok,hw=pcall(ctx.hardware.snapshot,ctx.hardware)
  hw=ok and hw or {}
  check('GPU',type(hw.gpuAddress)=='string' and hw.gpuAddress~='',hw.gpuAddress)
  check('DISPLAY',type(hw.resolutionW)=='number' and hw.resolutionW>0 and type(hw.resolutionH)=='number' and hw.resolutionH>0,
    tostring(hw.resolutionW or '?')..' x '..tostring(hw.resolutionH or '?'))
  check('GPU DEPTH',type(hw.depth)=='number' and hw.depth>=1,tostring(hw.depth or '?')..' bit')
  check('MEMORY',type(hw.freeMemory)=='number' and hw.freeMemory>0 and type(hw.totalMemory)=='number' and hw.totalMemory>0,
    tostring(math.floor((hw.freeMemory or 0)/1024))..' / '..tostring(math.floor((hw.totalMemory or 0)/1024))..' KiB free/total')
  check('COMPONENTS',type(hw.componentCount)=='number' and hw.componentCount>=2,hw.componentCount)
  local fs=ctx.fs
  if not fs then local okFs,obj=pcall(require,'filesystem');fs=okFs and obj or nil end
  local writable=nil
  if fs and type(fs.get)=='function' then
    local okDisk,disk=pcall(fs.get,'/home')
    if okDisk and disk and type(disk.isReadOnly)=='function' then
      local worked,ro=pcall(disk.isReadOnly);if worked then writable=not ro end
    end
  end
  check('HOME STORAGE',writable==true,writable==nil and 'not checked' or (writable and 'writable' or 'read-only'))
  check('LOGGER',ctx.logger.diskStatus=='PERSISTENT',ctx.logger.diskStatus)
  local failures=0
  for _,s in ipairs(ctx.services.ordered) do if s.status=='FAILED' then failures=failures+1 end end
  check('SERVICES',failures==0,failures..' failed')
  return result
end
return M
