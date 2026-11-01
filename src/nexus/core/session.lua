local M={}
function M.new(now)
  return setmetatable({started=now or 0,opened=0,lastApp='none',current='desktop',transitions=0},{__index=M})
end
function M:open(id) self.current=id;self.lastApp=id;self.opened=self.opened+1;self.transitions=self.transitions+1 end
function M:home() if self.current~='desktop' then self.transitions=self.transitions+1 end;self.current='desktop' end
return M
