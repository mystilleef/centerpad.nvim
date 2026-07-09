describe("centerpad.enabled", function()
  local enabled
  local state

  before_each(function()
    package.loaded["centerpad.state"] = nil
    package.loaded["centerpad.enabled"] = nil
    state = require("centerpad.state")
    enabled = require("centerpad.enabled")
    state.reset()
    vim.g.centerpad_enabled = nil
    vim.g.center_buf_enabled = nil
  end)

  describe("get()", function()
    it("should return internal enabled state", function()
      state.pad_state.enabled = true
      assert.is_true(enabled.get())

      state.pad_state.enabled = false
      assert.is_false(enabled.get())
    end)
  end)

  describe("set()", function()
    it("should set internal state and both globals to true", function()
      enabled.set(true)

      assert.is_true(state.pad_state.enabled)
      assert.is_true(vim.g.centerpad_enabled)
      assert.is_true(vim.g.center_buf_enabled)
    end)

    it("should set internal state and both globals to false", function()
      enabled.set(false)

      assert.is_false(state.pad_state.enabled)
      assert.is_false(vim.g.centerpad_enabled)
      assert.is_false(vim.g.center_buf_enabled)
    end)
  end)

  describe("read_globals()", function()
    it("should prefer centerpad_enabled when set", function()
      vim.g.centerpad_enabled = true
      vim.g.center_buf_enabled = false

      local new, legacy = enabled.read_globals()

      assert.is_true(new)
      assert.is_false(legacy)
    end)

    it("should mirror legacy-only global to new global", function()
      vim.g.centerpad_enabled = nil
      vim.g.center_buf_enabled = true

      local new = enabled.read_globals()

      assert.is_true(new)
      assert.is_true(vim.g.centerpad_enabled)
    end)

    it("should emit one warning for legacy-only usage", function()
      vim.g.centerpad_enabled = nil
      vim.g.center_buf_enabled = true

      local warnings = {}
      local orig_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(warnings, { msg = msg, level = level })
      end

      enabled.read_globals()
      enabled.read_globals()

      vim.notify = orig_notify

      assert.are.equal(1, #warnings)
      assert.is_true(string.match(warnings[1].msg, "deprecated") ~= nil)
      assert.are.equal(vim.log.levels.WARN, warnings[1].level)
    end)

    it("should return nil new value when both globals are unset", function()
      vim.g.centerpad_enabled = nil
      vim.g.center_buf_enabled = nil

      local new, legacy = enabled.read_globals()

      assert.is_nil(new)
      assert.is_nil(legacy)
    end)

    it("should not mirror when centerpad_enabled is already false", function()
      vim.g.centerpad_enabled = false
      vim.g.center_buf_enabled = true

      local new = enabled.read_globals()

      assert.is_false(new)
    end)

    it("should mirror false legacy-only global", function()
      vim.g.centerpad_enabled = nil
      vim.g.center_buf_enabled = false

      local new = enabled.read_globals()

      assert.is_false(new)
      assert.is_false(vim.g.centerpad_enabled)
    end)
  end)
end)
