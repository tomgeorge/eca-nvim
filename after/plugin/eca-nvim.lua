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

local has_blink, blink = pcall(require, "blink.cmp")
if has_blink then
  blink.add_source_provider("eca_commands", {
    name = "eca_commands",
    module = "eca.completion.blink.commands",
    enabled = true,
  })
  blink.add_filetype_source("eca-input", "eca_commands")

  blink.add_source_provider("eca_contexts", {
    name = "eca_contexts",
    module = "eca.completion.blink.context",
    enabled = true,
  })
  blink.add_filetype_source("eca-input", "eca_contexts")
end
