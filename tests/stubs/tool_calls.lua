local stubs = {}

stubs.read_file = {
  arguments = {
    path = "/Users/tgeorge/git/eca-nvim/hack/messages.lua",
  },
  id = "toolu_013zj73SHzZNoeE7kzD7qzb4",
  manualApproval = true,
  name = "eca_read_file",
  origin = "native",
  summary = "Reading file messages.lua",
  type = "toolCallRun",
}

stubs.edit_file = {
  arguments = {
    new_content = 'local M = {}\n\n--- Show ECA messages using snacks.picker\nfunction M.show()\n  local has_snacks, picker = pcall(require, "snacks.picker")\n  if not has_snacks then\n    vim.notify("snacks.picker is not available", vim.log.levels.ERROR)\n    return\n  end\n\n  Snacks.picker(\n    ---@type snacks.picker.Config\n    {\n      source = "eca messages",\n      finder = function(opts, ctx)\n        ---@type snacks.picker.finder.Item[]\n        local items = {}\n        for msg in vim.iter(require("eca").server.messages) do\n          local decoded = vim.json.decode(msg.content)\n          table.insert(items, {\n            text = decoded.method,\n            idx = decoded.id,\n            preview = {\n              text = vim.inspect(decoded),\n              ft = "lua",\n},\n})\n        end\n        return items\n      end,\n      preview = "preview",\n      format = "text",\n      confirm = function(self, item, _)\n        vim.fn.setreg("", item.preview.text)\n        self:close()\n      end,\n }\n  )\nend\n\nreturn M',
    original_content = 'local has_snacks, picker = pcall(require, "snacks.picker")\nif has_snacks then\n  Snacks.picker(\n    ---@type snacks.picker.Config\n    {\n      source = "eca messages",\n      finder = function(opts, ctx)\n        ---@type snacks.picker.finder.Item[]\n        local items = {}\n        for msg in vim.iter(require("eca").server.messages) do\n          local decoded = vim.json.decode(msg.content)\n          table.insert(items, {\n            text = decoded.method,\n            idx = decoded.id,\n            preview = {\n              text = vim.inspect(decoded),\n              ft = "lua",\n },\n })\n        end\n        return items\n      end,\n      preview = "preview",\n      format = "text",\n      confirm = function(self, item, _)\n        vim.fn.setreg("", item.preview.text)\n        self:close()\n      end,\n }\n  )\nend',
    path = "/Users/tgeorge/git/eca-nvim/hack/messages.lua",
  },
  details = {
    diff = '@@ -1, 5 +1, 13 @@\n-local has_snacks, picker = pcall(require, "snacks.picker")\n-if has_snacks then\n+local M = {}\n+\n+--- Show ECA messages using snacks.picker\n+function M.show()\n+  local has_snacks, picker = pcall(require, "snacks.picker")\n+  if not has_snacks then\n+    vim.notify("snacks.picker is not available", vim.log.levels.ERROR)\n+    return\n+  end\n+\n   Snacks.picker(\n     ---@type snacks.picker.Config\n     {\n@@ -29, 3 +37, 5 @@\n }\n   )\n end\n+\n+return M',
    linesAdded = 12,
    linesRemoved = 10,
    path = "/Users/tgeorge/git/eca-nvim/hack/messages.lua",
    type = "fileChange",
  },
  id = "toolu_01KAVb3qpJDcSnbnJmpUndQF",
  manualApproval = true,
  name = "eca_edit_file",
  origin = "native",
  summary = "Editting file",
  type = "toolCallRun",
}

stubs.mcp = {
  arguments = {
    content = 'return "hello world"',
    path = "/Users/tgeorge/git/eca-nvim/hack/test_mcp_write_file.lua",
  },
  id = "toolu_01B8xcb7csLRHvqrnAZTgzPi",
  manualApproval = true,
  name = "write_file",
  origin = "mcp",
  type = "toolCallRun",
}

return stubs
