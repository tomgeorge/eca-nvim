# Usage

Everything you need to get productive with ECA inside Neovim.

## Quick Start

1. Install the plugin using any package manager
2. Restart Neovim or reload your configuration
3. Open a file you want to analyze
4. Run `:EcaChat` or press `<leader>ec`
5. On first run, the server downloads automatically
6. Type your question and press `Ctrl+S` to send

---

## Available Commands

| Command | Description | Example |
|--------|-------------|---------|
| `:EcaChat` | Opens ECA chat | `:EcaChat` |
| `:EcaToggle` | Toggles sidebar visibility | `:EcaToggle` |
| `:EcaFocus` | Focus on ECA sidebar | `:EcaFocus` |
| `:EcaClose` | Closes ECA sidebar | `:EcaClose` |
| `:EcaAddFile [file]` | Adds file as context | `:EcaAddFile src/main.lua` |
| `:EcaAddSelection` | Adds current selection as context | `:EcaAddSelection` |
| `:EcaServerStart` | Starts ECA server manually | `:EcaServerStart` |
| `:EcaServerStop` | Stops ECA server | `:EcaServerStop` |
| `:EcaServerRestart` | Restarts ECA server | `:EcaServerRestart` |
| `:EcaSend <message>` | Sends message directly | `:EcaSend Explain this function` |

---

## Keyboard Shortcuts

### Global (default)

| Shortcut | Action |
|----------|--------|
| `<leader>ec` | Open/focus chat |
| `<leader>ef` | Focus on sidebar |
| `<leader>et` | Toggle sidebar |

### Chat

| Shortcut | Action | Context |
|----------|--------|---------|
| `Ctrl+S` | Send message | Insert/Normal mode |
| `Enter` | New line | Insert mode |
| `Esc` | Exit insert mode | Insert mode |

---

## Using the Chat

### Sending messages
- Type in the input line starting with `> `
- Press `Enter` to insert a new line
- Press `Ctrl+S` to send
- Responses stream in real time

### Examples

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

---

## Adding Context

### Current file

```vim
:EcaAddFile
```

### Specific file

```vim
:EcaAddFile src/main.lua
:EcaAddFile /full/path/to/file.js
```

### Code selection

1. Select code in visual mode (`v`, `V`, or `Ctrl+v`)
2. Run `:EcaAddSelection`
3. Selected code will be added as context

### Multiple files

```vim
:EcaAddFile src/utils.lua
:EcaAddFile src/config.lua
:EcaAddFile tests/test_utils.lua
```

---

## Common Use Cases

### Code analysis
```markdown
> Analyze this file and tell me if there are performance issues
```

### Debugging
```markdown
> This code is returning an error. Can you help me identify the problem?
[add the file as context first]
```

### Documentation
```markdown
> Generate JSDoc documentation for these functions
```

### Refactoring
```markdown
> How can I refactor this code to use ES6+ features?
```

### Testing
```markdown
> Create unit tests for this function
```

### Optimization
```markdown
> Suggest improvements to optimize this algorithm
```

---

## Recommended Workflow

1. Open the file you want to analyze
2. Add as context: `:EcaAddFile`
3. Open chat: `<leader>ec`
4. Ask your question:
   ```markdown
   > Explain what this function does and how I can improve it
   ```
5. Send with `Ctrl+S`
6. Read the response and implement suggestions
7. Continue the conversation for clarifications

---

## Advanced Commands

### Server management

```vim
" Restart if there are issues
:EcaServerRestart

" Stop temporarily
:EcaServerStop

" Start again
:EcaServerStart
```

### Quick commands

```vim
" Send message directly (without opening chat)
:EcaSend Explain this line of code

" Focus on chat if already open
:EcaFocus

" Toggle chat visibility
:EcaToggle
```

---

## Tips and Tricks

### Productivity
1. Use `:EcaAddFile` before asking about specific code
2. Combine contexts: add multiple related files
3. Be specific: detailed questions generate better responses
4. Use Markdown: ECA understands Markdown formatting

### Workflows

#### Code review
```markdown
> Analyze this code and suggest improvements:
- Performance
- Readability
- Best practices
- Possible bugs
```

#### Test creation
```markdown
> Create comprehensive unit tests for this function, including:
- Success cases
- Error cases
- Edge cases
- Mocks if necessary
```

#### Documentation
```markdown
> Generate complete documentation for this module:
- General description
- Parameters and types
- Usage examples
- Possible exceptions
```

### Custom shortcuts

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
