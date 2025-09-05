# Development and Contribution

## Support
- Issues: https://github.com/editor-code-assistant/eca-nvim/issues
- Discussions: https://github.com/editor-code-assistant/eca-nvim/discussions
- Wiki: https://github.com/editor-code-assistant/eca-nvim/wiki

## Local development

1. Clone the repository
   ```bash
   git clone https://github.com/editor-code-assistant/eca-nvim.git
   ```

2. Configure local path (optional)
   ```lua
   require("eca").setup({
     debug = true,
     -- server_path = "/path/to/eca-binary",
   })
   ```

3. Test changes
   ```vim
   :luafile %
   :EcaServerRestart
   ```

## Contributing

1. Fork the repository
2. Create a branch: `git checkout -b feature/new-functionality`
3. Commit your changes: `git commit -m 'Add new functionality'`
4. Push to your branch: `git push origin feature/new-functionality`
5. Open a Pull Request

## Testing

Run tests before submitting a PR:

```bash
# Unit tests
nvim --headless -c "lua require('eca.tests').run_all()"

# Manual test
nvim -c "lua require('eca').setup({debug=true})"
```
