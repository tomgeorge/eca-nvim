local Utils = require("eca.utils")

local M = {}

function M.setup()
  -- Define ECA commands
  vim.api.nvim_create_user_command("EcaChat", function(opts)
    require("eca.api").chat(opts.args and { message = opts.args } or {})
  end, {
    desc = "Open ECA chat",
    nargs = "?",
  })

  vim.api.nvim_create_user_command("EcaToggle", function()
    require("eca.api").toggle()
  end, {
    desc = "Toggle ECA sidebar",
  })

  vim.api.nvim_create_user_command("EcaFocus", function()
    require("eca.api").focus()
  end, {
    desc = "Focus ECA sidebar",
  })

  vim.api.nvim_create_user_command("EcaClose", function()
    require("eca.api").close()
  end, {
    desc = "Close ECA sidebar",
  })

  vim.api.nvim_create_user_command("EcaAddFile", function(opts)
    if opts.args and opts.args ~= "" then
      require("eca.api").add_file_context(opts.args)
    else
      require("eca.api").add_current_file_context()
    end
  end, {
    desc = "Add file as context to ECA",
    nargs = "?",
    complete = "file",
  })

  vim.api.nvim_create_user_command("EcaAddSelection", function()
    -- Force exit visual mode and set marks
    vim.cmd('normal! \\<Esc>')
    vim.defer_fn(function()
      require("eca.api").add_selection_context()
    end, 50) -- Small delay to ensure marks are set
  end, {
    desc = "Add current selection as context to ECA",
    range = true,
  })

  vim.api.nvim_create_user_command("EcaListContexts", function()
    require("eca.api").list_contexts()
  end, {
    desc = "List active contexts in ECA",
  })

  vim.api.nvim_create_user_command("EcaClearContexts", function()
    require("eca.api").clear_contexts()
  end, {
    desc = "Clear all contexts from ECA",
  })

  vim.api.nvim_create_user_command("EcaRemoveContext", function(opts)
    if opts.args and opts.args ~= "" then
      require("eca.api").remove_context(opts.args)
    else
      Utils.warn("Please provide a file path to remove")
    end
  end, {
    desc = "Remove specific context from ECA",
    nargs = "+",
    complete = "file",
  })

  vim.api.nvim_create_user_command("EcaAddRepoMap", function()
    require("eca.api").add_repo_map_context()
  end, {
    desc = "Add repository map context to ECA",
  })

  -- ===== Selected Code Commands =====
  
  vim.api.nvim_create_user_command("EcaShowSelection", function()
    require("eca.api").show_selected_code()
  end, {
    desc = "Show currently selected code in ECA",
  })

  vim.api.nvim_create_user_command("EcaClearSelection", function()
    require("eca.api").clear_selected_code()
  end, {
    desc = "Clear selected code from ECA",
  })

  -- ===== TODOs Commands =====
  
  vim.api.nvim_create_user_command("EcaAddTodo", function(opts)
    if opts.args and opts.args ~= "" then
      require("eca.api").add_todo(opts.args)
    else
      Utils.warn("Please provide TODO content")
    end
  end, {
    desc = "Add a new TODO to ECA",
    nargs = "+",
  })

  vim.api.nvim_create_user_command("EcaListTodos", function()
    require("eca.api").list_todos()
  end, {
    desc = "List active TODOs in ECA",
  })

  vim.api.nvim_create_user_command("EcaToggleTodo", function(opts)
    if opts.args and opts.args ~= "" then
      local index = tonumber(opts.args)
      if index then
        require("eca.api").toggle_todo(index)
      else
        Utils.warn("Please provide a valid TODO index")
      end
    else
      Utils.warn("Please provide TODO index to toggle")
    end
  end, {
    desc = "Toggle TODO completion status",
    nargs = 1,
  })

  vim.api.nvim_create_user_command("EcaClearTodos", function()
    require("eca.api").clear_todos()
  end, {
    desc = "Clear all TODOs from ECA",
  })

  vim.api.nvim_create_user_command("EcaServerStart", function()
    require("eca.api").start_server()
  end, {
    desc = "Start ECA server",
  })

  vim.api.nvim_create_user_command("EcaServerStop", function()
    require("eca.api").stop_server()
  end, {
    desc = "Stop ECA server",
  })

  vim.api.nvim_create_user_command("EcaServerRestart", function()
    require("eca.api").restart_server()
  end, {
    desc = "Restart ECA server",
  })

  vim.api.nvim_create_user_command("EcaServerStatus", function()
    local eca = require("eca")
    local status = eca.server and eca.server:status() or "Not initialized"
    local status_icon = "○"
    
    if status == "Running" then
      status_icon = "✓"
    elseif status == "Starting" then
      status_icon = "⋯"
    elseif status == "Failed" then
      status_icon = "✗"
    end
    
    Utils.info("ECA Server Status: " .. status .. " " .. status_icon)
    
    -- Also show path info if available
    if eca.server and eca.server._path_finder then
      local config = require("eca.config")
      if config.server_path and config.server_path ~= "" then
        Utils.info("Server path: " .. config.server_path .. " (custom)")
      else
        Utils.info("Server path: auto-detected/downloaded")
      end
    end
  end, {
    desc = "Show ECA server status with details",
  })

  vim.api.nvim_create_user_command("EcaSend", function(opts)
    if opts.args and opts.args ~= "" then
      require("eca.api").send_message(opts.args)
    else
      Utils.warn("Please provide a message to send")
    end
  end, {
    desc = "Send a message to ECA",
    nargs = "+",
  })

  vim.api.nvim_create_user_command("EcaDebugWidth", function()
    local Config = require("eca.config")
    local width = Config.get_window_width()
    local columns = vim.o.columns
    local percentage = Config.options.windows.width
    Utils.info(string.format("Width: %d columns (%.1f%% of %d total columns)", width, percentage, columns))
  end, {
    desc = "Debug window width calculation",
  })

  vim.api.nvim_create_user_command("EcaRedownload", function()
    local eca = require("eca")
    local Utils = require("eca.utils")
    
    if eca.server and eca.server:is_running() then
      Utils.info("Stopping server before re-download...")
      eca.server:stop()
    end
    
    -- Remove existing version file to force re-download
    local cache_dir = Utils.get_cache_dir()
    local version_file = cache_dir .. "/eca-version"
    os.remove(version_file)
    
    -- Remove existing binary
    local server_binary = cache_dir .. "/eca"
    os.remove(server_binary)
    
    Utils.info("Removed cached ECA server. Will re-download on next start.")
    
    -- Restart server
    vim.defer_fn(function()
      if eca.server then
        eca.server:start()
      end
    end, 1000)
  end, {
    desc = "Force re-download of ECA server",
  })

  vim.api.nvim_create_user_command("EcaStopResponse", function()
    local eca = require("eca")
    local Utils = require("eca.utils")
    
    -- Force stop any ongoing streaming response
    if eca.sidebar then
      eca.sidebar:_finalize_streaming_response()
      Utils.info("Forced stop of streaming response")
    else
      Utils.warn("No active sidebar to stop")
    end
  end, {
    desc = "Emergency stop for infinite loops or runaway responses",
  })

  vim.api.nvim_create_user_command("EcaFixTreesitter", function()
    local Utils = require("eca.utils")
    
    -- Emergency treesitter fix for chat buffer
    vim.schedule(function()
      local eca = require("eca")
      if eca.sidebar and eca.sidebar.containers and eca.sidebar.containers.chat then
        local bufnr = eca.sidebar.containers.chat.bufnr
        if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
          -- Disable all highlighting for this buffer
          pcall(vim.api.nvim_set_option_value, "syntax", "off", { buf = bufnr })
          
          -- Destroy treesitter highlighter if it exists
          pcall(function()
            if vim.treesitter.highlighter.active[bufnr] then
              vim.treesitter.highlighter.active[bufnr]:destroy()
              vim.treesitter.highlighter.active[bufnr] = nil
            end
          end)
          
          Utils.info("Disabled treesitter highlighting for ECA chat buffer")
          Utils.info("Buffer " .. bufnr .. " highlighting disabled")
        else
          Utils.warn("No valid chat buffer found")
        end
      else
        Utils.warn("No active ECA sidebar found")
      end
    end)
  end, {
    desc = "Emergency fix for treesitter issues in ECA chat",
  })

  Utils.debug("ECA commands registered")
end

return M
