local Utils = require("eca.utils")
local Config = require("eca.config")

---@param str string
---@return string
local function trim(str)
  return str:match("^%s*(.-)%s*$")
end

---@class eca.Container
---@field public winid integer The window ID
---@field public bufnr integer The buffer number

---@class eca.Sidebar
---@field public id integer The tab ID
---@field public containers table<string, eca.Container> The containers (chat, usage, input)
---@field private _initialized boolean Whether the sidebar has been initialized
---@field private _current_response_buffer string Buffer for accumulating streaming response
---@field private _is_streaming boolean Whether we're currently receiving a streaming response
---@field private _last_assistant_line integer Line number of the last assistant message
---@field private _usage_info string Current usage information
---@field private _last_user_message string Last user message to avoid duplicates
---@field private _current_tool_call table Current tool call being accumulated
---@field private _is_tool_call_streaming boolean Whether we're currently receiving a streaming tool call
---@field private _force_welcome boolean Whether to force show welcome content on next open
---@field private _contexts table Active contexts for this chat session
local M = {}
M.__index = M

---@param id integer Tab ID
---@return eca.Sidebar
function M:new(id)
  local instance = setmetatable({}, M)
  instance.id = id
  instance.containers = {}
  instance._initialized = false
  instance._current_response_buffer = ""
  instance._is_streaming = false
  instance._last_assistant_line = 0
  instance._usage_info = ""
  instance._last_user_message = ""
  instance._current_tool_call = nil
  instance._is_tool_call_streaming = false
  instance._force_welcome = false
  instance._contexts = {}
  return instance
end

---@return boolean
function M:is_open()
  return self.containers.chat and vim.api.nvim_win_is_valid(self.containers.chat.winid)
end

---@param opts? table
function M:open(opts)
  opts = opts or {}
  
  if self:is_open() then
    if Config.behaviour.auto_focus_sidebar then
      vim.api.nvim_set_current_win(self.containers.input.winid)
    end
    return
  end
  
  -- Check if we have existing containers with valid buffers but invalid windows
  local has_valid_buffers = false
  for name, container in pairs(self.containers) do
    if container and container.bufnr and vim.api.nvim_buf_is_valid(container.bufnr) then
      has_valid_buffers = true
      Utils.debug("Found existing buffer for container: " .. name)
    end
  end
  
  -- Create/recreate windows for containers
  self:_create_containers()
  
  -- Only setup containers (which includes setting content) if we don't have valid buffers
  -- or if this is genuinely the first time
  if not has_valid_buffers or not self._initialized then
    Utils.debug("Setting up containers (first time or no valid buffers)")
    self:_setup_containers()
  else
    Utils.debug("Reusing existing buffers, skipping setup")
    -- Just configure the windows and setup autocmds, but don't reset content
    self:_configure_container_windows()
    self:_setup_autocmds()
    self:_setup_markview()
    self._initialized = true
  end
  
  if Config.behaviour.auto_focus_sidebar then
    vim.api.nvim_set_current_win(self.containers.input.winid)
  end
  
  Utils.debug("ECA sidebar opened")
end

function M:close()
  self:_close_windows_only()
end

function M:_close_windows_only()
  -- Close windows but preserve buffers and container references
  for name, container in pairs(self.containers) do
    if container then
      -- Close window if valid
      if vim.api.nvim_win_is_valid(container.winid) then
        vim.api.nvim_win_close(container.winid, false)
      end
      -- Mark window as invalid but keep buffer reference
      container.winid = -1
    end
  end
  Utils.debug("ECA sidebar windows closed (buffers preserved)")
end

function M:_close_and_cleanup()
  -- This is the old close() behavior - actually delete buffers
  for name, container in pairs(self.containers) do
    if container then
      -- Close window if valid
      if vim.api.nvim_win_is_valid(container.winid) then
        vim.api.nvim_win_close(container.winid, false)
      end
      
      -- Clean up buffer if it exists and is not being used elsewhere
      if container.bufnr and vim.api.nvim_buf_is_valid(container.bufnr) then
        -- Check if buffer is displayed in any other window
        local wins = vim.fn.win_findbuf(container.bufnr)
        if #wins == 0 then
          -- Buffer is not displayed anywhere, safe to delete
          pcall(vim.api.nvim_buf_delete, container.bufnr, { force = true })
        end
      end
    end
  end
  self.containers = {}
  Utils.debug("ECA sidebar closed and cleaned up")
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
    vim.api.nvim_set_current_win(self.containers.input.winid)
  else
    self:open()
  end
end

function M:resize()
  if not self:is_open() then return end
  
  local width = Config.get_window_width()
  for name, container in pairs(self.containers) do
    if container and vim.api.nvim_win_is_valid(container.winid) then
      vim.api.nvim_win_set_width(container.winid, width)
    end
  end
  self:_adjust_container_heights()
end

function M:reset()
  if self:is_open() then
    self:_close_and_cleanup()
  else
    -- Even if not open, clean up any remaining containers
    self:_close_and_cleanup()
  end
  
  -- Clean up any remaining container references
  self.containers = {}
  self._initialized = false
  self._is_streaming = false
  self._current_response_buffer = ""
  self._last_assistant_line = 0
  self._usage_info = ""
  self._last_user_message = ""
  self._current_tool_call = nil
  self._is_tool_call_streaming = false
  self._force_welcome = false
  self._contexts = {}
end

function M:new_chat()
  -- Reset completely and clear all buffers
  self:reset()
  
  -- Force welcome content on next open
  self._force_welcome = true
  Utils.debug("New chat initiated - will show welcome content on next open")
end

---@param context table Context object with type, path, content
function M:add_context(context)
  -- Check if context already exists (by path)
  for i, existing in ipairs(self._contexts) do
    if existing.path == context.path then
      -- Update existing context
      self._contexts[i] = context
      self:_update_contexts_display()
      Utils.info("Updated context: " .. context.path)
      return
    end
  end
  
  -- Add new context
  table.insert(self._contexts, context)
  self:_update_contexts_display()
  Utils.info("Added context: " .. context.path .. " (" .. #self._contexts .. " total)")
end

---@param path string Path to remove from contexts
function M:remove_context(path)
  for i, context in ipairs(self._contexts) do
    if context.path == path then
      table.remove(self._contexts, i)
      self:_update_contexts_display()
      Utils.info("Removed context: " .. path)
      return true
    end
  end
  Utils.warn("Context not found: " .. path)
  return false
end

---@return table List of active contexts
function M:get_contexts()
  return vim.deepcopy(self._contexts)
end

---@return integer Number of active contexts
function M:get_context_count()
  return #self._contexts
end

function M:clear_contexts()
  local count = #self._contexts
  self._contexts = {}
  self:_update_contexts_display()
  Utils.info("Cleared " .. count .. " contexts")
end

---@private
function M:_update_contexts_display()
  local contexts = self.containers.contexts
  if not contexts or not vim.api.nvim_buf_is_valid(contexts.bufnr) then 
    return 
  end
  
  local lines = {}
  
  if #self._contexts == 0 then
    lines = { "📂 No contexts" }
  else
    -- Create bubbles/badges for each context
    local bubbles = {}
    
    for i, context in ipairs(self._contexts) do
      local icon = context.type == "file" and "📄" or 
                   context.type == "selection" and "📝" or 
                   context.type == "repoMap" and "🗺️" or "📁"
      local name = context.type == "repoMap" and "repoMap" or 
                   vim.fn.fnamemodify(context.path, ":t") -- Get filename only
      
      
      -- Create bubble with modern pill/badge style
      -- Different bubble styles to choose from:
      -- local bubble = "⟮ " .. icon .. name .. " ⟯"        -- Curved brackets (current)
      local bubble = "⌜".. name .."⌟"       -- Rounded corners alt
      table.insert(bubbles, bubble)
    end
    
    -- Start with header and arrange bubbles on same line when possible
    local max_width = 70 -- Approximate container width
    local header = "📂 (" .. #self._contexts .. "):"
    local current_line = header
    local bubble_lines = {}

    
    -- Add all bubbles to the same line
    for i, bubble in ipairs(bubbles) do
      local bubble_width = vim.fn.strdisplaywidth(bubble)
      local current_width = vim.fn.strdisplaywidth(current_line)
      
      -- Add spacing between elements
      local spacing = 1
      
      current_line = current_line .. " " .. bubble
    end
    
    -- Add the last line if not empty
    if current_line ~= "" then
      table.insert(bubble_lines, current_line)
    end
    
    -- Add bubble lines to display
    for _, line in ipairs(bubble_lines) do
      table.insert(lines, line)
    end
    
  end
  
  -- Update the buffer
  vim.api.nvim_set_option_value("modifiable", true, { buf = contexts.bufnr })
  vim.api.nvim_buf_set_lines(contexts.bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = contexts.bufnr })
end

---@param name string
---@return integer
function M:_get_or_create_buffer(name)
  -- Check if buffer with this name already exists
  local existing_bufnr = vim.fn.bufnr(name)
  if existing_bufnr ~= -1 and vim.api.nvim_buf_is_valid(existing_bufnr) then
    return existing_bufnr
  end
  
  -- Create new buffer
  local bufnr = vim.api.nvim_create_buf(false, false)
  
  -- Try to set the name, if it fails (name exists), use a unique name
  local success = pcall(vim.api.nvim_buf_set_name, bufnr, name)
  if not success then
    -- Generate unique name by adding timestamp
    local unique_name = name .. "_" .. tostring(vim.fn.localtime())
    pcall(vim.api.nvim_buf_set_name, bufnr, unique_name)
  end
  
  return bufnr
end

function M:_create_containers()
  local width = Config.get_window_width()
  local total_height = vim.o.lines - vim.o.cmdheight - 1
  
  Utils.debug(string.format("Creating containers with width: %d (%.1f%% of %d columns)", 
    width, Config.options.windows.width, vim.o.columns))
  
  -- Calculate heights: chat takes most space, contexts shows files, usage is 1 line, input is configurable
  local input_height = Config.windows.input and Config.windows.input.height or 4
  local usage_height = 1
  local contexts_height = 3 -- Height for showing context files
  local chat_height = math.max(10, total_height - input_height - usage_height - contexts_height - 3) -- Minimum height for chat
  
  local constants = Utils.constants()
  
  -- Create the main vertical split first
  vim.cmd("rightbelow vertical split")
  local main_winid = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_width(main_winid, width)
  
  -- Create chat container (use the main window)
  local chat_bufnr
  if self.containers.chat and vim.api.nvim_buf_is_valid(self.containers.chat.bufnr) then
    chat_bufnr = self.containers.chat.bufnr
    Utils.debug("Reusing existing chat buffer: " .. chat_bufnr)
  else
    chat_bufnr = self:_get_or_create_buffer(constants.SIDEBAR_BUFFER_NAME .. "_chat")
    Utils.debug("Created new chat buffer: " .. chat_bufnr)
  end
  vim.api.nvim_win_set_buf(main_winid, chat_bufnr)
  
  self.containers.chat = {
    winid = main_winid,
    bufnr = chat_bufnr
  }
  
  -- Create usage container (horizontal split below chat)
  vim.api.nvim_set_current_win(main_winid)
  vim.cmd("below " .. usage_height .. "split")
  local usage_winid = vim.api.nvim_get_current_win()
  local usage_bufnr
  if self.containers.usage and vim.api.nvim_buf_is_valid(self.containers.usage.bufnr) then
    usage_bufnr = self.containers.usage.bufnr
    Utils.debug("Reusing existing usage buffer: " .. usage_bufnr)
  else
    usage_bufnr = self:_get_or_create_buffer(constants.SIDEBAR_BUFFER_NAME .. "_usage")
    Utils.debug("Created new usage buffer: " .. usage_bufnr)
  end
  vim.api.nvim_win_set_buf(usage_winid, usage_bufnr)
  
  self.containers.usage = {
    winid = usage_winid,
    bufnr = usage_bufnr
  }
  
  -- Create contexts container (horizontal split below usage)
  vim.cmd("below " .. contexts_height .. "split")
  local contexts_winid = vim.api.nvim_get_current_win()
  local contexts_bufnr
  if self.containers.contexts and vim.api.nvim_buf_is_valid(self.containers.contexts.bufnr) then
    contexts_bufnr = self.containers.contexts.bufnr
    Utils.debug("Reusing existing contexts buffer: " .. contexts_bufnr)
  else
    contexts_bufnr = self:_get_or_create_buffer(constants.SIDEBAR_BUFFER_NAME .. "_contexts")
    Utils.debug("Created new contexts buffer: " .. contexts_bufnr)
  end
  vim.api.nvim_win_set_buf(contexts_winid, contexts_bufnr)
  
  self.containers.contexts = {
    winid = contexts_winid,
    bufnr = contexts_bufnr
  }
  
  -- Create input container (horizontal split below contexts)
  vim.cmd("below " .. input_height .. "split")
  local input_winid = vim.api.nvim_get_current_win()
  local input_bufnr
  if self.containers.input and vim.api.nvim_buf_is_valid(self.containers.input.bufnr) then
    input_bufnr = self.containers.input.bufnr
    Utils.debug("Reusing existing input buffer: " .. input_bufnr)
  else
    input_bufnr = self:_get_or_create_buffer(constants.SIDEBAR_BUFFER_NAME .. "_input")
    Utils.debug("Created new input buffer: " .. input_bufnr)
  end
  vim.api.nvim_win_set_buf(input_winid, input_bufnr)
  
  self.containers.input = {
    winid = input_winid,
    bufnr = input_bufnr
  }
  
  -- Ensure chat container takes up the remaining space
  vim.api.nvim_set_current_win(main_winid)
  local remaining_height = total_height - usage_height - contexts_height - input_height
  vim.api.nvim_win_set_height(main_winid, math.max(5, remaining_height))
  
  -- Configure window options for all containers
  self:_configure_container_windows()
end

function M:_configure_container_windows()
  for name, container in pairs(self.containers) do
    if container and vim.api.nvim_win_is_valid(container.winid) then
      vim.api.nvim_set_option_value("wrap", Config.windows.wrap, { win = container.winid })
      vim.api.nvim_set_option_value("number", false, { win = container.winid })
      vim.api.nvim_set_option_value("relativenumber", false, { win = container.winid })
      vim.api.nvim_set_option_value("signcolumn", "no", { win = container.winid })
      vim.api.nvim_set_option_value("foldcolumn", "0", { win = container.winid })
      vim.api.nvim_set_option_value("cursorline", false, { win = container.winid })
      vim.api.nvim_set_option_value("winfixheight", true, { win = container.winid })
      vim.api.nvim_set_option_value("winfixwidth", false, { win = container.winid })
      
      -- Special settings for usage container
      if name == "usage" then
        vim.api.nvim_set_option_value("statusline", " ", { win = container.winid })
        vim.api.nvim_set_option_value("winhighlight", "Normal:StatusLine", { win = container.winid })
      end
      
      -- Special settings for contexts container
      if name == "contexts" then
        vim.api.nvim_set_option_value("statusline", " ", { win = container.winid })
        vim.api.nvim_set_option_value("winhighlight", "Normal:Comment", { win = container.winid })
      end
      
      -- Special settings for input container
      if name == "input" then
        vim.api.nvim_set_option_value("statusline", " ", { win = container.winid })
      end
    end
  end
end

function M:_adjust_container_heights()
  if not self:is_open() then return end
  
  local total_height = vim.o.lines - vim.o.cmdheight - 1
  local input_height = Config.windows.input and Config.windows.input.height or 4
  local usage_height = 1
  local contexts_height = 3
  local chat_height = math.max(5, total_height - input_height - usage_height - contexts_height)
  
  -- Adjust heights in order: input, contexts, usage, then chat takes remaining space
  if self.containers.input and vim.api.nvim_win_is_valid(self.containers.input.winid) then
    vim.api.nvim_win_set_height(self.containers.input.winid, input_height)
  end
  if self.containers.contexts and vim.api.nvim_win_is_valid(self.containers.contexts.winid) then
    vim.api.nvim_win_set_height(self.containers.contexts.winid, contexts_height)
  end
  if self.containers.usage and vim.api.nvim_win_is_valid(self.containers.usage.winid) then
    vim.api.nvim_win_set_height(self.containers.usage.winid, usage_height)
  end
  if self.containers.chat and vim.api.nvim_win_is_valid(self.containers.chat.winid) then
    vim.api.nvim_win_set_height(self.containers.chat.winid, chat_height)
  end
end

function M:_setup_containers()
  if self._initialized then return end
  
  -- Setup chat container
  self:_setup_chat_container()
  
  -- Setup usage container
  self:_setup_usage_container()
  
  -- Setup contexts container
  self:_setup_contexts_container()
  
  -- Setup input container
  self:_setup_input_container()
  
  -- Set up autocmds for containers
  self:_setup_autocmds()
  
  -- Setup markview integration for chat container
  self:_setup_markview()
  
  self._initialized = true
end

function M:_setup_chat_container()
  local chat = self.containers.chat
  if not chat then return end
  
  -- Set buffer options for chat
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = chat.bufnr })
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = chat.bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = chat.bufnr })
  vim.api.nvim_set_option_value("modifiable", true, { buf = chat.bufnr })
  
  -- Disable treesitter initially to prevent highlighting errors during setup
  vim.api.nvim_set_option_value("syntax", "off", { buf = chat.bufnr })
  
  -- Set initial content first
  self:_set_welcome_content()
  
  -- Set filetype to markdown for markview (do this after content is set)
  vim.defer_fn(function()
    if vim.api.nvim_buf_is_valid(chat.bufnr) then
      vim.api.nvim_set_option_value("filetype", "markdown", { buf = chat.bufnr })
      vim.api.nvim_set_option_value("syntax", "on", { buf = chat.bufnr })
    end
  end, 200)
end

function M:_setup_usage_container()
  local usage = self.containers.usage
  if not usage then return end
  
  -- Set buffer options for usage
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = usage.bufnr })
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = usage.bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = usage.bufnr })
  vim.api.nvim_set_option_value("modifiable", true, { buf = usage.bufnr })
  
  -- Set initial usage info
  vim.api.nvim_buf_set_lines(usage.bufnr, 0, -1, false, { "Usage: Tokens | Cost" })
  
  -- Now make it non-modifiable
  vim.api.nvim_set_option_value("modifiable", false, { buf = usage.bufnr })
end

function M:_setup_contexts_container()
  local contexts = self.containers.contexts
  if not contexts then return end
  
  -- Set buffer options for contexts
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = contexts.bufnr })
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = contexts.bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = contexts.bufnr })
  vim.api.nvim_set_option_value("modifiable", true, { buf = contexts.bufnr })
  
  -- Set initial contexts display
  self:_update_contexts_display()
  
  -- Now make it non-modifiable
  vim.api.nvim_set_option_value("modifiable", false, { buf = contexts.bufnr })
end

function M:_setup_input_container()
  local input = self.containers.input
  if not input then return end
  
  -- Set buffer options for input
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = input.bufnr })
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = input.bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = input.bufnr })
  vim.api.nvim_set_option_value("modifiable", true, { buf = input.bufnr })
  
  -- Set initial input prompt
  self:_add_input_line()
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
  
  local chat = self.containers.chat
  if not chat then return end
  
  -- Enable markview for chat buffer
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(chat.bufnr) then
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
      
      -- Enable markview for chat buffer using the new API
      if markview.enable then
        markview.enable(chat.bufnr)
      elseif markview.attach then
        markview.attach(chat.bufnr)
      else
        -- Fallback: try to enable manually
        vim.api.nvim_buf_call(chat.bufnr, function()
          vim.cmd("Markview enable")
        end)
      end
      
      Utils.debug("markview.nvim enabled for ECA chat container")
    end
  end)
end

function M:_set_welcome_content()
  local chat = self.containers.chat
  if not chat then return end
  
  -- Check if we should force welcome content (new chat)
  if not self._force_welcome then
    -- Check if buffer already has content (more than just empty lines)
    local existing_lines = vim.api.nvim_buf_get_lines(chat.bufnr, 0, -1, false)
    local has_content = false
    
    for _, line in ipairs(existing_lines) do
      if line:match("%S") then -- Has non-whitespace content
        has_content = true
        break
      end
    end
    
    -- Only set welcome content if buffer is empty or has no meaningful content
    if has_content then
      Utils.debug("Preserving existing chat content")
      return
    end
  else
    -- Force welcome content and reset the flag
    Utils.debug("Forcing welcome content for new chat")
    self._force_welcome = false
  end
  
  local lines = {
    "# 🤖 ECA - Editor Code Assistant",
    "",
    "> **Welcome to ECA!** Your AI-powered code assistant is ready to help.",
    "",
    "## 🚀 Getting Started",
    "",
    "- **Chat**: Type your message in the input field at the bottom and press `Ctrl+S` to send",
    "- **Multiline**: Use `Enter` for new lines, `Ctrl+S` to send",
    "- **Context**: Use `@` to mention files or directories",
    "- **Context**: Use `:EcaAddFile` to add files, `:EcaListContexts` to view, `:EcaClearContexts` to clear",
    "- **Selection**: Use `:EcaAddSelection` to add code selection",
    "- **RepoMap**: Use `:EcaAddRepoMap` to add repository structure context",
    "",
    "---",
    "",
    "**💬 Messages will appear here:**",
    "",
  }
  
  Utils.debug("Setting welcome content for new chat")
  vim.api.nvim_buf_set_lines(chat.bufnr, 0, -1, false, lines)
  
  -- Auto-add repoMap context if enabled and not already present
  local Config = require("eca.config")
  if Config.options.context.auto_repo_map then
    -- Check if repoMap already exists
    local has_repo_map = false
    for _, context in ipairs(self._contexts) do
      if context.type == "repoMap" then
        has_repo_map = true
        break
      end
    end
    
    if not has_repo_map then
      self:add_context({
        type = "repoMap",
        path = "repoMap",
        content = "Repository structure and code mapping for better project understanding"
      })
      Utils.debug("Auto-added repoMap context on welcome")
    end
  end
end

function M:_setup_autocmds()
  local input = self.containers.input
  if not input then return end
  
  local group = vim.api.nvim_create_augroup("EcaSidebar_" .. input.bufnr, { clear = true })
  
  -- Handle container cleanup
  for name, container in pairs(self.containers) do
    if container then
      vim.api.nvim_create_autocmd("BufDelete", {
        buffer = container.bufnr,
        group = group,
        callback = function()
          self.containers[name] = nil
          if name == "chat" then
            self._initialized = false
          end
        end,
      })
      
      vim.api.nvim_create_autocmd("WinClosed", {
        group = group,
        callback = function(ev)
          if container and tonumber(ev.match) == container.winid then
            self.containers[name] = nil
          end
        end,
      })
    end
  end
  
  -- Handle Ctrl+S for sending messages (only on input buffer)
  vim.keymap.set("i", "<C-s>", function()
    self:_handle_input()
  end, { buffer = input.bufnr, noremap = true, desc = "Send message to ECA" })
  
  vim.keymap.set("n", "<C-s>", function()
    self:_handle_input()
  end, { buffer = input.bufnr, noremap = true, desc = "Send message to ECA" })
end

function M:_handle_input()
  local input = self.containers.input
  if not input then return end
  
  -- Get all lines from input buffer
  local lines = vim.api.nvim_buf_get_lines(input.bufnr, 0, -1, false)
  
  -- Remove "> " prefix from first line if it exists
  local message_lines = {}
  for i, line in ipairs(lines) do
    if i == 1 and line:match("^> ") then
      local content = line:sub(3) -- Remove "> " prefix
      if content and trim(content) ~= "" then
        table.insert(message_lines, trim(content))
      end
    elseif line and trim(line) ~= "" then
      table.insert(message_lines, line)
    end
  end
  
  -- Join all lines and trim
  local message = trim(table.concat(message_lines, "\n"))
  
  if message and message ~= "" then
    -- Clear input buffer
    vim.api.nvim_buf_set_lines(input.bufnr, 0, -1, false, {})
    self:_send_message(message)
  else
    Utils.warn("Empty message")
  end
end

---@param message string
function M:_send_message(message)
  Utils.debug("Sending message: " .. message)
  
  -- Store the last user message to avoid duplication
  self._last_user_message = message
  
  -- Add user message to chat
  self:_add_message("user", message)
  
  -- Send message to ECA server
  local eca = require("eca")
  if eca.server and eca.server:is_running() then
    -- Include active contexts in the message
    local contexts = self:get_contexts()
    Utils.debug("Sending message with " .. #contexts .. " contexts")
    eca.server:send_chat_message(message, contexts, function(err, result)
      if err then
        Utils.error("Failed to send message to ECA server: " .. tostring(err))
        self:_add_message("assistant", "❌ **Error**: Failed to send message to ECA server")
      end
      -- Response will come through server notification handler
      self:_add_input_line()
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
    
    -- Update usage container only (remove duplication in chat)
    local usage_text = string.format("Usage: Tokens %d in, %d out", 
      content.messageInputTokens or 0, 
      content.messageOutputTokens or 0)
    if content.messageCost then
      usage_text = usage_text .. " | Cost: " .. content.messageCost
    end
    self:_update_usage_info(usage_text)
  elseif content.type == "toolCallPrepare" then
    self:_finalize_streaming_response()
    self:_handle_tool_call_prepare(content)
    -- IMPORTANT: Return immediately - do NOT display anything for toolCallPrepare
    return
  elseif content.type == "toolCalled" then
    self:_finalize_streaming_response()
    
    -- Show the final accumulated tool call if we have one
    if self._is_tool_call_streaming and self._current_tool_call then
      self:_display_tool_call()
    end
    
    -- Show the tool result
    local tool_text = string.format("✅ **Tool Result**: %s", content.name or "unknown")
    if content.outputs and #content.outputs > 0 then
      for _, output in ipairs(content.outputs) do
        if output.type == "text" and output.content then
          tool_text = tool_text .. "\n" .. output.content
        end
      end
    end
    self:_add_message("assistant", tool_text)
    
    -- Clean up tool call state
    self:_finalize_tool_call()
  end
end

---@param text string
function M:_handle_streaming_text(text)
  if not self._is_streaming then
    -- Check if the entire response buffer (when it starts) is just echoing the user's message
    if self._last_user_message and #self._last_user_message > 0 then
      local accumulated_text = (self._current_response_buffer or "") .. text
      local trimmed_text = trim(accumulated_text)
      local trimmed_user_msg = trim(self._last_user_message)
      
      -- Skip if the accumulated text exactly matches the user's message
      if trimmed_text == trimmed_user_msg then
        Utils.debug("Skipping exact duplicate of user message in assistant response")
        return
      end
      
      -- Skip if this looks like the start of echoing the user message
      if #trimmed_text <= #trimmed_user_msg and trimmed_user_msg:sub(1, #trimmed_text) == trimmed_text then
        Utils.debug("Skipping potential echo of user message")
        return
      end
    end
    
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

---@param bufnr integer
---@param callback function
function M:_safe_buffer_update(bufnr, callback)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end
  
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    
    -- Temporarily disable treesitter highlighting
    local has_ts = pcall(require, "nvim-treesitter.highlight")
    if has_ts then
      pcall(vim.cmd, "TSBufDisable highlight " .. bufnr)
    end
    
    local original_syntax = vim.api.nvim_get_option_value("syntax", { buf = bufnr })
    vim.api.nvim_set_option_value("syntax", "off", { buf = bufnr })
    
    -- Execute the callback
    pcall(callback)
    
    -- Re-enable syntax highlighting with delay
    vim.defer_fn(function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_set_option_value("syntax", original_syntax, { buf = bufnr })
        if has_ts then
          pcall(vim.cmd, "TSBufEnable highlight " .. bufnr)
        end
      end
    end, 50)
  end)
end

function M:_start_assistant_message()
  local chat = self.containers.chat
  if not chat then return end
  
  self:_safe_buffer_update(chat.bufnr, function()
    local lines = vim.api.nvim_buf_get_lines(chat.bufnr, 0, -1, false)
    
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
    vim.api.nvim_buf_set_lines(chat.bufnr, 0, -1, false, lines)
  end)
end

---@param usage_text string
function M:_update_usage_info(usage_text)
  local usage = self.containers.usage
  if not usage then return end
  
  self._usage_info = usage_text
  vim.api.nvim_set_option_value("modifiable", true, { buf = usage.bufnr })
  vim.api.nvim_buf_set_lines(usage.bufnr, 0, -1, false, { usage_text })
  vim.api.nvim_set_option_value("modifiable", false, { buf = usage.bufnr })
end

---@param content table Tool call prepare content
function M:_handle_tool_call_prepare(content)
  Utils.debug("Tool call prepare received: " .. vim.inspect(content))
  
  -- Check if this is a new tool call (different name) or continuation
  if not self._is_tool_call_streaming or 
     (content.name and self._current_tool_call and content.name ~= self._current_tool_call.name) then
    
    -- Start new tool call accumulation (don't display previous one)
    self._is_tool_call_streaming = true
    self._current_tool_call = {
      name = content.name or "",
      argumentsText = content.argumentsText or ""
    }
    Utils.debug("Started new tool call accumulation for: " .. (content.name or "unknown"))
  else
    -- Accumulate more data to the current tool call
    if content.name and content.name ~= "" then
      self._current_tool_call.name = content.name
    end
    if content.argumentsText then
      self._current_tool_call.argumentsText = (self._current_tool_call.argumentsText or "") .. content.argumentsText
    end
    Utils.debug("Accumulated tool call data. Total length: " .. #(self._current_tool_call.argumentsText or ""))
  end
  
  -- Don't display anything here - wait for toolCalled to display the complete tool call
  Utils.debug("Tool call data accumulated silently, waiting for toolCalled event")
end

function M:_display_tool_call()
  if not self._current_tool_call then return end
  
  local tool_text = string.format("🔧 **Tool Call**: %s\n```json\n%s\n```", 
    self._current_tool_call.name or "Unknown",
    self._current_tool_call.argumentsText or "{}")
  
  self:_add_message("assistant", tool_text)
  
  -- Reset tool call state
  self._current_tool_call = nil
  self._is_tool_call_streaming = false
end

function M:_finalize_tool_call()
  -- Reset tool call state
  self._current_tool_call = nil
  self._is_tool_call_streaming = false
end

---@param text string
function M:_update_current_assistant_message(text)
  if not self._is_streaming or self._last_assistant_line == 0 then
    return
  end
  
  local chat = self.containers.chat
  if not chat then return end
  
  self:_safe_buffer_update(chat.bufnr, function()
    local lines = vim.api.nvim_buf_get_lines(chat.bufnr, 0, -1, false)
    
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
    
    -- Update buffer safely
    vim.api.nvim_buf_set_lines(chat.bufnr, 0, -1, false, new_lines)
    
    -- Scroll to bottom
    if vim.api.nvim_win_is_valid(chat.winid) then
      local line_count = #new_lines
      pcall(vim.api.nvim_win_set_cursor, chat.winid, { line_count, 0 })
    end
  end)
  
  -- Refresh markview rendering with delay (outside the buffer update)
  vim.defer_fn(function()
    self:_refresh_markview()
  end, 100)
end

function M:_finalize_streaming_response()
  if self._is_streaming then
    self._is_streaming = false
    self._current_response_buffer = ""
    self._last_assistant_line = 0
    
    -- Clear the last user message to avoid blocking future legitimate responses
    self._last_user_message = ""
    
    local chat = self.containers.chat
    if chat then
      self:_safe_buffer_update(chat.bufnr, function()
        -- Add an empty line after the response
        local lines = vim.api.nvim_buf_get_lines(chat.bufnr, 0, -1, false)
        table.insert(lines, "")
        vim.api.nvim_buf_set_lines(chat.bufnr, 0, -1, false, lines)
      end)
    end
  end
  
  -- Note: Don't finalize tool calls here - they are handled specifically in toolCalled
end

---@param role "user" | "assistant"
---@param content string
function M:_add_message(role, content)
  local chat = self.containers.chat
  if not chat then return end
  
  self:_safe_buffer_update(chat.bufnr, function()
    local lines = vim.api.nvim_buf_get_lines(chat.bufnr, 0, -1, false)
    
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
    
    -- Update buffer safely
    vim.api.nvim_buf_set_lines(chat.bufnr, 0, -1, false, lines)
    
    -- Scroll to bottom
    if vim.api.nvim_win_is_valid(chat.winid) then
      local line_count = #lines
      pcall(vim.api.nvim_win_set_cursor, chat.winid, { line_count, 0 })
    end
  end)
  
  -- Refresh markview rendering with delay (outside the buffer update)
  vim.defer_fn(function()
    self:_refresh_markview()
  end, 150)
end

function M:_refresh_markview()
  if not Config.markview.enable then
    return
  end
  
  local chat = self.containers.chat
  if not chat or not vim.api.nvim_buf_is_valid(chat.bufnr) then return end
  
  local markview_ok, markview = pcall(require, "markview")
  if markview_ok then
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(chat.bufnr) then return end
      
      -- Safely try different methods to refresh markview
      pcall(function()
        if markview.disable and markview.enable then
          -- New API: disable then enable
          markview.disable(chat.bufnr)
          vim.defer_fn(function()
            if vim.api.nvim_buf_is_valid(chat.bufnr) then
              markview.enable(chat.bufnr)
            end
          end, 50)
        elseif markview.detach and markview.attach then
          -- Old API: detach then attach
          markview.detach(chat.bufnr)
          vim.defer_fn(function()
            if vim.api.nvim_buf_is_valid(chat.bufnr) then
              markview.attach(chat.bufnr)
            end
          end, 50)
        else
          -- Fallback: use command
          vim.api.nvim_buf_call(chat.bufnr, function()
            pcall(vim.cmd, "Markview disable")
            vim.defer_fn(function()
              if vim.api.nvim_buf_is_valid(chat.bufnr) then
                pcall(vim.cmd, "Markview enable")
              end
            end, 50)
          end)
        end
      end)
    end)
  end
end

function M:_add_input_line()
  local input = self.containers.input
  if not input then return end
  
  -- Clear input buffer and add prompt
  vim.api.nvim_buf_set_lines(input.bufnr, 0, -1, false, { "> " })
  
  -- Move cursor to input line and position after prompt
  vim.api.nvim_win_set_cursor(input.winid, { 1, 2 })
  
  -- Focus input window and enter insert mode
  vim.api.nvim_set_current_win(input.winid)
  vim.cmd("startinsert!")
end

-- Helper function to trim strings
---@param str string
---@return string
local function trim(str)
  return str:match("^%s*(.-)%s*$")
end

return M
