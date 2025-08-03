-- ECA Plugin Testing
-- This file helps test the ECA plugin functionality

-- First, let's set up the plugin
require("eca").setup({
  debug = true,
  server_path = "", -- Will auto-download
  markview = {
    enable = true,
  },
  mappings = {
    chat = "<leader>ec",
    focus = "<leader>ef", 
    toggle = "<leader>et",
  },
})

-- Test functions
local function test_basic_functionality()
  print("Testing ECA basic functionality...")
  
  -- Test API functions
  local api = require("eca.api")
  
  -- Test server status
  local status = api.server_status()
  print("Server status:", status)
  
  -- Test opening chat
  api.chat()
  
  -- Test adding current file as context
  api.add_current_file_context()
end

-- Test the plugin
vim.defer_fn(function()
  test_basic_functionality()
end, 1000)

return {
  test_basic_functionality = test_basic_functionality,
}
