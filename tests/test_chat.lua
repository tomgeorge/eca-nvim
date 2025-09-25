local MiniTest = require("mini.test")
local helpers = require("tests.helpers")
local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ "-u", "scripts/minimal_init.lua" })
      child.lua([[
        server = require("tests.mock.server").new()
        mediator = require("eca.mediator").new(server)
        chat = require("eca.chat").new({mediator = mediator})
      ]])
    end,
    post_once = child.stop,
  },
})

T["Chat"] = MiniTest.new_set()
T["Chat"]["new"] = function()
  local chat = child.lua_get("chat")
  eq(chat.messages, {})
  eq(chat.contexts, { { type = "repoMap" } })
  eq(type(chat.ui), "table")

  local opts = {
    id = 5,
    ui = {
      windows = {
        chat = {
          buf = 3,
        },
      },
    },
  }

  chat = child.lua(
    [[
    opts = vim.tbl_deep_extend("keep", {mediator = mediator}, ...)
    chat = require("eca.chat").new(opts)
    return chat
  ]],
    { opts }
  )
  eq(chat.id, 5)
  eq(chat.ui.id, 5)
  eq(chat.ui.windows.chat.buf, 3)
  eq(chat.ui.windows.chat.win, nil)
end

T["Chat"]["push"] = function()
  local chat = child.lua([[
    chat:push("A test message")
    return chat
  ]])
  eq(chat.messages, { "A test message" })
end

T["Chat"]["is_open"] = function()
  local is_open = child.lua_get("chat:is_open()")
  eq(is_open, false)
  child.lua("chat:open()")
  is_open = child.lua_get("chat:is_open()")
  eq(is_open, true)
end

T["Chat"]["open"] = function()
  local chat = child.lua([[
    chat:push("message")
    chat:push("message 2")
    chat:push("message 3")
    chat:open()
    return chat
  ]])
  local lines = child.api.nvim_buf_get_lines(chat.ui.windows.chat.buf, 0, -1, false)
  local win = child.api.nvim_get_current_win()
  eq(chat.ui.windows.input.win, win)
  local screenshot = child.get_screenshot()
  MiniTest.expect.reference_screenshot(screenshot, nil, {})
  eq(#lines, 3)
end

T["Chat"]["close"] = function()
  child.lua([[
    chat:push("message")
    chat:push("message 2")
    chat:push("message 3")
    chat:open()
    chat:close()
    return chat
  ]])
  local is_open = child.lua_get("chat:is_open()")
  eq(is_open, false)
  local screenshot = child.get_screenshot()
  MiniTest.expect.reference_screenshot(screenshot, nil, {})
end

T["Chat"]["help"] = function()
  local chat = child.lua([[
    chat:open_help()
    return chat
  ]])

  local help_buf = child.lua_get("chat.ui.windows.help.buf")
  local lines = child.api.nvim_buf_get_lines(help_buf, 0, -1, false)
  local screenshot = child.get_screenshot()
  local expected = {
    "Close chat window         │ <leader>ax",
    "Show help                 │ g?",
    "Show server configuration │ <leader>ei",
    "Toggle context view       │ <leader>ct",
    "Toggle usage view         │ <leader>ut",
    "",
    "(Press `q` to close)",
  }

  eq(lines, expected)
  MiniTest.expect.reference_screenshot(screenshot, nil, {})
end

T["Chat"]["toggle context"] = function()
  local chat = child.lua([[
    chat:open()
    chat:toggle_context()
    return chat
  ]])
  local input_config = child.api.nvim_win_get_config(chat.ui.windows.input.win)
  eq(input_config.height, 10)
  eq(child.api.nvim_get_option_value("winfixheight", { win = chat.ui.windows.input.win }), true)
  local screenshot = child.get_screenshot()
  MiniTest.expect.reference_screenshot(screenshot, nil, {})
end

T["Chat"]["toggle usage"] = function()
  local chat = child.lua([[
    chat:open()
    chat:toggle_usage()
    return chat
  ]])
  local screenshot = child.get_screenshot()
  MiniTest.expect.reference_screenshot(screenshot, nil, {})
end

T["Chat"]["server info waiting"] = function()
  local chat = child.lua([[
    chat:open()
    chat:open_info()
    return chat
  ]])
  local lines = child.api.nvim_buf_get_lines(chat.ui.windows.info.buf, 0, -1, false)
  eq(lines, {
    "Waiting for server information",
    "",
    "Press 'q' to close",
  })
  local screenshot = child.get_screenshot()
  MiniTest.expect.reference_screenshot(screenshot, nil, {})
end

T["Chat"]["mappings can be overridden"] = function()
  local opts = {
    mappings = {
      close = "<Leader>xx",
      toggle_context = "ccc",
    },
  }
  local chat = child.lua(
    [[
    opts = vim.tbl_deep_extend("keep", { mediator = mediator}, ...)
    require("eca.chat").new(opts)
    chat:open_help()
    return chat
  ]],
    { opts }
  )
  local lines = child.api.nvim_buf_get_lines(chat.ui.windows.help.buf, 0, -1, false)
  local expected = {
    "Close chat window         │ <Leader>xx",
    "Show help                 │ g?",
    "Show server configuration │ <leader>ei",
    "Toggle context view       │ ccc",
    "Toggle usage view         │ <leader>ut",
    "",
    "(Press `q` to close)",
  }
  eq(lines, expected)
end

return T
