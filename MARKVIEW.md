# Markview.nvim Integration

The ECA plugin for Neovim includes native integration with [markview.nvim](https://github.com/OXY2DEV/markview.nvim) for beautiful markdown rendering in chat.

## Markview Installation

### With lazy.nvim

```lua
{
  "OXY2DEV/markview.nvim",
  lazy = false,
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons"
  },
  opts = {
    preview = {
      filetypes = { "markdown", "Eca" }, -- Includes "Eca" for chat
      ignore_buftypes = {},
    }
  }
}
```

### With packer.nvim

```lua
use {
  "OXY2DEV/markview.nvim",
  requires = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons"
  },
  config = function()
    require("markview").setup({
      preview = {
        filetypes = { "markdown", "Eca" }
      }
    })
  end
}
```

## ECA Configuration with Markview

```lua
require("eca").setup({
  markview = {
    enable = true, -- Enables markview integration
    filetypes = { "markdown", "Eca" }, -- File types to enable
  },
  -- ... other configurations
})
```

## Supported Features

ECA with markview.nvim offers:

- ✅ **Headers**: `#`, `##`, `###` rendered with highlighting
- ✅ **Bold text**: `**text**` and `__text__`
- ✅ **Italic text**: `*text*` and `_text_`
- ✅ **Inline code**: `` `code` ``
- ✅ **Code blocks**: ````code```` with syntax highlighting
- ✅ **Lists**: `- item`, `* item`, `1. item`
- ✅ **Quotes**: `> quote`
- ✅ **Links**: `[text](url)`
- ✅ **Separators**: `---`
- ✅ **Tables**: Markdown tables
- ✅ **Emojis**: 🤖, 👤, 💡, etc.

## Rendering Examples

### User input:
```markdown
## 👤 You

How can I improve this code?

```python
def fibonacci(n):
    if n <= 1:
        return n
    return fibonacci(n-1) + fibonacci(n-2)
```
```

### ECA response:
```markdown
## 🤖 ECA

Here are some **improvements** for the code:

### 1. 🚀 Memoization

```python
from functools import lru_cache

@lru_cache(maxsize=None)
def fibonacci(n):
    if n <= 1:
        return n
    return fibonacci(n-1) + fibonacci(n-2)
```

### 2. 💡 Iterative Implementation

```python
def fibonacci(n):
    if n <= 1:
        return n
    
    a, b = 0, 1
    for _ in range(2, n + 1):
        a, b = b, a + b
    return b
```

> **Tip**: The iterative version is more efficient for large numbers!
```

## Disabling Markview

If you prefer to use plain markdown, disable markview:

```lua
require("eca").setup({
  markview = {
    enable = false, -- Disables markview
  },
})
```

## Troubleshooting

### Markview not working
1. Check if plugin is installed: `:Lazy check markview.nvim`
2. Check if treesitter is configured: `:TSInstall markdown`
3. Restart Neovim after installing

### Slow performance
If markview is slow with long chats:

```lua
require("eca").setup({
  markview = {
    enable = true,
    filetypes = { "markdown" }, -- Remove "Eca" if necessary
  },
})
```

### Highlight conflicts
If there are visual conflicts:

```lua
-- In your init.lua, after configuring markview
vim.api.nvim_set_hl(0, "MarkviewHeading1", { fg = "#7aa2f7", bold = true })
vim.api.nvim_set_hl(0, "MarkviewCode", { bg = "#1a1b26", fg = "#bb9af7" })
```
