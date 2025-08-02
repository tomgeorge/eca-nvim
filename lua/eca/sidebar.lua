local Utils = require("eca.utils")
local Config = require("eca.config")

---@class eca.Sidebar
---@field public id integer The tab ID
---@field public winid integer The window ID
---@field public bufnr integer The buffer number
---@field private _initialized boolean Whether the sidebar has been initialized
local M = {}
M.__index = M

---@param id integer Tab ID
---@return eca.Sidebar
function M:new(id)
  local instance = setmetatable({}, M)
  instance.id = id
  instance.winid = -1
  instance.bufnr = -1
  instance._initialized = false
  return instance
end

---@return boolean
function M:is_open()
  return vim.api.nvim_win_is_valid(self.winid)
end

---@param opts? table
function M:open(opts)
  opts = opts or {}
  
  if self:is_open() then
    if Config.behaviour.auto_focus_sidebar then
      vim.api.nvim_set_current_win(self.winid)
    end
    return
  end
  
  self:_create_buffer()
  self:_create_window()
  self:_setup_buffer()
  
  if Config.behaviour.auto_focus_sidebar then
    vim.api.nvim_set_current_win(self.winid)
  end
  
  Utils.debug("ECA sidebar opened")
end

function M:close()
  if self:is_open() then
    vim.api.nvim_win_close(self.winid, false)
    self.winid = -1
  end
  Utils.debug("ECA sidebar closed")
end

---@param opts? table
---@return boolean
function M:toggle(opts)
  if self:is_open() then
    self:close()
    return false
  else
    self:open(opts)
    return true
  end
end

function M:focus()
  if self:is_open() then
    vim.api.nvim_set_current_win(self.winid)
  else
    self:open()
  end
end

function M:resize()
  if not self:is_open() then return end
  
  local width = Config.get_window_width()
  vim.api.nvim_win_set_width(self.winid, width)
end

function M:reset()
  if self:is_open() then
    self:close()
  end
  self._initialized = false
end

function M:_create_buffer()
  if vim.api.nvim_buf_is_valid(self.bufnr) then
    return
  end
  
  self.bufnr = vim.api.nvim_create_buf(false, false)
  local constants = Utils.constants()
  vim.api.nvim_buf_set_name(self.bufnr, constants.SIDEBAR_BUFFER_NAME)
end

function M:_create_window()
  local width = Config.get_window_width()
  local height = vim.o.lines - vim.o.cmdheight - 1
  
  Utils.debug(string.format("Creating window with width: %d (%.1f%% of %d columns)", 
    width, Config.options.windows.width, vim.o.columns))
  
  -- Create vertical split on the right
  vim.cmd("rightbelow vertical split")
  self.winid = vim.api.nvim_get_current_win()
  
  -- Set the buffer in the window
  vim.api.nvim_win_set_buf(self.winid, self.bufnr)
  
  -- Set window width
  vim.api.nvim_win_set_width(self.winid, width)
  
  -- Set window options
  vim.api.nvim_set_option_value("wrap", Config.windows.wrap, { win = self.winid })
  vim.api.nvim_set_option_value("number", false, { win = self.winid })
  vim.api.nvim_set_option_value("relativenumber", false, { win = self.winid })
  vim.api.nvim_set_option_value("signcolumn", "no", { win = self.winid })
  vim.api.nvim_set_option_value("foldcolumn", "0", { win = self.winid })
  vim.api.nvim_set_option_value("cursorline", false, { win = self.winid })
end

function M:_setup_buffer()
  if self._initialized then return end
  
  local constants = Utils.constants()
  
  -- Set buffer options
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = self.bufnr })  -- Use markdown for markview
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = self.bufnr })
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = self.bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = self.bufnr })
  vim.api.nvim_set_option_value("modifiable", true, { buf = self.bufnr })
  
  -- Set initial content
  self:_set_welcome_content()
  
  -- Set up autocmds for this buffer
  self:_setup_autocmds()
  
  -- Setup markview integration
  self:_setup_markview()
  
  self._initialized = true
end

function M:_setup_markview()
  -- Check if markview is available and enabled in config
  if not Config.markview.enable then
    return
  end
  
  local markview_ok, markview = pcall(require, "markview")
  if not markview_ok then
    Utils.debug("markview.nvim not found, using plain markdown rendering")
    return
  end
  
  -- Enable markview for this buffer
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(self.bufnr) then
      -- Configure markview with the new API
      local markview_config = {
        preview = {
          filetypes = Config.markview.filetypes,
          ignore_buftypes = {},
        },
        markdown = {
          headings = {
            enable = true,
            shift_width = 1,
          },
          code_blocks = {
            enable = true,
            style = "language",
            border_hl = "CursorLine",
          },
          list_items = {
            enable = true,
            shift_width = 2,
          },
          tables = {
            enable = true,
          },
        },
        links = {
          enable = true,
        },
        max_length = 99999, -- Allow long content
      }
      
      -- Set up markview (only once globally)
      if not vim.g.markview_eca_setup then
        markview.setup(markview_config)
        vim.g.markview_eca_setup = true
      end
      
      -- Enable markview for this buffer using the new API
      if markview.enable then
        markview.enable(self.bufnr)
      elseif markview.attach then
        markview.attach(self.bufnr)
      else
        -- Fallback: try to enable manually
        vim.api.nvim_buf_call(self.bufnr, function()
          vim.cmd("Markview enable")
        end)
      end
      
      Utils.debug("markview.nvim enabled for ECA sidebar")
    end
  end)
end

function M:_set_welcome_content()
  local lines = {
    "# 🤖 ECA - Editor Code Assistant",
    "",
    "> **Welcome to ECA!** Your AI-powered code assistant is ready to help.",
    "",
    "## 🚀 Getting Started",
    "",
    "- **Chat**: Type your message below and press `Enter`",
    "- **Context**: Use `@` to mention files or directories",
    "- **Commands**: Use `:EcaAddFile` to add file context",
    "- **Selection**: Use `:EcaAddSelection` to add code selection",
    "",
    "## 💡 Examples",
    "",
    "```markdown",
    "Explain this function",
    "Help me optimize this code",
    "What does this error mean?",
    "```",
    "",
    "---",
    "",
    "**💬 Start chatting below:**",
    "",
    "> ",
  }
  
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)
  
  -- Move cursor to the input line
  local line_count = #lines
  vim.api.nvim_win_set_cursor(self.winid, { line_count, 2 })
end

function M:_setup_autocmds()
  local group = vim.api.nvim_create_augroup("EcaSidebar_" .. self.bufnr, { clear = true })
  
  -- Handle buffer deletion
  vim.api.nvim_create_autocmd("BufDelete", {
    buffer = self.bufnr,
    group = group,
    callback = function()
      self.bufnr = -1
      self.winid = -1
      self._initialized = false
    end,
  })
  
  -- Handle window close
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(ev)
      if tonumber(ev.match) == self.winid then
        self.winid = -1
      end
    end,
  })
  
  -- Handle Enter key for sending messages
  vim.keymap.set("i", "<CR>", function()
    self:_handle_input()
  end, { buffer = self.bufnr, noremap = true })
  
  vim.keymap.set("n", "<CR>", function()
    self:_handle_input()
  end, { buffer = self.bufnr, noremap = true })
end

function M:_handle_input()
  local cursor = vim.api.nvim_win_get_cursor(self.winid)
  local current_line = cursor[1]
  local line_content = vim.api.nvim_buf_get_lines(self.bufnr, current_line - 1, current_line, false)[1]
  
  -- Check if line starts with "> " (prompt)
  if line_content and line_content:match("^> ") then
    local message = line_content:sub(3):trim()
    if message and message ~= "" then
      self:_send_message(message)
    end
  end
end

---@param message string
function M:_send_message(message)
  Utils.debug("Sending message: " .. message)
  
  -- Add user message to chat
  self:_add_message("user", message)
  
  -- TODO: Send message to ECA server and handle response
  -- For now, just add a placeholder response
  vim.defer_fn(function()
    self:_add_message("assistant", "This is a placeholder response. ECA server communication is not yet implemented.")
    self:_add_input_line()
  end, 100)
end

---@param role "user" | "assistant"
---@param content string
function M:_add_message(role, content)
  local lines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)
  
  -- Remove the last input line if it exists
  if #lines > 0 and lines[#lines]:match("^> ") then
    table.remove(lines)
  end
  
  -- Add separator if not the first message
  if #lines > 0 and lines[#lines] ~= "" then
    table.insert(lines, "")
    table.insert(lines, "---")
    table.insert(lines, "")
  end
  
  -- Add role header with better markdown formatting
  if role == "user" then
    table.insert(lines, "## 👤 You")
  else
    table.insert(lines, "## 🤖 ECA")
  end
  
  table.insert(lines, "")
  
  -- Add content with better markdown formatting
  local content_lines = Utils.split_lines(content)
  
  -- Check if content looks like code (starts with common programming patterns)
  local is_code = content:match("^%s*function") or 
                  content:match("^%s*class") or
                  content:match("^%s*def ") or
                  content:match("^%s*import") or
                  content:match("^%s*#include") or
                  content:match("^%s*<%?") or
                  content:match("^%s*<html")
  
  if is_code then
    -- Wrap in code block with auto-detection
    table.insert(lines, "```")
    for _, line in ipairs(content_lines) do
      table.insert(lines, line)
    end
    table.insert(lines, "```")
  else
    -- Regular text content
    for _, line in ipairs(content_lines) do
      table.insert(lines, line)
    end
  end
  
  table.insert(lines, "")
  
  -- Update buffer
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)
  
  -- Scroll to bottom
  local line_count = #lines
  vim.api.nvim_win_set_cursor(self.winid, { line_count, 0 })
  
  -- Refresh markview rendering if available
  self:_refresh_markview()
end

function M:_refresh_markview()
  if not Config.markview.enable then
    return
  end
  
  local markview_ok, markview = pcall(require, "markview")
  if markview_ok and vim.api.nvim_buf_is_valid(self.bufnr) then
    vim.schedule(function()
      -- Try different methods to refresh markview based on available API
      if markview.disable and markview.enable then
        -- New API: disable then enable
        markview.disable(self.bufnr)
        markview.enable(self.bufnr)
      elseif markview.detach and markview.attach then
        -- Old API: detach then attach
        markview.detach(self.bufnr)
        markview.attach(self.bufnr)
      else
        -- Fallback: use command
        vim.api.nvim_buf_call(self.bufnr, function()
          pcall(vim.cmd, "Markview disable")
          pcall(vim.cmd, "Markview enable")
        end)
      end
    end)
  end
end

function M:_add_input_line()
  local lines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)
  table.insert(lines, "> ")
  
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)
  
  -- Move cursor to input line
  local line_count = #lines
  vim.api.nvim_win_set_cursor(self.winid, { line_count, 2 })
  
  -- Enter insert mode
  vim.cmd("startinsert!")
end

-- Helper function to trim strings
function string:trim()
  return self:match("^%s*(.-)%s*$")
end

return M
