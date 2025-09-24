--- tuple of keymap, description
---@alias eca.ChatKeymapSpec [string, string]

--- mappings are tuples of keymaps and description
---@class eca.ChatKeymaps
---@field close eca.ChatKeymapSpec
---@field open_help eca.ChatKeymapSpec
---@field toggle_context eca.ChatKeymapSpec
---@field toggle_usage eca.ChatKeymapSpec

---@type eca.ChatKeymaps
local default_mappings = {
  toggle_context = { "<leader>ct", "Toggle context view" },
  toggle_usage = { "<leader>ut", "Toggle usage view" },
  close = { "<leader>ax", "Close chat window" },
  open_help = { "g?", "Show help" },
}

---@alias eca.UserKeymapOverrides {[string]: string}

---@class eca.Chat
---@field id number the chat id
---@field title string LLM-generated summary of the discussion
---@field contexts eca.ChatContext[] the contexts for the chat
---@field messages string[] chat messages from the server
---@field mappings eca.ChatKeymaps
---@field ui eca.ChatUI the ui provider for the chat
local Chat = {}

---@param chat eca.Chat
local function make_buffer_mappings(chat)
  local function buf_map(buf, lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = buf, desc = desc, silent = true })
  end

  for _, window in pairs(chat.ui.windows) do
    buf_map(window.buf, chat.mappings.close[1], function()
      chat:close()
    end, chat.mappings.close[2])
    buf_map(window.buf, chat.mappings.toggle_context[1], function()
      chat:toggle_context()
    end, chat.mappings.toggle_context[2])
    buf_map(window.buf, chat.mappings.open_help[1], function()
      chat:open_help()
    end, chat.mappings.open_help[2])
    buf_map(window.buf, chat.mappings.toggle_usage[1], function()
      chat:toggle_usage()
    end, chat.mappings.toggle_usage[2])
  end
end

--- Override default mappings
--- We need a special function here because we store the mappings as a tuple of
--- mapping and description. Users should not need to pass in this tuple, as
--- they aren't changing the description, only the mapping
--- @param mappings eca.UserKeymapOverrides
local function override_mappings(mappings)
  local m = default_mappings
  for k, mapping in pairs(mappings) do
    m[k][1] = mapping
  end
  return m
end

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
  }, opts or {})

  local ui = require("eca.chat.ui").new(opts.id, opts.ui)
  local self = setmetatable({
    id = opts.id,
    ui = ui,
    mappings = override_mappings(opts.mappings or {}),
    messages = {},
    contexts = { { type = "repoMap" } },
    help = opts.help,
  }, { __index = Chat })
  make_buffer_mappings(self)
  return self
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

function Chat:toggle_context()
  self.ui:toggle_context()
end

function Chat:toggle_usage()
  self.ui:toggle_usage()
end

return Chat
