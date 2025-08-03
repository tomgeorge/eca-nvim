-- Test to verify if markview.nvim is working
-- Run this file with :luafile test-markview.lua

local function test_markview()
  print("🔍 Testing markview.nvim integration...")
  
  -- Check if markview is available
  local markview_ok, markview = pcall(require, "markview")
  
  if not markview_ok then
    print("❌ markview.nvim not found")
    print("💡 Install with: { 'OXY2DEV/markview.nvim', lazy = false }")
    return false
  end
  
  print("✅ markview.nvim found")
  
  -- Check available methods
  local methods = {}
  if markview.enable then table.insert(methods, "enable") end
  if markview.disable then table.insert(methods, "disable") end
  if markview.attach then table.insert(methods, "attach") end
  if markview.detach then table.insert(methods, "detach") end
  if markview.setup then table.insert(methods, "setup") end
  
  print("📋 Available methods: " .. table.concat(methods, ", "))
  
  -- Check if treesitter is configured for markdown
  local ts_ok, ts = pcall(require, "nvim-treesitter")
  if ts_ok then
    print("✅ nvim-treesitter available")
  else
    print("⚠️  nvim-treesitter not found (required for markview)")
  end
  
  -- Check markdown parser
  local has_markdown = vim.fn.executable("markdown") == 1 or 
                      pcall(vim.treesitter.get_parser, 0, "markdown")
  
  if has_markdown then
    print("✅ Markdown parser available")
  else
    print("⚠️  Markdown parser not found")
    print("💡 Run: :TSInstall markdown")
  end
  
  print("\n🎉 Test completed! Now test ECA with :EcaChat")
  return true
end

-- Run test
test_markview()
