describe("centerpad.state", function()
  local state
  local test_helper = require("test_helper")

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

    it("should have nil restore timer", function()
      assert.is_nil(state.get_restore_timer())
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
      state.set_restore_timer(123)

      -- Reset
      state.reset()

      -- Verify reset
      assert.is_nil(state.pad_state.main_win)
      assert.is_nil(state.pad_state.left_win)
      assert.is_nil(state.pad_state.right_win)
      assert.is_false(state.pad_state.enabled)
      assert.is_nil(state.get_restore_timer())
    end)

    it("should preserve sibling tab stores", function()
      state.pad_state.main_win = 10
      state.pad_state.enabled = true

      -- Create a second tab and reset there
      vim.cmd("tabnew")
      state.reset()

      -- Switch back to first tab
      vim.cmd("tabprevious")
      assert.are.equal(10, state.pad_state.main_win)
      assert.is_true(state.pad_state.enabled)

      -- Clean up extra tab
      vim.cmd("silent! tabonly")
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
      assert.are.equal(1, #issues)
      assert.are.equal("Right pad missing", issues[1])

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
      assert.are.equal(1, #issues)
      assert.are.equal("Left pad missing", issues[1])

      -- Cleanup
      vim.api.nvim_win_close(win, true)
    end)

    it("should detect invalid main window", function()
      state.pad_state.main_win = 9999 -- Invalid window ID

      local valid, issues = state.validate()
      assert.is_false(valid)
      assert.are.equal(1, #issues)
      assert.are.equal("Main window invalid", issues[1])
    end)

    it("should detect enabled flag mismatch - enabled but no pads", function()
      state.pad_state.enabled = true
      state.pad_state.left_win = nil
      state.pad_state.right_win = nil

      local valid, issues = state.validate()
      assert.is_false(valid)
      assert.are.equal(1, #issues)
      assert.are.equal("Enabled flag set but pads don't exist", issues[1])
    end)

    it(
      "should detect enabled flag mismatch - pads exist but not enabled",
      function()
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
        state.pad_state.enabled = false

        local valid, issues = state.validate()
        assert.is_false(valid)
        assert.are.equal(1, #issues)
        assert.are.equal("Pads exist but enabled flag not set", issues[1])

        -- Cleanup
        vim.api.nvim_win_close(win1, true)
        vim.api.nvim_win_close(win2, true)
      end
    )

    it("should detect multiple issues at once", function()
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
      state.pad_state.main_win = 9999

      local valid, issues = state.validate()
      assert.is_false(valid)
      assert.are.equal(2, #issues)
      assert.is_true(vim.tbl_contains(issues, "Right pad missing"))
      assert.is_true(vim.tbl_contains(issues, "Main window invalid"))

      -- Cleanup
      vim.api.nvim_win_close(win, true)
    end)

    it(
      "should return valid when both pads exist and enabled is true",
      function()
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
        state.pad_state.enabled = true

        local valid, issues = state.validate()
        assert.is_true(valid)
        assert.are.equal(0, #issues)

        -- Cleanup
        vim.api.nvim_win_close(win1, true)
        vim.api.nvim_win_close(win2, true)
      end
    )
  end)

  describe("tabpage-scoped proxy", function()
    it("should scope reads/writes to the current tabpage", function()
      state.pad_state.main_win = 42
      state.pad_state.enabled = true

      -- Create second tab and verify isolation
      vim.cmd("tabnew")
      assert.is_nil(state.pad_state.main_win)
      assert.is_false(state.pad_state.enabled)

      -- Set different values in tab 2
      state.pad_state.main_win = 99
      state.pad_state.enabled = true

      -- Return to tab 1 and verify original values preserved
      vim.cmd("tabprevious")
      assert.are.equal(42, state.pad_state.main_win)
      assert.is_true(state.pad_state.enabled)

      vim.cmd("silent! tabonly")
    end)

    it("should initialize default values for new tabpages", function()
      vim.cmd("tabnew")

      assert.is_nil(state.pad_state.main_win)
      assert.is_nil(state.pad_state.left_win)
      assert.is_nil(state.pad_state.right_win)
      assert.is_false(state.pad_state.enabled)

      vim.cmd("silent! tabonly")
    end)

    it("should prune closed tabpage stores on access", function()
      state.pad_state.main_win = 1

      vim.cmd("tabnew")
      state.pad_state.main_win = 2
      assert.are.equal(2, state._tab_store_count())

      -- Close the new tab (tab 2) while we are on it
      local ok, err = pcall(vim.cmd, "tabclose")
      assert.is_true(ok, "tabclose failed: " .. tostring(err))

      -- Access triggers pruning; only original tab store should remain
      assert.are.equal(1, state.pad_state.main_win)
      assert.are.equal(1, state._tab_store_count())
    end)

    it(
      "should not error on nil window IDs, absent stores, and reset()",
      function()
        -- nil window IDs in a fresh tab
        vim.cmd("tabnew")
        assert.is_nil(state.pad_state.left_win)
        assert.is_nil(state.pad_state.right_win)
        assert.is_nil(state.pad_state.main_win)

        -- reset() in a tab without prior store
        state.reset()
        assert.is_nil(state.pad_state.main_win)

        vim.cmd("silent! tabonly")
      end
    )
  end)

  describe("per-tab config snapshot", function()
    it("should have nil config snapshot fields initially", function()
      assert.is_nil(state.config_snapshot.leftpad)
      assert.is_nil(state.config_snapshot.rightpad)
      assert.is_nil(state.config_snapshot.ignore_filetypes)
      assert.is_nil(state.config_snapshot.ignore_buftypes)
    end)

    it("should scope config snapshot to current tabpage", function()
      state.config_snapshot.leftpad = 12
      state.config_snapshot.rightpad = 13

      vim.cmd("tabnew")
      assert.is_nil(state.config_snapshot.leftpad)
      assert.is_nil(state.config_snapshot.rightpad)

      state.config_snapshot.leftpad = 31
      state.config_snapshot.rightpad = 32

      vim.cmd("tabprevious")
      assert.are.equal(12, state.config_snapshot.leftpad)
      assert.are.equal(13, state.config_snapshot.rightpad)

      vim.cmd("silent! tabonly")
    end)
  end)

  describe("per-tab restore timer", function()
    it("should have nil restore timer initially", function()
      assert.is_nil(state.get_restore_timer())
    end)

    it("should scope restore timer to current tabpage", function()
      state.set_restore_timer(111)

      vim.cmd("tabnew")
      assert.is_nil(state.get_restore_timer())

      state.set_restore_timer(222)

      vim.cmd("tabprevious")
      assert.are.equal(111, state.get_restore_timer())

      vim.cmd("silent! tabonly")
    end)

    it("should reset restore timer on tab reset", function()
      state.set_restore_timer(999)
      state.reset()
      assert.is_nil(state.get_restore_timer())
    end)
  end)

  describe("per-tab tracker state", function()
    it("should have nil debounce_timer initially", function()
      assert.is_nil(state.tracker.debounce_timer)
    end)

    it("should scope tracker debounce_timer to current tabpage", function()
      state.tracker.debounce_timer = 42

      vim.cmd("tabnew")
      assert.is_nil(state.tracker.debounce_timer)

      state.tracker.debounce_timer = 99

      vim.cmd("tabprevious")
      assert.are.equal(42, state.tracker.debounce_timer)

      vim.cmd("silent! tabonly")
    end)
  end)

  describe("_tab_store_keys()", function()
    it("should return empty table when no stores exist", function()
      local keys = state._tab_store_keys()
      assert.are.equal(0, #keys)
    end)

    it("should return stored tab handles", function()
      state.pad_state.main_win = 1
      local keys = state._tab_store_keys()
      assert.are.equal(1, #keys)
    end)

    it("should include handles from multiple tabs", function()
      state.pad_state.main_win = 1
      vim.cmd("tabnew")
      state.pad_state.main_win = 2
      -- Should have two stores now
      assert.are.equal(2, state._tab_store_count())
      local keys = state._tab_store_keys()
      assert.are.equal(2, #keys)
      vim.cmd("silent! tabonly")
    end)
  end)

  describe("_has_store()", function()
    it("should return false for tab without a store", function()
      vim.cmd("tabnew")
      local new_tab = vim.api.nvim_get_current_tabpage()
      vim.cmd("tabprevious")
      -- new_tab was never accessed via proxy, so it has no store
      assert.is_false(state._has_store(new_tab))
      vim.cmd("silent! tabonly")
    end)

    it("should return true for tab with a store", function()
      local tab = vim.api.nvim_get_current_tabpage()
      state.pad_state.main_win = 42
      assert.is_true(state._has_store(tab))
    end)
  end)

  describe("_get_pad_state()", function()
    it("should return nil for tab without a store", function()
      vim.cmd("tabnew")
      local new_tab = vim.api.nvim_get_current_tabpage()
      vim.cmd("tabprevious")
      assert.is_nil(state._get_pad_state(new_tab))
      vim.cmd("silent! tabonly")
    end)

    it("should return snapshot of tab's pad_state", function()
      state.pad_state.left_win = 10
      state.pad_state.right_win = 20
      state.pad_state.main_win = 30
      state.pad_state.enabled = true

      local tab = vim.api.nvim_get_current_tabpage()
      local snap = state._get_pad_state(tab)

      assert.are.equal(10, snap.left_win)
      assert.are.equal(20, snap.right_win)
      assert.are.equal(30, snap.main_win)
      assert.is_true(snap.enabled)
    end)

    it("should return snapshot from different tab than current", function()
      state.pad_state.enabled = true
      local tab1 = vim.api.nvim_get_current_tabpage()

      vim.cmd("tabnew")
      state.pad_state.enabled = false

      -- From tab2, read tab1's state
      local snap = state._get_pad_state(tab1)
      assert.is_true(snap.enabled)

      vim.cmd("silent! tabonly")
    end)
  end)

  describe("tracker state fields", function()
    it("should default tracker fields to false/nil", function()
      assert.is_false(state.tracker.opted_in)
      assert.is_nil(state.tracker.config)
      assert.is_false(state.tracker.suspended)
      assert.is_nil(state.tracker.debounce_timer)
    end)

    it("should scope tracker fields per tab", function()
      state.tracker.opted_in = true
      state.tracker.config = { leftpad = 10 }
      state.tracker.suspended = true

      vim.cmd("tabnew")
      assert.is_false(state.tracker.opted_in)
      assert.is_nil(state.tracker.config)
      assert.is_false(state.tracker.suspended)

      vim.cmd("tabprevious")
      assert.is_true(state.tracker.opted_in)
      assert.are.equal(10, state.tracker.config.leftpad)
      assert.is_true(state.tracker.suspended)

      vim.cmd("silent! tabonly")
    end)

    it("should survive reset()", function()
      state.tracker.opted_in = true
      state.tracker.debounce_timer = 99

      state.reset()

      assert.is_false(state.tracker.opted_in)
      assert.is_nil(state.tracker.debounce_timer)
    end)
  end)

  describe("direct tab-scoped accessors with unknown tabs", function()
    it("_clear_pad_state returns early for tab without store", function()
      vim.cmd("tabnew")
      local unknown = vim.api.nvim_get_current_tabpage()
      vim.cmd("tabprevious")
      -- Must not error and leave sibling stores unharmed.
      state._clear_pad_state(unknown)
      assert.is_nil(state._get_pad_state(unknown))
      vim.cmd("silent! tabonly")
    end)

    it("_tracker_store returns nil for tab without store", function()
      vim.cmd("tabnew")
      local unknown = vim.api.nvim_get_current_tabpage()
      vim.cmd("tabprevious")
      assert.is_nil(state._tracker_store(unknown))
      vim.cmd("silent! tabonly")
    end)

    it("_tracker_store returns live tracker for tab with store", function()
      state.tracker.opted_in = true
      state.tracker.suspended = true
      local tab = vim.api.nvim_get_current_tabpage()
      local t = state._tracker_store(tab)
      assert.is_not_nil(t)
      assert.is_true(t.opted_in)
      assert.is_true(t.suspended)
    end)

    it("_set_restore_timer no-ops for tab without store", function()
      vim.cmd("tabnew")
      local unknown = vim.api.nvim_get_current_tabpage()
      vim.cmd("tabprevious")
      -- Calling _set_restore_timer on unknown tab must not error.
      local ok = pcall(state._set_restore_timer, unknown, 555)
      assert.is_true(ok)
      vim.cmd("silent! tabonly")
    end)

    it("_set_restore_timer persists for tab with store", function()
      local tab = vim.api.nvim_get_current_tabpage()
      state.pad_state.main_win = 1
      state._set_restore_timer(tab, 777)
      assert.are.equal(777, state._restore_timer(tab))
    end)

    it("_source_options returns nil for tab without store", function()
      vim.cmd("tabnew")
      local unknown = vim.api.nvim_get_current_tabpage()
      vim.cmd("tabprevious")
      assert.is_nil(state._source_options(unknown))
      vim.cmd("silent! tabonly")
    end)

    it("_source_options returns live options for tab with store", function()
      local buf = vim.api.nvim_create_buf(false, true)
      local win = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      state.source_options.win = win
      state.source_options.fillchars = "fold: "
      local tab = vim.api.nvim_get_current_tabpage()
      local opts = state._source_options(tab)
      assert.is_not_nil(opts)
      assert.are.equal(win, opts.win)
      assert.are.equal("fold: ", opts.fillchars)
      vim.api.nvim_win_close(win, true)
    end)
  end)

  describe("logging", function()
    before_each(function()
      test_helper.notify_spy:clear()
    end)

    it("should not log when debug is disabled", function()
      state.debug = false
      state.log_error("test", "error message")
      state.log_info("test", "info message")

      assert.spy(test_helper.notify_spy).was_not_called()
    end)

    it("should log error when debug is enabled", function()
      state.debug = true
      state.log_error("test", "error message")

      assert
        .spy(test_helper.notify_spy)
        .was_called_with("Centerpad [test]: error message", vim.log.levels.WARN)
    end)

    it("should log info when debug is enabled", function()
      state.debug = true
      state.log_info("test", "info message")

      assert
        .spy(test_helper.notify_spy)
        .was_called_with("Centerpad [test]: info message", vim.log.levels.INFO)
    end)

    it("should format error message correctly", function()
      state.debug = true
      local table_err = { key = "value" }
      state.log_error("context1", "simple error")
      state.log_error("context2", 42)
      state.log_error("context3", table_err)

      assert.spy(test_helper.notify_spy).was_called(3)
      assert
        .spy(test_helper.notify_spy)
        .was_called_with("Centerpad [context1]: simple error", vim.log.levels.WARN)
      assert
        .spy(test_helper.notify_spy)
        .was_called_with("Centerpad [context2]: 42", vim.log.levels.WARN)
      assert
        .spy(test_helper.notify_spy)
        .was_called_with("Centerpad [context3]: " .. tostring(table_err), vim.log.levels.WARN)
    end)

    it("should format info message correctly", function()
      state.debug = true
      state.log_info("context1", "simple message")
      state.log_info("context2", 123)
      state.log_info("context3", true)

      assert.spy(test_helper.notify_spy).was_called(3)
      assert
        .spy(test_helper.notify_spy)
        .was_called_with("Centerpad [context1]: simple message", vim.log.levels.INFO)
      assert
        .spy(test_helper.notify_spy)
        .was_called_with("Centerpad [context2]: 123", vim.log.levels.INFO)
      assert
        .spy(test_helper.notify_spy)
        .was_called_with("Centerpad [context3]: true", vim.log.levels.INFO)
    end)

    it("should handle debug mode toggle", function()
      state.debug = false
      state.log_error("test1", "should not log")

      state.debug = true
      state.log_error("test2", "should log")

      state.debug = false
      state.log_info("test3", "should not log")

      assert.spy(test_helper.notify_spy).was_called(1)
      assert
        .spy(test_helper.notify_spy)
        .was_called_with("Centerpad [test2]: should log", vim.log.levels.WARN)
    end)
  end)
end)
