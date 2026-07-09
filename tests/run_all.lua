-- Test runner that runs all specs via the built-in simple runner.
-- Run with: nvim --headless -u tests/minimal_init.lua -l tests/run_all.lua

-- The simple runner provides describe/it/assert and executes each spec file.
dofile("tests/simple_runner.lua")
