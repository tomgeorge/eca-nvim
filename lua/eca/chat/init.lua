---@class eca.Chat
---@field id number the chat id
---@field title string LLM-generated summary of the discussion
---@field contexts eca.ChatContext[] the contexts for the chat
---@field messages string[] chat messages from the server
---@field mappings table<string, string>
---@field ui eca.ChatUI the ui provider for the chat
local Chat = {}

local default_mappings = {
  close = "<leader>ax",
}

---@param windows eca.ChatUIWindows
local function make_buffer_mappings(_) end

---@class eca.ChatOpts
---@field id number
---@field ui eca.ChatUIOpts
---@field mappings table<string, string>

---@param opts? eca.ChatOpts
---@return eca.Chat
function Chat.new(opts)
  opts = vim.tbl_deep_extend("force", {
    ui = {},
    id = math.random(1000, 9999),
    title = "",
    mappings = default_mappings,
  }, opts or {})

  local ui = require("eca.chat.ui").new(opts.id, opts.ui)

  return setmetatable({
    id = opts.id,
    ui = require("eca.chat.ui").new(opts.id, opts.ui),
    mappings = opts.mappings,
    messages = {},
    contexts = { { type = "repoMap" } },
    help = opts.help,
  }, { __index = Chat })
end

---@param message string
function Chat:push(message)
  table.insert(self.messages, message)
end

function Chat:is_open()
  return self.ui:is_open()
end

function Chat:open()
  self.ui:render({ messages = self.messages, contexts = self.contexts })
  self.ui:open()
end

function Chat:close()
  self.ui:close()
end

function Chat:open_help()
  self.ui:open_help(self.mappings)
end

return Chat
