local M = {}

---@param s string
---@return boolean
function M.is_nil_or_empty(s)
  return s == nil or s == ""
end

return M
