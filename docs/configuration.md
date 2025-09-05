# Configuration

ECA is highly configurable. This page lists all available options and provides common presets.

## Full configuration reference

```lua
require("eca").setup({
  -- === BASIC SETTINGS ===

  -- Enable debug mode (shows detailed logs)
  debug = false,

  -- Path to ECA binary (empty = automatic download)
  server_path = "",

  -- Extra arguments for ECA server
  server_args = "--log-level info",

  -- Usage string format (tokens/cost)
  usage_string_format = "{messageCost} / {sessionCost}",

  -- === BEHAVIOR ===
  behaviour = {
    -- Set keymaps automatically
    auto_set_keymaps = true,

    -- Focus sidebar automatically when opening
    auto_focus_sidebar = true,

    -- Start server automatically
    auto_start_server = true,

    -- Download server automatically if not found
    auto_download = true,

    -- Show status updates in notifications
    show_status_updates = true,
  },

  -- === KEY MAPPINGS ===
  mappings = {
    chat = "<leader>ec",      -- Open chat
    focus = "<leader>ef",     -- Focus sidebar
    toggle = "<leader>et",    -- Toggle sidebar
  },

  -- === CHAT ===
  chat = {
    headers = {
      user = "## 👤 You",
      assistant = "## 🤖 ECA",
    },
  },

  -- === WINDOW SETTINGS ===
  windows = {
    -- Automatic line wrapping
    wrap = true,

    -- Width as percentage of screen (1-100)
    width = 40,

    -- Sidebar header configuration
    sidebar_header = {
      enabled = true,
      align = "center",     -- "left", "center", "right"
      rounded = true,
    },

    -- Input area configuration
    input = {
      prefix = "> ",        -- Input line prefix
      height = 8,           -- Input window height
    },

    -- Edit window configuration
    edit = {
      border = "rounded",   -- "none", "single", "double", "rounded"
      start_insert = true,  -- Start in insert mode
    },

    -- Ask window configuration
    ask = {
      floating = false,     -- Use floating window
      start_insert = true,  -- Start in insert mode
      border = "rounded",
      focus_on_apply = "ours", -- "ours" or "theirs"
    },
  },

  -- === HIGHLIGHTS AND COLORS ===
  highlights = {
    diff = {
      current = "DiffText",   -- Highlight for current diff
      incoming = "DiffAdd",   -- Highlight for incoming diff
    },
  },
})
```

---

## Chat headers
You can customize the chat role headers shown in the sidebar. For example:

```lua
require("eca").setup({
  chat = {
    headers = {
      user = "## 👨 Me",       -- default: "## 👤 You"
      assistant = "## 🤖 Copilot", -- default: "## 🤖 ECA"
    },
  },
})
```

Notes:
- These are plain strings; they will be printed verbatim as a single line.
- A blank line is automatically inserted after the header.

## Presets

### Minimalist
```lua
require("eca").setup({
  behaviour = { show_status_updates = false },
  windows = { width = 30 },
})
```

### Visual/UX focused
```lua
require("eca").setup({
  behaviour = { auto_focus_sidebar = true },
  windows = {
    width = 50,
    wrap = true,
    sidebar_header = { enabled = true, rounded = true },
    input = { prefix = "💬 ", height = 10 },
  },
})
```

### Development
```lua
require("eca").setup({
  debug = true,
  server_args = "--log-level debug",
  behaviour = {
    auto_start_server = true,
    show_status_updates = true,
  },
  mappings = {
    chat = "<F12>",
    toggle = "<F11>",
    focus = "<F10>",
  },
})
```

### Performance-oriented
```lua
require("eca").setup({
  behaviour = {
    auto_focus_sidebar = false,
    show_status_updates = false,
  },
  windows = { width = 25 },
})
```

---

## Notes
- Set `server_path` if you prefer using a local ECA binary.
- For noisy environments, disable `show_status_updates`.
- Adjust `windows.width` to fit your layout.
- Keymaps can be set manually by turning off `auto_set_keymaps`.
