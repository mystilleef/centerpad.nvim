--# selene: allow(global_usage)
-- Simple test runner that doesn't require external dependencies
-- Just uses Neovim's built-in assert functions
--
-- Uses io.stdout:write instead of print to avoid headless UI event-loop
-- interactions that can segfault in some Neovim nightly builds when many
-- floating windows/autocmds are active.

local tests_passed = 0
local tests_failed = 0

local before_stack = {}
local after_stack = {}

local function write(...)
  io.write(...)
end

local function writeln(...)
  write(...)
  write("\n")
end

local function before_each(fn)
  before_stack[#before_stack] = fn
end

local function after_each(fn)
  after_stack[#after_stack] = fn
end

-- Simple test framework exposed globally for test files
_G.describe = function(name, fn)
  writeln("\n" .. string.rep("=", 60))
  writeln("Test Suite: " .. name)
  writeln(string.rep("=", 60))
  table.insert(before_stack, false)
  table.insert(after_stack, false)
  fn()
  table.remove(before_stack)
  table.remove(after_stack)
end

_G.it = function(description, fn)
  local status, err = pcall(function()
    for _, b in ipairs(before_stack) do
      if b then
        b()
      end
    end
    fn()
    for i = #after_stack, 1, -1 do
      local a = after_stack[i]
      if a then
        a()
      end
    end
  end)

  if status then
    tests_passed = tests_passed + 1
    writeln("  ✓ " .. description)
  else
    tests_failed = tests_failed + 1
    writeln("  ✗ " .. description)
    writeln("    Error: " .. tostring(err))
    writeln("    Traceback: " .. debug.traceback())
  end
end

_G.before_each = before_each
_G.after_each = after_each

-- Simple assertion library
_G.assert = setmetatable({
  is_true = function(val)
    if not val then
      error("Expected true, got " .. tostring(val))
    end
  end,

  is_false = function(val)
    if val then
      error("Expected false, got " .. tostring(val))
    end
  end,

  is_nil = function(val)
    if val ~= nil then
      error("Expected nil, got " .. tostring(val))
    end
  end,

  is_not_nil = function(val)
    if val == nil then
      error("Expected non-nil value")
    end
  end,

  is_table = function(val)
    if type(val) ~= "table" then
      error("Expected table, got " .. type(val))
    end
  end,

  are = {
    equal = function(expected, actual)
      if expected ~= actual then
        error(
          string.format(
            "Expected %s, got %s",
            tostring(expected),
            tostring(actual)
          )
        )
      end
    end,

    not_equal = function(expected, actual)
      if expected == actual then
        error(
          string.format(
            "Expected values to be different, both are %s",
            tostring(expected)
          )
        )
      end
    end,
  },

  are_not = {
    equal = function(expected, actual)
      if expected == actual then
        error(
          string.format(
            "Expected values to be different, both are %s",
            tostring(expected)
          )
        )
      end
    end,
  },

  has_key = function(tbl, key)
    if tbl[key] == nil then
      error(string.format("Table does not have key '%s'", key))
    end
  end,
}, {
  __call = function(_, cond, msg)
    if not cond then
      error(msg or "assertion failed")
    end
    return cond, msg
  end,
})

-- Helper for vim.tbl_contains
if not vim.tbl_contains then
  vim.tbl_contains = function(tbl, val)
    for _, v in ipairs(tbl) do
      if v == val then
        return true
      end
    end
    return false
  end
end

writeln("\n" .. string.rep("=", 60))
writeln("Running Centerpad Test Suite")
writeln(string.rep("=", 60))

-- Load and run test files
local test_files = {
  "tests/centerpad/state_spec.lua",
  "tests/centerpad/window_spec.lua",
  "tests/centerpad/autocmds_spec.lua",
  "tests/centerpad/centerpad_spec.lua",
  "tests/centerpad/enabled_spec.lua",
  "tests/centerpad/health_spec.lua",
  "tests/centerpad/smoke_report_spec.lua",
  "tests/centerpad/verify_completion_spec.lua",
}

for _, test_file in ipairs(test_files) do
  local ok, err = pcall(dofile, test_file)
  if not ok then
    writeln("\n✗ Error loading " .. test_file .. ": " .. tostring(err))
    tests_failed = tests_failed + 1
  end
end

-- Print summary
writeln("\n" .. string.rep("=", 60))
writeln("Test Summary")
writeln(string.rep("=", 60))
writeln(string.format("Passed: %d", tests_passed))
writeln(string.format("Failed: %d", tests_failed))
writeln(string.rep("=", 60))

if tests_failed > 0 then
  writeln("\n❌ Some tests failed!")
  os.exit(1)
else
  writeln("\n✅ All tests passed!")
  os.exit(0)
end
