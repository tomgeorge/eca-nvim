local MiniTest = require("mini.test")
local eq = MiniTest.expect.equality
local child = require("mini.test").new_child_neovim()

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
T["UI"]["open"] = function()
  local foo = child.lua_get([[ChatUI.new({
  bufnr = 4,
  winnr = 5,
  chat_id = 1
  })]])
  eq({ bufnr = 4, winnr = 5, chat_id = 1 }, foo)
end

T["UI"]["render"] = function()
  local lines = child.lua([[
  ChatUI.new({ bufnr = 0 }):render({ messages = { content = "foo" }})
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
  ]])
  eq(lines, { "a b c d e f g" })
end

---@param messages {content: string}[]
local function doit(messages)
  return vim
    .iter(messages)
    :map(function(msg)
      return msg.content
    end)
    :fold({}, function(acc, msg)
      for _, m in ipairs(vim.split(msg, "\n")) do
        table.insert(acc, m)
      end
      return acc
    end)
end

T["messin"] = MiniTest.new_set()
T["messin"]["around"] = function()
  eq(doit({ { content = "hi" } }), { "hi" })
  eq(doit({ { content = "omg" }, { content = "hi" }, { content = "hello\nthere" } }), { "omg", "hi", "hello", "there" })
end

return T
