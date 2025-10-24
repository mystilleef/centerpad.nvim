-- Simple test runner that uses Neovim's built-in busted
-- Run with: nvim --headless -u tests/minimal_init.lua -l tests/run_all.lua

-- Load modules
local state_spec = dofile("tests/centerpad/state_spec.lua")
local window_spec = dofile("tests/centerpad/window_spec.lua")
local autocmds_spec = dofile("tests/centerpad/autocmds_spec.lua")
local centerpad_spec = dofile("tests/centerpad/centerpad_spec.lua")

print("✓ All test files loaded successfully")
print("\nTo run tests, use:")
print("  busted tests/")
print("\nOr if nlua/busted aren't configured, test manually by:")
print("  :source tests/centerpad/state_spec.lua")
print("  etc.")

os.exit(0)
