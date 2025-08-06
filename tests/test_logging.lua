local MiniTest = require("mini.test")
local child = MiniTest.new_child_neovim()
local eq = MiniTest.expect.equality
local new_set = MiniTest.new_set

local expect_match = MiniTest.new_expectation("string matching", function(str, pattern)
  return str:find(pattern) ~= nil
end, function(str, pattern)
  return string.format("Pattern: %s\nObserved string: %s", vim.inspect(pattern), str)
end)

local expect_no_match = MiniTest.new_expectation("string not matching", function(str, pattern)
  return str:find(pattern) == nil
end, function(str, pattern)
  return string.format("Pattern: %s\nObserved string: %s", vim.inspect(pattern), str)
end)

local setup_test_environment = function()
  child.lua([[
    _G.test_log_dir = vim.fn.tempname() .. '_logs'
    vim.fn.mkdir(_G.test_log_dir, 'p')

    _G.captured_notifications = {}
    local original_notify = vim.notify
    vim.notify = function(msg, level, opts)
      table.insert(_G.captured_notifications, {
        message = msg,
        level = level,
        opts = opts or {}
      })
      return original_notify(msg, level, opts)
    end
  ]])
end

local cleanup_test_files = function()
  child.lua([[
    if _G.test_log_dir then
      vim.fn.delete(_G.test_log_dir, 'rf')
    end
  ]])
end

--- Get absolute path for a test log file within the temporary test directory
---
--- @param filename string The filename within the test directory (e.g., "test.log", "nested/dir/file.log")
--- @return string Absolute path to the test file
local get_test_file_path = function(filename)
  return child.lua_get("_G.test_log_dir") .. "/" .. filename
end

--- Setup the Logger module with a given configuration in the child Neovim process
--- Use this when you need custom logger configuration that doesn't fit the common patterns
--- covered by setup_logger_with_file().
---
--- @param config table Logger configuration options (level, file, display, etc.)
local setup_logger = function(config)
  child.lua("Logger.setup(...)", { config })
end

--- Setup logger with a test file and common defaults, with optional overrides
---
--- @param filename string The log filename within the test directory
--- @param overrides? table Optional config overrides (level, display, etc.)
local setup_logger_with_file = function(filename, overrides)
  local config = vim.tbl_extend("force", {
    level = vim.log.levels.INFO,
    file = get_test_file_path(filename),
  }, overrides or {})
  setup_logger(config)
end

--- Read entire contents of a test log file as a single string
---
--- @param relative_path string Path relative to test directory, should start with "/" (e.g., "/test.log")
--- @return string Complete file contents joined with newlines, or empty string if file not found
local read_log_file = function(relative_path)
  return child.lua([[
    local log_path = _G.test_log_dir .. ']] .. relative_path .. [['
    if vim.fn.filereadable(log_path) == 1 then
      return table.concat(vim.fn.readfile(log_path), '\n')
    end
    return ''
  ]])
end

--- Read only the first line of a test log file
---
--- @param relative_path string Path relative to test directory, should start with "/" (e.g., "/test.log")
--- @return string First line of the file, or empty string if file not found or empty
---
--- Example usage:
---   local first_line = read_log_first_line("/format_test.log")
---   expect_match(first_line, "%[%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d%]")  -- timestamp format
local read_log_first_line = function(relative_path)
  return child.lua([[
    local log_path = _G.test_log_dir .. ']] .. relative_path .. [['
    if vim.fn.filereadable(log_path) == 1 then
      return vim.fn.readfile(log_path)[1] or ''
    end
    return ''
  ]])
end

--- Wait for async logging operations to complete
---
--- @param ms? number Milliseconds to wait (default: 100)
---
local wait_for_async = function(ms)
  vim.uv.sleep(ms or 100)
end

--- Common test loop: sconfigure logger → run logging code → verify file contents
---
--- @param filename string The log filename within the test directory (no leading slash)
--- @param log_commands string Lua code to execute in child process (usually Logger.* calls)
--- @param config_overrides? table Optional logger config overrides (level, notify, etc.)
--- @return string Complete log file contents for assertion testing
---
--- Example usage:
---   -- basic
---   local contents = log_and_read("test.log", "Logger.info('hello world')")
---   expect_match(contents, "hello world")
---
---   -- Test with custom log level
---   local contents = log_and_read("debug.log", [[
---     Logger.debug('debug msg')
---     Logger.info('info msg')
---   ]], { level = vim.log.levels.DEBUG })
---
---   -- Test multiple log calls
---   local contents = log_and_read("multi.log", [[
---     Logger.warn('warning')
---     Logger.error('error')
---   ]])
local log_and_read = function(filename, log_commands, config_overrides)
  setup_logger_with_file(filename, config_overrides)
  child.lua(log_commands)
  wait_for_async()
  return read_log_file("/" .. filename)
end

local T = new_set({
  hooks = {
    pre_case = function()
      child.restart({ "-u", "scripts/minimal_init.lua" })
      child.lua([[Logger = require('eca.logger')]])
      setup_test_environment()
    end,
    post_case = cleanup_test_files,
    post_once = child.stop,
  },
})

T["configuration"] = new_set()

T["configuration"]["default configuration"] = function()
  child.lua([[
    Logger.setup()
  ]])

  eq(child.lua_get("Logger.get_log_path()"), vim.fn.stdpath("state") .. "/eca.log")
  eq(child.lua_get("Logger.config.level"), vim.log.levels.INFO)
  eq(child.lua_get("Logger.config.display"), "split")
end

T["configuration"]["file logging with default path"] = function()
  setup_logger({
    level = vim.log.levels.INFO,
  })

  local log_path = child.lua_get("Logger.get_log_path()")
  eq(vim.fn.stdpath("state") .. "/eca.log", log_path)
end

T["configuration"]["file logging with custom path"] = function()
  setup_logger({
    level = vim.log.levels.INFO,
    file = get_test_file_path("custom.log"),
  })

  local log_path = child.lua_get("Logger.get_log_path()")
  expect_match(log_path, "custom%.log$")
end

T["log_levels"] = new_set()

T["log_levels"]["respects minimum log level"] = function()
  local contents = log_and_read(
    "level_test.log",
    [[
    Logger.debug('debug message')
    Logger.info('info message')
    Logger.warn('warn message')
    Logger.error('error message')
  ]],
    { level = vim.log.levels.WARN }
  )

  expect_no_match(contents, "DEBUG")
  expect_no_match(contents, "INFO")
  expect_match(contents, "WARN")
  expect_match(contents, "ERROR")
end

T["log_levels"]["invalid level defaults to info"] = function()
  local contents = log_and_read(
    "invalid_level.log",
    [[
    Logger.debug('debug message')
    Logger.info('info message')
  ]],
    { level = 999 }
  )

  expect_no_match(contents, "DEBUG")
  expect_no_match(contents, "INFO")
end

T["file_logging"] = new_set()

T["file_logging"]["writes to file with correct format"] = function()
  setup_logger_with_file("format_test.log")
  child.lua([[Logger.info('test message')]])
  wait_for_async()

  local contents = read_log_first_line("/format_test.log")

  expect_match(contents, "%[%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d%]")
  expect_match(contents, "INFO")
  expect_match(contents, "test message")
end

T["file_logging"]["creates parent directory"] = function()
  setup_logger({
    level = vim.log.levels.INFO,
    file = get_test_file_path("nested/dir/test.log"),
  })

  child.lua([[Logger.info('nested test')]])

  wait_for_async()

  local dir_exists = child.lua([[
    return vim.fn.isdirectory(_G.test_log_dir .. '/nested/dir') == 1
  ]])
  local file_exists = child.lua([[
    return vim.fn.filereadable(_G.test_log_dir .. '/nested/dir/test.log') == 1
  ]])

  eq(dir_exists, true)
  eq(file_exists, true)
end

T["file_logging"]["supports path expansion"] = function()
  setup_logger({
    level = vim.log.levels.INFO,
    file = "~/test-eca.log",
  })

  local expanded_path = child.lua_get("Logger.get_log_path()")
  expect_no_match(expanded_path, "^~")
  expect_match(expanded_path, "test%-eca%.log$")
end

T["notifications"] = new_set()

T["notifications"]["Logger.notify sends vim.notify"] = function()
  setup_logger_with_file("notify_test.log")

  child.lua([[
    Logger.notify('warning message', vim.log.levels.WARN)
    Logger.notify('error message', vim.log.levels.ERROR)
  ]])

  local notifications = child.lua_get("_G.captured_notifications")
  eq(#notifications, 2)
  eq(notifications[1].message, "warning message")
  eq(notifications[1].level, vim.log.levels.WARN)
  eq(notifications[2].message, "error message")
  eq(notifications[2].level, vim.log.levels.ERROR)
end

T["notifications"]["Logger.notify defaults to INFO level"] = function()
  setup_logger_with_file("notify_default_test.log")

  child.lua([[Logger.notify('default level message')]])

  local notifications = child.lua_get("_G.captured_notifications")
  eq(#notifications, 1)
  eq(notifications[1].message, "default level message")
  eq(notifications[1].level, vim.log.levels.INFO)
end

T["notifications"]["Logger.notify writes to log file"] = function()
  local contents = log_and_read(
    "notify_log_test.log",
    [[
    Logger.notify('test notification message', vim.log.levels.WARN)
  ]]
  )

  expect_match(contents, "WARN")
  expect_match(contents, "test notification message")

  local notifications = child.lua_get("_G.captured_notifications")
  eq(#notifications, 1)
  eq(notifications[1].message, "test notification message")
  eq(notifications[1].level, vim.log.levels.WARN)
end

T["display modes"] = new_set()

T["display modes"]["default display mode is split"] = function()
  setup_logger_with_file("display_test.log")

  local display = child.lua_get("Logger.get_display()")
  eq(display, "split")
end

T["display modes"]["can configure popup mode"] = function()
  setup_logger({
    level = vim.log.levels.INFO,
    file = get_test_file_path("popup_test.log"),
    display = "popup",
  })

  local display = child.lua_get("Logger.get_display()")
  eq(display, "popup")
end

T["utilities"] = new_set()

T["utilities"]["get_log_stats"] = function()
  setup_logger_with_file("stats_test.log")

  child.lua([[Logger.info('message for stats')]])

  wait_for_async()

  local stats = child.lua_get("Logger.get_log_stats()")
  eq(type(stats), "table")
  expect_match(stats.path, "stats_test%.log$")
  eq(type(stats.size), "number")
  eq(stats.size > 0, true)
  eq(type(stats.size_mb), "number")
  eq(type(stats.modified), "string")
end

T["utilities"]["clear_log"] = function()
  local content_before = log_and_read("clear_test.log", [[Logger.info('message to be cleared')]])
  expect_match(content_before, "message to be cleared")

  local cleared = child.lua_get("Logger.clear_log()")
  eq(cleared, true)

  local content_after = read_log_file("/clear_test.log")
  eq(content_after, "")
end

T["integration"] = new_set()

T["integration"]["logger functions work correctly"] = function()
  local contents = log_and_read(
    "logger_integration.log",
    [[
    Logger.debug('debug message')
    Logger.info('info message')
    Logger.warn('warn message')
    Logger.error('error message')
  ]],
    { level = vim.log.levels.DEBUG }
  )

  expect_match(contents, "debug message")
  expect_match(contents, "info message")
  expect_match(contents, "warn message")
  expect_match(contents, "error message")
end

T["integration"]["server logging with prefix"] = function()
  local contents = log_and_read(
    "server_integration.log",
    [[
    Logger.log('server stdout message', vim.log.levels.INFO, { server = true })
    Logger.log('server stderr message', vim.log.levels.WARN, { server = true })
    Logger.info('client message')
  ]]
  )

  expect_match(contents, "%[SERVER%] server stdout message")
  expect_match(contents, "%[SERVER%] server stderr message") 
  expect_match(contents, "client message")
  expect_no_match(contents, "%[SERVER%] client message")
end

T["integration"]["EcaLogs command behavior"] = function()
  setup_logger_with_file("eca_logs_test.log")

  child.lua([[Logger.info('Test log entry for EcaLogs')]])

  wait_for_async()

  local log_path = child.lua_get("Logger.get_log_path()")
  expect_match(log_path, "eca_logs_test%.log$")

  local api_result = child.lua([[
    local Api = require('eca.api')
    local Logger = require('eca.logger')

    local log_path = Logger.get_log_path()
    return {
      log_path_exists = vim.fn.filereadable(log_path) == 1,
      log_path = log_path,
      file_readable = vim.fn.filereadable(log_path) == 1
    }
  ]])

  eq(api_result.log_path_exists, true)
  eq(api_result.file_readable, true)
  expect_match(api_result.log_path, "eca_logs_test%.log$")
end

T["integration"]["EcaLogs subcommands"] = function()
  setup_logger_with_file("subcommands_test.log")

  child.lua([[
    Logger.info('Test content for subcommands')
    Logger.warn('Test warning message')
  ]])

  wait_for_async()

  local log_path_result = child.lua([[
    local Logger = require("eca.logger")
    return Logger.get_log_path()
  ]])
  expect_match(log_path_result, "subcommands_test%.log$")

  local stats_result = child.lua([[
    local Logger = require("eca.logger")
    return Logger.get_log_stats()
  ]])
  eq(type(stats_result), "table")
  expect_match(stats_result.path, "subcommands_test%.log$")
  eq(stats_result.size > 0, true)

  local clear_result = child.lua([[
    local Logger = require("eca.logger")
    return Logger.clear_log()
  ]])
  eq(clear_result, true)

  local file_empty = child.lua([[
    local Logger = require("eca.logger")
    local stats = Logger.get_log_stats()
    return stats and stats.size == 0
  ]])
  eq(file_empty, true)
end

T["integration"]["large log file notification"] = function()
  -- Create a small log file first
  setup_logger_with_file("notification_test.log")
  child.lua([[Logger.info('Initial log entry')]])
  wait_for_async()

  -- Clear notifications before testing
  child.lua([[_G.captured_notifications = {}]])

  -- Setup logger with max_file_size_mb = 0 to trigger notification immediately
  setup_logger({
    level = vim.log.levels.INFO,
    file = get_test_file_path("notification_test.log"),
    max_file_size_mb = 0, -- Set to 0 to trigger notification for any file size
  })

  wait_for_async(200)

  local notifications = child.lua_get("_G.captured_notifications")
  eq(#notifications >= 1, true)

  local large_file_notification = nil
  for _, notification in ipairs(notifications) do
    if notification.message and notification.message:match("ECA log file is large") then
      large_file_notification = notification
      break
    end
  end

  eq(large_file_notification ~= nil, true)
  expect_match(large_file_notification.message, "ECA log file is large")
  expect_match(large_file_notification.message, "MB%)")
  expect_match(large_file_notification.message, "Consider clearing it with :EcaLogs clear")
  eq(large_file_notification.level, vim.log.levels.WARN)
  eq(large_file_notification.opts.title, "ECA")
end

return T
