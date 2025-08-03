local Utils = require("eca.utils")

---@class eca.StatusBar
---@field private _namespace number
---@field private _status string
local M = {}
M.__index = M

---@return eca.StatusBar
function M:new()
  local instance = setmetatable({}, M)
  instance._namespace = vim.api.nvim_create_namespace("eca_status")
  instance._status = "Stopped"
  return instance
end

---@param status string
function M:update(status)
  self._status = status
  self:_refresh()
end

function M:_refresh()
  -- Clear existing status
  vim.api.nvim_buf_clear_namespace(0, self._namespace, 0, -1)
  
  local status_text = "ECA: " .. self._status
  local highlight_group
  
  if self._status == "Running" then
    highlight_group = "DiagnosticOk"
    status_text = status_text .. " ✓"
  elseif self._status == "Starting" then
    highlight_group = "DiagnosticWarn"
    status_text = status_text .. " ⋯"
  elseif self._status == "Failed" then
    highlight_group = "DiagnosticError"
    status_text = status_text .. " ✗"
  else
    highlight_group = "Comment"
    status_text = status_text .. " ○"
  end
  
  -- Show in command line temporarily
  vim.notify(status_text, vim.log.levels.INFO)
  
  -- Also update the global status for other components to use
  vim.g.eca_server_status = self._status
end

function M:get_status()
  return self._status
end

function M:show()
  self:_refresh()
end

function M:hide()
  vim.api.nvim_buf_clear_namespace(0, self._namespace, 0, -1)
end

return M
