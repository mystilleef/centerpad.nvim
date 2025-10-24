-- Simple test runner that doesn't require external dependencies
-- Just uses Neovim's built-in assert functions

local tests_passed = 0
local tests_failed = 0
local current_suite = ""

-- Simple test framework
local function describe(name, fn)
  current_suite = name
  print("\n" .. string.rep("=", 60))
  print("Test Suite: " .. name)
  print(string.rep("=", 60))
  fn()
end

local function it(description, fn)
  local full_name = current_suite .. " > " .. description
  local status, err = pcall(fn)

  if status then
    tests_passed = tests_passed + 1
    print("  ✓ " .. description)
  else
    tests_failed = tests_failed + 1
    print("  ✗ " .. description)
    print("    Error: " .. tostring(err))
  end
end

local function before_each(fn)
  -- Store for later if needed
  _G._before_each = fn
end

local function after_each(fn)
  -- Store for later if needed
  _G._after_each = fn
end

-- Make functions global for test files
_G.describe = describe
_G.it = it
_G.before_each = before_each
_G.after_each = after_each

-- Simple assertion library
_G.assert = {
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

  are = {
    equal = function(expected, actual)
      if expected ~= actual then
        error(string.format("Expected %s, got %s", tostring(expected), tostring(actual)))
      end
    end,

    not_equal = function(expected, actual)
      if expected == actual then
        error(string.format("Expected values to be different, both are %s", tostring(expected)))
      end
    end,
  },

  has_key = function(tbl, key)
    if tbl[key] == nil then
      error(string.format("Table does not have key '%s'", key))
    end
  end,
}

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

print("\n" .. string.rep("=", 60))
print("Running Centerpad Test Suite")
print(string.rep("=", 60))

-- Load and run test files
local test_files = {
  "tests/centerpad/state_spec.lua",
  "tests/centerpad/window_spec.lua",
  "tests/centerpad/autocmds_spec.lua",
  "tests/centerpad/centerpad_spec.lua",
}

for _, test_file in ipairs(test_files) do
  local ok, err = pcall(dofile, test_file)
  if not ok then
    print("\n✗ Error loading " .. test_file .. ": " .. tostring(err))
    tests_failed = tests_failed + 1
  end
end

-- Print summary
print("\n" .. string.rep("=", 60))
print("Test Summary")
print(string.rep("=", 60))
print(string.format("Passed: %d", tests_passed))
print(string.format("Failed: %d", tests_failed))
print(string.rep("=", 60))

if tests_failed > 0 then
  print("\n❌ Some tests failed!")
  os.exit(1)
else
  print("\n✅ All tests passed!")
  os.exit(0)
end
