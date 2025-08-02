local Utils = require("eca.utils")
local Config = require("eca.config")

---@class eca.Server
---@field private _proc? userdata Process handle
---@field private _connection? table JSON-RPC connection
---@field private _status string Current server status
---@field private _on_started? function Callback when server starts
---@field private _on_status_changed? function Callback when status changes
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
  return self._connection
end

---@return string
function M:_find_server_path()
  local config_path = Config.server_path
  if config_path and config_path ~= "" then
    if Utils.file_exists(config_path) then
      return config_path
    else
      Utils.warn("Configured server path does not exist: " .. config_path)
    end
  end
  
  -- Try to find eca in PATH
  local handle = io.popen("which eca 2>/dev/null")
  if handle then
    local result = handle:read("*a"):gsub("%s+", "")
    handle:close()
    if result and result ~= "" and Utils.file_exists(result) then
      return result
    end
  end
  
  -- Download if not found
  return self:_download_server()
end

---@return string
function M:_download_server()
  local cache_dir = Utils.get_cache_dir()
  local server_path = cache_dir .. "/eca"
  
  if Utils.file_exists(server_path) then
    return server_path
  end
  
  Utils.info("Downloading ECA server...")
  
  -- Determine platform and architecture
  local platform = vim.loop.os_uname().sysname:lower()
  local arch = vim.loop.os_uname().machine
  
  local artifacts = {
    darwin = {
      x86_64 = "eca-native-macos-amd64.zip",
      arm64 = "eca-native-macos-aarch64.zip",
    },
    linux = {
      x86_64 = "eca-native-static-linux-amd64.zip",
      aarch64 = "eca-native-linux-aarch64.zip",
    }
  }
  
  local artifact_name = artifacts[platform] and artifacts[platform][arch]
  if not artifact_name then
    error("Unsupported platform: " .. platform .. " " .. arch)
  end
  
  -- Get latest version from GitHub API
  local version_cmd = 'curl -s https://api.github.com/repos/editor-code-assistant/eca/releases/latest | grep "tag_name" | cut -d "\\"" -f 4'
  local version_handle = io.popen(version_cmd)
  local version = version_handle and version_handle:read("*a"):gsub("%s+", "") or "latest"
  if version_handle then version_handle:close() end
  
  local download_url = string.format(
    "https://github.com/editor-code-assistant/eca/releases/download/%s/%s",
    version,
    artifact_name
  )
  
  local download_path = cache_dir .. "/" .. artifact_name
  local download_cmd = string.format("curl -L -o %s %s", vim.fn.shellescape(download_path), download_url)
  
  local download_result = os.execute(download_cmd)
  if download_result ~= 0 then
    error("Failed to download ECA server from: " .. download_url)
  end
  
  -- Extract if it's a zip file
  if artifact_name:match("%.zip$") then
    local extract_cmd = string.format("cd %s && unzip -o %s", vim.fn.shellescape(cache_dir), vim.fn.shellescape(artifact_name))
    local extract_result = os.execute(extract_cmd)
    if extract_result ~= 0 then
      error("Failed to extract ECA server")
    end
    
    -- Make executable
    os.execute("chmod +x " .. vim.fn.shellescape(server_path))
  end
  
  if not Utils.file_exists(server_path) then
    error("ECA server binary not found after download and extraction")
  end
  
  Utils.info("ECA server downloaded successfully")
  return server_path
end

function M:start()
  if self._status ~= ServerStatus.Stopped then
    Utils.debug("Server already starting or running")
    return
  end
  
  self:_change_status(ServerStatus.Starting)
  
  local server_path = self:_find_server_path()
  if not server_path then
    self:_change_status(ServerStatus.Failed)
    Utils.error("Could not find or download ECA server")
    return
  end
  
  Utils.debug("Starting ECA server: " .. server_path)
  
  local args = { "server" }
  if Config.server_args and Config.server_args ~= "" then
    vim.list_extend(args, vim.split(Config.server_args, " "))
  end
  
  -- Start the server process
  self._proc = vim.system(
    vim.list_extend({ server_path }, args),
    {
      stdin = true,
      stdout = true,
      stderr = true,
    },
    function(result)
      if result.code ~= 0 then
        self:_change_status(ServerStatus.Failed)
        Utils.error("ECA server process exited with code: " .. result.code)
        if result.stderr then
          Utils.error("Server stderr: " .. result.stderr)
        end
      end
    end
  )
  
  if not self._proc then
    self:_change_status(ServerStatus.Failed)
    Utils.error("Failed to start ECA server process")
    return
  end
  
  -- Create JSON-RPC connection
  self._connection = self:_create_rpc_connection()
  
  -- Initialize the server
  self:_initialize_server()
end

function M:_create_rpc_connection()
  -- This would create a JSON-RPC connection over stdin/stdout
  -- For now, this is a placeholder - would need to implement proper JSON-RPC
  return {
    send_request = function(method, params, callback)
      Utils.debug("Would send RPC request: " .. method)
      -- TODO: Implement actual JSON-RPC communication
      if callback then
        callback(nil, { success = true })
      end
    end,
    send_notification = function(method, params)
      Utils.debug("Would send RPC notification: " .. method)
      -- TODO: Implement actual JSON-RPC communication
    end
  }
end

function M:_initialize_server()
  local workspace_folders = {
    {
      name = vim.fn.fnamemodify(Utils.get_project_root(), ":t"),
      uri = "file://" .. Utils.get_project_root()
    }
  }
  
  self._connection.send_request("initialize", {
    processId = vim.fn.getpid(),
    clientInfo = {
      name = "Neovim",
      version = vim.version().major .. "." .. vim.version().minor
    },
    capabilities = {
      codeAssistant = {
        chat = true
      }
    },
    workspaceFolders = workspace_folders
  }, function(err, result)
    if err then
      self:_change_status(ServerStatus.Failed)
      Utils.error("Failed to initialize ECA server: " .. tostring(err))
      return
    end
    
    self:_change_status(ServerStatus.Running)
    Utils.info("ECA server started successfully")
    
    -- Send initialized notification
    self._connection.send_notification("initialized", {})
    
    if self._on_started then
      self._on_started(self._connection)
    end
  end)
end

function M:stop()
  if self._status == ServerStatus.Stopped then
    return
  end
  
  if self._connection then
    self._connection.send_request("shutdown", {}, function()
      self._connection.send_notification("exit", {})
    end)
  end
  
  if self._proc then
    self._proc:kill(15) -- SIGTERM
    self._proc:wait(5000) -- Wait up to 5 seconds
    if self._proc:is_closing() then
      self._proc:kill(9) -- SIGKILL if still running
    end
  end
  
  self._connection = nil
  self._proc = nil
  self:_change_status(ServerStatus.Stopped)
  Utils.info("ECA server stopped")
end

---@param method string
---@param params table
---@param callback? function
function M:send_request(method, params, callback)
  if not self:is_running() or not self._connection then
    Utils.error("ECA server is not running")
    if callback then
      callback("Server not running", nil)
    end
    return
  end
  
  self._connection.send_request(method, params, callback)
end

---@param method string
---@param params table
function M:send_notification(method, params)
  if not self:is_running() or not self._connection then
    Utils.error("ECA server is not running")
    return
  end
  
  self._connection.send_notification(method, params)
end

return M
