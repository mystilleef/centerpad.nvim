describe("centerpad.state", function()
  local state

  before_each(function()
    -- Reload the module to get a fresh state
    package.loaded["centerpad.state"] = nil
    state = require("centerpad.state")
    state.reset()
  end)

  describe("initial state", function()
    it("should have nil window IDs", function()
      assert.is_nil(state.pad_state.main_win)
      assert.is_nil(state.pad_state.left_win)
      assert.is_nil(state.pad_state.right_win)
    end)

    it("should have enabled set to false", function()
      assert.is_false(state.pad_state.enabled)
    end)

    it("should have nil saved settings", function()
      assert.is_nil(state.saved_settings.fillchars)
      assert.is_nil(state.saved_settings.lazyredraw)
    end)

    it("should have nil restore timer", function()
      assert.is_nil(state.restore_timer)
    end)

    it("should have debug mode disabled", function()
      assert.is_false(state.debug)
    end)
  end)

  describe("reset()", function()
    it("should reset all state to initial values", function()
      -- Modify state
      state.pad_state.main_win = 1
      state.pad_state.left_win = 2
      state.pad_state.right_win = 3
      state.pad_state.enabled = true
      state.saved_settings.fillchars = "test"
      state.saved_settings.lazyredraw = true
      state.restore_timer = 123

      -- Reset
      state.reset()

      -- Verify reset
      assert.is_nil(state.pad_state.main_win)
      assert.is_nil(state.pad_state.left_win)
      assert.is_nil(state.pad_state.right_win)
      assert.is_false(state.pad_state.enabled)
      assert.is_nil(state.saved_settings.fillchars)
      assert.is_nil(state.saved_settings.lazyredraw)
      assert.is_nil(state.restore_timer)
    end)
  end)

  describe("pads_exist()", function()
    it("should return nil when no pads are set", function()
      assert.is_nil(state.pads_exist())
    end)

    it("should return nil when only left pad is set", function()
      -- Create a dummy window to get a valid ID
      local buf = vim.api.nvim_create_buf(false, true)
      local win = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      state.pad_state.left_win = win
      state.pad_state.right_win = nil

      assert.is_nil(state.pads_exist())

      -- Cleanup
      vim.api.nvim_win_close(win, true)
    end)

    it("should return nil when only right pad is set", function()
      local buf = vim.api.nvim_create_buf(false, true)
      local win = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      state.pad_state.left_win = nil
      state.pad_state.right_win = win

      assert.is_nil(state.pads_exist())

      -- Cleanup
      vim.api.nvim_win_close(win, true)
    end)

    it("should return true when both valid pads exist", function()
      local buf1 = vim.api.nvim_create_buf(false, true)
      local win1 = vim.api.nvim_open_win(buf1, false, {
        relative = "editor",
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })

      local buf2 = vim.api.nvim_create_buf(false, true)
      local win2 = vim.api.nvim_open_win(buf2, false, {
        relative = "editor",
        width = 10,
        height = 10,
        row = 0,
        col = 20,
      })

      state.pad_state.left_win = win1
      state.pad_state.right_win = win2

      assert.is_true(state.pads_exist())

      -- Cleanup
      vim.api.nvim_win_close(win1, true)
      vim.api.nvim_win_close(win2, true)
    end)

    it("should return false when window IDs are invalid", function()
      state.pad_state.left_win = 9999
      state.pad_state.right_win = 9998

      -- Invalid windows return false, not nil
      assert.is_false(state.pads_exist())
    end)
  end)

  describe("validate()", function()
    it("should return valid when state is clean", function()
      local valid, issues = state.validate()
      assert.is_true(valid)
      assert.are.equal(0, #issues)
    end)

    it("should detect missing right pad", function()
      local buf = vim.api.nvim_create_buf(false, true)
      local win = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      state.pad_state.left_win = win
      state.pad_state.right_win = nil

      local valid, issues = state.validate()
      assert.is_false(valid)
      assert.is_true(vim.tbl_contains(issues, "Right pad missing"))

      -- Cleanup
      vim.api.nvim_win_close(win, true)
    end)

    it("should detect missing left pad", function()
      local buf = vim.api.nvim_create_buf(false, true)
      local win = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      state.pad_state.left_win = nil
      state.pad_state.right_win = win

      local valid, issues = state.validate()
      assert.is_false(valid)
      assert.is_true(vim.tbl_contains(issues, "Left pad missing"))

      -- Cleanup
      vim.api.nvim_win_close(win, true)
    end)

    it("should detect invalid main window", function()
      state.pad_state.main_win = 9999 -- Invalid window ID

      local valid, issues = state.validate()
      assert.is_false(valid)
      assert.is_true(vim.tbl_contains(issues, "Main window invalid"))
    end)

    it("should detect enabled flag mismatch - enabled but no pads", function()
      state.pad_state.enabled = true
      state.pad_state.left_win = nil
      state.pad_state.right_win = nil

      local valid, issues = state.validate()
      assert.is_false(valid)
      assert.is_true(
        vim.tbl_contains(issues, "Enabled flag set but pads don't exist")
      )
    end)
  end)

  describe("logging", function()
    it("should not log when debug is disabled", function()
      state.debug = false
      -- These should not error but also not produce output
      state.log_error("test", "error message")
      state.log_info("test", "info message")
    end)

    it("should log when debug is enabled", function()
      state.debug = true
      -- These should produce notifications (we can't easily test the output)
      -- Just verify they don't error
      state.log_error("test", "error message")
      state.log_info("test", "info message")
    end)
  end)
end)
