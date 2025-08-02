-- plugin/eca.lua
-- Main plugin entry point for ECA

if vim.g.loaded_eca then
  return
end

-- Setup commands immediately
require("eca.commands").setup()

vim.g.loaded_eca = 1
