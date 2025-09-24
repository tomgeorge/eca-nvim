---@class eca.ChatUIWindows
---@field chat eca.ChatWindowConfiguration
---@field context eca.ChatWindowConfiguration
---@field usage eca.ChatWindowConfiguration
---@field input eca.ChatWindowConfiguration
---@field help eca.ChatWindowConfiguration

---@class eca.ChatWindowConfiguration
---@field buf? number
---@field win? number
---@field enter boolean
---@field win_config vim.api.keyset.win_config
---@field win_options table
---@field buf_options table
---@field name string

---@param window eca.ChatWindowConfiguration
---@param relative_win? number
---@return eca.ChatWindowConfiguration
local function open_win(window, relative_win)
  if relative_win then
    window.win_config.win = relative_win
  end
  if not window.win or not vim.api.nvim_win_is_valid(window.win) then
    window.win = vim.api.nvim_open_win(window.buf, window.enter, window.win_config)
    for option, value in pairs(window.buf_options) do
      vim.api.nvim_set_option_value(option, value, { buf = window.buf })
    end
    if window.name ~= "Help" then
      vim.api.nvim_buf_set_name(window.buf, window.name)
    end
  end
  return window
end

---@class eca.ChatUI
---@field id number
---@field ns number
---@field windows eca.ChatUIWindows
local UI = {}

local gwidth = math.floor(
  vim.api.nvim_list_uis() and vim.api.nvim_list_uis()[1] and vim.api.nvim_list_uis()[1].width or vim.o.columns
)

local gheight = math.floor(
  vim.api.nvim_list_uis() and vim.api.nvim_list_uis()[1] and vim.api.nvim_list_uis()[1].height or vim.o.lines
)

local default_size = 0.4

---@type eca.ChatUIWindows
local default_windows = {
  chat = {
    name = "Chat",
    enter = false,
    win_config = {
      width = math.floor(gwidth * default_size),
      split = "right",
    },
    win_options = {},
    buf_options = {
      filetype = "markdown",
    },
  },
  input = {
    name = "Input",
    enter = true,
    win_config = {
      height = 10,
      width = math.floor(gwidth * default_size),
      split = "below",
    },
    win_options = {},
    buf_options = {
      filetype = "eca_input",
    },
  },
  context = {
    name = "Contexts",
    enter = false,
    win_config = {
      height = 1,
      width = math.floor(gwidth * default_size),
      split = "below",
    },
    win_options = {},
    buf_options = {
      filetype = "eca_context",
    },
  },
  usage = {
    name = "Usage",
    enter = false,
    win_config = {
      height = 1,
      width = math.floor(gwidth * default_size),
      split = "below",
    },
    win_options = {},
    buf_options = {
      filetype = "eca_usage",
    },
  },
  help = {
    name = "Help",
    enter = true,
    win_config = {
      relative = "cursor",
      row = 10,
      col = 10,
      width = 10,
      height = 10,
      title = "Buffer mappings",
      border = "single",
    },
    win_options = {
      number = false,
      relativenumber = false,
      cursorline = true,
    },
    buf_options = {
      filetype = "eca-help",
      modifiable = false,
    },
  },
}

---@alias eca.UIMessage string

---@class eca.ChatUIOpts
---@field windows eca.ChatUIWindows

---@param id number
---@param opts eca.ChatUIOpts
---@return eca.ChatUI
function UI.new(id, opts)
  opts = opts or {}
  local ns = vim.api.nvim_create_namespace("eca.chat.ui")

  local windows = vim.tbl_deep_extend("force", default_windows, opts.windows or {})

  for _, window in pairs(windows) do
    if not window.buf then
      window.buf = vim.api.nvim_create_buf(false, true)
    end
  end

  return setmetatable({
    id = id,
    ns = ns,
    windows = windows,
  }, { __index = UI })
end

---@param contexts eca.ChatContext[]
local function render_contexts(contexts)
  local ctx = vim.iter(contexts):fold("Contexts:", function(s, context)
    return s .. " @" .. context.type
  end)
  return { ctx }
end

---@param state {messages: eca.UIMessage[], contexts: eca.ChatContext[]}
function UI:render(state)
  state = state or {}
  if state.contexts then
    vim.api.nvim_buf_set_lines(self.windows.context.buf, 0, -1, false, render_contexts(state.contexts))
  end
  local _ = require("eca.highlights")
  vim.api.nvim_buf_set_lines(self.windows.chat.buf, 0, -1, false, state.messages)
end

---@param message eca.UIMessage
function UI:append(message)
  message = message or ""
  vim.api.nvim_buf_set_lines(self.windows.chat.buf, -1, -1, false, { message })
end

--- Open the chat window
--- NOTE: Order matters here
function UI:open()
  if not self:is_open() then
    --- TODO: do we want to make these default windows configurable?
    self.windows.chat = open_win(self.windows.chat)
    self.windows.input = open_win(self.windows.input, self.windows.chat.win)
    self.windows.context = open_win(self.windows.context, self.windows.chat.win)
  end
end

function UI:close()
  if not self:is_open() then
    return
  end
  ---@type eca.ChatWindowConfiguration
  for _, window in pairs(self.windows) do
    if window.win and window.win > 0 and vim.api.nvim_win_is_valid(window.win) then
      vim.api.nvim_win_hide(window.win)
      vim.api.nvim_buf_delete(window.buf, { unload = true })
      window.win = nil
    end
  end
end

---@return boolean
function UI:is_open()
  for _, window in pairs(self.windows) do
    if window.win and vim.api.nvim_win_is_valid(window.win) then
      return true
    end
  end
  return false
end

--- TODO: better type
--- @param mappings table<string, table<string, string>>
function UI:open_help(mappings)
  local map_data, desc_width = {}, 0

  for _, mapping in pairs(mappings) do
    local keymap = mapping[1]
    local desc = mapping[2]
    desc_width = math.max(desc_width, string.len(desc))
    map_data[desc] = keymap
  end

  local desc_arr = vim.tbl_keys(map_data)
  table.sort(desc_arr)
  local map_format = string.format("%%-%ds │ %%s", desc_width)

  local lines = {}
  for _, desc in ipairs(desc_arr) do
    table.insert(lines, string.format(map_format, desc, map_data[desc]))
  end

  table.insert(lines, "")
  table.insert(lines, "(Press `q` to close)")

  local line_widths = {}
  for _, line in ipairs(lines) do
    table.insert(line_widths, vim.fn.strdisplaywidth(line))
  end
  local max_width = math.max(unpack(line_widths))
  local height = #lines

  vim.api.nvim_set_option_value("modifiable", true, { buf = self.windows.help.buf })
  vim.api.nvim_buf_set_lines(self.windows.help.buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = self.windows.help.buf })

  self.windows.help.win_config = vim.tbl_deep_extend("force", self.windows.help.win_config, {
    relative = "cursor",
    width = max_width + 2,
    height = height,
    col = math.floor((gwidth - max_width) / 2),
    row = math.floor((gheight - height) / 2),
    style = "minimal",
    border = "rounded",
    title_pos = "center",
  })

  open_win(self.windows.help)

  vim.keymap.set("n", "q", "<Cmd>close<CR>", {
    buffer = self.windows.help.buf,
    desc = "Close help window",
    nowait = true,
    silent = true,
  })
end

return UI
