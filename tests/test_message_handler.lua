local MiniTest = require("mini.test")
local eq = MiniTest.expect.equality
local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ "-u", "scripts/minimal_init.lua" })
    end,
    post_case = function()
      child.lua("if _G.proc then _G.proc:kill() end")
    end,
    post_once = child.stop,
  },
})

local function grab_message(data)
  child.lua("_G.data =" .. vim.inspect(data))
  eq(child.lua_get("_G.data"), data)
  return child.lua_get("require('eca.message_handler').parse_raw_messages(_G.data)")
end

T["message handling"] = MiniTest.new_set({
  parametrize = {
    { 'Content-Length: 18\n\n{"jsonrpc": "1.0"}', { { content_length = 18, content = '{"jsonrpc": "1.0"}' } } },
    {
      'Content-Length: 18\n\n{"jsonrpc": "1.0"}Content-Length: 18\n\n{"jsonrpc": "2.0"}',
      {
        { content_length = 18, content = '{"jsonrpc": "1.0"}' },
        { content_length = 18, content = '{"jsonrpc": "2.0"}' },
      },
    },
    { "", {} },
    { "not a message", {} },
  },
})
T["message handling"]["parses one message"] = function(input, want)
  local got = grab_message(input)
  eq(got, want)
end

return T
