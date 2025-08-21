local MiniTest = require("mini.test")
local helpers = dofile("tests/helpers.lua")
local child = MiniTest.new_child_neovim()
local eq = MiniTest.expect.equality
local new_set = MiniTest.new_set

local T = new_set({
  hooks = {
    pre_case = function()
      child.restart({ "-u", "scripts/minimal_init.lua" })
    end,
    post_case = function()
      child.lua("_G.chat = nil")
    end,
    post_once = child.stop,
  },
})

---@param message eca.Message
local function write_message(message)
  child.lua(string.format("_G.chat:add_message(%s)", vim.inspect(message)))
end

T["Chat"] = new_set()
T["Chat"]["new()"] = function()
  ---@type eca.Chat
  local chat = child.lua_get([[
  require("eca.chat").new()
  ]])
  local welcome_message = child.lua([[
    local chat = require("eca.chat").new()
    return chat:welcome_message()
  ]])
  helpers.expect_contains_message(chat.messages, "**Welcome to ECA!**")
  eq(chat.server, nil)
end

T["Chat"]["add_message()"] = function()
  ---@type eca.Chat
  child.lua([[
  local chat = require("eca.chat").new()
  _G.chat = chat
  return _G.chat
  ]])
  write_message("What's up?")
  helpers.expect_contains_message(child.lua_get("_G.chat.messages"), "What's up?")
  write_message({ content = "Not much" })
  eq(child.lua_get("_G.chat.messages[#_G.chat.messages]"), { content = "Not much" })
  eq(3, child.lua_get("#_G.chat.messages"))
end

T["Chat"]["add_message splits on newlines for replacement"] = function()
  child.lua([[
  local chat = require("eca.chat").new()
  _G.chat = chat
  return _G.chat
  ]])
  write_message("Multi-line message\nbroken up by newlines")
  eq(child.lua_get("#_G.chat.messages"), 3)
end

return T
