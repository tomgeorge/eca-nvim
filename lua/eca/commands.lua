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
    local status = require("eca.api").server_status()
    Utils.info("ECA Server Status: " .. status)
  end, {
    desc = "Show ECA server status",
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

  Utils.debug("ECA commands registered")
end

return M
