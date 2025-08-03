# 🧪 Quick Test Guide - ECA.nvim

This guide helps you test if the ECA.nvim plugin is working correctly.

## 📋 Prerequisites

Make sure you have:
- [ ] Neovim >= 0.8.0
- [ ] `curl` installed (for automatic server download)
- [ ] `unzip` installed (to extract the server)
- [ ] Internet connection (first run)

## 🚀 Basic Test

### 1. Configure the Plugin

Add to your Neovim config (init.lua):

```lua
require("eca").setup({
  debug = true,  -- Enable for detailed logs
  behaviour = {
    auto_start_server = true,  -- Start server automatically (default)
    auto_download = true,      -- Download server automatically (default)
    show_status_updates = true, -- Show status updates (default)
  }
})
```

### 2. Automatic Verification

After installing and configuring the plugin:

1. **Start Neovim** - The server should start automatically
2. **Watch notifications** - You should see:
   - "Starting ECA server..."
   - "ECA server started and ready!" (when ready)
3. **Check status**: `:EcaServerStatus`

### 3. Test Commands

Run the following commands in Neovim:

```vim
" 1. Check server status (now with more details)
:EcaServerStatus

" 2. Open chat (server should already be running)
:EcaChat

" 3. Toggle sidebar
:EcaToggle

" 4. Focus on sidebar
:EcaFocus
```

### 4. Chat Test

1. ✨ **New**: Chat opens automatically when server is ready
2. Type a simple message: `Hello, ECA!`
3. **Press `Ctrl+S` to send** (not Enter anymore)
4. Wait for response

### 5. Multiline Message Test ✨

1. In chat, type a multiline message:
   ```
   > Explain this code:
   function test() {
     return "hello world";
   }
   ```
2. **Press `Ctrl+S` to send** (Enter just breaks line)
3. Complete message will be sent

### 4. Context Test

1. Open a `.lua` or `.py` file
2. Run `:EcaAddFile`
3. In chat, ask: `> Explain this file`

### 5. Selection Test

1. In visual mode, select some lines of code
2. Run `:EcaAddSelection`
3. Ask in chat: `> What does this code do?`

## 🔍 Problem Verification

### ✨ New Automatic Behavior

The plugin now starts automatically! No need to run `:EcaServerStart` manually anymore.

### Server doesn't start automatically?

```vim
" Check logs to understand the problem
:messages

" Check current status
:EcaServerStatus

" Restart manually if necessary
:EcaServerRestart
```

### Download issues?

```vim
" Force server re-download
:EcaRedownload

" Check if curl is available
:!which curl

" Check connection manually
:!curl -I https://github.com/editor-code-assistant/eca/releases/latest
```

### Sidebar doesn't appear?

```vim
" Check if window is open
:lua print(require("eca").is_sidebar_open())

" Open manually
:EcaChat

" Check width configuration
:EcaDebugWidth
```

### No chat response?

The server now starts automatically, but if there are issues:

1. Check status: `:EcaServerStatus`
2. Check your internet connection
3. Enable debug and see logs: `:messages`
4. If necessary, force re-download: `:EcaRedownload`

## 📝 Useful Logs

To see detailed logs:

```lua
" Enable debug in config
require("eca").setup({ debug = true })

" See Neovim messages
:messages

" See detailed status
:lua print(vim.inspect(require("eca").server:status()))
```

## ✅ Feature Checklist

### ✨ Automatic (New)
- [ ] Plugin loads without errors
- [ ] Server downloads automatically (first time)
- [ ] Server starts automatically on setup
- [ ] Status is shown via notifications
- [ ] Visual status indicator works

### Interface
- [ ] Sidebar opens/closes
- [ ] Chat receives messages
- [ ] AI responds to messages
- [ ] Keyboard shortcuts work

### Context
- [ ] File context works
- [ ] Selection context works
- [ ] Commands respond correctly

### Advanced Commands
- [ ] `:EcaServerStatus` shows detailed information
- [ ] `:EcaRedownload` forces new download
- [ ] `:EcaDebugWidth` shows width calculations

## 🆘 Common Troubleshooting

### Error: "Server not running"
```vim
:EcaServerStart
```

### Error: "Could not download ECA server"
- Check internet connection
- Check if `curl` is installed
- Try setting `server_path` manually

### Error: "Failed to extract ECA server"
- Check if `unzip` is installed
- Check write permissions in cache dir

### Sidebar too narrow/wide
```lua
require("eca").setup({
  windows = { width = 30 }  -- Adjust as needed
})
```

## 📞 Reporting Issues

If you find problems:

1. Enable debug: `require("eca").setup({ debug = true })`
2. Reproduce the problem
3. Collect logs: `:messages`
4. Report on GitHub with:
   - Neovim version
   - Operating system
   - Complete logs
   - Steps to reproduce

## 🎯 Next Steps

### ✨ New: Zero-Config Experience

Now ECA.nvim works practically without configuration! If everything works automatically:

1. **Start using**: Server starts by itself, just open `:EcaChat`
2. **Configure custom shortcuts** if desired
3. **Explore advanced commands** like `:EcaRedownload`
4. **Integrate with markview.nvim** for beautiful markdown
5. **Configure automatic contexts** for your workflow
6. **Customize interface** according to your preference

### 🔄 Migration from Previous Version

If you used the previous version that needed `:EcaServerStart`:

- **Remove manual commands** from your workflow
- **Take advantage of autostart** - no need to manage server anymore
- **Use `:EcaServerStatus`** for monitoring when necessary

Happy coding with ECA! 🚀

---

**Main Improvements in this Version:**
- 🎯 **Autostart**: Server starts automatically  
- 📥 **Auto-download**: Downloads server automatically
- 🔔 **Notifications**: Visual status integrated to Neovim
- 🛠️ **Management**: Advanced commands for diagnostics
- 🚀 **Zero-config**: Works immediately after installation

