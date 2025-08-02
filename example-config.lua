-- Exemplo de configuração para testar o plugin ECA

-- Configuração básica
require("eca").setup({
  debug = true,  -- Ativa logs de debug para desenvolvimento
  behaviour = {
    auto_set_keymaps = true,
    auto_focus_sidebar = true,
  },
  markview = {
    enable = true, -- Ativa integração com markview.nvim para markdown bonito
    filetypes = { "markdown", "Eca" },
  },
  mappings = {
    chat = "<leader>ac",
    focus = "<leader>af",
    toggle = "<leader>at",
  },
  windows = {
    width = 50,  -- 50% da largura da tela (valores de 1 a 100)
  },
})

-- Alguns comandos úteis para teste:
-- :EcaChat - Abre o chat
-- :EcaToggle - Alterna a visibilidade
-- :EcaServerStatus - Verifica status do servidor

-- IMPORTANTE: Para usar markview.nvim, instale-o primeiro:
-- Com lazy.nvim:
-- {
--   "OXY2DEV/markview.nvim",
--   lazy = false,
--   dependencies = {
--     "nvim-treesitter/nvim-treesitter",
--     "nvim-tree/nvim-web-devicons"
--   },
--   opts = {
--     preview = {
--       filetypes = { "markdown", "Eca" },
--       ignore_buftypes = {},
--     }
--   }
-- }
