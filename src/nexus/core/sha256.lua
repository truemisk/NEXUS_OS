-- Pure Lua 5.3 streaming SHA-256 for OpenComputers (no Data Card required).
-- Only stores one 64-byte compression block and a bounded read buffer.
local M={}
local MASK=0xffffffff
local K={
  0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
  0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
  0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
  0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
  0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
  0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
  0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
  0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
}
local H0={0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19}
local function ror(x,n) return ((x>>n)|(x<<(32-n))) & MASK end
local function hashBlock(h,block)
  local w={}
  for i=1,16 do
    local a,b,c,d=block:byte(i*4-3,i*4)
    w[i]=((a<<24)|(b<<16)|(c<<8)|d)&MASK
  end
  for i=17,64 do
    local x,y=w[i-15],w[i-2]
    local s0=ror(x,7)~ror(x,18)~(x>>3)
    local s1=ror(y,17)~ror(y,19)~(y>>10)
    w[i]=(w[i-16]+s0+w[i-7]+s1)&MASK
  end
  local a,b,c,d,e,f,g,z=table.unpack(h)
  for i=1,64 do
    local s1=ror(e,6)~ror(e,11)~ror(e,25)
    local ch=(e&f)~((~e)&g)
    local t1=(z+s1+ch+K[i]+w[i])&MASK
    local s0=ror(a,2)~ror(a,13)~ror(a,22)
    local maj=(a&b)~(a&c)~(b&c)
    local t2=(s0+maj)&MASK
    z,g,f,e,d,c,b,a=g,f,e,(d+t1)&MASK,c,b,a,(t1+t2)&MASK
  end
  local values={a,b,c,d,e,f,g,z}
  for i=1,8 do h[i]=(h[i]+values[i])&MASK end
end
local function new()
  local h={table.unpack(H0)}
  local tail=''
  local size=0
  local blocks=0
  local obj={}
  function obj:update(chunk)
    assert(type(chunk)=='string','SHA-256 input must be a string')
    size=size+#chunk
    local data=tail..chunk
    local index=1
    while index+63<=#data do
      hashBlock(h,data:sub(index,index+63))
      index=index+64
      blocks=blocks+1
      -- Yield to OpenComputers occasionally during lengthy verification.
      if blocks%128==0 and type(os.sleep)=='function' then pcall(os.sleep,0) end
    end
    tail=data:sub(index)
  end
  function obj:finish()
    assert(size < 0x20000000,'SHA-256 input too large for NEXUS updater')
    local bitlen=size*8
    local padding='\128'..string.rep('\0',(56-(size+1)%64)%64)
    local high=math.floor(bitlen/4294967296)
    local low=bitlen%4294967296
    local function be32(x)
      return string.char((x>>24)&255,(x>>16)&255,(x>>8)&255,x&255)
    end
    local data=tail..padding..be32(high)..be32(low)
    for index=1,#data,64 do hashBlock(h,data:sub(index,index+63)) end
    return string.format('%08x%08x%08x%08x%08x%08x%08x%08x',table.unpack(h))
  end
  return obj
end
M.new=new
function M.sum(input)
  local h=new();h:update(input);return h:finish()
end
function M.file(path,open,limit)
  local f,reason=(open or io.open)(path,'rb')
  if not f then return nil,'Cannot open SHA file: '..tostring(reason) end
  local h=new();local bytes=0
  local ok,result=pcall(function()
    while true do
      local chunk=f:read(4096)
      if not chunk or chunk=='' then break end
      bytes=bytes+#chunk
      if limit and bytes>limit then error('File exceeds SHA size limit') end
      h:update(chunk)
    end
    return h:finish()
  end)
  pcall(function()f:close()end)
  if not ok then return nil,tostring(result) end
  return result,bytes
end
return M
