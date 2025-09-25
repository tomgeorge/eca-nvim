local MiniTest = require("mini.test")
local helpers = require("tests.helpers")
local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local cleanup_test_files = function()
  child.lua([[
    if _G.test_log_dir then
      vim.fn.delete(_G.test_log_dir, 'rf')
    end
  ]])
end

local T = MiniTest.new_set({
  hooks = {
    post_once = child.stop,
    post_case = cleanup_test_files,
    pre_case = function()
      child.restart({ "-u", "scripts/minimal_init.lua" })
      child.g.mapleader = " "
      helpers.mock_logging(child)
      helpers.mock_notify(child)
      child.lua([[
        require("eca").setup({
          log = {
            file = _G.test_log_dir .. "/test.log"
          },
          mappings = {
            chat = " ec",
          },
          chat = {
            use_experimental_ui = true,
            mappings = {
              close = "<Leader>cl",
            },
          },
        })
        require("mini.test").expect.equality(_G.did_mediator, 1)
      ]])
    end,
  },
})

T["integration"] = MiniTest.new_set()

T["integration"]["respects mappings"] = function()
  child.type_keys(200, " ec", "g?")
  local screenshot = child.get_screenshot()
  MiniTest.expect.reference_screenshot(screenshot, nil, {})
  ---@type eca.Chat
  local close_mapping = child.lua_get("_G.chats[1].mappings.close")
  eq(close_mapping, { "<Leader>cl", "Close chat window" })
end

T["integration"]["runs a command"] = function()
  child.type_keys(200, " ec", "i/config", "<C-s>")
  local screenshot = child.get_screenshot()
  MiniTest.expect.reference_screenshot(screenshot, nil, {})

  local chat_buf = child.lua_get("_G.chats[1].ui.windows.chat.buf")
  eq(child.api.nvim_buf_get_lines(chat_buf, 0, -1, false), { "Hi" })
end

return T
