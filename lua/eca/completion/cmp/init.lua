local cmp = require("cmp")

vim.api.nvim_create_autocmd("FileType", {
  pattern = "eca-input",
  callback = function()
    cmp.register_source("eca_commands", require("eca.completion.cmp.commands").new())
    cmp.register_source("eca_contexts", require("eca.completion.cmp.context").new())
    cmp.setup.filetype("eca-input", {
      sources = {
        { name = "eca_contexts" },
        { name = "eca_commands" },
      },
    })
    -- returning true will remove this autocmd
    -- now that the completion sources are registered
    return true
  end,
})
