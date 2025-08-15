local cmp = require("cmp")
---@module 'cmp'
---@param context eca.ChatContext
---@return cmp.CompletionItem
local function as_completion_item(context)
  ---@type lsp.CompletionItem
  ---@diagnostic disable-next-line: missing-fields
  local item = {}
  if context.type == "file" then
    item.label = string.format("@%s", vim.fn.fnamemodify(context.path, ":."))
    item.kind = cmp.lsp.CompletionItemKind.File
    item.data = {
      context_item = context,
    }
  elseif context.type == "directory" then
    item.label = string.format("@%s", vim.fn.fnamemodify(context.path, ":."))
    item.kind = cmp.lsp.CompletionItemKind.Folder
  elseif context.type == "web" then
    item.label = context.url
    item.kind = cmp.lsp.CompletionItemKind.File
  elseif context.type == "repoMap" then
    item.label = "repoMap"
    item.kind = cmp.lsp.CompletionItemKind.Module
    item.detail = "Summary view of workspace files."
  elseif context.type == "mcpResource" then
    item.label = string.format("%s:%s", context.server, context.name)
    item.kind = cmp.lsp.CompletionItemKind.Struct
    item.detail = context.description
  end
  if not item.label then
    return {}
  end
  return item
end

local source = {}

function source.new()
  return setmetatable({}, { __index = source })
end

function source:get_trigger_characters()
  return { "@" }
end

function source:get_keyword_pattern()
  return [[\k\+]]
end

function source:is_available()
  return vim.bo.filetype == "eca-input"
end

---@param params cmp.SourceCompletionApiParams
---@diagnostic disable-next-line: unused-local
function source:complete(params, callback)
  local context = require("eca.completion.context")
  local query = context.get_query(params.context.cursor_line, params.context.cursor)
  if query then
    context.get_completion_candidates(query, as_completion_item, callback)
  end
end

--- Taken from https://github.com/hrsh7th/cmp-path/blob/9a16c8e5d0be845f1d1b64a0331b155a9fe6db4d/lua/cmp_path/init.lua
--- Show a small preview of file contexft items in the documentation window.
---@param data eca.ChatContext
---@return lsp.MarkupContent
source._get_documentation = function(_, data, count)
  if data and data.path then
    local filename = data.path
    local binary = assert(io.open(data.path, "rb"))
    local first_kb = binary:read(1024)
    if first_kb and first_kb:find("\0") then
      return { kind = vim.lsp.protocol.MarkupKind.PlainText, value = "binary file" }
    end

    local content = io.lines(data.path)

    --- Try to support line ranges, I don't know if this works or not yet
    local start = data.lines_range and data.lines_range.start or 1
    local last = data.lines_range and data.lines_range["end"] or count
    local skip_lines = start - 1
    local take_lines = last - start
    local contents = vim.iter(content):skip(skip_lines):take(take_lines):totable()

    local filetype = vim.filetype.match({ filename = filename })
    if not filetype then
      return { kind = vim.lsp.protocol.MarkupKind.PlainText, value = table.concat(contents, "\n") }
    end

    table.insert(contents, 1, "```" .. filetype)
    table.insert(contents, "```")
    return { kind = vim.lsp.protocol.MarkupKind.Markdown, value = table.concat(contents, "\n") }
  end
  return {}
end

---@param completion_item lsp.CompletionItem
function source:resolve(completion_item, callback)
  if completion_item.data then
    local context_item = completion_item.data.context_item
    ---@cast context_item eca.ChatContext
    if context_item.type == "file" then
      completion_item.documentation = self:_get_documentation(context_item, 20)
    end
    callback(completion_item)
  end
end

return source
