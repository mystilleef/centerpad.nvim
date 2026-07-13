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

    it("should mirror the current operation to both globals", function()
      enabled.set(true)
      assert.is_true(vim.g.centerpad_enabled)
      assert.is_true(vim.g.center_buf_enabled)

      enabled.set(false)
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

    it(
      "should not change internal state when mirroring legacy-only global",
      function()
        state.pad_state.enabled = false
        vim.g.centerpad_enabled = nil
        vim.g.center_buf_enabled = true

        enabled.read_globals()

        assert.is_false(state.pad_state.enabled)
        assert.is_true(vim.g.centerpad_enabled)
      end
    )
  end)

  describe("global contract", function()
    it("should treat internal state as the durable source of truth", function()
      state.pad_state.enabled = true
      enabled.set(true)

      vim.g.centerpad_enabled = false
      vim.g.center_buf_enabled = false

      assert.is_true(enabled.get())
    end)

    it("should not infer durable state from globals alone", function()
      state.pad_state.enabled = false
      vim.g.centerpad_enabled = true
      vim.g.center_buf_enabled = true

      assert.is_false(enabled.get())
    end)

    it("should keep globals synchronized with set operations", function()
      state.pad_state.enabled = false
      vim.g.centerpad_enabled = true
      vim.g.center_buf_enabled = true

      enabled.set(false)

      assert.is_false(vim.g.centerpad_enabled)
      assert.is_false(vim.g.center_buf_enabled)
    end)
  end)

  describe("_reset_warning()", function()
    it("should reset the legacy warning flag", function()
      local warnings = {}
      local orig_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(warnings, { msg = msg, level = level })
      end

      -- Cycle 1: trigger warning
      vim.g.centerpad_enabled = nil
      vim.g.center_buf_enabled = true
      enabled.read_globals()
      assert.are.equal(1, #warnings)

      -- First call set centerpad_enabled to legacy value.  Reset
      -- both the warning flag AND the global to trigger it again.
      enabled._reset_warning()
      vim.g.centerpad_enabled = nil
      vim.g.center_buf_enabled = true

      -- Should warn again
      enabled.read_globals()
      assert.are.equal(2, #warnings)

      vim.notify = orig_notify
    end)

    it("should not warn when new global is already set", function()
      -- After reset, the new global (centerpad_enabled) is already
      -- populated, so the condition new == nil is false.
      local warnings = {}
      local orig_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(warnings, { msg = msg, level = level })
      end

      vim.g.centerpad_enabled = nil
      vim.g.center_buf_enabled = true
      enabled.read_globals() -- warns, mirrors legacy→new
      assert.are.equal(1, #warnings)

      enabled._reset_warning()
      -- new global is already set; condition new == nil is false
      enabled.read_globals()
      assert.are.equal(1, #warnings)

      vim.notify = orig_notify
    end)

    it(
      "should be callable without side effects when no warning occurred",
      function()
        -- Should not error
        enabled._reset_warning()
        enabled._reset_warning()
      end
    )
  end)

  describe("cross-tab enabled bridge", function()
    it("set(true) on tab1 then set(false) on tab2 clears globals", function()
      -- Simulate tab 1 enabled
      state.pad_state.enabled = true
      enabled.set(true)
      assert.is_true(vim.g.centerpad_enabled)
      assert.is_true(vim.g.center_buf_enabled)

      -- Simulate tab 2 disable (current tab context)
      state.pad_state.enabled = false
      enabled.set(false)

      -- Globals should be false
      assert.is_false(vim.g.centerpad_enabled)
      assert.is_false(vim.g.center_buf_enabled)
    end)

    it("internal state is per-operation, not per-tab", function()
      -- Enabled module reads from state.pad_state.enabled
      -- which is the current-tab proxy. Verify get/set consistency.
      state.pad_state.enabled = true
      assert.is_true(enabled.get())

      state.pad_state.enabled = false
      assert.is_false(enabled.get())

      enabled.set(true)
      assert.is_true(state.pad_state.enabled)
      assert.is_true(vim.g.centerpad_enabled)

      enabled.set(false)
      assert.is_false(state.pad_state.enabled)
      assert.is_false(vim.g.centerpad_enabled)
    end)
  end)
end)
