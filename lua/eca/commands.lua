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
    require("eca.api").add_selection_context()
  end, {
    desc = "Add current selection as context to ECA",
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

  Utils.debug("ECA commands registered")
end

return M
