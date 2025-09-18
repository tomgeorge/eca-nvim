local MiniTest = require("mini.test")
local eq = MiniTest.expect.equality
local child = MiniTest.new_child_neovim()
local stubs = require("tests.stubs.tool_calls")

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ "-u", "scripts/minimal_init.lua" })
      child.lua([[
        _G.notifications = {}
        _G.on_accept = function() table.insert(_G.notifications, "accept") end
        _G.on_reject = function() table.insert(_G.notifications, "reject") end
      ]])
    end,
    post_once = child.stop,
  },
})

T["preview lines"] = function()
  local test_cases = {
    {
      input = stubs.read_file,
      want = {
        "Summary: Reading file messages.lua",
        "Tool Name: eca_read_file",
        "Tool Type: native",
        "Tool Arguments: ",
        "{",
        '  path = "/Users/tgeorge/git/eca-nvim/hack/messages.lua"',
        "}",
      },
    },
    {
      input = stubs.edit_file,
      want = {
        "/Users/tgeorge/git/eca-nvim/hack/messages.lua",
        "@@ -1, 5 +1, 13 @@",
        '-local has_snacks, picker = pcall(require, "snacks.picker")',
        "-if has_snacks then",
        "+local M = {}",
        "+",
        "+--- Show ECA messages using snacks.picker",
        "+function M.show()",
        '+  local has_snacks, picker = pcall(require, "snacks.picker")',
        "+  if not has_snacks then",
        '+    vim.notify("snacks.picker is not available", vim.log.levels.ERROR)',
        "+    return",
        "+  end",
        "+",
        "   Snacks.picker(",
        "     ---@type snacks.picker.Config",
        "     {",
        "@@ -29, 3 +37, 5 @@",
        " }",
        "   )",
        " end",
        "+",
        "+return M",
      },
    },
    {
      input = stubs.mcp,
      want = {
        "Tool Name: write_file",
        "Tool Type: mcp",
        "Tool Arguments: ",
        "{",
        "  content = 'return \"hello world\"',",
        '  path = "/Users/tgeorge/git/eca-nvim/hack/test_mcp_write_file.lua"',
        "}",
      },
    },
  }
  for _, test_case in pairs(test_cases) do
    local got = child.lua_get('require("eca.approve").get_preview_lines(...)', { test_case.input })
    eq(got, test_case.want)
  end
end

T["tool approval calls callback"] = function()
  child.lua("_G.tool_call = " .. vim.inspect(stubs.read_file))
  child.lua('require("eca.approve").approve_tool_call(_G.tool_call, _G.on_accept, _G.on_reject)')
  child.type_keys("y")
  eq(child.lua_get("_G.notifications"), { "accept" })
  child.lua('require("eca.approve").approve_tool_call(_G.tool_call, _G.on_accept, _G.on_reject)')
  child.type_keys("n")
  eq(child.lua_get("_G.notifications"), { "accept", "reject" })
end

return T
