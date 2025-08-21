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

  ---@param messages eca.Message[]
  local function add_messages_to_buf(messages)
    local rendered = vim
      .iter(messages)
      :map(function(msg)
        return msg.content
      end)
      :fold({}, function(acc, msg)
        for _, m in ipairs(vim.split(msg, "\n")) do
          table.insert(acc, m)
        end
        return acc
      end)
    vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, rendered)
  end

  add_messages_to_buf(opts.messages or {})
end

return UI
