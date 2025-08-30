local MiniTest = require("mini.test")
local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ "-u", "scripts/minimal_init.lua" })
      child.lua([[
        server = require("tests.mock.server").new()
        mediator = require("eca.mediator").new(server)
        sidebar = require("eca.sidebar").new(1, mediator)
        require("eca.config").options.windows.icons = false
      ]])
    end,
    post_once = child.stop,
  },
})

local function approve_tool_call()
  child.lua([[
    vim.api.nvim_feedkeys("y", "i", false)
    vim.api.nvim_feedkeys("y", "n", false)
  ]])
end

T["chat content"] = MiniTest.new_set()
T["chat content"]["append_to_chat"] = function()
  local text = child.lua([[
    server = require("tests.mock.server").new()
    mediator = require("eca.mediator").new(server)
    _G.sidebar = require("eca.sidebar").new(1, mediator)
    _G.sidebar:open()
    _G.sidebar:append_to_chat("messages ")
    _G.sidebar:append_to_chat("can come i")
    _G.sidebar:append_to_chat("n")
    _G.sidebar:append_to_chat(" as a stream")

    return vim.api.nvim_buf_get_lines(_G.sidebar.containers.chat.bufnr, 0, -1, false)
  ]])
  MiniTest.expect.equality(text[#text], "messages can come in as a stream")
end

T["chat content"]["renders a user's prompt"] = function()
  local prompt = require("tests.stubs.chat_prompt")
  local text = child.lua(
    [[
    sidebar:open()
    server:handle(...)
    return vim.api.nvim_buf_get_lines(_G.sidebar.containers.chat.bufnr, 0, -1, false)
  ]],
    { prompt }
  )
  approve_tool_call()
  local screenshot = child.get_screenshot()
  eq(child.lua_get("_G.on_approve"), 1)
  eq(#text, 35)
  MiniTest.expect.reference_screenshot(screenshot, nil, {})
end
return T
