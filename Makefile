# Makefile for ECA Neovim plugin testing

.PHONY: test test-file deps clean

# Download dependencies for testing
deps: deps/mini.nvim deps/nui.nvim

deps/mini.nvim:
	mkdir -p deps
	git clone --filter=blob:none https://github.com/echasnovski/mini.nvim deps/mini.nvim

deps/nui.nvim:
	mkdir -p deps
	git clone --filter=blob:none https://github.com/MunifTanjim/nui.nvim deps/nui.nvim

# Run all tests
test: deps
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run()"

# Run a specific test file
# Usage: make test-file FILE=tests/test_example.lua
test-file: deps
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run_file('$(FILE)')"

# Clean up dependencies
clean:
	rm -rf deps/