local Utils = require("eca.utils")
local Config = require("eca.config")
local RPC = require("eca.rpc")
local PathFinder = require("eca.path_finder")
local Logger = require("eca.logger")

---@class eca.Server
---@field private _proc? userdata Process handle
---@field private _rpc? eca.RPC JSON-RPC connection
---@field private _status string Current server status
---@field private _on_started? function Callback when server starts
---@field private _on_status_changed? function Callback when status changes
---@field private _server_capabilities? table Server capabilities
---@field private _chat_id? string Current chat ID
---@field private _path_finder eca.PathFinder Server path finder
local M = {}
M.__index = M

---@enum eca.ServerStatus
local ServerStatus = {
  Stopped = "Stopped",
  Starting = "Starting",
  Running = "Running",
  Failed = "Failed",
}

---@param opts? table
---@return eca.Server
function M:new(opts)
  opts = opts or {}
  local instance = setmetatable({}, M)
  instance._status = ServerStatus.Stopped
  instance._on_started = opts.on_started
  instance._on_status_changed = opts.on_status_changed
  instance._path_finder = PathFinder:new()
  return instance
end

---@return string
function M:status()
  return self._status
end

---@param new_status string
function M:_change_status(new_status)
  self._status = new_status
  if self._on_status_changed then
    self._on_status_changed(new_status)
  end
end

---@return boolean
function M:is_running()
  return self._status == ServerStatus.Running
end

---@return table?
function M:connection()
  return self._rpc
end

---@param params table
function M:_handle_chat_content(params)
  -- Broadcast chat content to any listening components
  local eca = require("eca")
  local sidebar = eca.get(false)

  if sidebar and params then
    sidebar:_handle_server_content(params)
  end
end

function M:start()
  if self._status ~= ServerStatus.Stopped then
    Logger.notify("Server already starting or running", vim.log.levels.INFO)
    return
  end

  self:_change_status(ServerStatus.Starting)

  local server_path
  local ok, err = pcall(function()
    server_path = self._path_finder:find()
  end)

  if not ok or not server_path then
    self:_change_status(ServerStatus.Failed)
    local error_msg = "Could not find or download ECA server: " .. tostring(err)
    Logger.error(error_msg)
    return
  end

  Logger.debug("Starting ECA server: " .. server_path)

  local args = { server_path, "server" }
  if Config.server_args and Config.server_args ~= "" then
    vim.list_extend(args, vim.split(Config.server_args, " "))
  end

  -- Use vim.fn.jobstart for interactive processes
  local job_opts = {
    on_stdout = function(_, data, _)
      if data and self._rpc then
        local output = table.concat(data, "\n")
        if output and output ~= "" and output ~= "\n" then
          Logger.log(output, vim.log.levels.INFO, { server = true })
          self._rpc:_handle_stdout(output)
        end
      end
    end,
    on_stderr = function(_, data, _)
      if data then
        -- Filter out empty lines and join meaningful content
        local meaningful_lines = {}
        for _, line in ipairs(data) do
          local trimmed = line:match("^%s*(.-)%s*$") -- Trim whitespace
          if trimmed and trimmed ~= "" then
            table.insert(meaningful_lines, trimmed)
          end
        end

        if #meaningful_lines > 0 then
          local error_output = table.concat(meaningful_lines, "\n")
          Logger.log(error_output, vim.log.levels.WARN, { server = true })
        end
      end
    end,
    on_exit = function(_, code, _)
      Logger.debug("ECA server process exited with code: " .. code)
      if code ~= 0 then
        self:_change_status(ServerStatus.Failed)
        Logger.error("ECA server process exited with code: " .. code)
      else
        Logger.debug("ECA server process exited normally")
      end
      self._proc = nil
    end,
    stdin = "pipe",
    stdout_buffered = false,
    stderr_buffered = false,
  }

  self._proc = vim.fn.jobstart(args, job_opts)

  if self._proc <= 0 then
    self:_change_status(ServerStatus.Failed)
    local error_msg = "Failed to start ECA server process. Job ID: " .. tostring(self._proc)
    Logger.error(error_msg)
    return
  end

  Logger.debug("ECA server started with job ID: " .. self._proc)

  -- Create RPC connection with the job ID
  self._rpc = RPC:new(self._proc)

  -- Setup message handling
  self:_setup_rpc_handlers()

  -- Initialize the server with a small delay
  vim.defer_fn(function()
    self:_initialize_server()
  end, 500)
end

function M:_setup_rpc_handlers()
  if not self._rpc then
    return
  end

  -- Handle notifications from server
  self._rpc:on_notification(function(method, params)
    if method == "chat/contentReceived" then
      self:_handle_chat_content(params)
    elseif method == "tool/serverUpdated" then
      self:_handle_tool_server_update(params)
    end
  end)

  -- No need for manual stdout reading with jobstart - it's handled in on_stdout callback
end

---@param params table
function M:_handle_tool_server_update(params)
  Logger.debug("Tool server updated: " .. vim.inspect(params))
end

function M:_create_rpc_connection()
  -- This function is no longer needed - using RPC class instead
  return nil
end

function M:_initialize_server()
  local workspace_folders = {
    {
      name = vim.fn.fnamemodify(Utils.get_project_root(), ":t"),
      uri = "file://" .. Utils.get_project_root(),
    },
  }

  self._rpc:send_request("initialize", {
    processId = vim.fn.getpid(),
    clientInfo = {
      name = "Neovim",
      version = vim.version().major .. "." .. vim.version().minor,
    },
    capabilities = {
      codeAssistant = {
        chat = true,
      },
    },
    workspaceFolders = workspace_folders,
  }, function(err, result)
    if err then
      self:_change_status(ServerStatus.Failed)
      local error_msg = "Failed to initialize ECA server: " .. tostring(err)
      Logger.error(error_msg)
      return
    end

    -- Store server capabilities
    if result then
      self._server_capabilities = result
      Logger.debug("Server capabilities: " .. vim.inspect(result))
    end

    self:_change_status(ServerStatus.Running)
    Logger.debug("ECA server started successfully")

    -- Send initialized notification
    self._rpc:send_notification("initialized", {})

    if self._on_started then
      self._on_started(self._rpc)
    end
  end)
end

function M:stop()
  if self._status == ServerStatus.Stopped then
    return
  end

  if self._rpc then
    self._rpc:send_request("shutdown", {}, function()
      self._rpc:send_notification("exit", {})
    end)
    self._rpc:stop()
  end

  if self._proc and self._proc > 0 then
    -- Use vim.fn.jobstop for jobs started with jobstart
    vim.fn.jobstop(self._proc)

    -- Wait a bit for graceful shutdown
    vim.defer_fn(function()
      -- Force kill if still running (jobstop with SIGKILL)
      if self._proc and self._proc > 0 then
        vim.fn.jobstop(self._proc)
      end
    end, 5000)
  end

  self._rpc = nil
  self._proc = nil
  self._chat_id = nil
  self:_change_status(ServerStatus.Stopped)
  Logger.info("ECA server stopped")
end

---@param method string
---@param params table
---@param callback? function
function M:send_request(method, params, callback)
  if not self:is_running() or not self._rpc then
    Logger.error("ECA server is not running")
    if callback then
      callback("Server not running", nil)
    end
    return
  end

  self._rpc:send_request(method, params, callback)
end

---@param method string
---@param params table
function M:send_notification(method, params)
  if not self:is_running() or not self._rpc then
    Logger.error("ECA server is not running")
    return
  end

  self._rpc:send_notification(method, params)
end

---@param message string
---@param contexts? table[]
---@param callback? function
function M:send_chat_message(message, contexts, callback)
  if not self:is_running() then
    if callback then
      callback("Server not running", nil)
    end
    return
  end

  local chat_params = {
    chatId = self._chat_id,
    requestId = tostring(os.time()),
    message = message,
    contexts = contexts or {},
  }

  self:send_request("chat/prompt", chat_params, function(err, result)
    if err then
      Logger.error("Chat request failed: " .. tostring(err))
      if callback then
        callback(err, nil)
      end
      return
    end

    if result and result.chatId then
      self._chat_id = result.chatId
      Logger.debug("Chat message sent, chatId: " .. result.chatId)
    end

    if callback then
      callback(nil, result)
    end
  end)
end

return M
