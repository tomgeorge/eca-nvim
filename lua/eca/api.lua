local Utils = require("eca.utils")

---@class eca.Api
local M = {}

---@param opts? table
function M.chat(opts)
  opts = opts or {}
  local eca = require("eca")
  eca.open_sidebar(opts)
end

function M.focus()
  local eca = require("eca")
  local sidebar = eca.get()
  if sidebar then
    sidebar:focus()
  else
    M.chat()
  end
end

function M.toggle()
  local eca = require("eca")
  return eca.toggle_sidebar()
end

function M.close()
  local eca = require("eca")
  local sidebar = eca.get()
  if sidebar then
    sidebar:new_chat() -- This will reset and force welcome content on next open
  else
    eca.close_sidebar()
  end
end

---@param message string
function M.send_message(message)
  local eca = require("eca")
  local sidebar = eca.get()
  if not sidebar or not sidebar:is_open() then
    M.chat()
    sidebar = eca.get()
  end
  
  if sidebar then
    sidebar:_send_message(message)
  else
    Utils.error("Could not open ECA sidebar")
  end
end

---@param file_path string
function M.add_file_context(file_path)
  Utils.info("Adding file context: " .. file_path)
  local eca = require("eca")
  
  if not eca.server or not eca.server:is_running() then
    Utils.error("ECA server is not running")
    return
  end
  
  -- Read file content
  local content = Utils.read_file(file_path)
  if not content then
    Utils.error("Could not read file: " .. file_path)
    return
  end
  
  -- Create context object
  local context = {
    type = "file",
    path = file_path,
    content = content
  }
  
  -- For now, store it for next message
  -- TODO: Implement context management
  Utils.debug("File context added: " .. file_path)
end

---@param directory_path string
function M.add_directory_context(directory_path)
  Utils.info("Adding directory context: " .. directory_path)
  local eca = require("eca")
  
  if not eca.server or not eca.server:is_running() then
    Utils.error("ECA server is not running")
    return
  end
  
  -- Create context object for directory
  local context = {
    type = "directory",
    path = directory_path
  }
  
  -- For now, store it for next message
  -- TODO: Implement context management
  Utils.debug("Directory context added: " .. directory_path)
end

function M.add_current_file_context()
  local current_file = vim.api.nvim_buf_get_name(0)
  if current_file and current_file ~= "" then
    M.add_file_context(current_file)
  else
    Utils.warn("No current file to add as context")
  end
end

function M.add_selection_context()
  -- Get visual selection
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  
  if start_pos[2] == 0 or end_pos[2] == 0 then
    Utils.warn("No selection to add as context")
    return
  end
  
  local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
  if #lines > 0 then
    local selection_text = table.concat(lines, "\n")
    Utils.info("Adding selection context (" .. #lines .. " lines)")
    -- TODO: Send selection to ECA server as context
  end
end

---@return boolean
function M.is_server_running()
  local eca = require("eca")
  return eca.server and eca.server:is_running()
end

function M.start_server()
  local eca = require("eca")
  if eca.server then
    eca.server:start()
  else
    Utils.error("ECA server not initialized")
  end
end

function M.stop_server()
  local eca = require("eca")
  if eca.server then
    eca.server:stop()
  end
end

function M.restart_server()
  M.stop_server()
  vim.defer_fn(function()
    M.start_server()
  end, 1000)
end

function M.server_status()
  local eca = require("eca")
  if eca.server then
    return eca.server:status()
  else
    return "Not initialized"
  end
end

return M
