-- 🧪 Simple test script for ECA server
-- Run this file to test if the server starts correctly

local function test_eca_server()
  print("🔧 Testing ECA server...")
  
  -- Import modules
  local ok, eca = pcall(require, "eca")
  if not ok then
    print("❌ Error loading ECA module: " .. tostring(eca))
    return
  end
  
  -- Configure ECA
  local setup_ok, setup_err = pcall(eca.setup, {
    debug = true,
    behaviour = {
      auto_start_server = true,
      show_status_updates = true,
    }
  })
  
  if not setup_ok then
    print("❌ Error in ECA setup: " .. tostring(setup_err))
    return
  end
  
  print("✅ ECA configured successfully")
  
  -- Check if server was created
  if not eca.server then
    print("❌ Server was not created")
    return
  end
  
  print("✅ Server created")
  print("📊 Initial status: " .. eca.server:status())
  
  -- Wait a bit to see if server starts
  vim.defer_fn(function()
    print("📊 Status after delay: " .. eca.server:status())
    
    if eca.server:is_running() then
      print("✅ Server is running!")
    else
      print("⚠️  Server is not running yet")
      print("💡 Check :messages for more details")
    end
  end, 3000)
end

-- Run test
test_eca_server()
