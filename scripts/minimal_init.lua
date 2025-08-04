-- Minimal init.lua for testing
vim.cmd([[let &rtp.=','.getcwd()]])

-- Add dependencies to runtime path if headless
if #vim.api.nvim_list_uis() == 0 then
  vim.cmd('set rtp+=deps/mini.nvim')
  vim.cmd('set rtp+=deps/nui.nvim')
  require('mini.test').setup({
    collect = {
      emulate_busted = true,
      find_files = function()
        return vim.fn.globpath('tests', '**/test_*.lua', true, true)
      end,
    },
    execute = {
      stop_on_error = false,
    },
    silent = false,
  })
end