---@class FakeServer
---@field messages string[]
---@field is_running boolean
local FakeServer = {}
_G.notifications = {}

function FakeServer.new()
  return setmetatable({
    messages = {},
    is_running = true,
  }, { __index = FakeServer })
end

function FakeServer:running()
  return self.is_running
end

function FakeServer:handle(messages)
  for _, message in ipairs(messages) do
    require("mini.test").expect.equality(type(message), "string")
    table.insert(self.messages, vim.json.decode(message))
    require("eca.observer").notify(vim.json.decode(message))
  end
end

return FakeServer
