---@param command eca.ChatCommand
---@return lsp.CompletionItem
local function as_completion_item(command)
  local cmp = require("cmp")
  ---@type lsp.CompletionItem
  return {
    label = command.name,
    kind = cmp.lsp.CompletionItemKind.Function,
    detail = command.description or ("ECA command: " .. command.name),
    documentation = command.help and {
      kind = "markdown",
      value = command.help,
    } or nil,
  }
end

local source = {}

source.new = function()
  return setmetatable({ cache = {} }, { __index = source })
end

function source:get_trigger_characters()
  return { "/" }
end

function source:is_available()
  return vim.bo.filetype == "eca-input"
end

---@diagnostic disable-next-line: unused-local
function source:complete(params, callback)
  -- Only complete if we're typing a command (starts with /)
  local commands = require("eca.completion.commands")
  local query = commands.get_query(params.context.cursor_line)
  if query then
    commands.get_completion_candidates(query, as_completion_item, callback)
  end
end
return source
