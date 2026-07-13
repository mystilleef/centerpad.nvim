# Centerpad Tests

This directory contains the test suite for centerpad.nvim using the
busted testing framework.

## Test Structure

```
tests/
├── minimal_init.lua           # Minimal Neovim config for testing
├── run_all.lua                # Simple test file loader
├── simple_runner.lua          # Alternative runner
├── smoke_report.lua           # Smoke report generation
├── terminal_smoke.lua         # Terminal smoke tests
├── verify_completion.lua      # Completion verification
├── verify_smoke_report.lua    # Smoke report verification
├── README.md                  # This file
└── centerpad/
    ├── state_spec.lua           # State management and tab isolation
    ├── window_spec.lua          # Window creation, fillchars, cleanup
    ├── autocmds_spec.lua        # Autocmd lifecycle and callbacks
    ├── centerpad_spec.lua       # Coordinator guards and commands
    ├── enabled_spec.lua         # Global mirror and legacy bridge
    ├── fillchars_spec.lua       # Window-local fillchars isolation
    ├── health_spec.lua          # Health check and debug reporting
    ├── integration_spec.lua     # Cross-tab isolation and stress
    ├── buffer_tracker_spec.lua  # Context suspend/resume behavior
    ├── smoke_report_spec.lua    # Smoke report helpers
    └── verify_completion_spec.lua  # Completion verification helpers
```

## Running Tests

### Using Busted (Recommended)

If you have `busted` and `nlua` installed:

```bash
# Install dependencies
luarocks install busted
luarocks install nlua

# Run all tests
make test

# Or directly
busted tests/
```

### Using Plenary (Alternative)

If you have plenary.nvim installed:

```bash
nvim --headless -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }" -c "qa!"
```

## Test Coverage

### state_spec.lua (State Management)

- ✓ Initial state verification
- ✓ State reset functionality
- ✓ `pads_exist()` logic with various scenarios
- ✓ State validation with issue detection
- ✓ Debug logging functionality
- ✓ Tab-scoped state proxy
- ✓ Invalid tab pruning

### window_spec.lua (Window Manipulation)

- ✓ Buffer identification (`is_pad_buffer()`)
- ✓ Window focus management
- ✓ Pad window creation with correct properties
- ✓ Buffer/window option verification
- ✓ Pad deletion (O(1) using tracked IDs)
- ✓ Window-local fillchars

### autocmds_spec.lua (Autocmd Management)

- ✓ Autocmd group existence
- ✓ Focus prevention autocmd setup
- ✓ Restore autocmd with debouncing
- ✓ Autocmd cleanup
- ✓ Full cleanup (autocmds + pads + settings)
- ✓ Coordinator callback injection
- ✓ Timer stop ordering

### centerpad_spec.lua (Main Coordinator)

- ✓ `should_enable()` with various buffer types
- ✓ Enable/disable functionality
- ✓ Toggle behavior
- ✓ `run()` command with argument parsing
- ✓ Input validation (bounds checking, non-numeric)
- ✓ Debug mode management
- ✓ State inspection (`get_state()`)
- ✓ State validation

### enabled_spec.lua (Enabled State)

- ✓ Global mirror contract
- ✓ Legacy bridge behavior
- ✓ Per-tab truth from Centerpad state

### fillchars_spec.lua (Fillchars)

- ✓ Window-local fillchars isolation
- ✓ Global fillchars unchanged
- ✓ Cleanup behavior

### health_spec.lua (Health Checks)

- ✓ Current-tab reporting
- ✓ Debug state inspection

### integration_spec.lua (Integration)

- ✓ Independent tab widths
- ✓ Cross-tab pad validity
- ✓ Tab-close pruning
- ✓ Suspend/resume behavior
- ✓ Stress stability

### buffer_tracker_spec.lua (Context Tracker)

- ✓ Suspend on ignored contexts
- ✓ Resume on normal contexts
- ✓ Debounce behavior

### smoke_report_spec.lua (Smoke Reports)

- ✓ Report generation helpers

### verify_completion_spec.lua (Completion)

- ✓ Completion verification helpers

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

Make sure you're running in a headless Neovim instance with proper
initialization.

### Module not found errors

Ensure the plugin directory is in the runtimepath. The
`minimal_init.lua` should handle this automatically.
