local uv = vim.uv or vim.loop

---@class eca.Logger
local M = {}

---@type eca.LogConfig
M.config = nil

local LEVEL_NAMES = {
  [vim.log.levels.TRACE] = "TRACE",
  [vim.log.levels.DEBUG] = "DEBUG",
  [vim.log.levels.INFO] = "INFO",
  [vim.log.levels.WARN] = "WARN",
  [vim.log.levels.ERROR] = "ERROR",
}

---Get XDG-compliant default log path
---@return string
local function get_default_log_path()
  return vim.fn.stdpath("state") .. "/eca.log"
end

---@type eca.LogConfig
local DEFAULT_CONFIG = {
  level = vim.log.levels.INFO,
  file = get_default_log_path(),
  display = "split",
  max_file_size_mb = 10,
}

---Get log level name
---@param level integer
---@return string
local function get_level_name(level)
  return LEVEL_NAMES[level] or "UNKNOWN"
end

---Check if log file is over size limit and notify if needed
---@param log_path string
---@param max_size_mb number
local function check_log_size_and_notify(log_path, max_size_mb)
  uv.fs_stat(log_path, function(err, stat)
    if err or not stat then
      return
    end

    local max_size = max_size_mb * 1024 * 1024 -- Convert MB to bytes
    if stat.size > max_size then
      local size_mb = math.floor(stat.size / 1024 / 1024 * 100) / 100
      vim.notify(
        string.format("ECA log file is large (%.1fMB). Consider clearing it with :EcaLogs clear", size_mb),
        vim.log.levels.WARN,
        { title = "ECA" }
      )
    end
  end)
end

--- Initialize logger with configuration
---@param config eca.LogConfig
function M.setup(config)
  config = config or {}
  local strings = require("eca.strings")

  M.config = {
    level = config.level or DEFAULT_CONFIG.level,
    file = strings.is_nil_or_empty(config.file) and DEFAULT_CONFIG.file or config.file,
    display = config.display or DEFAULT_CONFIG.display,
    max_file_size_mb = config.max_file_size_mb or DEFAULT_CONFIG.max_file_size_mb,
  }

  local log_path = M.get_log_path()
  check_log_size_and_notify(log_path, M.config.max_file_size_mb)
end

---@return string
function M.get_display()
  return M.config and M.config.display or "split"
end

--- Get current log file path
---@return string
function M.get_log_path()
  assert(M.config and M.config.file ~= "", "Logger must be configured with a non-empty file path")
  return vim.fn.expand(M.config.file)
end

--- Log a message to the log file
---@param message string
---@param level integer
function M.log(message, level)
  if vim.in_fast_event() then
    return vim.schedule(function()
      M.log(message, level)
    end)
  end

  if not M.config then
    return
  end

  if level < M.config.level then
    return
  end

  local log_path = M.get_log_path()

  vim.fn.mkdir(vim.fn.fnamemodify(log_path, ":h"), "p")

  local timestamp = os.date("%Y-%m-%d %H:%M:%S")
  local level_name = get_level_name(level)
  local formatted = string.format("[%s] %-5s %s\n", timestamp, level_name, message)

  uv.fs_open(log_path, "a", 420, function(err, fd)
    if err or not fd then
      return
    end
    uv.fs_write(fd, formatted, -1, function()
      uv.fs_close(fd)
    end)
  end)
end

--- Log debug message
---@param message string
function M.debug(message)
  M.log(message, vim.log.levels.DEBUG)
end

--- Log info message
---@param message string
function M.info(message)
  M.log(message, vim.log.levels.INFO)
end

--- Log warn message
---@param message string
function M.warn(message)
  M.log(message, vim.log.levels.WARN)
end

--- Log error message
---@param message string
function M.error(message)
  M.log(message, vim.log.levels.ERROR)
end

--- Send notification to user via vim.notify
---@param message string
---@param level? integer vim.log.levels (default: INFO)
---@param opts? {title?: string}
function M.notify(message, level, opts)
  if vim.in_fast_event() then
    return vim.schedule(function()
      M.notify(message, level, opts)
    end)
  end

  level = level or vim.log.levels.INFO
  opts = opts or {}

  M.log(message, level)

  vim.notify(message, level, {
    title = opts.title or "ECA",
  })
end

--- Get log file statistics
---@return table|nil
function M.get_log_stats()
  local log_path = M.get_log_path()
  local stat = uv.fs_stat(log_path)
  if not stat then
    return nil
  end

  return {
    path = log_path,
    size = stat.size,
    size_mb = math.floor(stat.size / 1024 / 1024 * 100) / 100,
    modified = os.date("%Y-%m-%d %H:%M:%S", stat.mtime.sec),
  }
end

--- Clear log file
---@return boolean
function M.clear_log()
  local log_path = M.get_log_path()
  local file = io.open(log_path, "w")
  if file then
    file:close()
    return true
  end
  return false
end

return M
