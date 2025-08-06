---@param commands eca.ChatCommand
---@return lsp.CompletionItem[]
local function create_completion_items(commands)
  ---@type lsp.CompletionItem[]
  local items = {}

  if commands then
    for _, command in ipairs(commands) do
      ---@type lsp.CompletionItem
      local item = {
        label = command.name or command.command,
        kind = vim.lsp.protocol.CompletionItemKind.Function,
        detail = command.description or ("ECA command: " .. (command.name or command.command)),
        documentation = command.help and {
          kind = "markdown",
          value = command.help,
        } or nil,
        insertText = command.name or command.command,
      }
      table.insert(items, item)
    end
  end

  return items
end

---@param s string
---@return string
local function get_query(s)
  local match = s:match("^>?%s*/(.*)$")
  return match
end

-- Query server for available commands
local function query_server_commands(query, callback)
  local eca = require("eca")
  if not eca.server or not eca.server:is_running() then
    callback({})
    return
  end

  eca.server:send_request("chat/queryCommands", { query = query }, function(err, result)
    if err then
      callback({})
      return
    end

    local items = create_completion_items(result.commands)
    callback(items)
  end)
end

local source = {}

source.new = function()
  return setmetatable({ cache = {} }, { __index = source })
end

source.get_trigger_characters = function()
  return { "/" }
end

source.is_available = function()
  return vim.bo.filetype == "eca-input"
end

---@diagnostic disable-next-line: unused-local
source.complete = function(self, _, callback)
  local logger = require("eca.logger")
  -- Only complete if we're typing a command (starts with /)
  local line = vim.api.nvim_get_current_line()
  local query = get_query(line)

  -- Only provide command completions when we have / followed by word characters or at word boundary
  if query then
    local bufnr = vim.api.nvim_get_current_buf()

    if self.cache[bufnr] and self.cache[bufnr][query] then
      callback({ items = self.cache[bufnr][query], isIncomplete = false })
    else
      logger.debug("not cached")
      query_server_commands(query, function(items)
        callback({
          items = items,
          isIncomplete = false,
        })
        self.cache[bufnr] = {}
        self.cache[bufnr][query] = items
      end)
    end
  else
    callback({
      items = {},
      isIncomplete = false,
    })
  end
end
return source
