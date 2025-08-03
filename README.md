# 🤖 ECA Neovim Plugin

A modern Neovim plugin that integrates [ECA (Editor Code Assistant)](https://eca.dev/) directly into the editor, providing an integrated and intuitive AI experience.

## ✨ Features

- 🤖 **Integrated AI Chat**: Chat interface directly in Neovim
- 📁 **Smart Context**: Add files, directories and selections as context
- 🚀 **Automatic Download**: ECA server downloads automatically
- ⚡ **Auto-start**: Server starts automatically with the plugin
- 🎨 **Modern Interface**: Integrated sidebar with markdown support
- ⌨️ **Intuitive Commands**: Ctrl+S to send, Enter for new line
- 🔧 **Highly Configurable**: Customizable shortcuts, appearance and behavior
- ✨ **Beautiful Markdown**: Integration with [markview.nvim](https://github.com/OXY2DEV/markview.nvim)
- 📊 **Visual Feedback**: Status bar with server information
- 🔄 **Real-time Streaming**: Responses appear as they are generated

## 📦 Installation

### 🚀 [lazy.nvim](https://github.com/folke/lazy.nvim) (Recommended)

#### Basic Configuration

```lua
{
  "W3ND31/eca-neovim",
  config = function()
    require("eca").setup()
  end
}
```

#### Complete Configuration with Markview

```lua
{
  "W3ND31/eca-neovim",
  dependencies = {
    -- Recommended for beautiful markdown rendering
    {
      "OXY2DEV/markview.nvim",
      lazy = false,
      dependencies = {
        "nvim-treesitter/nvim-treesitter",
        "nvim-tree/nvim-web-devicons"
      }
    }
  },
  config = function()
    require("eca").setup({
      debug = false,
      behaviour = {
        auto_set_keymaps = true,
        auto_focus_sidebar = true,
        auto_start_server = true,
      },
      markview = {
        enable = true,
        filetypes = { "markdown", "Eca" },
      },
      mappings = {
        chat = "<leader>ec",
        focus = "<leader>ef",
        toggle = "<leader>et",
      },
      windows = {
        width = 40,
        wrap = true,
      },
    })
  end
}
```

### 📦 [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "W3ND31/eca-neovim",
  requires = {
    -- Optional: for beautiful markdown
    {
      "OXY2DEV/markview.nvim",
      requires = {
        "nvim-treesitter/nvim-treesitter",
        "nvim-tree/nvim-web-devicons"
      }
    }
  },
  config = function()
    require("eca").setup({
      -- Your configurations here
    })
  end
}
```

### 🔌 [vim-plug](https://github.com/junegunn/vim-plug)

```vim
" In your init.vim or init.lua
Plug 'W3ND31/eca-neovim'

" Optional: for beautiful markdown
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'nvim-tree/nvim-web-devicons'
Plug 'OXY2DEV/markview.nvim'

" After the plugins, add:
lua << EOF
require("eca").setup({
  -- Your configurations here
})
EOF
```

### 📋 [dein.vim](https://github.com/Shougo/dein.vim)

```vim
call dein#add('W3ND31/eca-neovim')

" Optional: for beautiful markdown
call dein#add('nvim-treesitter/nvim-treesitter')
call dein#add('nvim-tree/nvim-web-devicons')
call dein#add('OXY2DEV/markview.nvim')

" Configuration
lua << EOF
require("eca").setup()
EOF
```

### 🦘 [rocks.nvim](https://github.com/nvim-neorocks/rocks.nvim)

```toml
# rocks.toml
[plugins]
"eca-neovim" = { git = "W3ND31/eca-neovim" }

# Optional: for beautiful markdown
"markview.nvim" = { git = "OXY2DEV/markview.nvim" }
"nvim-treesitter" = "scm"
"nvim-web-devicons" = "scm"
```

### 🌱 [mini.deps](https://github.com/echasnovski/mini.nvim)

```lua
local add = MiniDeps.add

add({
  source = "W3ND31/eca-neovim",
  depends = {
    -- Optional: for beautiful markdown
    "OXY2DEV/markview.nvim",
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons"
  }
})

require("eca").setup()
```

## ⚡ Quick Start

1. **Install the plugin** using your favorite package manager
2. **Configure the plugin** (basic configuration is sufficient)
3. **Open the chat** with `:EcaChat` or `<leader>ec`
4. **Type your message** and press `Ctrl+S` to send
5. **Add context** using `:EcaAddFile` or `:EcaAddSelection`

## 🎮 Available Commands

| Command | Description | Example |
|---------|-------------|---------|
| `:EcaChat` | Opens ECA chat | `:EcaChat` |
| `:EcaToggle` | Toggles sidebar visibility | `:EcaToggle` |
| `:EcaFocus` | Focus on ECA sidebar | `:EcaFocus` |
| `:EcaClose` | Closes ECA sidebar | `:EcaClose` |
| `:EcaAddFile [file]` | Adds file as context | `:EcaAddFile src/main.lua` |
| `:EcaAddSelection` | Adds current selection as context | `:EcaAddSelection` |
| `:EcaServerStart` | Starts ECA server manually | `:EcaServerStart` |
| `:EcaServerStop` | Stops ECA server | `:EcaServerStop` |
| `:EcaServerRestart` | Restarts ECA server | `:EcaServerRestart` |
| `:EcaServerStatus` | Shows detailed server status | `:EcaServerStatus` |
| `:EcaSend <message>` | Sends message directly | `:EcaSend Explain this function` |

## ⌨️ Keyboard Shortcuts

### Global Shortcuts (Default)

| Shortcut | Action | Configuration |
|----------|--------|---------------|
| `<leader>ec` | Open/focus chat | `mappings.chat` |
| `<leader>ef` | Focus on sidebar | `mappings.focus` |
| `<leader>et` | Toggle sidebar | `mappings.toggle` |

### Chat Shortcuts

| Shortcut | Action | Context |
|----------|--------|---------|
| `Ctrl+S` | Send message | Insert/Normal mode |
| `Enter` | New line in message | Insert mode |
| `Esc` | Exit insert mode | Insert mode |

## 🔧 Complete Configuration

### All Available Options

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
  
  -- === MARKVIEW INTEGRATION ===
  markview = {
    -- Enable markview.nvim integration
    enable = true,
    
    -- File types to enable markview
    filetypes = { "markdown", "Eca" },
  },
  
  -- === KEY MAPPINGS ===
  mappings = {
    chat = "<leader>ec",      -- Open chat
    focus = "<leader>ef",     -- Focus sidebar
    toggle = "<leader>et",    -- Toggle sidebar
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

### Configuration by Use Profile

#### 🏎️ Minimalist Configuration

```lua
require("eca").setup({
  markview = { enable = false },
  behaviour = { show_status_updates = false },
  windows = { width = 30 },
})
```

#### 🎨 Complete Visual Configuration

```lua
require("eca").setup({
  markview = { enable = true },
  behaviour = { auto_focus_sidebar = true },
  windows = {
    width = 50,
    wrap = true,
    sidebar_header = { enabled = true, rounded = true },
    input = { prefix = "💬 ", height = 10 },
  },
})
```

#### 🚀 Development Configuration

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

#### ⚡ Performance Configuration

```lua
require("eca").setup({
  markview = { enable = false },
  behaviour = {
    auto_focus_sidebar = false,
    show_status_updates = false,
  },
  windows = { width = 25 },
})
```

## 📝 Detailed Usage Guide

### 🚀 Getting Started

1. **Install the plugin** using any package manager
2. **Restart Neovim** or reload configuration
3. **Open a file** you want to analyze
4. **Run** `:EcaChat` or press `<leader>ec`
5. **Server will download automatically** on first run
6. **Type your question** and press `Ctrl+S` to send

### 💬 Using the Chat

#### Sending Messages

- **Type your message** in the line starting with `> `
- **Press `Enter`** to break line (messages can have multiple lines)
- **Press `Ctrl+S`** to send the message
- **Wait for response** which appears in real time

#### Message Examples

```markdown
Explain what this function does
```

```markdown
Optimize this code:
[code will be added as context]
```

```markdown
How can I improve the performance of this function?
Consider readability and maintainability.
```

### 📁 Adding Context

#### Current File

```vim
:EcaAddFile
```

#### Specific File

```vim
:EcaAddFile src/main.lua
:EcaAddFile /full/path/to/file.js
```

#### Code Selection

1. Select code in visual mode (`v`, `V`, or `Ctrl+v`)
2. Run `:EcaAddSelection`
3. Selected code will be added as context

#### Multiple Files

```vim
:EcaAddFile src/utils.lua
:EcaAddFile src/config.lua
:EcaAddFile tests/test_utils.lua
```

### 🎯 Common Use Cases

#### 🔍 Code Analysis

```markdown
> Analyze this file and tell me if there are performance issues
```

#### 🐛 Debug and Problem Solving

```markdown
> This code is returning an error. Can you help me identify the problem?
[add the file as context first]
```

#### 📚 Documentation

```markdown
> Generate JSDoc documentation for these functions
```

#### ♻️ Refactoring

```markdown
> How can I refactor this code to use ES6+ features?
```

#### 🧪 Testing

```markdown
> Create unit tests for this function
```

#### 💡 Optimization

```markdown
> Suggest improvements to optimize this algorithm
```

### ⌨️ Recommended Workflow

1. **Open the file** you want to analyze
2. **Add as context**: `:EcaAddFile`
3. **Open chat**: `<leader>ec`
4. **Ask your question**:

   ```markdown
   > Explain what this function does and how I can improve it
   ```

5. **Send with `Ctrl+S`**
6. **Read the response** and implement suggestions
7. **Continue conversation** for clarifications

### 🔧 Advanced Commands

#### Server Management

```vim
" Check status
:EcaServerStatus

" Restart if there are issues
:EcaServerRestart

" Stop temporarily
:EcaServerStop

" Start again
:EcaServerStart
```

#### Quick Commands

```vim
" Send message directly (without opening chat)
:EcaSend Explain this line of code

" Focus on chat if already open
:EcaFocus

" Toggle chat visibility
:EcaToggle
```

## 📋 System Requirements

### 🔧 Required

- **Neovim >= 0.8.0** (Recommended: >= 0.9.0)
- **curl** (for automatic server download)
- **unzip** (for server extraction)
- **Internet connection** (for initial download and ECA functionality)

### ✨ Optional

- **[markview.nvim](https://github.com/OXY2DEV/markview.nvim)** - For beautiful markdown rendering in chat
- **[nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)** - Required for markview
- **[nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons)** - Icons for markview
- **[plenary.nvim](https://github.com/nvim-lua/plenary.nvim)** - Utility functions (some distributions)

### 🎨 Installing Markview (Recommended)

Markview.nvim makes the chat much more beautiful and readable:

```lua
-- With lazy.nvim
{
  "OXY2DEV/markview.nvim",
  lazy = false,
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons"
  },
  config = function()
    require("markview").setup({
      modes = { "n", "i", "no", "c" },
      hybrid_modes = { "i" },
    })
  end
}
```

### 💻 Tested Systems

- ✅ **macOS** (Intel and Apple Silicon)
- ✅ **Linux** (Ubuntu, Arch, Fedora, etc.)
- ✅ **Windows** (WSL2 recommended)
- ✅ **FreeBSD**

## 🚨 Troubleshooting

### ❌ Server won't start

**Symptoms**: Chat doesn't respond, "server not running" error

**Solutions**:

- Check if `curl` and `unzip` are installed
- Try setting `server_path` manually with absolute path
- Run `:EcaServerStatus` for diagnostics
- Check logs with `debug = true` in configuration
- Try `:EcaServerRestart`

```lua
-- Debug configuration
require("eca").setup({
  debug = true,
  server_args = "--log-level debug",
})
```

### 🌐 Connectivity issues

**Symptoms**: Download fails, timeouts, network errors

**Solutions**:

- Check your internet connection
- Check if firewalls are not blocking
- Try restarting with `:EcaServerRestart`
- Configure proxy if necessary
- Download server manually and configure `server_path`

### 🎨 Markview not working

**Symptoms**: Markdown appears as plain text

**Solutions**:

- Install markview.nvim and dependencies
- Check if `markview.enable = true` in configuration
- Run `:TSUpdate markdown` to update parsers
- Restart Neovim after installing markview

### ⌨️ Shortcuts not working

**Symptoms**: `<leader>ec` doesn't open chat

**Solutions**:

- Check if `behaviour.auto_set_keymaps = true`
- Confirm what your `<leader>` key is (default: `\`)
- Configure shortcuts manually:

```lua
vim.keymap.set("n", "<leader>ec", ":EcaChat<CR>", { desc = "ECA Chat" })
vim.keymap.set("n", "<leader>et", ":EcaToggle<CR>", { desc = "ECA Toggle" })
```

### 📱 Windows issues

**Symptoms**: Path errors, server not found

**Solutions**:

- Use WSL2 for better compatibility
- Install curl and unzip on Windows
- Use forward slashes `/` in paths
- Configure `server_path` with `.exe` extension

### 🔧 Performance issues

**Symptoms**: Lag when typing, slow responses

**Solutions**:

- Disable markview: `markview.enable = false`
- Reduce window width: `windows.width = 25`
- Disable visual updates: `behaviour.show_status_updates = false`
- Use minimalist configuration

## 🎓 Tips and Tricks

### 💡 Productivity

1. **Use `:EcaAddFile`** before asking questions about specific code
2. **Combine contexts**: Add multiple related files
3. **Be specific**: Detailed questions generate better responses
4. **Use markdown**: ECA understands markdown formatting in questions

### 🔄 Workflows

#### 📝 Code Review

```markdown
> Analyze this code and suggest improvements:
- Performance
- Readability  
- Best practices
- Possible bugs
```

#### 🧪 Test Creation

```markdown
> Create comprehensive unit tests for this function, including:
- Success cases
- Error cases
- Edge cases
- Mocks if necessary
```

#### 📚 Documentation

```markdown
> Generate complete documentation for this module:
- General description
- Parameters and types
- Usage examples
- Possible exceptions
```

### ⌨️ Custom Shortcuts

```lua
-- More convenient shortcuts
vim.keymap.set("n", "<F12>", ":EcaChat<CR>")
vim.keymap.set("n", "<F11>", ":EcaToggle<CR>")
vim.keymap.set("v", "<leader>ea", ":EcaAddSelection<CR>")

-- Shortcut to add current file
vim.keymap.set("n", "<leader>ef", function()
  vim.cmd("EcaAddFile " .. vim.fn.expand("%"))
end)
```

## 🤝 Development and Contribution

### 📞 Support

- **Issues**: [GitHub Issues](https://github.com/W3ND31/eca-neovim/issues)
- **Discussions**: [GitHub Discussions](https://github.com/W3ND31/eca-neovim/discussions)
- **Wiki**: [GitHub Wiki](https://github.com/W3ND31/eca-neovim/wiki)

### 🔧 Local Development

1. **Clone the repository**:
   ```bash
   git clone https://github.com/W3ND31/eca-neovim.git
   ```

2. **Configure local path**:
   ```lua
   require("eca").setup({
     debug = true,
     -- Point to your local clone
     -- server_path = "/path/to/eca-binary",
   })
   ```

3. **Test changes**:
   ```vim
   :luafile %
   :EcaServerRestart
   ```

### 🎯 Contributing

1. **Fork** the repository
2. **Create branch** for your feature: `git checkout -b feature/new-functionality`
3. **Commit** your changes: `git commit -m 'Add new functionality'`
4. **Push** to branch: `git push origin feature/new-functionality`
5. **Open Pull Request**

### 🧪 Testing

Run tests before submitting PR:

```bash
# Unit tests
nvim --headless -c "lua require('eca.tests').run_all()"

# Manual test
nvim -c "lua require('eca').setup({debug=true})"
```

## 📄 License

**MIT License** - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

This plugin was inspired and based on the work of:

- **[avante.nvim](https://github.com/yetone/avante.nvim)** - Base structure and UI concepts
- **[eca-vscode](https://github.com/editor-code-assistant/eca-vscode)** - ECA server integration
- **[markview.nvim](https://github.com/OXY2DEV/markview.nvim)** - Beautiful markdown rendering
- **Neovim Community** - For all the tools and inspiration

## 🔗 Useful Links

- **[Official ECA Website](https://eca.dev/)**
- **[ECA Documentation](https://docs.eca.dev/)**
- **[VS Code Plugin](https://marketplace.visualstudio.com/items?itemName=editor-code-assistant.eca-vscode)**
- **[ECA GitHub](https://github.com/editor-code-assistant)**

---

<div align="center">

**✨ Made with ❤️ for the Neovim community ✨**

[⭐ Give a star if this plugin was useful!](https://github.com/W3ND31/eca-neovim)

</div>
