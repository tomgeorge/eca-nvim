---@class eca.Chat
---@field server eca.server
---@field messages eca.Message[]
---@field ui eca.chat.UI

---@class eca.ChatOpts
---@field bufnr integer
---@field messages eca.Message
---@field show_welcome boolean

---@alias eca.Message {content: string}
---@alias eca.AddMessageArg {content: string} | string

local default_welcome = [[
  # 🤖 ECA - Editor Code Assistant

  > **Welcome to ECA!** Your AI-powered code assistant is ready to help.

  ## 🚀 Getting Started

  - **Chat**: Type your message in the input field at the bottom and press `Ctrl+S` to send
  - **Multiline**: Use `Enter` for new lines `Ctrl+S` to send
  - **Context**: Use `@` to mention files or directories
  - **Context**: Use `:EcaAddFile` to add files, `:EcaListContexts` to view, `:EcaClearContexts` to clear
  - **Selection**: Use `:EcaAddSelection` to add code selection
  - **RepoMap**: Use `:EcaAddRepoMap` to add repository structure context

  ---
]]

local Chat = {}

---@param opts? eca.ChatOpts
---@return eca.Chat
function Chat.new(opts)
  opts = opts or {}
  local self = setmetatable({
    messages = opts.messages or {},
    show_welcome = opts.show_welcome == nil and true or opts.show_welcome,
    server = opts.server or nil,
  }, { __index = Chat })

  local server = require("eca").server
  if server:is_running() then
    self.server = server
  end

  self.ui = require("eca.chat.ui").new({
    bufnr = opts.bufnr,
    winnr = opts.winnr,
  })

  if self.show_welcome then
    self:add_message(self:welcome_message())
  end
  return self
end

---@param message eca.Message | string
function Chat:add_message(message)
  if type(message) == "string" then
    table.insert(self.messages, { content = message })
    return
  end
  if message and message.content then
    table.insert(self.messages, message)
  end
end

---@return string
function Chat:welcome_message()
  if self.server and self.server:is_running() then
    return self.server.chat_welcome_message
  end
  return default_welcome
end

return Chat
