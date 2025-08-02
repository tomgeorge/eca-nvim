-- Teste para verificar se o markview.nvim está funcionando
-- Execute este arquivo com :luafile test-markview.lua

local function test_markview()
  print("🔍 Testando integração com markview.nvim...")
  
  -- Verificar se markview está disponível
  local markview_ok, markview = pcall(require, "markview")
  
  if not markview_ok then
    print("❌ markview.nvim não encontrado")
    print("💡 Instale com: { 'OXY2DEV/markview.nvim', lazy = false }")
    return false
  end
  
  print("✅ markview.nvim encontrado")
  
  -- Verificar métodos disponíveis
  local methods = {}
  if markview.enable then table.insert(methods, "enable") end
  if markview.disable then table.insert(methods, "disable") end
  if markview.attach then table.insert(methods, "attach") end
  if markview.detach then table.insert(methods, "detach") end
  if markview.setup then table.insert(methods, "setup") end
  
  print("📋 Métodos disponíveis: " .. table.concat(methods, ", "))
  
  -- Verificar se treesitter está configurado para markdown
  local ts_ok, ts = pcall(require, "nvim-treesitter")
  if ts_ok then
    print("✅ nvim-treesitter disponível")
  else
    print("⚠️  nvim-treesitter não encontrado (necessário para markview)")
  end
  
  -- Verificar parser markdown
  local has_markdown = vim.fn.executable("markdown") == 1 or 
                      pcall(vim.treesitter.get_parser, 0, "markdown")
  
  if has_markdown then
    print("✅ Parser markdown disponível")
  else
    print("⚠️  Parser markdown não encontrado")
    print("💡 Execute: :TSInstall markdown")
  end
  
  print("\n🎉 Teste concluído! Agora teste o ECA com :EcaChat")
  return true
end

-- Executar teste
test_markview()
