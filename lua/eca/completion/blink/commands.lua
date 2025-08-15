local source = {}

-- `opts` table comes from `sources.providers.your_provider.opts`
-- You may also accept a second argument `config`, to get the full
-- `sources.providers.your_provider` table
function source.new(opts)
  -- vim.validate("your-source.opts.some_option", opts.some_option, { "string" })
  -- vim.validate("your-source.opts.optional_option", opts.optional_option, { "string" }, true)

  local self = setmetatable({}, { __index = source })
  self.opts = opts
  return self
end

function source:enabled()
  return vim.bo.filetype == "eca-input"
end

---@return lsp.CompletionItem
---@param command eca.ChatCommand
local function as_completion_item(command)
  ---@type lsp.CompletionItem
  return {
    label = command.name,
    detail = command.description or ("ECA command: " .. command.name),
    documentation = command.help and {
      kind = "markdown",
      value = command.help,
    } or nil,
  }
end

-- (Optional) Non-alphanumeric characters that trigger the source
function source:get_trigger_characters()
  return { "/" }
end

---@module 'blink.cmp'
---@param ctx blink.cmp.Context
---@param callback fun(response?: blink.cmp.CompletionResponse)
function source:get_completions(ctx, callback)
  local commands = require("eca.completion.commands")
  local q = commands.get_query(ctx.line)
  if q then
    commands.get_completion_candidates(q, as_completion_item, callback)
  end
end

return source
