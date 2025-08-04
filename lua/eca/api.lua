local Utils = require("eca.utils")

---@class eca.Api
local M = {}

---@param opts? table
function M.chat(opts)
  opts = opts or {}
  local eca = require("eca")
  eca.open_sidebar(opts)
end

function M.focus()
  local eca = require("eca")
  local sidebar = eca.get()
  if sidebar then
    sidebar:focus()
  else
    M.chat()
  end
end

function M.toggle()
  local eca = require("eca")
  return eca.toggle_sidebar()
end

function M.close()
  local eca = require("eca")
  local sidebar = eca.get()
  if sidebar then
    sidebar:new_chat() -- This will reset and force welcome content on next open
  else
    eca.close_sidebar()
  end
end

---@param message string
function M.send_message(message)
  local eca = require("eca")
  local sidebar = eca.get()
  if not sidebar or not sidebar:is_open() then
    M.chat()
    sidebar = eca.get()
  end
  
  if sidebar then
    sidebar:_send_message(message)
  else
    Utils.error("Could not open ECA sidebar")
  end
end

---@param file_path string
function M.add_file_context(file_path)
  Utils.info("Adding file context: " .. file_path)
  local eca = require("eca")
  
  if not eca.server or not eca.server:is_running() then
    Utils.error("ECA server is not running")
    return
  end
  
  -- Read file content
  local content = Utils.read_file(file_path)
  if not content then
    Utils.error("Could not read file: " .. file_path)
    return
  end
  
  -- Create context object
  local context = {
    type = "file",
    path = file_path,
    content = content
  }
  
  -- Get current sidebar and add context
  local sidebar = eca.get()
  if not sidebar then
    Utils.info("Opening ECA sidebar to add context...")
    M.chat()
    sidebar = eca.get()
  end
  
  if sidebar then
    sidebar:add_context(context)
  else
    Utils.error("Failed to create ECA sidebar")
  end
end

---@param directory_path string
function M.add_directory_context(directory_path)
  Utils.info("Adding directory context: " .. directory_path)
  local eca = require("eca")
  
  if not eca.server or not eca.server:is_running() then
    Utils.error("ECA server is not running")
    return
  end
  
  -- Create context object for directory
  local context = {
    type = "directory",
    path = directory_path
  }
  
  -- For now, store it for next message
  -- TODO: Implement context management
  Utils.debug("Directory context added: " .. directory_path)
end

function M.add_current_file_context()
  local current_file = vim.api.nvim_buf_get_name(0)
  if current_file and current_file ~= "" then
    M.add_file_context(current_file)
  else
    Utils.warn("No current file to add as context")
  end
end

function M.add_selection_context()
  -- Get visual selection marks (should be set by the command before calling this)
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  
  if start_pos[2] == 0 or end_pos[2] == 0 then
    Utils.warn("No selection to add as context. Please make a visual selection first.")
    return
  end
  
  -- Ensure we have the right line order
  local start_line = math.min(start_pos[2], end_pos[2])
  local end_line = math.max(start_pos[2], end_pos[2])
  
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  if #lines > 0 then
    local selection_text = table.concat(lines, "\n")
    local current_file = vim.api.nvim_buf_get_name(0)
    local context_path = current_file .. ":" .. start_line .. "-" .. end_line
    
    -- Create context object
    local context = {
      type = "selection",
      path = context_path,
      content = selection_text,
      source_file = current_file,
      start_line = start_line,
      end_line = end_line
    }
    
    -- Get current sidebar and add context
    local eca = require("eca")
    local sidebar = eca.get()
    if not sidebar then
      Utils.info("Opening ECA sidebar to add context...")
      M.chat()
      sidebar = eca.get()
    end
    
    if sidebar then
      sidebar:add_context(context)
      
      -- Also set as selected code for visual display
      local selected_code = {
        filepath = current_file,
        content = selection_text,
        start_line = start_line,
        end_line = end_line,
        filetype = vim.api.nvim_get_option_value("filetype", { buf = 0 })
      }
      sidebar:set_selected_code(selected_code)
      
      Utils.info("Added selection context (" .. #lines .. " lines from lines " .. start_line .. "-" .. end_line .. ")")
    else
      Utils.error("Failed to create ECA sidebar")
    end
  else
    Utils.warn("No lines found in selection")
  end
end

function M.list_contexts()
  local eca = require("eca")
  local sidebar = eca.get()
  if not sidebar then
    Utils.warn("No active ECA sidebar")
    return
  end
  
  local contexts = sidebar:get_contexts()
  if #contexts == 0 then
    Utils.info("No active contexts")
    return
  end
  
  Utils.info("Active contexts (" .. #contexts .. "):")
  for i, context in ipairs(contexts) do
    local size_info = ""
    if context.content then
      local lines = vim.split(context.content, "\n")
      size_info = " (" .. #lines .. " lines)"
    end
    Utils.info(i .. ". " .. context.type .. ": " .. context.path .. size_info)
  end
end

function M.clear_contexts()
  local eca = require("eca")
  local sidebar = eca.get()
  if not sidebar then
    Utils.warn("No active ECA sidebar")
    return
  end
  
  sidebar:clear_contexts()
end

function M.remove_context(path)
  local eca = require("eca")
  local sidebar = eca.get()
  if not sidebar then
    Utils.warn("No active ECA sidebar")
    return
  end
  
  sidebar:remove_context(path)
end

function M.add_repo_map_context()
  local eca = require("eca")
  local sidebar = eca.get()
  if not sidebar then
    Utils.info("Opening ECA sidebar to add repoMap context...")
    M.chat()
    sidebar = eca.get()
  end
  
  if sidebar then
    -- Check if repoMap already exists
    local contexts = sidebar:get_contexts()
    for _, context in ipairs(contexts) do
      if context.type == "repoMap" then
        Utils.info("RepoMap context already added")
        return
      end
    end
    
    -- Add repoMap context
    sidebar:add_context({
      type = "repoMap",
      path = "repoMap",
      content = "Repository structure and code mapping for better project understanding"
    })
    Utils.info("Added repoMap context")
  else
    Utils.error("Failed to create ECA sidebar")
  end
end

---@return boolean
function M.is_server_running()
  local eca = require("eca")
  return eca.server and eca.server:is_running()
end

function M.start_server()
  local eca = require("eca")
  if eca.server then
    eca.server:start()
  else
    Utils.error("ECA server not initialized")
  end
end

function M.stop_server()
  local eca = require("eca")
  if eca.server then
    eca.server:stop()
  end
end

function M.restart_server()
  M.stop_server()
  vim.defer_fn(function()
    M.start_server()
  end, 1000)
end

function M.server_status()
  local eca = require("eca")
  if eca.server then
    return eca.server:status()
  else
    return "Not initialized"
  end
end

-- ===== Selected Code Management =====

function M.show_selected_code()
  local eca = require("eca")
  local sidebar = eca.get()
  if sidebar then
    local selected_code = sidebar._selected_code
    if selected_code then
      Utils.info("Selected code: " .. selected_code.filepath .. " (lines " .. 
                (selected_code.start_line or "?") .. "-" .. (selected_code.end_line or "?") .. ")")
    else
      Utils.info("No code currently selected")
    end
  else
    Utils.warn("ECA sidebar not available")
  end
end

function M.clear_selected_code()
  local eca = require("eca")
  local sidebar = eca.get()
  if sidebar then
    sidebar:clear_selected_code()
  else
    Utils.warn("ECA sidebar not available")
  end
end

-- ===== TODOs Management =====

function M.add_todo(content)
  local eca = require("eca")
  local sidebar = eca.get()
  if not sidebar then
    Utils.info("Opening ECA sidebar to add TODO...")
    M.chat()
    sidebar = eca.get()
  end
  
  if sidebar then
    local todo = {
      content = content,
      status = "pending"
    }
    sidebar:add_todo(todo)
  else
    Utils.error("Failed to create ECA sidebar")
  end
end

function M.list_todos()
  local eca = require("eca")
  local sidebar = eca.get()
  if sidebar then
    local todos = sidebar:get_todos()
    if #todos == 0 then
      Utils.info("No active TODOs")
      return
    end
    
    Utils.info("Active TODOs:")
    for i, todo in ipairs(todos) do
      local status_icon = todo.status == "completed" and "✓" or "○"
      Utils.info(string.format("%d. %s %s", i, status_icon, todo.content))
    end
  else
    Utils.warn("ECA sidebar not available")
  end
end

function M.toggle_todo(index)
  local eca = require("eca")
  local sidebar = eca.get()
  if sidebar then
    return sidebar:toggle_todo(index)
  else
    Utils.warn("ECA sidebar not available")
    return false
  end
end

function M.clear_todos()
  local eca = require("eca")
  local sidebar = eca.get()
  if sidebar then
    sidebar:clear_todos()
  else
    Utils.warn("ECA sidebar not available")
  end
end

return M
