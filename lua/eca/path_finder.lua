local Utils = require("eca.utils")
local Config = require("eca.config")

---@class eca.PathFinder
---@field private _cache_dir string
---@field private _version_file string
local M = {}
M.__index = M

---@return eca.PathFinder
function M:new()
  local instance = setmetatable({}, M)
  instance._cache_dir = Utils.get_cache_dir()
  instance._version_file = instance._cache_dir .. "/eca-version"
  return instance
end

---@return table<string, table<string, string>>
function M:_get_artifacts()
  return {
    darwin = {
      x86_64 = "eca-native-macos-amd64.zip",
      arm64 = "eca-native-macos-aarch64.zip",
    },
    linux = {
      x86_64 = "eca-native-static-linux-amd64.zip",
      aarch64 = "eca-native-linux-aarch64.zip",
      arm64 = "eca-native-linux-aarch64.zip",
    },
    windows = {
      x86_64 = "eca-native-windows-amd64.zip",
    }
  }
end

---@param platform? string
---@param arch? string
---@return string
function M:_get_artifact_name(platform, arch)
  platform = platform or vim.loop.os_uname().sysname:lower()
  arch = arch or vim.loop.os_uname().machine
  
  -- Normalize platform names
  if platform:match("darwin") then
    platform = "darwin"
  elseif platform:match("linux") then
    platform = "linux"
  elseif platform:match("windows") or platform:match("mingw") or platform:match("msys") then
    platform = "windows"
  end
  
  local artifacts = self:_get_artifacts()
  local platform_artifacts = artifacts[platform]
  
  if not platform_artifacts then
    error("Unsupported platform: " .. platform)
  end
  
  return platform_artifacts[arch] or "eca.jar"
end

---@param platform? string
---@param arch? string
---@return string
function M:_get_extension_server_path(platform, arch)
  local artifact_name = self:_get_artifact_name(platform, arch)
  local name
  
  if artifact_name:match("%.jar$") then
    name = "eca.jar"
  else
    platform = platform or vim.loop.os_uname().sysname:lower()
    name = platform:match("windows") and "eca.exe" or "eca"
  end
  
  return self._cache_dir .. "/" .. name
end

---@return string?
function M:_read_version_file()
  local file = io.open(self._version_file, "r")
  if not file then
    return nil
  end
  
  local version = file:read("*a"):gsub("%s+", "")
  file:close()
  return version ~= "" and version or nil
end

---@param version string
function M:_write_version_file(version)
  -- Ensure cache directory exists
  vim.fn.mkdir(self._cache_dir, "p")
  
  local file = io.open(self._version_file, "w")
  if file then
    file:write(version)
    file:close()
  else
    Utils.warn("Could not write version file: " .. self._version_file)
  end
end

---@return string?
function M:_get_latest_version()
  local cmd = 'curl -s https://api.github.com/repos/editor-code-assistant/eca/releases/latest'
  local handle = io.popen(cmd .. ' 2>/dev/null')
  
  if not handle then
    Utils.warn("Failed to check for latest ECA version")
    return nil
  end
  
  local response = handle:read("*a")
  handle:close()
  
  if not response or response == "" then
    return nil
  end
  
  -- Parse JSON to get tag_name
  local tag_match = response:match('"tag_name"%s*:%s*"([^"]+)"')
  return tag_match
end

---@param server_path string
---@param version string
---@return boolean success
function M:_download_latest_server(server_path, version)
  local artifact_name = self:_get_artifact_name()
  local download_url = string.format(
    "https://github.com/editor-code-assistant/eca/releases/download/%s/%s",
    version,
    artifact_name
  )
  
  local download_path = self._cache_dir .. "/" .. artifact_name
  
  Utils.info("Downloading latest ECA server version from: " .. download_url)
  
  -- Ensure cache directory exists
  vim.fn.mkdir(self._cache_dir, "p")
  
  -- Download the file
  local download_cmd = string.format(
    "curl -L --fail --show-error --silent -o %s %s",
    vim.fn.shellescape(download_path),
    vim.fn.shellescape(download_url)
  )
  
  local download_result = os.execute(download_cmd)
  if download_result ~= 0 then
    Utils.error("Failed to download ECA server from: " .. download_url)
    return false
  end
  
  -- Extract if it's a zip file
  if artifact_name:match("%.zip$") then
    local extract_cmd = string.format(
      "cd %s && unzip -o %s",
      vim.fn.shellescape(self._cache_dir),
      vim.fn.shellescape(artifact_name)
    )
    
    local extract_result = os.execute(extract_cmd)
    if extract_result ~= 0 then
      Utils.error("Failed to extract ECA server")
      return false
    end
    
    -- Remove the zip file after extraction
    os.remove(download_path)
  end
  
  -- Make executable (if not Windows)
  if not vim.loop.os_uname().sysname:lower():match("windows") then
    os.execute("chmod +x " .. vim.fn.shellescape(server_path))
  end
  
  if not Utils.file_exists(server_path) then
    Utils.error("ECA server binary not found after download and extraction")
    return false
  end
  
  -- Write version file
  self:_write_version_file(version)
  
  Utils.info("ECA server downloaded successfully")
  return true
end

---@return string
function M:find()
  -- Check for custom server path first
  local custom_path = Config.server_path
  if custom_path and custom_path:gsub("%s+", "") ~= "" then
    if Utils.file_exists(custom_path) then
      Utils.debug("Using custom server path: " .. custom_path)
      return custom_path
    else
      Utils.warn("Custom server path does not exist: " .. custom_path)
    end
  end
  
  local server_path = self:_get_extension_server_path()
  local latest_version = self:_get_latest_version()
  local current_version = self:_read_version_file()
  
  local server_exists = Utils.file_exists(server_path)
  
  -- If we can't get the latest version and server doesn't exist, that's an error
  if not latest_version and not server_exists then
    error("Could not fetch latest version of ECA. Please check your internet connection and try again. You can also download ECA manually and set the path in the settings.")
  end
  
  -- Download if server doesn't exist or version is outdated
  if not server_exists or (latest_version and current_version ~= latest_version) then
    if not latest_version then
      Utils.warn("Could not check for latest version, using existing server")
      return server_path
    end
    
    local success = self:_download_latest_server(server_path, latest_version)
    if not success then
      error("Failed to download ECA server")
    end
  end
  
  Utils.debug("Using ECA server: " .. server_path)
  return server_path
end

return M
