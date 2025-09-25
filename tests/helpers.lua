local Helpers = {}

local function assert_child(child)
  assert(child, "child is nil, call new_child_neovim()")
end

--- Get mocked notifications
function Helpers.mocked_notifications(child)
  assert_child(child)
  local notifications = child.lua_get("_G.notifications")
  assert(notifications, "_G.notifications not found, run helpers.mock_notify()")
  return notifications
end

--- Mock vim.notify
function Helpers.mock_notify(child)
  assert_child(child)
  child.lua([[
    _G.notifications = {}
    vim.notify = function(msg, level, opts)
      table.insert(_G.notifications, { msg = msg, level = level, opts = opts })
    end
  ]])
end

local function test_log_path()
  return vim.fn.tempname() .. "_logs"
end

function Helpers.mock_logging(child)
  assert_child(child)
  child.lua(
    [[
    _G.test_log_dir = ...
    vim.fn.mkdir(_G.test_log_dir, "p")
  ]],
    { test_log_path() }
  )
end

return Helpers
