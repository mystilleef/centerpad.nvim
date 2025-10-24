# Centerpad Tests

This directory contains the test suite for centerpad.nvim using the busted testing framework.

## Test Structure

```
tests/
├── minimal_init.lua          # Minimal Neovim config for testing
├── run_all.lua              # Simple test file loader
├── README.md                # This file
└── centerpad/
    ├── state_spec.lua       # Tests for state module
    ├── window_spec.lua      # Tests for window module
    ├── autocmds_spec.lua    # Tests for autocmds module
    └── centerpad_spec.lua   # Tests for main coordinator
```

## Running Tests

### Option 1: Using Busted (Recommended)

If you have `busted` and `nlua` installed:

```bash
# Install dependencies
luarocks install busted
luarocks install nlua

# Run all tests
busted tests/

# Or use make
make test
```

### Option 2: Using Plenary (Alternative)

If you have plenary.nvim installed:

```bash
nvim --headless -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }" -c "qa!"
```

### Option 3: Manual Testing in Neovim

You can also source test files directly in Neovim:

```vim
:source tests/centerpad/state_spec.lua
:source tests/centerpad/window_spec.lua
" etc.
```

## Test Coverage

### state_spec.lua (State Management)
- ✓ Initial state verification
- ✓ State reset functionality
- ✓ `pads_exist()` logic with various scenarios
- ✓ State validation with issue detection
- ✓ Debug logging functionality

### window_spec.lua (Window Manipulation)
- ✓ Buffer identification (`is_pad_buffer()`)
- ✓ Window focus management
- ✓ Pad window creation with correct properties
- ✓ Buffer/window option verification
- ✓ Pad deletion (O(1) using tracked IDs)
- ✓ Global settings save/restore

### autocmds_spec.lua (Autocmd Management)
- ✓ Autocmd group existence
- ✓ Focus prevention autocmd setup
- ✓ Restore autocmd with debouncing
- ✓ Autocmd cleanup
- ✓ Full cleanup (autocmds + pads + settings)

### centerpad_spec.lua (Main Coordinator)
- ✓ `should_enable()` with various buffer types
- ✓ Enable/disable functionality
- ✓ Toggle behavior
- ✓ `run()` command with argument parsing
- ✓ Input validation (bounds checking, non-numeric)
- ✓ Debug mode management
- ✓ State inspection (`get_state()`)
- ✓ State validation

## Writing New Tests

Follow busted's BDD-style syntax:

```lua
describe("module_name", function()
  before_each(function()
    -- Setup before each test
  end)

  after_each(function()
    -- Cleanup after each test
  end)

  describe("feature_name", function()
    it("should do something", function()
      assert.is_true(condition)
      assert.are.equal(expected, actual)
    end)
  end)
end)
```

## Continuous Integration

Use the Makefile targets for CI:

```bash
make ci  # Runs lint, format check, and tests
```

## Troubleshooting

### "nlua not found"
Install nlua: `luarocks install nlua`

### "busted not found"
Install busted: `luarocks install busted`

### Tests fail due to window/buffer issues
Make sure you're running in a headless Neovim instance with proper initialization.

### Module not found errors
Ensure the plugin directory is in the runtimepath. The `minimal_init.lua` should handle this automatically.
