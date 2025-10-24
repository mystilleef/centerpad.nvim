# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

centerpad.nvim is a Neovim plugin that centers the main buffer by adding padding buffers on the left and right sides. Written entirely in Lua, it's designed for lazy.nvim compatibility. The padding buffers are empty, non-modifiable, and non-focusable.

## Development Commands

### Linting and Formatting

```bash
# Run luacheck (static analysis)
luacheck .

# Run selene (Lua linter with Neovim/Vim support)
selene .

# Format code with stylua (2 spaces, 80 column width, double quotes)
stylua .

# Check formatting without modifying
stylua --check .
```

### Testing

```bash
# Run all tests with busted (recommended)
busted tests/

# Or use make targets
make test          # Run all tests
make lint          # Run linters
make format        # Format code
make check         # Check formatting
make ci            # Run all checks (lint + format + test)

# Run simple module test
nvim --headless -u NONE -c "set rtp+=." -c "luafile test_refactoring.lua" -c "quit"
```

**Test Coverage:**
- `state_spec.lua` - State management and validation
- `window_spec.lua` - Window/buffer operations
- `autocmds_spec.lua` - Autocmd setup and cleanup
- `centerpad_spec.lua` - Main coordinator logic

See `tests/README.md` for detailed testing documentation.

**Code Style Requirements:**
- 2-space indentation
- 80-column width
- Double quotes for strings
- Standard Vim globals are allowed

## Architecture

### Module Structure (Modular Architecture)

The plugin uses a **modular architecture** with clear separation of concerns:

1. **plugin/centerpad.lua** - Command registration
   - Registers the `:Centerpad` user command
   - Entry point when Neovim loads the plugin

2. **lua/centerpad/init.lua** - Public API layer
   - Exposes: `setup()`, `enable()`, `disable()`, `toggle()`, `run()`, `set_debug()`, `get_state()`
   - Manages plugin configuration with deep merge
   - Default config: `leftpad=25`, `rightpad=25`, `enable_by_default=false`
   - Configuration includes `ignore_filetypes` and `ignore_buftypes` lists

3. **lua/centerpad/centerpad.lua** - Main coordinator
   - Orchestrates state, window, and autocmd modules
   - Implements business logic (enable, disable, toggle, run)
   - Input validation (1-500 column bounds)
   - Automatic state validation and recovery

4. **lua/centerpad/state.lua** - State management module
   - Centralizes all mutable state in one place
   - Tracks: `pad_state` (window IDs, enabled flag), `saved_settings`, `restore_timer`
   - Provides: `validate()`, `pads_exist()`, `reset()`, `log_error()`, `log_info()`
   - Debug mode flag

5. **lua/centerpad/window.lua** - Window manipulation module
   - Pure functions for window/buffer operations
   - Functions: `create_pad_window()`, `delete_pads()`, `is_pad_buffer()`
   - Settings management: `save_global_settings()`, `restore_global_settings()`
   - Efficient O(1) deletion using tracked window IDs

6. **lua/centerpad/autocmds.lua** - Autocmd management module
   - Manages autocmd group "padgroup"
   - Functions: `setup_prevent_focus_autocmd()`, `setup_restore_pads_autocmd()`
   - Cleanup: `clear_autocmds()`, `cleanup()`
   - 50ms debouncing on WinClosed events

7. **lua/centerpad/health.lua** - Health check module
   - Accessible via `:checkhealth centerpad`
   - Validates: Neovim version, module loading, state consistency
   - Diagnostic information for debugging

### Key Implementation Details

**Buffer Identification:**
- Uses buffer variables (`is_centerpad`, `pad_side`) instead of string matching
- Prevents false positives from user files with similar names
- Robust and safe buffer detection

**Window Management:**
- Tracks window IDs explicitly in `state.pad_state`
- Direct window navigation using `nvim_set_current_win()` with fallback to `wincmd`
- O(1) pad deletion using tracked IDs instead of O(n) iteration

**Error Handling:**
- Comprehensive `pcall()` wrapping on all Neovim API calls
- Debug logging available via `set_debug(true)`
- Graceful degradation on failures
- Automatic state validation with recovery

**Settings Preservation:**
- Saves original `fillchars` and `lazyredraw` before modification
- Restores settings on disable/cleanup
- Prevents permanent corruption of user settings

**Performance:**
- 50ms debouncing on WinClosed autocmd prevents excessive re-rendering
- Lazy evaluation and scheduled validation
- Efficient buffer/window operations

**API Modernization:**
- Uses `nvim_set_option_value()` and `nvim_get_option_value()` (not deprecated APIs)
- Future-proof for Neovim 0.10+

### State Management

**State Tracking (`state.pad_state`):**
```lua
{
  main_win = nil,      -- ID of main window
  left_win = nil,      -- ID of left pad window
  right_win = nil,     -- ID of right pad window
  enabled = false,     -- Whether centerpad is active
}
```

**Validation:**
- Checks for orphaned pads (only left or only right)
- Verifies main window validity
- Ensures enabled flag matches actual state
- Returns list of issues for diagnostics

### Command Interface

- `:Centerpad` - Toggle on/off
- `:Centerpad <width>` - Set both pads to width (1-500)
- `:Centerpad <left> <right>` - Set different widths
- `:checkhealth centerpad` - Run health checks
- `:lua require('centerpad').set_debug(true)` - Enable debug logging
- `:lua vim.print(require('centerpad').get_state())` - Inspect state

## Installation and Testing

### Manual Testing

1. Install locally in your Neovim config:
```lua
{
  dir = "/path/to/centerpad.nvim",
  main = "centerpad",
  opts = { enable_by_default = false, leftpad = 25, rightpad = 25 },
}
```

2. Reload Neovim and test with `:Centerpad`

3. Run health checks: `:checkhealth centerpad`

4. Enable debug mode for verbose logging:
```lua
:lua require('centerpad').set_debug(true)
```

### Automated Testing

Run the test script:
```bash
nvim --headless -u NONE -c "set rtp+=." -c "luafile test_refactoring.lua" -c "quit"
```

### Verification Checklist

- [ ] Pads cannot be focused (cursor redirects to main window)
- [ ] Pads cannot be modified
- [ ] Closing main buffer restores pads (if not ignored filetype)
- [ ] Ignored filetypes/buftypes don't activate centerpad
- [ ] Invalid width inputs show error messages
- [ ] Settings are restored on disable
- [ ] State validation detects issues
- [ ] Health check provides diagnostic info

## Development Guidelines

**When modifying code:**
1. Maintain separation of concerns (keep modules focused)
2. Add error handling with `pcall()` for API calls
3. Use `state.log_error()` and `state.log_info()` for debug logging
4. Update state validation in `state.lua` if adding new state
5. Run linters before committing
6. Test with `:checkhealth centerpad`

**Module Dependencies:**
- `state.lua` - No dependencies (leaf module)
- `window.lua` - Depends on `state`
- `autocmds.lua` - Depends on `state`, `window`
- `centerpad.lua` - Depends on `state`, `window`, `autocmds`
- `init.lua` - Depends on `centerpad`
- `health.lua` - Depends on `state`, `centerpad`
