local Utils = require("eca.utils")
local Config = require("eca.config")

-- Check if nui.nvim is available
local nui_available, Split = pcall(require, "nui.split")
local nui_event_available, event = pcall(require, "nui.utils.autocmd")

if not nui_available then
  Utils.warn("nui.nvim not found. Install MunifTanjim/nui.nvim for enhanced UI experience.")
  return nil
end

if not nui_event_available then
  Utils.warn("nui.utils.autocmd not found. Some features may not work properly.")
  event = nil
end

---@class eca.NuiSidebar
---@field public id integer The tab ID
---@field public containers table<string, NuiSplit> The nui containers
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
---@field private _selected_code table Current selected code for display
---@field private _todos table List of active todos
---@field private _augroup integer Autocmd group ID
local M = {}
M.__index = M

---@param id integer Tab ID
---@return eca.NuiSidebar
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
  instance._selected_code = nil
  instance._todos = {}
  instance._augroup = vim.api.nvim_create_augroup("eca_nui_sidebar_" .. id, { clear = true })
  return instance
end

---@return boolean
function M:is_open()
  return self.containers.chat and self.containers.chat.winid and vim.api.nvim_win_is_valid(self.containers.chat.winid)
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
  
  -- Clean up any invalid containers
  self:_cleanup_invalid_containers()
  
  -- Create/recreate containers using nui.split
  self:_create_nui_containers()
  
  -- Setup containers if not initialized or if we need to refresh content
  if not self._initialized then
    Utils.debug("Setting up nui containers (first time)")
    self:_setup_containers()
  else
    Utils.debug("Reusing existing nui containers")
    self:_refresh_container_content()
  end
  
  if Config.behaviour.auto_focus_sidebar then
    vim.api.nvim_set_current_win(self.containers.input.winid)
  end
  
  Utils.debug("ECA nui sidebar opened")
end

function M:close()
  self:_close_windows_only()
end

function M:_close_windows_only()
  for name, container in pairs(self.containers) do
    if container and container.winid and vim.api.nvim_win_is_valid(container.winid) then
      container:unmount()
      -- Keep the container reference but mark window as invalid
      container.winid = nil
    end
  end
  Utils.debug("ECA nui sidebar windows closed")
end

function M:_close_and_cleanup()
  for name, container in pairs(self.containers) do
    if container then
      if container.winid and vim.api.nvim_win_is_valid(container.winid) then
        container:unmount()
      end
      -- Check if buffer is displayed elsewhere before deleting
      if container.bufnr and vim.api.nvim_buf_is_valid(container.bufnr) then
        local wins = vim.fn.win_findbuf(container.bufnr)
        if #wins == 0 then
          pcall(vim.api.nvim_buf_delete, container.bufnr, { force = true })
        end
      end
    end
  end
  self.containers = {}
  Utils.debug("ECA nui sidebar closed and cleaned up")
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
  
  -- Recalculate and update container sizes
  self:_update_container_sizes()
end

function M:reset()
  if self:is_open() then
    self:_close_and_cleanup()
  else
    self:_close_and_cleanup()
  end
  
  -- Reset all state
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
  self._selected_code = nil
  self._todos = {}
end

function M:new_chat()
  self:reset()
  self._force_welcome = true
  Utils.debug("New chat initiated - will show welcome content on next open")
end

---@private
function M:_cleanup_invalid_containers()
  for name, container in pairs(self.containers) do
    if container then
      -- Check if window is still valid
      if container.winid and not vim.api.nvim_win_is_valid(container.winid) then
        container.winid = nil
      end
      -- Check if buffer is still valid
      if container.bufnr and not vim.api.nvim_buf_is_valid(container.bufnr) then
        container.bufnr = nil
      end
    end
  end
end

---@private
function M:_create_nui_containers()
  local width = Config.get_window_width()
  
  -- Calculate dynamic heights using existing methods
  local input_height = Config.windows.input.height
  local usage_height = 1
  local contexts_height = self:get_contexts_height()
  local selected_code_height = self:get_selected_code_height()
  local todos_height = self:get_todos_height()
  local chat_height = self:get_chat_height()
  
  -- Base options for all containers
  local base_buf_options = {
    buftype = "nofile",
    bufhidden = "hide",
    swapfile = false,
  }
  
  local base_win_options = {
    wrap = Config.windows.wrap,
    number = false,
    relativenumber = false,
    signcolumn = "no",
    foldcolumn = "0",
    cursorline = false,
    winfixheight = true,
    winfixwidth = false,
  }
  
  -- 1. Create and mount main chat container first
  self.containers.chat = Split({
    relative = "editor",
    position = "right",
    size = {
      width = width,
      height = chat_height,
    },
    buf_options = vim.tbl_deep_extend("force", base_buf_options, {
      modifiable = true,
      filetype = "markdown",
    }),
    win_options = base_win_options,
  })
  self.containers.chat:mount()
  self:_setup_container_events(self.containers.chat, "chat")
  Utils.debug("Mounted nui container: chat (winid: " .. self.containers.chat.winid .. ")")
  
  -- Track the last mounted container winid for relative positioning
  local last_winid = self.containers.chat.winid
  
  -- 2. Create selected_code container (conditional)
  if selected_code_height > 0 then
    self.containers.selected_code = Split({
      relative = {
        type = "win",
        winid = last_winid,
      },
      position = "bottom",
      size = { height = selected_code_height },
      buf_options = vim.tbl_deep_extend("force", base_buf_options, {
        modifiable = false,
        filetype = self._selected_code and self._selected_code.filetype or "text",
      }),
      win_options = vim.tbl_deep_extend("force", base_win_options, {
        winhighlight = "Normal:Visual",
      }),
    })
    self.containers.selected_code:mount()
    self:_setup_container_events(self.containers.selected_code, "selected_code")
    last_winid = self.containers.selected_code.winid
    Utils.debug("Mounted nui container: selected_code (winid: " .. last_winid .. ")")
  end
  
  -- 3. Create todos container (conditional)
  if todos_height > 0 then
    self.containers.todos = Split({
      relative = {
        type = "win",
        winid = last_winid,
      },
      position = "bottom",
      size = { height = todos_height },
      buf_options = vim.tbl_deep_extend("force", base_buf_options, {
        modifiable = false,
      }),
      win_options = vim.tbl_deep_extend("force", base_win_options, {
        winhighlight = "Normal:DiffAdd",
      }),
    })
    self.containers.todos:mount()
    self:_setup_container_events(self.containers.todos, "todos")
    last_winid = self.containers.todos.winid
    Utils.debug("Mounted nui container: todos (winid: " .. last_winid .. ")")
  end
  
  -- 4. Create contexts container (always present)
  self.containers.contexts = Split({
    relative = {
      type = "win",
      winid = last_winid,
    },
    position = "bottom",
    size = { height = contexts_height },
    buf_options = vim.tbl_deep_extend("force", base_buf_options, {
      modifiable = false,
    }),
    win_options = vim.tbl_deep_extend("force", base_win_options, {
      winhighlight = "Normal:Comment",
    }),
  })
  self.containers.contexts:mount()
  self:_setup_container_events(self.containers.contexts, "contexts")
  last_winid = self.containers.contexts.winid
  Utils.debug("Mounted nui container: contexts (winid: " .. last_winid .. ")")
  
  -- 5. Create usage container (always present)
  self.containers.usage = Split({
    relative = {
      type = "win",
      winid = last_winid,
    },
    position = "bottom",
    size = { height = usage_height },
    buf_options = vim.tbl_deep_extend("force", base_buf_options, {
      modifiable = false,
    }),
    win_options = vim.tbl_deep_extend("force", base_win_options, {
      winhighlight = "Normal:StatusLine",
      statusline = " ",
    }),
  })
  self.containers.usage:mount()
  self:_setup_container_events(self.containers.usage, "usage")
  last_winid = self.containers.usage.winid
  Utils.debug("Mounted nui container: usage (winid: " .. last_winid .. ")")
  
  -- 6. Create input container (always present)
  self.containers.input = Split({
    relative = {
      type = "win",
      winid = last_winid,
    },
    position = "bottom",
    size = { height = input_height },
    buf_options = vim.tbl_deep_extend("force", base_buf_options, {
      modifiable = true,
    }),
    win_options = vim.tbl_deep_extend("force", base_win_options, {
      statusline = " ",
    }),
  })
  self.containers.input:mount()
  self:_setup_container_events(self.containers.input, "input")
  Utils.debug("Mounted nui container: input (winid: " .. self.containers.input.winid .. ")")
  
  Utils.debug(string.format("Created nui containers: chat=%d, selected_code=%s, todos=%s, contexts=%d, usage=%d, input=%d", 
    chat_height, 
    selected_code_height > 0 and tostring(selected_code_height) or "hidden",
    todos_height > 0 and tostring(todos_height) or "hidden",
    contexts_height, 
    usage_height, 
    input_height))
end

---@private
---@param container NuiSplit
---@param name string
function M:_setup_container_events(container, name)
  if not event then return end
  
  -- Setup event handling for each container
  container:on(event.event.BufWinEnter, function()
    Utils.debug("Container " .. name .. " entered")
    -- Container-specific setup can go here
  end)
  
  container:on(event.event.BufLeave, function()
    Utils.debug("Container " .. name .. " left")
    -- Container-specific cleanup can go here
  end)
  
  container:on(event.event.WinClosed, function()
    Utils.debug("Container " .. name .. " window closed")
    self:_handle_container_closed(name)
  end)
  
  -- Setup container-specific keymaps
  if name == "todos" then
    self:_setup_todos_keymaps(container)
  elseif name == "input" then
    self:_setup_input_keymaps(container)
  end
end

---@private
---@param name string
function M:_handle_container_closed(name)
  -- Handle when a container window is closed
  if self.containers[name] then
    self.containers[name].winid = nil
  end
end

---@private
---@param container NuiSplit
function M:_setup_todos_keymaps(container)
  -- Setup keymaps for todos container
  container:map("n", "<Space>", function()
    local line = vim.api.nvim_win_get_cursor(container.winid)[1]
    if line > 0 then
      local header_offset = Config.windows.sidebar_header.enabled and 1 or 0
      local todo_index = line - header_offset
      if todo_index > 0 and todo_index <= #self._todos then
        self:toggle_todo(todo_index)
      end
    end
  end, { noremap = true, silent = true })
  
  container:map("n", "<Enter>", function()
    local line = vim.api.nvim_win_get_cursor(container.winid)[1]
    if line > 0 then
      local header_offset = Config.windows.sidebar_header.enabled and 1 or 0
      local todo_index = line - header_offset
      if todo_index > 0 and todo_index <= #self._todos then
        self:toggle_todo(todo_index)
      end
    end
  end, { noremap = true, silent = true })
end

---@private
---@param container NuiSplit
function M:_setup_input_keymaps(container)
  -- Setup keymaps for input container
  container:map("n", "<C-s>", function()
    self:_handle_input()
  end, { noremap = true, silent = true })
  
  container:map("i", "<C-s>", function()
    self:_handle_input()
  end, { noremap = true, silent = true })
end

---@private
function M:_update_container_sizes()
  if not self:is_open() then return end
  
  -- Recalculate heights
  local new_heights = {
    chat = self:get_chat_height(),
    selected_code = self:get_selected_code_height(),
    todos = self:get_todos_height(),
    contexts = self:get_contexts_height(),
    usage = 1,
    input = Config.windows.input.height,
  }
  
  -- Update container sizes
  for name, height in pairs(new_heights) do
    local container = self.containers[name]
    if container and container.winid and vim.api.nvim_win_is_valid(container.winid) then
      if height > 0 then
        vim.api.nvim_win_set_height(container.winid, height)
      end
    end
  end
end

-- Include all the height calculation methods from the original sidebar
function M:get_selected_code_height()
  if not self._selected_code or not Config.selected_code.enabled then 
    return 0 
  end
  
  local lines = vim.split(self._selected_code.content or "", "\n")
  local content_lines = #lines
  local header_lines = Config.windows.sidebar_header.enabled and 1 or 0
  
  return math.min(Config.selected_code.max_height, content_lines + header_lines + 1)
end

function M:get_todos_height()
  if #self._todos == 0 or not Config.todos.enabled then 
    return 0 
  end
  
  local header_lines = Config.windows.sidebar_header.enabled and 1 or 0
  local todo_lines = math.min(#self._todos, Config.todos.max_height - header_lines)
  
  return math.min(Config.todos.max_height, todo_lines + header_lines)
end

function M:get_contexts_height()
  if #self._contexts == 0 then
    return 1 -- Always show at least "No contexts"
  end
  
  local header_lines = 1 -- "📂 Contexts (N):"
  local bubble_lines = 1 -- All bubbles on same line as requested
  
  return header_lines + bubble_lines
end

function M:get_chat_height()
  local total_height = vim.o.lines - vim.o.cmdheight - 1
  local input_height = Config.windows.input.height
  local usage_height = 1
  local contexts_height = self:get_contexts_height()
  local selected_code_height = self:get_selected_code_height()
  local todos_height = self:get_todos_height()
  
  return math.max(10, 
    total_height - input_height - usage_height - contexts_height 
    - selected_code_height - todos_height - 3
  )
end

-- Include all the context/todo/selected_code management methods from original sidebar
-- (These will be copied from the original implementation)

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

---@param code table Selected code object with filepath, content, start_line, end_line
function M:set_selected_code(code)
  self._selected_code = code
  self:_update_selected_code_display()
  Utils.info("Selected code updated: " .. (code and code.filepath or "none"))
end

function M:clear_selected_code()
  self._selected_code = nil
  self:_update_selected_code_display()
  Utils.info("Selected code cleared")
end

---@param todo table Todo object with content, status ("pending", "completed")
function M:add_todo(todo)
  table.insert(self._todos, todo)
  self:_update_todos_display()
  Utils.info("Added TODO: " .. todo.content)
end

---@param index integer Index of todo to toggle
function M:toggle_todo(index)
  if index <= 0 or index > #self._todos then
    Utils.warn("Invalid TODO index: " .. index)
    return false
  end
  
  local todo = self._todos[index]
  todo.status = todo.status == "completed" and "pending" or "completed"
  self:_update_todos_display()
  Utils.info("Toggled TODO " .. index .. ": " .. todo.content)
  return true
end

function M:clear_todos()
  local count = #self._todos
  self._todos = {}
  self:_update_todos_display()
  Utils.info("Cleared " .. count .. " TODOs")
end

---@return table List of active todos
function M:get_todos()
  return vim.deepcopy(self._todos)
end

-- Placeholder methods for the display and setup functions
-- These will use the same logic as the original sidebar but with nui containers

function M:_setup_containers()
  -- Setup each container's content and behavior
  self:_setup_chat_container()
  
  if self.containers.selected_code then
    self:_setup_selected_code_container()
  end
  
  if self.containers.todos then
    self:_setup_todos_container()
  end
  
  self:_setup_contexts_container()
  self:_setup_usage_container()
  self:_setup_input_container()
  
  self._initialized = true
end

function M:_refresh_container_content()
  -- Refresh content without full setup
  if self.containers.chat then
    self:_set_welcome_content()
  end
  
  if self.containers.selected_code then
    self:_update_selected_code_display()
  end
  
  if self.containers.todos then
    self:_update_todos_display()
  end
  
  if self.containers.contexts then
    self:_update_contexts_display()
  end
  
  if self.containers.usage then
    self:_update_usage_info(self._usage_info)
  end
  
  if self.containers.input then
    self:_add_input_line()
  end
end

-- Placeholder for all the other methods from original sidebar
-- (These would be copied over with minimal modifications to work with nui containers)

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
  
  -- Set filetype to markdown for syntax highlighting
  vim.defer_fn(function()
    if vim.api.nvim_buf_is_valid(chat.bufnr) then
      vim.api.nvim_set_option_value("filetype", "markdown", { buf = chat.bufnr })
      vim.api.nvim_set_option_value("syntax", "on", { buf = chat.bufnr })
    end
  end, 200)
end

function M:_setup_selected_code_container()
  local container = self.containers.selected_code
  if not container then return end
  
  -- Set initial content
  self:_update_selected_code_display()
  
  -- Set filetype based on the selected code's language
  if self._selected_code and self._selected_code.filetype then
    vim.api.nvim_set_option_value("filetype", self._selected_code.filetype, { buf = container.bufnr })
  end
end

function M:_setup_todos_container()
  local container = self.containers.todos
  if not container then return end
  
  -- Set initial content
  self:_update_todos_display()
end

function M:_setup_contexts_container()
  local contexts = self.containers.contexts
  if not contexts then return end
  
  -- Set initial contexts display
  self:_update_contexts_display()
end

function M:_setup_usage_container()
  local usage = self.containers.usage
  if not usage then return end
  
  -- Set initial usage info
  vim.api.nvim_set_option_value("modifiable", true, { buf = usage.bufnr })
  vim.api.nvim_buf_set_lines(usage.bufnr, 0, -1, false, { "Usage: Tokens | Cost" })
  vim.api.nvim_set_option_value("modifiable", false, { buf = usage.bufnr })
end

function M:_setup_input_container()
  local input = self.containers.input
  if not input then return end
  
  -- Set initial input prompt
  self:_add_input_line()
end

-- Placeholder methods that need to be implemented
-- (These would be copied from the original sidebar with minimal modifications)

function M:_set_welcome_content()
  -- Implementation from original sidebar
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

function M:_add_input_line()
  local input = self.containers.input
  if not input then return end
  
  local prefix = Config.windows.input.prefix or "> "
  vim.api.nvim_buf_set_lines(input.bufnr, 0, -1, false, { prefix })
  
  -- Set cursor to end of line
  if vim.api.nvim_win_is_valid(input.winid) then
    vim.api.nvim_win_set_cursor(input.winid, { 1, #prefix })
  end
end

function M:_handle_input()
  local input = self.containers.input
  if not input then return end
  
  local lines = vim.api.nvim_buf_get_lines(input.bufnr, 0, -1, false)
  if #lines == 0 then return end
  
  -- Process input (remove prefix, concatenate lines)
  local message_lines = {}
  local prefix = Config.windows.input.prefix or "> "
  
  for _, line in ipairs(lines) do
    local content = line
    if vim.startswith(line, prefix) then
      content = line:sub(#prefix + 1)
    end
    if content ~= "" then
      table.insert(message_lines, content)
    end
  end
  
  local message = table.concat(message_lines, "\n")
  if message == "" then return end
  
  -- Clear input
  vim.api.nvim_buf_set_lines(input.bufnr, 0, -1, false, {})
  
  -- Send message
  self:_send_message(message)
  
  -- Add new input line
  self:_add_input_line()
end

-- Placeholder for the other display update methods
function M:_update_selected_code_display()
  -- Implementation would be similar to original but use nui container
  local container = self.containers.selected_code
  if not container or not vim.api.nvim_buf_is_valid(container.bufnr) then 
    return 
  end
  
  local lines = {}
  
  if not self._selected_code then
    lines = { "📝 No code selected" }
  else
    -- Add header if enabled
    local filename = vim.fn.fnamemodify(self._selected_code.filepath or "unknown", ":t")
    local line_info = ""
    if self._selected_code.start_line and self._selected_code.end_line then
      line_info = string.format(" (lines %d-%d)", self._selected_code.start_line, self._selected_code.end_line)
    end
    local header_text = "📝 " .. filename .. line_info
    local header_lines = self:_render_header("selected_code", header_text)
    for _, line in ipairs(header_lines) do
      table.insert(lines, line)
    end
    
    -- Add code content
    local code_lines = vim.split(self._selected_code.content or "", "\n")
    for _, line in ipairs(code_lines) do
      table.insert(lines, line)
    end
  end
  
  -- Update the buffer
  vim.api.nvim_set_option_value("modifiable", true, { buf = container.bufnr })
  vim.api.nvim_buf_set_lines(container.bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = container.bufnr })
end

function M:_update_todos_display()
  -- Similar implementation for todos...
  local container = self.containers.todos
  if not container or not vim.api.nvim_buf_is_valid(container.bufnr) then 
    return 
  end
  
  local lines = {}
  
  if #self._todos == 0 then
    lines = { "✅ No active TODOs" }
  else
    -- Add header if enabled
    local completed_count = 0
    for _, todo in ipairs(self._todos) do
      if todo.status == "completed" then
        completed_count = completed_count + 1
      end
    end
    local header_text = string.format("✅ Tasks (%d/%d completed)", completed_count, #self._todos)
    local header_lines = self:_render_header("todos", header_text)
    for _, line in ipairs(header_lines) do
      table.insert(lines, line)
    end
    
    -- Add todos
    for i, todo in ipairs(self._todos) do
      local checkbox = todo.status == "completed" and "[x]" or "[ ]"
      local line = string.format("%d. %s %s", i, checkbox, todo.content)
      table.insert(lines, line)
    end
  end
  
  -- Update the buffer
  vim.api.nvim_set_option_value("modifiable", true, { buf = container.bufnr })
  vim.api.nvim_buf_set_lines(container.bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = container.bufnr })
end

function M:_update_contexts_display()
  -- Similar implementation for contexts...
  local contexts = self.containers.contexts
  if not contexts or not vim.api.nvim_buf_is_valid(contexts.bufnr) then 
    return 
  end
  
  local lines = {}
  
  if #self._contexts == 0 then
    local header_text = "📂 No contexts"
    local header_lines = self:_render_header("contexts", header_text)
    if #header_lines > 0 then
      for _, line in ipairs(header_lines) do
        table.insert(lines, line)
      end
    else
      table.insert(lines, header_text)
    end
  else
    -- Create bubbles/badges for each context
    local bubbles = {}
    
    for i, context in ipairs(self._contexts) do
      local name = context.type == "repoMap" and "repoMap" or 
                   vim.fn.fnamemodify(context.path, ":t") -- Get filename only
      
      -- Create bubble with modern pill/badge style
      local bubble = "⌜".. name .."⌟"
      table.insert(bubbles, bubble)
    end
    
    -- Add header with context count
    local header_text = string.format("📂 Contexts (%d)", #self._contexts)
    local header_lines = self:_render_header("contexts", header_text)
    if #header_lines > 0 then
      for _, line in ipairs(header_lines) do
        table.insert(lines, line)
      end
    else
      table.insert(lines, header_text)
    end
    
    -- Add all bubbles to the same line  
    local bubbles_line = table.concat(bubbles, " ")
    table.insert(lines, bubbles_line)
  end
  
  -- Update the buffer
  vim.api.nvim_set_option_value("modifiable", true, { buf = contexts.bufnr })
  vim.api.nvim_buf_set_lines(contexts.bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = contexts.bufnr })
end

function M:_update_usage_info(usage_text)
  local usage = self.containers.usage
  if not usage or not vim.api.nvim_buf_is_valid(usage.bufnr) then 
    return 
  end
  
  self._usage_info = usage_text or "Usage: Tokens | Cost"
  
  vim.api.nvim_set_option_value("modifiable", true, { buf = usage.bufnr })
  vim.api.nvim_buf_set_lines(usage.bufnr, 0, -1, false, { self._usage_info })
  vim.api.nvim_set_option_value("modifiable", false, { buf = usage.bufnr })
end

function M:_render_header(container_name, header_text)
  if not Config.windows.sidebar_header.enabled then
    return {}
  end
  
  local align = Config.windows.sidebar_header.align or "center"
  local rounded = Config.windows.sidebar_header.rounded
  
  if rounded then
    header_text = "『" .. header_text .. "』"
  else
    header_text = " " .. header_text .. " "
  end
  
  return { header_text }
end

-- ===== Message handling methods (copied from original sidebar) =====

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
      
      -- If the accumulated text so far exactly matches the user message, skip it
      if trimmed_text == trimmed_user_msg then
        Utils.debug("Skipping echo of user message: " .. trimmed_text)
        return
      end
    end
    
    -- Start streaming
    self._is_streaming = true
    self:_add_message("assistant", "")
    self._last_assistant_line = self:_get_last_message_line()
  end
  
  -- Accumulate text
  self._current_response_buffer = (self._current_response_buffer or "") .. text
  
  -- Update the assistant's message in place
  self:_update_streaming_message(self._current_response_buffer)
end

---@param content string
function M:_update_streaming_message(content)
  local chat = self.containers.chat
  if not chat or self._last_assistant_line == 0 then return end
  
  self:_safe_buffer_update(chat.bufnr, function()
    local lines = vim.api.nvim_buf_get_lines(chat.bufnr, 0, -1, false)
    
    -- Find the assistant message section and update content
    local content_lines = Utils.split_lines(content)
    local start_line = self._last_assistant_line + 2  -- Skip "## 🤖 ECA" and empty line
    
    -- Clear existing assistant content
    local end_line = #lines
    for i = start_line, #lines do
      if lines[i] and (lines[i]:match("^## ") or lines[i]:match("^%-%-%-")) then
        end_line = i - 1
        break
      end
    end
    
    -- Insert new content
    local new_lines = {}
    for i = 1, start_line - 1 do
      table.insert(new_lines, lines[i] or "")
    end
    
    for _, line in ipairs(content_lines) do
      table.insert(new_lines, line)
    end
    
    table.insert(new_lines, "")
    
    -- Add remaining lines if any
    for i = end_line + 1, #lines do
      if lines[i] then
        table.insert(new_lines, lines[i])
      end
    end
    
    vim.api.nvim_buf_set_lines(chat.bufnr, 0, -1, false, new_lines)
  end)
end

---@param role string
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
  end)
  
  -- Store assistant message line for streaming updates
  if role == "assistant" then
    self._last_assistant_line = self:_get_last_message_line()
  end
end

function M:_finalize_streaming_response()
  if self._is_streaming then
    self._is_streaming = false
    self._current_response_buffer = ""
    self._last_assistant_line = 0
  end
end

function M:_get_last_message_line()
  local chat = self.containers.chat
  if not chat then return 0 end
  
  local lines = vim.api.nvim_buf_get_lines(chat.bufnr, 0, -1, false)
  for i = #lines, 1, -1 do
    if lines[i] and lines[i]:match("^## 🤖 ECA") then
      return i
    end
  end
  return 0
end

---@param bufnr integer
---@param callback function
function M:_safe_buffer_update(bufnr, callback)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end
  
  -- Temporarily disable treesitter and syntax to prevent errors during updates
  local ts_hl_enabled = pcall(vim.treesitter.get_parser, bufnr)
  local syntax_enabled = vim.api.nvim_get_option_value("syntax", { buf = bufnr })
  
  if ts_hl_enabled then
    pcall(vim.api.nvim_set_option_value, "syntax", "off", { buf = bufnr })
  end
  
  -- Execute the callback
  pcall(callback)
  
  -- Re-enable syntax with a delay to allow content to settle
  if ts_hl_enabled and syntax_enabled ~= "off" then
    vim.defer_fn(function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        pcall(vim.api.nvim_set_option_value, "syntax", syntax_enabled, { buf = bufnr })
      end
    end, 100)
  end
end

-- ===== Tool call handling methods =====

function M:_handle_tool_call_prepare(content)
  if not self._is_tool_call_streaming then
    self._is_tool_call_streaming = true
    self._current_tool_call = {
      name = "",
      arguments = ""
    }
  end
  
  -- Accumulate tool call data
  if content.name then
    self._current_tool_call.name = content.name
  end
  
  if content.argumentsText then
    self._current_tool_call.arguments = (self._current_tool_call.arguments or "") .. content.argumentsText
  end
end

function M:_display_tool_call()
  if not self._current_tool_call then return end
  
  local tool_text = string.format("🔧 **Tool Call**: %s", self._current_tool_call.name or "unknown")
  
  if self._current_tool_call.arguments and self._current_tool_call.arguments ~= "" then
    tool_text = tool_text .. "\n```json\n" .. self._current_tool_call.arguments .. "\n```"
  end
  
  self:_add_message("assistant", tool_text)
end

function M:_finalize_tool_call()
  self._current_tool_call = nil
  self._is_tool_call_streaming = false
end

-- Helper function from utils
local function trim(str)
  return str:match("^%s*(.-)%s*$")
end

return M