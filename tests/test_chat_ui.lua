local MiniTest = require("mini.test")
local eq = MiniTest.expect.equality
local child = require("mini.test").new_child_neovim()

local function get_lines(bufnr)
  return child.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function render(buf, content)
  child.lua(string.format("_G.chat = ChatUI.new({ bufnr = %d})", buf))
  child.lua(string.format("_G.chat:render(%s)", vim.inspect(content)))
end

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ "-u", "scripts/minimal_init.lua" })
      child.lua([[ChatUI = require("eca.chat.ui")]])
    end,
    post_once = child.stop,
  },
})

T["UI"] = MiniTest.new_set()

T["UI"]["render"] = function()
  local buf = child.lua_get("vim.api.nvim_create_buf(false, true)")
  render(buf, { messages = { { content = "foo\nbar\nbaz" } } })
  eq(get_lines(buf), { "foo", "bar", "baz" })
end

return T
