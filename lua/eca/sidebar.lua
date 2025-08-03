local Utils = require("eca.utils")
local Config = require("eca.config")

---@param str string
---@return string
local function trim(str)
  return str:match("^%s*(.-)%s*$")
end

---@class eca.Sidebar
---@field public id integer The tab ID
---@field public winid integer The window ID
---@field public bufnr integer The buffer number
---@field private _initialized boolean Whether the sidebar has been initialized
---@field private _current_response_buffer string Buffer for accumulating streaming response
---@field private _is_streaming boolean Whether we're currently receiving a streaming response
---@field private _last_assistant_line integer Line number of the last assistant message
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
  instance._current_response_buffer = ""
  instance._is_streaming = false
  instance._last_assistant_line = 0
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
    "- **Chat**: Type your message below and press `Ctrl+S` to send",
    "- **Multiline**: Use `Enter` for new lines, `Ctrl+S` to send",
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
    "## ⌨️ Shortcuts",
    "",
    "- **`Ctrl+S`**: Send message",
    "- **`Enter`**: New line in message",
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
  
  -- Handle Ctrl+S for sending messages
  vim.keymap.set("i", "<C-s>", function()
    self:_handle_input()
  end, { buffer = self.bufnr, noremap = true, desc = "Send message to ECA" })
  
  vim.keymap.set("n", "<C-s>", function()
    self:_handle_input()
  end, { buffer = self.bufnr, noremap = true, desc = "Send message to ECA" })
end

function M:_handle_input()
  local cursor = vim.api.nvim_win_get_cursor(self.winid)
  local current_line = cursor[1]
  
  -- Find the last prompt line (starts with "> ")
  local lines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)
  local prompt_start = nil
  
  -- Look for the last "> " line
  for i = #lines, 1, -1 do
    if lines[i]:match("^> ") then
      prompt_start = i
      break
    end
  end
  
  if not prompt_start then
    Utils.warn("No prompt found")
    return
  end
  
  -- Collect all lines from the prompt to the current position
  local message_lines = {}
  local first_line = lines[prompt_start]:sub(3) -- Remove "> " prefix
  if first_line and trim(first_line) ~= "" then
    table.insert(message_lines, trim(first_line))
  end
  
  -- Add subsequent lines until we reach the current cursor or find another prompt
  for i = prompt_start + 1, current_line do
    local line = lines[i]
    if line and not line:match("^> ") then -- Don't include other prompts
      table.insert(message_lines, line)
    else
      break
    end
  end
  
  -- Join all lines and trim
  local message = trim(table.concat(message_lines, "\n"))
  
  if message and message ~= "" then
    self:_send_message(message)
  else
    Utils.warn("Empty message")
  end
end

---@param message string
function M:_send_message(message)
  Utils.debug("Sending message: " .. message)
  
  -- Add user message to chat
  self:_add_message("user", message)
  
  -- Send message to ECA server
  local eca = require("eca")
  if eca.server and eca.server:is_running() then
    eca.server:send_chat_message(message, {}, function(err, result)
      if err then
        Utils.error("Failed to send message to ECA server: " .. tostring(err))
        self:_add_message("assistant", "❌ **Error**: Failed to send message to ECA server")
        self:_add_input_line()
      end
      -- Response will come through server notification handler
    end)
  else
    self:_add_message("assistant", "❌ **Error**: ECA server is not running. Please check server status.")
    self:_add_input_line()
  end
end

---@param params table Server content notification
function M:_handle_server_content(params)
  if not params or not params.content then return end
  
  local content = params.content
  
  if content.type == "text" then
    -- Handle streaming text content
    self:_handle_streaming_text(content.text)
  elseif content.type == "progress" then
    if content.state == "running" then
      self:_add_message("assistant", "⏳ " .. (content.text or "Processing..."))
    elseif content.state == "finished" then
      -- Finalize any streaming response and prepare for next input
      self:_finalize_streaming_response()
      self:_add_input_line()
    end
  elseif content.type == "usage" then
    -- Finalize streaming before adding usage info
    self:_finalize_streaming_response()
    local usage_text = string.format("💰 **Usage**: Tokens: %d input, %d output", 
      content.messageInputTokens or 0, 
      content.messageOutputTokens or 0)
    if content.messageCost then
      usage_text = usage_text .. " | Cost: " .. content.messageCost
    end
    self:_add_message("assistant", usage_text)
  elseif content.type == "toolCallPrepare" then
    self:_finalize_streaming_response()
    local tool_text = string.format("🔧 **Tool Call**: %s\n```json\n%s\n```", 
      content.name, content.argumentsText)
    self:_add_message("assistant", tool_text)
  elseif content.type == "toolCalled" then
    self:_finalize_streaming_response()
    local tool_text = string.format("✅ **Tool Result**: %s", content.name)
    if content.outputs and #content.outputs > 0 then
      for _, output in ipairs(content.outputs) do
        if output.type == "text" then
          tool_text = tool_text .. "\n" .. output.content
        end
      end
    end
    self:_add_message("assistant", tool_text)
  end
end

---@param text string
function M:_handle_streaming_text(text)
  if not self._is_streaming then
    -- Start new streaming response
    self._is_streaming = true
    self._current_response_buffer = ""
    self:_start_assistant_message()
  end
  
  -- Accumulate text
  self._current_response_buffer = self._current_response_buffer .. text
  
  -- Update the current assistant message with accumulated text
  self:_update_current_assistant_message(self._current_response_buffer)
end

function M:_start_assistant_message()
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
  
  -- Add assistant header
  table.insert(lines, "## 🤖 ECA")
  table.insert(lines, "")
  
  -- Add empty content line (will be updated with streaming text)
  table.insert(lines, "")
  
  -- Store the line number where the content will be updated
  self._last_assistant_line = #lines
  
  -- Update buffer
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)
end

---@param text string
function M:_update_current_assistant_message(text)
  if not self._is_streaming or self._last_assistant_line == 0 then
    return
  end
  
  local lines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)
  
  -- Split the accumulated text into lines
  local content_lines = Utils.split_lines(text)
  
  -- Replace the content starting from the assistant content line
  local new_lines = {}
  
  -- Keep lines before the assistant content
  for i = 1, self._last_assistant_line - 1 do
    table.insert(new_lines, lines[i] or "")
  end
  
  -- Add the updated content
  for _, line in ipairs(content_lines) do
    table.insert(new_lines, line)
  end
  
  -- Update buffer
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, new_lines)
  
  -- Scroll to bottom
  local line_count = #new_lines
  vim.api.nvim_win_set_cursor(self.winid, { line_count, 0 })
  
  -- Refresh markview rendering
  self:_refresh_markview()
end

function M:_finalize_streaming_response()
  if self._is_streaming then
    self._is_streaming = false
    self._current_response_buffer = ""
    self._last_assistant_line = 0
    
    -- Add an empty line after the response
    local lines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)
    table.insert(lines, "")
    vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)
  end
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
---@param str string
---@return string
local function trim(str)
  return str:match("^%s*(.-)%s*$")
end

return M
