# Agent

## Rules

- After edits: run `make check`.
- After task completion: run `make test`.
- Address all issues from lints and tests.

## Build/Lint/Test Commands

- **Format**: `stylua .` (80 col width, 2 spaces, double quotes)
- **Lint**: `luacheck .` (allows vim _globals_)
- **Type check**: `selene .` (vim std library)
- No test suite currently exists

## Code style

- **Language**: Pure `Lua` for Neovim plugin
- **Indentation**: 2 spaces (never tabs)
- **Line length**: 80 characters max
- **Quotes**: Always use double quotes for strings
- **Globals**: `vim`—only allowed global
- **Imports**: Use `require()` for internal modules (for example,
  `require("centerpad.centerpad")`)
- **Naming**: snake_case for functions/variables, PascalCase for module
  tables (M)
- **Module pattern**: Return table with public functions; use local for
  private functions
- **Options**: Use _`vim.api.nvim_set_option_value()`_ with explicit
  scope
- **Error handling**: Check validity with
  _`vim.api.nvim_win_is_valid()`_ before operations
- **Autocmds**: Always specify group and use callbacks instead of
  command strings
- **Comments**: Minimal; only for complex logic or complicated behavior

## Architecture

- Entry point: `lua/centerpad/init.lua` (setup/config)
- Core logic: `lua/centerpad/centerpad.lua` (window/buffer management)
- Plugin command: `plugin/centerpad.lua` registers `:Centerpad` command
