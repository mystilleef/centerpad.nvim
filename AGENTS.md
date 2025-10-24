# Agent Guidelines for centerpad.nvim

## Build/Lint/Test Commands
- **Format**: `stylua .` (80 col width, 2 spaces, double quotes)
- **Lint**: `luacheck .` (allows vim globals)
- **Type check**: `selene .` (vim std library)
- No test suite currently exists

## Code Style
- **Language**: Pure Lua for Neovim plugin
- **Indentation**: 2 spaces (never tabs)
- **Line length**: 80 characters max
- **Quotes**: Always use double quotes for strings
- **Globals**: `vim` is the only allowed global
- **Imports**: Use `require()` for internal modules (e.g., `require("centerpad.centerpad")`)
- **Naming**: snake_case for functions/variables, PascalCase for module tables (M)
- **Module pattern**: Return table with public functions; use local for private functions
- **Options**: Use `vim.api.nvim_set_option_value()` with explicit scope
- **Error handling**: Check validity with `vim.api.nvim_win_is_valid()` before operations
- **Autocmds**: Always specify group and use callbacks instead of command strings
- **Comments**: Minimal; only for complex logic or non-obvious behavior

## Architecture
- Entry point: `lua/centerpad/init.lua` (setup/config)
- Core logic: `lua/centerpad/centerpad.lua` (window/buffer management)
- Plugin command: `plugin/centerpad.lua` registers `:Centerpad` command
