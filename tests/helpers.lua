local FakeServer = {}

function FakeServer:new()
  return setmetatable({
    messages = {},
    is_running = true,
  }, { __index = FakeServer })
end

function FakeServer:is_running()
  return self.is_running
end

return FakeServer
