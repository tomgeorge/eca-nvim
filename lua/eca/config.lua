---@class eca.Config
local M = {}

---@class eca.Config
M._defaults = {
  debug = false,
  ---@type string
  server_path = "", -- Path to the ECA binary, will download automatically if empty
  ---@type string
  server_args = "", -- Extra args for the eca start command
  ---@type string
  usage_string_format = "{messageCost} / {sessionCost}",
  behaviour = {
    auto_set_keymaps = true,
    auto_focus_sidebar = true,
    auto_start_server = true, -- Automatically start server on setup
    auto_download = true, -- Automatically download server if not found
    show_status_updates = true, -- Show status updates in notifications
  },
  markview = {
    enable = true, -- Enable markview.nvim integration
    filetypes = { "markdown", "Eca" }, -- Filetypes to enable markview
  },
  mappings = {
    chat = "<leader>ec",
    focus = "<leader>ef",
    toggle = "<leader>et",
  },
  windows = {
    wrap = true,
    width = 40, -- Window width as percentage (40 = 40% of screen width)
    sidebar_header = {
      enabled = true,
      align = "center",
      rounded = true,
    },
    input = {
      prefix = "> ",
      height = 8, -- Height of the input window
    },
    edit = {
      border = "rounded",
      start_insert = true, -- Start insert mode when opening the edit window
    },
    ask = {
      floating = false, -- Open the 'AvanteAsk' prompt in a floating window
      start_insert = true, -- Start insert mode when opening the ask window
      border = "rounded",
      ---@type "ours" | "theirs"
      focus_on_apply = "ours", -- Which diff to focus after applying
    },
  },
  highlights = {
    ---@type AvanteConflictHighlights
    diff = {
      current = "DiffText",
      incoming = "DiffAdd",
    },
  },
}

---@type eca.Config
M.options = M._defaults

---@param opts eca.Config
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M._defaults, opts or {})
end

---@param override eca.Config
function M.override(override)
  M.options = vim.tbl_deep_extend("force", M.options, override)
end

function M.get_window_width()
  return math.ceil(vim.o.columns * (M.options.windows.width / 100))
end

function M.get_input_height()
  return M.options.windows.input.height
end

return setmetatable(M, {
  __index = function(_, k)
    if M.options[k] ~= nil then
      return M.options[k]
    end
    return M._defaults[k]
  end,
})
