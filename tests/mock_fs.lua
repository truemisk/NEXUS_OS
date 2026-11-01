local M={}
function M.new()
  local nodes={['/']={dir=true},['/home']={dir=true},['/home/demo']={dir=true},
    ['/home/demo/a.txt']={data='alpha\nbeta\n'},['/home/demo/b.bin']={data='abc\0def'},
    ['/home/demo/empty']={dir=true},['/boot']={dir=true},['/boot/boot.lua']={data='boot'}}
  local fs={nodes=nodes}
  function fs.exists(path) return nodes[path]~=nil end
  function fs.isDirectory(path) return nodes[path] and nodes[path].dir or false end
  function fs.size(path) return nodes[path] and #(nodes[path].data or '') or 0 end
  function fs.list(path)
    if not nodes[path] or not nodes[path].dir then return nil,'not a folder' end
    local items={}
    for p,n in pairs(nodes) do
      if p~=path and p:sub(1,#path+1)==(path=='/' and '/' or path..'/') then
        local suffix=p:sub(#path+(path=='/' and 1 or 2))
        if suffix~='' and not suffix:find('/') then items[#items+1]=suffix..(n.dir and '/' or '') end
      end
    end
    table.sort(items)
    local i=0
    return function() i=i+1;return items[i] end
  end
  function fs.copy(src,dst)
    if not nodes[src] or nodes[src].dir or nodes[dst] then return nil,'not copyable' end
    nodes[dst]={data=nodes[src].data};return true
  end
  function fs.rename(src,dst)
    if not nodes[src] or nodes[dst] then return nil,'cannot rename' end
    nodes[dst]=nodes[src];nodes[src]=nil;return true
  end
  function fs.makeDirectory(path)
    if nodes[path] then return nil,'exists' end
    nodes[path]={dir=true};return true
  end
  function fs.remove(path)
    if not nodes[path] then return nil,'missing' end
    nodes[path]=nil;return true
  end
  function fs.get(path)
    return {spaceTotal=function() return 1000000 end,spaceUsed=function() return 500000 end,
      isReadOnly=function() return false end}
  end
  local function open(path,mode)
    if mode~='rb' then return nil,'unsupported mock mode' end
    local node=nodes[path];if not node or node.dir then return nil,'missing' end
    local closed=false
    return {read=function(_,size) assert(not closed);return node.data:sub(1,size) end,
      close=function() closed=true end}
  end
  return fs,open
end
return M
