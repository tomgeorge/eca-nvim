---@class eca.chat.UIOpts
---@field bufnr integer
---@field winnr integer
---@field chat_id integer
---@field window vim.api.keyset.win_config

---@class eca.chat.UI
---@field bufnr integer
---@field winnr integer
---@field chat_id integer
---@field window vim.api.keyset.win_config
local UI = {}

---@return eca.chat.UI
---@param opts eca.chat.UIOpts
function UI.new(opts)
  opts = opts or {}
  return setmetatable({
    bufnr = opts.bufnr,
    chat_id = opts.chat_id,
    winnr = opts.winnr,
    window = opts.window,
  }, { __index = UI })
end

function UI:render(opts)
  if not opts.messages then
    return
  end
  local acc = {}
  local messages = vim
    .iter(opts.messages)
    :map(function(m)
      return m.content
    end)
    :each(function(m) end)

  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, { messages.line })
end

return UI
