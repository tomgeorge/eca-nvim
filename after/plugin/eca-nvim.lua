---@diagnostic disable-next-line: param-type-mismatch
local has_cmp, cmp = pcall(require, "cmp")
if has_cmp then
  cmp.register_source("eca_commands", require("eca.completion.cmp.commands").new())
  cmp.register_source("eca_contexts", require("eca.completion.cmp.context").new())
  cmp.setup.filetype("eca-input", {
    sources = {
      { name = "eca_contexts" },
      { name = "eca_commands" },
    },
  })
end
