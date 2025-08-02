-- Plugin specification for package managers
return {
  name = "eca-neovim",
  description = "ECA (Editor Code Assistant) integration for Neovim",
  dependencies = {
    "nvim-lua/plenary.nvim", -- For async operations (optional)
  },
  config = function()
    require("eca").setup({
      -- Default configuration
      debug = false,
      server_path = "",
      server_args = "",
      behaviour = {
        auto_set_keymaps = true,
        auto_focus_sidebar = true,
      },
      mappings = {
        chat = "<leader>ec",
        focus = "<leader>ef",
        toggle = "<leader>et",
      },
    })
  end,
  keys = {
    { "<leader>ec", "<cmd>EcaChat<cr>", desc = "Open ECA chat" },
    { "<leader>ef", "<cmd>EcaFocus<cr>", desc = "Focus ECA sidebar" },
    { "<leader>et", "<cmd>EcaToggle<cr>", desc = "Toggle ECA sidebar" },
  },
  cmd = {
    "EcaChat",
    "EcaToggle", 
    "EcaFocus",
    "EcaClose",
    "EcaAddFile",
    "EcaAddSelection",
    "EcaServerStart",
    "EcaServerStop",
    "EcaServerRestart",
    "EcaServerStatus",
    "EcaSend",
  },
}
