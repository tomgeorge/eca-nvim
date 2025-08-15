local M = {}

---@param cursor_line string
---@param cursor_position lsp.Position|vim.Position
---@return string
function M.get_query(cursor_line, cursor_position)
  local before_cursor = cursor_line:sub(1, cursor_position.col)
  ---@type string[]
  local matches = {}
  local it = before_cursor:gmatch("@([%w%./_\\%-~]*)")
  for match in it do
    table.insert(matches, match)
  end
  return matches[#matches]
end

---@param query string
---@param as_completion_item fun(eca.ChatContext): lsp.CompletionItem
---@param callback fun(resp: {items: lsp.CompletionItem[], isIncomplete?: boolean, is_incomplete_forward?: boolean, is_incomplete_backward?: boolean})
function M.get_completion_candidates(query, as_completion_item, callback)
  local server = require("eca").server
  server:send_request("chat/queryContext", { query = query }, function(err, result)
    if err then
      callback({ items = { items = {} } })
      return
    end

    local items = vim.iter(result.contexts):map(as_completion_item):totable()
    callback({ items = items })
  end)
end
return M
