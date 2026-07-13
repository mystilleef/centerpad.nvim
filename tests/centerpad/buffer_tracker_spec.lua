describe("centerpad.buffer_tracker", function()
  local centerpad
  local state
  local autocmds
  local window
  local test_helper

  before_each(function()
    package.loaded["centerpad.state"] = nil
    package.loaded["centerpad.enabled"] = nil
    package.loaded["centerpad.window"] = nil
    package.loaded["centerpad.autocmds"] = nil
    package.loaded["centerpad.centerpad"] = nil
    package.loaded["test_helper"] = nil

    state = require("centerpad.state")
    window = require("centerpad.window")
    autocmds = require("centerpad.autocmds")
    centerpad = require("centerpad.centerpad")
    test_helper = require("test_helper")

    state.reset()
    vim.g.centerpad_enabled = false
    vim.g.center_buf_enabled = false

    -- Fresh single window with normal buffer
    local fresh_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("buftype", "", { buf = fresh_buf })
    vim.api.nvim_set_option_value("filetype", "", { buf = fresh_buf })
    vim.cmd("new")
    local fresh_win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_option_value("winfixbuf", false, { win = fresh_win })
    vim.api.nvim_win_set_buf(fresh_win, fresh_buf)
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if win ~= fresh_win then
        pcall(vim.api.nvim_win_close, win, true)
      end
    end
    vim.o.columns = 120
  end)

  after_each(function()
    test_helper.cleanup_headless_spec()
  end)

  local function default_config()
    return {
      ignore_filetypes = { "help", "centerpad" },
      ignore_buftypes = { "nofile", "terminal", "prompt", "quickfix" },
      leftpad = 25,
      rightpad = 25,
    }
  end

  local function enable_with_tracker(config)
    config = config or default_config()
    centerpad.enable(config)
    vim.wait(100)
  end

  describe("suspend on ignored context", function()
    it("suspends pads when switching to ignored filetype", function()
      local config = default_config()
      enable_with_tracker(config)

      assert.is_true(state.pad_state.enabled)
      assert.is_true(state.pads_exist())

      -- Switch to help filetype (ignored)
      local help_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = help_buf })
      vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf })
      vim.api.nvim_set_current_buf(help_buf)
      vim.wait(150)

      -- Pads should be suspended
      assert.is_false(state.pad_state.enabled)
      assert.is_falsy(state.pads_exist())
      assert.is_true(state.tracker.suspended)
      assert.is_true(state.tracker.opted_in)
    end)

    it("suspends pads when switching to ignored buftype", function()
      local config = default_config()
      enable_with_tracker(config)

      assert.is_true(state.pad_state.enabled)

      -- Switch to nofile buftype (ignored)
      local nofile_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "nofile", { buf = nofile_buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = nofile_buf })
      vim.api.nvim_set_current_buf(nofile_buf)
      vim.wait(150)

      assert.is_false(state.pad_state.enabled)
      assert.is_falsy(state.pads_exist())
      assert.is_true(state.tracker.suspended)
    end)

    it("suspends pads when switching to floating window", function()
      local config = default_config()
      enable_with_tracker(config)

      assert.is_true(state.pad_state.enabled)

      -- Open and focus a floating window
      local float_buf = vim.api.nvim_create_buf(false, true)
      local float_win = vim.api.nvim_open_win(float_buf, true, {
        relative = "editor",
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      vim.wait(150)

      assert.is_false(state.pad_state.enabled)
      assert.is_falsy(state.pads_exist())
      assert.is_true(state.tracker.suspended)

      pcall(vim.api.nvim_win_close, float_win, true)
      vim.api.nvim_buf_delete(float_buf, { force = true })
    end)

    it(
      "suspends pads when entering an ignored context buffer directly",
      function()
        local config = default_config()
        enable_with_tracker(config)

        assert.is_true(state.pad_state.enabled)

        -- Switch to help buffer (ignored filetype)
        local help_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = help_buf })
        vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf })
        vim.api.nvim_set_current_buf(help_buf)
        vim.wait(200)

        -- Pads should be suspended (help buffers are not valid source context)
        assert.is_false(state.pad_state.enabled)
        assert.is_true(state.tracker.suspended)
      end
    )
  end)

  describe("resume on valid context", function()
    it("resumes pads when returning to normal source buffer", function()
      local config = default_config()
      enable_with_tracker(config)

      -- Suspend by switching to help
      local help_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = help_buf })
      vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf })
      vim.api.nvim_set_current_buf(help_buf)
      vim.wait(150)

      assert.is_false(state.pad_state.enabled)
      assert.is_true(state.tracker.suspended)

      -- Resume by switching to a normal buffer
      local normal_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = normal_buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = normal_buf })
      vim.api.nvim_set_current_buf(normal_buf)
      vim.wait(150)

      assert.is_true(state.pad_state.enabled)
      assert.is_true(state.pads_exist())
      assert.is_false(state.tracker.suspended)
      assert.is_true(vim.g.centerpad_enabled)
      -- Pads should have been recreated
      assert.is_not_nil(state.pad_state.left_win)
      assert.is_not_nil(state.pad_state.right_win)
    end)

    it("resumes pads with correct widths from tracked config", function()
      local config = {
        ignore_filetypes = { "help" },
        ignore_buftypes = {},
        leftpad = 15,
        rightpad = 35,
      }
      enable_with_tracker(config)

      -- Suspend
      local help_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = help_buf })
      vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf })
      vim.api.nvim_set_current_buf(help_buf)
      vim.wait(150)

      assert.is_false(state.pad_state.enabled)

      -- Resume
      local normal_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = normal_buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = normal_buf })
      vim.api.nvim_set_current_buf(normal_buf)
      vim.wait(150)

      assert.is_true(state.pad_state.enabled)
      assert.is_true(state.pads_exist())
      assert.are.equal(15, vim.api.nvim_win_get_width(state.pad_state.left_win))
      assert.are.equal(
        35,
        vim.api.nvim_win_get_width(state.pad_state.right_win)
      )
    end)

    it("resumes after floating window is closed", function()
      local config = default_config()
      enable_with_tracker(config)

      -- Suspend via floating window
      local float_buf = vim.api.nvim_create_buf(false, true)
      local float_win = vim.api.nvim_open_win(float_buf, true, {
        relative = "editor",
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      vim.wait(150)

      assert.is_false(state.pad_state.enabled)
      assert.is_true(state.tracker.suspended)

      -- Close floating window - should return focus to normal source
      vim.api.nvim_win_close(float_win, true)
      vim.wait(150)

      assert.is_true(state.pad_state.enabled)
      assert.is_true(state.pads_exist())
      assert.is_false(state.tracker.suspended)
    end)
  end)

  describe("no auto-enable without opt-in", function()
    it("does not auto-enable for tabs that never opted in", function()
      -- Don't call enable_with_tracker, just set up a buffer
      local normal_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = normal_buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = normal_buf })
      vim.api.nvim_set_current_buf(normal_buf)
      vim.wait(150)

      -- Should not be enabled
      assert.is_false(state.pad_state.enabled)
      assert.is_falsy(state.pads_exist())
      assert.is_false(state.tracker.opted_in)
    end)

    it("does not re-enable after manual disable", function()
      local config = default_config()
      enable_with_tracker(config)

      assert.is_true(state.pad_state.enabled)

      -- Manual disable (user toggles off)
      centerpad.disable()
      vim.wait(50)

      assert.is_false(state.pad_state.enabled)
      assert.is_false(state.tracker.opted_in)
      assert.is_false(state.tracker.suspended)

      -- Switch buffers - should NOT re-enable
      local normal_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = normal_buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = normal_buf })
      vim.api.nvim_set_current_buf(normal_buf)
      vim.wait(150)

      assert.is_false(state.pad_state.enabled)
      assert.is_falsy(state.pads_exist())
    end)
  end)

  describe("suspended flag", function()
    it("starts as false when tracker is set up", function()
      local config = default_config()
      enable_with_tracker(config)

      assert.is_false(state.tracker.suspended)
    end)

    it("is set to true when suspending", function()
      local config = default_config()
      enable_with_tracker(config)

      local help_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = help_buf })
      vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf })
      vim.api.nvim_set_current_buf(help_buf)
      vim.wait(150)

      assert.is_true(state.tracker.suspended)
    end)

    it("is reset to false when resuming", function()
      local config = default_config()
      enable_with_tracker(config)

      -- Suspend
      local help_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = help_buf })
      vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf })
      vim.api.nvim_set_current_buf(help_buf)
      vim.wait(150)

      assert.is_true(state.tracker.suspended)

      -- Resume
      local normal_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = normal_buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = normal_buf })
      vim.api.nvim_set_current_buf(normal_buf)
      vim.wait(150)

      assert.is_false(state.tracker.suspended)
    end)

    it(
      "prevents re-enable after recovery cleanup (not tracker-initiated)",
      function()
        local config = default_config()
        enable_with_tracker(config)

        -- Simulate recovery cleanup (NOT via tracker suspend)
        -- e.g., pad close event triggers recovery
        autocmds.cleanup()

        assert.is_false(state.pad_state.enabled)
        assert.is_false(state.tracker.suspended)

        -- Tracker should NOT re-enable because we didn't suspend
        local normal_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = normal_buf })
        vim.api.nvim_set_option_value("filetype", "", { buf = normal_buf })
        vim.api.nvim_set_current_buf(normal_buf)
        vim.wait(150)

        assert.is_false(state.pad_state.enabled)
      end
    )
  end)

  describe("failure modes converge through cleanup", function()
    it("suspended state resets when pads fail to recreate on resume", function()
      local config = default_config()
      enable_with_tracker(config)

      -- Suspend
      local help_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = help_buf })
      vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf })
      vim.api.nvim_set_current_buf(help_buf)
      vim.wait(150)

      assert.is_false(state.pad_state.enabled)
      assert.is_true(state.tracker.suspended)

      -- Make pad creation fail
      local orig_open_win = vim.api.nvim_open_win
      vim.api.nvim_open_win = function()
        error("forced failure")
      end

      -- Try to resume
      local normal_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = normal_buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = normal_buf })
      vim.api.nvim_set_current_buf(normal_buf)
      vim.wait(200)

      -- Should be in clean state
      assert.is_false(state.pad_state.enabled)
      assert.is_falsy(state.pads_exist())
      -- suspended was reset before enable was called
      assert.is_false(state.tracker.suspended)

      vim.api.nvim_open_win = orig_open_win
    end)

    it("no duplicate pad buffers after rapid suspend/resume cycles", function()
      local config = default_config()
      enable_with_tracker(config)

      -- Rapid suspend/resume cycles with enough time for debounce (50ms)
      -- and full event processing
      for _ = 1, 3 do
        -- Suspend: switch to help buffer
        local help_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = help_buf })
        vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf })
        vim.api.nvim_set_current_buf(help_buf)
        vim.wait(150)

        -- Resume: switch back to normal buffer
        local normal_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = normal_buf })
        vim.api.nvim_set_option_value("filetype", "", { buf = normal_buf })
        vim.api.nvim_set_current_buf(normal_buf)
        vim.wait(150)
      end
      vim.wait(200)

      -- Verify final state is clean: exactly one left/right pad pair
      assert.is_true(state.pad_state.enabled)
      assert.is_not_nil(state.pad_state.left_win)
      assert.is_not_nil(state.pad_state.right_win)
      assert.is_true(vim.api.nvim_win_is_valid(state.pad_state.left_win))
      assert.is_true(vim.api.nvim_win_is_valid(state.pad_state.right_win))
      assert.is_true(window.are_pads_valid())

      -- Verify tracked pads have pad buffers
      local left_buf = vim.api.nvim_win_get_buf(state.pad_state.left_win)
      local right_buf = vim.api.nvim_win_get_buf(state.pad_state.right_win)
      assert.is_true(window.is_pad_buffer(left_buf))
      assert.is_true(window.is_pad_buffer(right_buf))
    end)
  end)

  describe("cross-tab tracker isolation", function()
    it("tab1 still observes BufEnter after tab2 disables", function()
      -- Tab 1: enable with tracker
      local config1 = {
        ignore_filetypes = { "help" },
        ignore_buftypes = {},
        leftpad = 12,
        rightpad = 13,
      }
      enable_with_tracker(config1)
      assert.is_true(state.pad_state.enabled)
      assert.is_true(state.tracker.opted_in)

      -- Tab 2: enable with tracker
      vim.cmd("tabnew")
      local fresh_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = fresh_buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = fresh_buf })
      vim.api.nvim_set_current_buf(fresh_buf)
      local config2 = {
        ignore_filetypes = { "help" },
        ignore_buftypes = {},
        leftpad = 31,
        rightpad = 32,
      }
      centerpad.enable(config2)
      vim.wait(100)
      assert.is_true(state.pad_state.enabled)

      -- Disable tab 2
      centerpad.disable()
      vim.wait(50)
      assert.is_false(state.pad_state.enabled)
      assert.is_false(state.tracker.opted_in)

      -- Switch back to tab 1
      vim.cmd("tabprevious")

      -- Tab 1 should still be opted in and enabled
      assert.is_true(state.tracker.opted_in)
      assert.is_true(state.pad_state.enabled)
      assert.is_true(state.pads_exist())

      -- Tab 1 should still respond to BufEnter: suspend on help
      local help_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = help_buf })
      vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf })
      vim.api.nvim_set_current_buf(help_buf)
      vim.wait(150)

      assert.is_true(state.tracker.suspended)
      assert.is_false(state.pad_state.enabled)

      -- Tab 1 should resume from its own events
      local normal_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = normal_buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = normal_buf })
      vim.api.nvim_set_current_buf(normal_buf)
      vim.wait(150)

      assert.is_true(state.pad_state.enabled)
      assert.is_true(state.pads_exist())
      assert.is_false(state.tracker.suspended)

      -- Verify widths are still tab1's config
      assert.are.equal(12, vim.api.nvim_win_get_width(state.pad_state.left_win))
      assert.are.equal(
        13,
        vim.api.nvim_win_get_width(state.pad_state.right_win)
      )

      vim.cmd("silent! tabonly")
    end)

    it("tab2 enable then disable does not remove tab1 opt-in", function()
      -- Tab 1: enable
      local config1 = {
        ignore_filetypes = { "help" },
        ignore_buftypes = {},
        leftpad = 15,
        rightpad = 17,
      }
      enable_with_tracker(config1)

      -- Tab 2: enable then disable
      vim.cmd("tabnew")
      local fresh_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = fresh_buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = fresh_buf })
      vim.api.nvim_set_current_buf(fresh_buf)
      local config2 = {
        ignore_filetypes = { "help" },
        ignore_buftypes = {},
        leftpad = 40,
        rightpad = 50,
      }
      centerpad.enable(config2)
      vim.wait(100)
      centerpad.disable()

      -- Switch back to tab 1
      vim.cmd("tabprevious")

      -- Tab 1 tracker should still be alive
      assert.is_true(state.tracker.opted_in)
      assert.is_false(state.tracker.suspended)
      assert.is_true(state.pad_state.enabled)

      vim.cmd("silent! tabonly")
    end)

    it("tab2 re-enable does not clear tab1 tracker callbacks", function()
      -- Tab 1: enable
      local config1 = {
        ignore_filetypes = { "help" },
        ignore_buftypes = {},
        leftpad = 10,
        rightpad = 11,
      }
      enable_with_tracker(config1)

      -- Tab 2: enable, disable, re-enable
      vim.cmd("tabnew")
      local fresh_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = fresh_buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = fresh_buf })
      vim.api.nvim_set_current_buf(fresh_buf)
      local config2 = {
        ignore_filetypes = { "help" },
        ignore_buftypes = {},
        leftpad = 40,
        rightpad = 50,
      }
      centerpad.enable(config2)
      vim.wait(100)
      centerpad.disable()
      centerpad.enable(config2)
      vim.wait(100)

      -- Switch back to tab 1
      vim.cmd("tabprevious")

      -- Tab 1 should still be fully functional
      assert.is_true(state.tracker.opted_in)
      assert.is_true(state.pad_state.enabled)
      assert.is_true(state.pads_exist())

      -- Verify widths are still tab1's
      assert.are.equal(10, vim.api.nvim_win_get_width(state.pad_state.left_win))
      assert.are.equal(
        11,
        vim.api.nvim_win_get_width(state.pad_state.right_win)
      )

      vim.cmd("silent! tabonly")
    end)

    it("tab2 BufEnter does not resume tab2 from tab1 events", function()
      -- Tab 1: enable
      local config1 = {
        ignore_filetypes = { "help" },
        ignore_buftypes = {},
        leftpad = 12,
        rightpad = 13,
      }
      enable_with_tracker(config1)

      -- Tab 2: enable, then suspend
      vim.cmd("tabnew")
      local fresh_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = fresh_buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = fresh_buf })
      vim.api.nvim_set_current_buf(fresh_buf)
      local config2 = {
        ignore_filetypes = { "help" },
        ignore_buftypes = {},
        leftpad = 31,
        rightpad = 32,
      }
      centerpad.enable(config2)
      vim.wait(100)

      -- Suspend tab 2
      local help_buf2 = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = help_buf2 })
      vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf2 })
      vim.api.nvim_set_current_buf(help_buf2)
      vim.wait(150)
      assert.is_true(state.tracker.suspended)
      assert.is_false(state.pad_state.enabled)

      -- Switch to tab 1 (should NOT resume tab 2)
      vim.cmd("tabprevious")
      vim.wait(150)

      -- Tab 2 should still be suspended
      vim.cmd("tabnext")
      assert.is_true(state.tracker.suspended)
      assert.is_false(state.pad_state.enabled)

      -- Tab 1 should still be enabled
      vim.cmd("tabprevious")
      assert.is_true(state.pad_state.enabled)
      assert.is_false(state.tracker.suspended)

      vim.cmd("silent! tabonly")
    end)

    it("disable on one tab does not affect sibling tracker config", function()
      -- Tab 1: enable with specific config
      local config1 = {
        ignore_filetypes = { "help", "centerpad" },
        ignore_buftypes = { "nofile" },
        leftpad = 14,
        rightpad = 16,
      }
      enable_with_tracker(config1)

      -- Tab 2: enable and disable
      vim.cmd("tabnew")
      local fresh_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = fresh_buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = fresh_buf })
      vim.api.nvim_set_current_buf(fresh_buf)
      local config2 = {
        ignore_filetypes = { "nerdtree" },
        ignore_buftypes = { "terminal" },
        leftpad = 50,
        rightpad = 60,
      }
      centerpad.enable(config2)
      vim.wait(100)
      centerpad.disable()

      -- Switch to tab 1
      vim.cmd("tabprevious")

      -- Tab 1 tracker config should be intact
      assert.is_not_nil(state.tracker.config)
      assert.are.equal(14, state.tracker.config.leftpad)
      assert.are.equal(16, state.tracker.config.rightpad)

      vim.cmd("silent! tabonly")
    end)
  end)

  describe("edge cases", function()
    it("handles nil window IDs during suspend gracefully", function()
      local config = default_config()
      enable_with_tracker(config)

      state.pad_state.left_win = nil
      state.pad_state.right_win = nil

      -- Switch to ignored context - should not crash
      local help_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = help_buf })
      vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf })
      vim.api.nvim_set_current_buf(help_buf)
      vim.wait(150)

      -- Should not crash (window IDs are nil)
      -- enabled may stay true because pads don't exist (nil IDs)
      assert.is_not_nil(state.tracker.opted_in)
    end)

    it("does not suspend if already suspended (no double-suspend)", function()
      local config = default_config()
      enable_with_tracker(config)

      -- Suspend
      local help_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = help_buf })
      vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf })
      vim.api.nvim_set_current_buf(help_buf)
      vim.wait(150)

      assert.is_true(state.tracker.suspended)
      assert.is_false(state.pad_state.enabled)

      -- Switch to another ignored context - should not crash
      local nofile_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "nofile", { buf = nofile_buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = nofile_buf })
      vim.api.nvim_set_current_buf(nofile_buf)
      vim.wait(150)

      -- Still suspended, no crash
      assert.is_true(state.tracker.suspended)
      assert.is_false(state.pad_state.enabled)
    end)

    it("does not resume if not suspended (no-op on valid context)", function()
      local config = default_config()
      enable_with_tracker(config)

      assert.is_true(state.pad_state.enabled)
      assert.is_false(state.tracker.suspended)

      -- Switch to another valid buffer - should not re-enable
      local normal_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = normal_buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = normal_buf })
      vim.api.nvim_set_current_buf(normal_buf)
      vim.wait(150)

      -- Still enabled, no double-enable
      assert.is_true(state.pad_state.enabled)
      assert.is_false(state.tracker.suspended)
    end)

    it("cleanup clears tracker state and prevents resume", function()
      local config = default_config()
      enable_with_tracker(config)

      -- Suspend via tracker
      local help_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = help_buf })
      vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf })
      vim.api.nvim_set_current_buf(help_buf)
      vim.wait(150)

      assert.is_true(state.tracker.suspended)
      assert.is_true(state.tracker.opted_in)

      -- Full disable clears everything
      centerpad.disable()

      assert.is_false(state.tracker.opted_in)
      assert.is_false(state.tracker.suspended)

      -- Resume should not happen
      local normal_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = normal_buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = normal_buf })
      vim.api.nvim_set_current_buf(normal_buf)
      vim.wait(150)

      assert.is_false(state.pad_state.enabled)
    end)

    it("global fillchars stay unchanged after suspend and resume", function()
      local config = default_config()
      -- Save global fillchars (not window-local)
      local original = vim.go.fillchars

      enable_with_tracker(config)

      -- Suspend
      local help_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = help_buf })
      vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf })
      vim.api.nvim_set_current_buf(help_buf)
      vim.wait(150)

      assert.are.equal(original, vim.go.fillchars)

      -- Resume
      local normal_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = normal_buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = normal_buf })
      vim.api.nvim_set_current_buf(normal_buf)
      vim.wait(150)

      assert.are.equal(original, vim.go.fillchars)
    end)

    it("vim.g flags stay consistent after suspend and resume", function()
      local config = default_config()
      enable_with_tracker(config)

      assert.is_true(vim.g.centerpad_enabled)

      -- Suspend
      local help_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = help_buf })
      vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf })
      vim.api.nvim_set_current_buf(help_buf)
      vim.wait(150)

      assert.is_false(vim.g.centerpad_enabled)
      assert.is_false(vim.g.center_buf_enabled)

      -- Resume
      local normal_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = normal_buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = normal_buf })
      vim.api.nvim_set_current_buf(normal_buf)
      vim.wait(150)

      assert.is_true(vim.g.centerpad_enabled)
      assert.is_true(vim.g.center_buf_enabled)
    end)
  end)

  describe("immediate guards and tracker isolation", function()
    it(
      "one tab disable leaves sibling tracker debounce timer intact",
      function()
        -- Tab 1: enable with tracker
        local config1 = {
          ignore_filetypes = { "help" },
          ignore_buftypes = {},
          leftpad = 12,
          rightpad = 13,
        }
        enable_with_tracker(config1)
        assert.is_true(state.tracker.opted_in)

        -- Tab 2: enable with tracker
        vim.cmd("tabnew")
        local fresh_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = fresh_buf })
        vim.api.nvim_set_option_value("filetype", "", { buf = fresh_buf })
        vim.api.nvim_set_current_buf(fresh_buf)
        local config2 = {
          ignore_filetypes = { "help" },
          ignore_buftypes = {},
          leftpad = 31,
          rightpad = 32,
        }
        centerpad.enable(config2)
        vim.wait(100)

        -- Trigger tracker debounce on tab 2 by switching to help
        local help_buf2 = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = help_buf2 })
        vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf2 })
        vim.api.nvim_set_current_buf(help_buf2)
        -- Don't wait - timer should be pending

        -- Disable tab 2 while debounce is pending
        centerpad.disable()
        vim.wait(50)

        -- Tab 1 tracker should still be intact
        vim.cmd("tabprevious")
        assert.is_true(state.tracker.opted_in)
        assert.is_false(state.tracker.suspended)

        -- Tab 1 should still be enabled
        assert.is_true(state.pad_state.enabled)
        assert.is_true(state.pads_exist())

        vim.cmd("silent! tabonly")
      end
    )

    it("one tab cleanup leaves sibling tracker resume widths intact", function()
      -- Tab 1: enable with tracker and specific widths
      local config1 = {
        ignore_filetypes = { "help" },
        ignore_buftypes = {},
        leftpad = 14,
        rightpad = 16,
      }
      enable_with_tracker(config1)
      assert.is_true(state.tracker.opted_in)

      -- Tab 2: enable with tracker
      vim.cmd("tabnew")
      local fresh_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = fresh_buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = fresh_buf })
      vim.api.nvim_set_current_buf(fresh_buf)
      local config2 = {
        ignore_filetypes = { "help" },
        ignore_buftypes = {},
        leftpad = 40,
        rightpad = 50,
      }
      centerpad.enable(config2)
      vim.wait(100)

      -- Cleanup on tab 2
      autocmds.cleanup()
      vim.wait(50)

      -- Tab 1 tracker resume widths should be intact
      vim.cmd("tabprevious")
      assert.is_true(state.tracker.opted_in)
      assert.is_not_nil(state.tracker.config)
      assert.are.equal(14, state.tracker.config.leftpad)
      assert.are.equal(16, state.tracker.config.rightpad)

      -- Tab 1 should still be enabled
      assert.is_true(state.pad_state.enabled)
      assert.is_true(state.pads_exist())

      vim.cmd("silent! tabonly")
    end)

    it("tracker debounce after tab switch never suspends non-owner", function()
      -- Tab 1: enable with tracker
      local config1 = {
        ignore_filetypes = { "help" },
        ignore_buftypes = {},
        leftpad = 12,
        rightpad = 13,
      }
      enable_with_tracker(config1)

      -- Tab 2: enable with tracker and its own normal buffer
      vim.cmd("tabnew")
      local fresh_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = fresh_buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = fresh_buf })
      vim.api.nvim_set_current_buf(fresh_buf)
      local config2 = {
        ignore_filetypes = { "help" },
        ignore_buftypes = {},
        leftpad = 31,
        rightpad = 32,
      }
      centerpad.enable(config2)
      vim.wait(100)

      -- Suspend tab 2 fully
      local help_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = help_buf })
      vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf })
      vim.api.nvim_set_current_buf(help_buf)
      vim.wait(150)
      assert.is_true(state.tracker.suspended)
      assert.is_false(state.pad_state.enabled)

      -- Switch to tab 1 - should not affect tab 1
      vim.cmd("tabprevious")
      vim.wait(150)

      -- Tab 1 should NOT be suspended (non-owner protection)
      assert.is_false(state.tracker.suspended)
      assert.is_true(state.pad_state.enabled)
      assert.is_true(state.pads_exist())

      -- Tab 2 should still be suspended
      vim.cmd("tabnext")
      assert.is_true(state.tracker.suspended)
      assert.is_false(state.pad_state.enabled)

      vim.cmd("silent! tabonly")
    end)

    it("tracker debounce after tab switch never resumes non-owner", function()
      -- Tab 1: enable with tracker
      local config1 = {
        ignore_filetypes = { "help" },
        ignore_buftypes = {},
        leftpad = 12,
        rightpad = 13,
      }
      enable_with_tracker(config1)

      -- Tab 2: enable with tracker and its own normal buffer
      vim.cmd("tabnew")
      local fresh_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = fresh_buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = fresh_buf })
      vim.api.nvim_set_current_buf(fresh_buf)
      local config2 = {
        ignore_filetypes = { "help" },
        ignore_buftypes = {},
        leftpad = 31,
        rightpad = 32,
      }
      centerpad.enable(config2)
      vim.wait(100)

      -- Suspend tab 2
      local help_buf2 = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = help_buf2 })
      vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf2 })
      vim.api.nvim_set_current_buf(help_buf2)
      vim.wait(150)
      assert.is_true(state.tracker.suspended)
      assert.is_false(state.pad_state.enabled)

      -- Switch to tab 1 (non-owner) - should not affect tab 1
      vim.cmd("tabprevious")
      vim.wait(150)

      -- Tab 1 should still be enabled (non-owner protection)
      assert.is_true(state.pad_state.enabled)
      assert.is_false(state.tracker.suspended)

      -- Tab 2 should still be suspended
      vim.cmd("tabnext")
      assert.is_true(state.tracker.suspended)
      assert.is_false(state.pad_state.enabled)

      -- Now resume tab 2 by switching to normal buffer
      local normal_buf2 = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = normal_buf2 })
      vim.api.nvim_set_option_value("filetype", "", { buf = normal_buf2 })
      vim.api.nvim_set_current_buf(normal_buf2)
      vim.wait(150)

      -- Tab 2 should be resumed
      assert.is_true(state.pad_state.enabled)
      assert.is_false(state.tracker.suspended)

      -- Tab 1 should still be enabled (resuming tab 2 didn't affect tab 1)
      vim.cmd("tabprevious")
      assert.is_true(state.pad_state.enabled)
      assert.is_false(state.tracker.suspended)

      vim.cmd("silent! tabonly")
    end)

    it(
      "nil tracker timers are safe with simultaneous enabled siblings",
      function()
        -- Tab 1: enable with tracker
        local config1 = {
          ignore_filetypes = { "help" },
          ignore_buftypes = {},
          leftpad = 12,
          rightpad = 13,
        }
        enable_with_tracker(config1)
        assert.is_true(state.tracker.opted_in)

        -- Tab 2: enable with tracker
        vim.cmd("tabnew")
        local fresh_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = fresh_buf })
        vim.api.nvim_set_option_value("filetype", "", { buf = fresh_buf })
        vim.api.nvim_set_current_buf(fresh_buf)
        local config2 = {
          ignore_filetypes = { "help" },
          ignore_buftypes = {},
          leftpad = 31,
          rightpad = 32,
        }
        centerpad.enable(config2)
        vim.wait(100)

        -- Both tabs should be enabled simultaneously
        assert.is_true(state.pad_state.enabled)
        assert.is_true(state.pads_exist())

        -- Switch back to tab 1
        vim.cmd("tabprevious")

        -- Tab 1 should also be enabled
        assert.is_true(state.pad_state.enabled)
        assert.is_true(state.pads_exist())
        assert.is_true(state.tracker.opted_in)

        -- Verify both tabs have their own widths
        assert.are.equal(
          12,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          13,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )

        -- Switch to tab 2 and verify its widths
        vim.cmd("tabnext")
        assert.are.equal(
          31,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          32,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )

        vim.cmd("silent! tabonly")
      end
    )
  end)

  describe("config-free toggle tracking", function()
    it("toggle(nil) enables pads and survives lifecycle events", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      state.pad_state.enabled = false

      local ok, err = pcall(function()
        centerpad.toggle(nil)
        vim.wait(50)

        assert.is_true(state.pad_state.enabled)
        assert.is_true(state.tracker.opted_in)
        assert.is_true(state.pads_exist())

        -- Nil ignore lists mean no filtering; normal context stays enabled.
        local normal_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = normal_buf })
        vim.api.nvim_set_option_value("filetype", "", { buf = normal_buf })
        vim.api.nvim_set_current_buf(normal_buf)
        vim.wait(150)

        assert.is_true(state.pad_state.enabled)
        assert.is_false(state.tracker.suspended)
      end)

      assert.is_true(ok, err)
    end)

    it("toggle(nil) with partial config filters only supplied list", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      state.pad_state.enabled = false

      centerpad.toggle({ ignore_filetypes = { "help" } })
      vim.wait(50)

      assert.is_true(state.pad_state.enabled)

      -- Supplied filetype ignore list suspends on help.
      local help_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = help_buf })
      vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf })
      vim.api.nvim_set_current_buf(help_buf)
      vim.wait(150)

      assert.is_false(state.pad_state.enabled)
      assert.is_true(state.tracker.suspended)

      -- Resume to a normal buffer.
      local normal_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = normal_buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = normal_buf })
      vim.api.nvim_set_current_buf(normal_buf)
      vim.wait(150)

      assert.is_true(state.pad_state.enabled)
      assert.is_false(state.tracker.suspended)

      -- Omitted buftype ignore list means no buftype filtering.
      local nofile_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "nofile", { buf = nofile_buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = nofile_buf })
      vim.api.nvim_set_current_buf(nofile_buf)
      vim.wait(150)

      assert.is_true(state.pad_state.enabled)
      assert.is_false(state.tracker.suspended)
    end)

    it("omitted ignore_buftypes does not filter buftype", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      state.pad_state.enabled = false

      centerpad.toggle({ ignore_filetypes = { "help" } })
      vim.wait(50)

      -- nofile is not ignored because ignore_buftypes is omitted.
      local nofile_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "nofile", { buf = nofile_buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = nofile_buf })
      vim.api.nvim_set_current_buf(nofile_buf)
      vim.wait(150)

      assert.is_true(state.pad_state.enabled)
      assert.is_false(state.tracker.suspended)
    end)

    it("omitted ignore_filetypes does not filter filetype", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      state.pad_state.enabled = false

      centerpad.toggle({ ignore_buftypes = { "nofile" } })
      vim.wait(50)

      -- help is not ignored because ignore_filetypes is omitted.
      local help_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = help_buf })
      vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf })
      vim.api.nvim_set_current_buf(help_buf)
      vim.wait(150)

      assert.is_true(state.pad_state.enabled)
      assert.is_false(state.tracker.suspended)
    end)
  end)

  describe("committed width promotion", function()
    it(
      "asymmetric resize updates snapshot and tracker config while keeping pad IDs",
      function()
        local config = {
          ignore_filetypes = { "help" },
          ignore_buftypes = {},
          leftpad = 15,
          rightpad = 35,
        }
        enable_with_tracker(config)

        local left_win = state.pad_state.left_win
        local right_win = state.pad_state.right_win

        centerpad.run(config, { fargs = { "18", "42" } })
        vim.wait(100)

        assert.are.equal(left_win, state.pad_state.left_win)
        assert.are.equal(right_win, state.pad_state.right_win)
        assert.are.equal(
          18,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          42,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )
        assert.are.equal(18, state.config_snapshot.leftpad)
        assert.are.equal(42, state.config_snapshot.rightpad)
        assert.is_not_nil(state.tracker.config)
        assert.are.equal(18, state.tracker.config.leftpad)
        assert.are.equal(42, state.tracker.config.rightpad)
      end
    )

    it("resumes after asymmetric resize at committed widths", function()
      local config = {
        ignore_filetypes = { "help" },
        ignore_buftypes = {},
        leftpad = 15,
        rightpad = 35,
      }
      enable_with_tracker(config)

      centerpad.run(config, { fargs = { "18", "42" } })
      vim.wait(100)

      -- Suspend by switching to ignored filetype
      local help_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = help_buf })
      vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf })
      vim.api.nvim_set_current_buf(help_buf)
      vim.wait(150)

      assert.is_true(state.tracker.suspended)
      assert.is_false(state.pad_state.enabled)

      -- Resume by switching to a normal buffer
      local normal_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = normal_buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = normal_buf })
      vim.api.nvim_set_current_buf(normal_buf)
      vim.wait(150)

      assert.is_true(state.pad_state.enabled)
      assert.is_true(state.pads_exist())
      assert.is_false(state.tracker.suspended)
      assert.are.equal(18, vim.api.nvim_win_get_width(state.pad_state.left_win))
      assert.are.equal(
        42,
        vim.api.nvim_win_get_width(state.pad_state.right_win)
      )
    end)

    it(
      "two tabs keep distinct committed widths through suspend and resume",
      function()
        -- Tab 1: opt-in with 12:13
        local config1 = {
          ignore_filetypes = { "help" },
          ignore_buftypes = {},
          leftpad = 12,
          rightpad = 13,
        }
        enable_with_tracker(config1)

        -- Tab 2: opt-in with 31:32
        vim.cmd("tabnew")
        local fresh_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = fresh_buf })
        vim.api.nvim_set_option_value("filetype", "", { buf = fresh_buf })
        vim.api.nvim_set_current_buf(fresh_buf)
        local config2 = {
          ignore_filetypes = { "help" },
          ignore_buftypes = {},
          leftpad = 31,
          rightpad = 32,
        }
        centerpad.enable(config2)
        vim.wait(100)

        -- Resize tab 2 to 40:50 and commit
        centerpad.run(config2, { fargs = { "40", "50" } })
        vim.wait(100)

        -- Suspend and resume tab 2
        local help_buf2 = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = help_buf2 })
        vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf2 })
        vim.api.nvim_set_current_buf(help_buf2)
        vim.wait(150)

        local normal_buf2 = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = normal_buf2 })
        vim.api.nvim_set_option_value("filetype", "", { buf = normal_buf2 })
        vim.api.nvim_set_current_buf(normal_buf2)
        vim.wait(150)

        assert.is_true(state.pad_state.enabled)
        assert.are.equal(
          40,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          50,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )

        -- Switch to tab 1 and verify its widths are untouched
        vim.cmd("tabprevious")
        assert.is_true(state.pad_state.enabled)
        assert.are.equal(
          12,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          13,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )

        -- Suspend and resume tab 1
        local help_buf1 = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = help_buf1 })
        vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf1 })
        vim.api.nvim_set_current_buf(help_buf1)
        vim.wait(150)

        local normal_buf1 = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = normal_buf1 })
        vim.api.nvim_set_option_value("filetype", "", { buf = normal_buf1 })
        vim.api.nvim_set_current_buf(normal_buf1)
        vim.wait(150)

        assert.is_true(state.pad_state.enabled)
        assert.are.equal(
          12,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          13,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )

        vim.cmd("silent! tabonly")
      end
    )
  end)

  describe("tab-scoped callback ownership", function()
    local function tracker_autocmd_count(event)
      return #vim.api.nvim_get_autocmds({
        group = autocmds.centerpad_tracker,
        event = event,
      })
    end

    local function tracker_ids(event)
      local ids = {}
      for _, a in
        ipairs(vim.api.nvim_get_autocmds({
          group = autocmds.centerpad_tracker,
          event = event,
        }))
      do
        table.insert(ids, a.id)
      end
      return ids
    end

    it(
      "creates exactly one BufEnter and one WinEnter callback per owner tab",
      function()
        assert.are.equal(1, tracker_autocmd_count("TabEnter"))
        assert.are.equal(0, tracker_autocmd_count("BufEnter"))
        assert.are.equal(0, tracker_autocmd_count("WinEnter"))

        local config = default_config()
        enable_with_tracker(config)

        assert.are.equal(1, tracker_autocmd_count("TabEnter"))
        assert.are.equal(1, tracker_autocmd_count("BufEnter"))
        assert.are.equal(1, tracker_autocmd_count("WinEnter"))
      end
    )

    it("does not accumulate callbacks on repeated enable", function()
      local config = default_config()
      for _ = 1, 3 do
        centerpad.enable(config)
        vim.wait(50)
      end

      assert.are.equal(1, tracker_autocmd_count("BufEnter"))
      assert.are.equal(1, tracker_autocmd_count("WinEnter"))
    end)

    it("removes owner callbacks on full opt-out and cancels timer", function()
      local config = default_config()
      enable_with_tracker(config)

      local fired = false
      state.tracker.debounce_timer = vim.fn.timer_start(1000, function()
        fired = true
      end)

      centerpad.disable()
      vim.wait(50)

      assert.are.equal(0, tracker_autocmd_count("BufEnter"))
      assert.are.equal(0, tracker_autocmd_count("WinEnter"))
      assert.are.equal(1, tracker_autocmd_count("TabEnter"))
      assert.is_nil(state.tracker.debounce_timer)

      vim.wait(100)
      assert.is_false(fired)
    end)

    it("retains owner callback during ignore-context suspension", function()
      local config = default_config()
      enable_with_tracker(config)

      local before_buf = tracker_ids("BufEnter")
      local before_win = tracker_ids("WinEnter")

      local help_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = help_buf })
      vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf })
      vim.api.nvim_set_current_buf(help_buf)
      vim.wait(150)

      assert.is_true(state.tracker.suspended)
      assert.are.same(before_buf, tracker_ids("BufEnter"))
      assert.are.same(before_win, tracker_ids("WinEnter"))
    end)

    it(
      "replaces owner callback with a fresh pair on valid-context resume",
      function()
        local config = default_config()
        enable_with_tracker(config)

        local before_buf = tracker_ids("BufEnter")
        local before_win = tracker_ids("WinEnter")

        local help_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = help_buf })
        vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf })
        vim.api.nvim_set_current_buf(help_buf)
        vim.wait(150)

        local normal_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = normal_buf })
        vim.api.nvim_set_option_value("filetype", "", { buf = normal_buf })
        vim.api.nvim_set_current_buf(normal_buf)
        vim.wait(150)

        assert.is_true(state.pad_state.enabled)
        assert.are.equal(1, tracker_autocmd_count("BufEnter"))
        assert.are.equal(1, tracker_autocmd_count("WinEnter"))

        local after_buf = tracker_ids("BufEnter")
        local after_win = tracker_ids("WinEnter")
        assert.are_not.equal(before_buf[1], after_buf[1])
        assert.are_not.equal(before_win[1], after_win[1])
      end
    )

    it("preserves sibling callbacks and TabEnter bridge across tabs", function()
      local config1 = {
        ignore_filetypes = { "help" },
        ignore_buftypes = {},
        leftpad = 12,
        rightpad = 13,
      }
      enable_with_tracker(config1)

      vim.cmd("tabnew")
      local fresh_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = fresh_buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = fresh_buf })
      vim.api.nvim_set_current_buf(fresh_buf)
      local config2 = {
        ignore_filetypes = { "help" },
        ignore_buftypes = {},
        leftpad = 31,
        rightpad = 32,
      }
      centerpad.enable(config2)
      vim.wait(100)

      assert.are.equal(2, tracker_autocmd_count("BufEnter"))
      assert.are.equal(2, tracker_autocmd_count("WinEnter"))
      assert.are.equal(1, tracker_autocmd_count("TabEnter"))

      centerpad.disable()
      vim.wait(50)

      assert.are.equal(1, tracker_autocmd_count("BufEnter"))
      assert.are.equal(1, tracker_autocmd_count("WinEnter"))
      assert.are.equal(1, tracker_autocmd_count("TabEnter"))

      vim.cmd("tabprevious")
      local help_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = help_buf })
      vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf })
      vim.api.nvim_set_current_buf(help_buf)
      vim.wait(150)

      assert.is_true(state.tracker.suspended)
      assert.is_false(state.pad_state.enabled)

      vim.cmd("silent! tabonly")
    end)

    it("prunes callbacks when a tab is closed", function()
      local config1 = {
        ignore_filetypes = { "help" },
        ignore_buftypes = {},
        leftpad = 12,
        rightpad = 13,
      }
      enable_with_tracker(config1)

      vim.cmd("tabnew")
      local fresh_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = fresh_buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = fresh_buf })
      vim.api.nvim_set_current_buf(fresh_buf)
      local config2 = {
        ignore_filetypes = { "help" },
        ignore_buftypes = {},
        leftpad = 31,
        rightpad = 32,
      }
      centerpad.enable(config2)
      vim.wait(100)

      assert.are.equal(2, tracker_autocmd_count("BufEnter"))
      assert.are.equal(2, tracker_autocmd_count("WinEnter"))

      vim.cmd("tabclose")
      vim.wait(50)

      assert.are.equal(1, tracker_autocmd_count("BufEnter"))
      assert.are.equal(1, tracker_autocmd_count("WinEnter"))

      local help_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = help_buf })
      vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf })
      vim.api.nvim_set_current_buf(help_buf)
      vim.wait(150)

      assert.is_true(state.tracker.suspended)
    end)

    it("recovery replaces old callbacks with a fresh pair", function()
      local config = default_config()
      enable_with_tracker(config)

      local before_buf = tracker_ids("BufEnter")
      local before_win = tracker_ids("WinEnter")

      local left_buf = vim.api.nvim_win_get_buf(state.pad_state.left_win)
      vim.api.nvim_buf_set_var(left_buf, "is_centerpad", false)

      local split_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = split_buf })
      local split_win = vim.api.nvim_open_win(
        split_buf,
        false,
        { split = "right", win = state.pad_state.main_win }
      )
      vim.api.nvim_win_close(split_win, true)
      vim.wait(300)

      assert.is_true(state.pad_state.enabled)
      assert.is_true(window.are_pads_valid())
      assert.are.equal(1, tracker_autocmd_count("BufEnter"))
      assert.are.equal(1, tracker_autocmd_count("WinEnter"))

      local after_buf = tracker_ids("BufEnter")
      local after_win = tracker_ids("WinEnter")
      assert.are_not.equal(before_buf[1], after_buf[1])
      assert.are_not.equal(before_win[1], after_win[1])
    end)

    it("enable failure removes callbacks", function()
      local orig = window.create_pad_window
      window.create_pad_window = function()
        return nil
      end

      local config = default_config()
      local ok, err = pcall(centerpad.enable, config)
      vim.wait(100)

      window.create_pad_window = orig

      assert.is_true(ok, err)
      assert.is_false(state.pad_state.enabled)
      assert.is_false(state.tracker.opted_in)
      assert.are.equal(0, tracker_autocmd_count("BufEnter"))
      assert.are.equal(0, tracker_autocmd_count("WinEnter"))
      assert.are.equal(1, tracker_autocmd_count("TabEnter"))
    end)

    it("cancels pending timer on direct callback replacement", function()
      local config = default_config()
      enable_with_tracker(config)

      local fired = false
      state.tracker.debounce_timer = vim.fn.timer_start(1000, function()
        fired = true
      end)

      autocmds.setup_buffer_tracker(config, nil, function() end)
      vim.wait(50)

      assert.is_nil(state.tracker.debounce_timer)
      vim.wait(100)
      assert.is_false(fired)
    end)
  end)

  describe("stale deferred context event containment", function()
    local orig_timer_start
    local orig_timer_stop
    local timer_callbacks
    local stopped_timers
    local next_timer_id

    before_each(function()
      orig_timer_start = vim.fn.timer_start
      orig_timer_stop = vim.fn.timer_stop
      timer_callbacks = {}
      stopped_timers = {}
      next_timer_id = 0

      vim.fn.timer_start = function(_, cb)
        next_timer_id = next_timer_id + 1
        timer_callbacks[next_timer_id] = cb
        return next_timer_id
      end

      vim.fn.timer_stop = function(id)
        stopped_timers[id] = true
      end
    end)

    after_each(function()
      vim.fn.timer_start = orig_timer_start
      vim.fn.timer_stop = orig_timer_stop
    end)

    local function current_tab()
      local ok, t = state.get_current_tab()
      assert.is_true(ok)
      return t
    end

    it(
      "does not affect enabled sibling when deferred callback fires after tab switch",
      function()
        local config1 = {
          ignore_filetypes = { "help" },
          ignore_buftypes = {},
          leftpad = 12,
          rightpad = 13,
        }
        centerpad.enable(config1)
        vim.wait(50)

        -- Start a pending suspend debounce on tab 1.
        local help_buf1 = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf1 })
        vim.api.nvim_set_current_buf(help_buf1)

        local tab1 = current_tab()
        local tab1_pending_id = state._tracker_store(tab1).debounce_timer
        assert.is_not_nil(tab1_pending_id)

        -- Create enabled sibling tab 2.
        vim.cmd("tabnew")
        local fresh_buf2 = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = fresh_buf2 })
        vim.api.nvim_set_option_value("filetype", "", { buf = fresh_buf2 })
        vim.api.nvim_set_current_buf(fresh_buf2)
        local config2 = {
          ignore_filetypes = { "help" },
          ignore_buftypes = {},
          leftpad = 31,
          rightpad = 32,
        }
        centerpad.enable(config2)
        vim.wait(50)
        local tab2 = current_tab()

        -- Start distinct pending suspend debounce on tab 2.
        local nofile_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "nofile", { buf = nofile_buf })
        vim.api.nvim_set_current_buf(nofile_buf)
        local tab2_pending_id = state._tracker_store(tab2).debounce_timer
        assert.is_not_nil(tab2_pending_id)

        -- Fire tab 1's stale deferred callback while tab 2 is current.
        timer_callbacks[tab1_pending_id]()

        -- Tab 2's pending debounce and state must be untouched.
        assert.are.equal(
          tab2_pending_id,
          state._tracker_store(tab2).debounce_timer
        )
        assert.is_false(stopped_timers[tab2_pending_id] or false)
        assert.is_true(state.pad_state.enabled)
        assert.is_true(state.pads_exist())
        assert.is_false(state.tracker.suspended)
        assert.is_true(vim.g.centerpad_enabled)

        -- Tab 1 must also remain enabled; its stale callback did not run live.
        local tab1_state = state._get_pad_state(tab1)
        assert.is_true(tab1_state.enabled)
        assert.is_not_nil(tab1_state.left_win)
        assert.is_true(vim.api.nvim_win_is_valid(tab1_state.left_win))

        -- The stale callback should clear only its own fired timer slot.
        assert.is_nil(state._tracker_store(tab1).debounce_timer)

        vim.cmd("silent! tabonly")
      end
    )

    it(
      "does not affect surviving tab when deferred callback fires after owner close",
      function()
        local config1 = {
          ignore_filetypes = { "help" },
          ignore_buftypes = {},
          leftpad = 12,
          rightpad = 13,
        }
        centerpad.enable(config1)
        vim.wait(50)

        -- Start a pending suspend debounce on tab 1.
        local help_buf1 = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf1 })
        vim.api.nvim_set_current_buf(help_buf1)

        local tab1 = current_tab()
        local tab1_pending_id = state._tracker_store(tab1).debounce_timer
        assert.is_not_nil(tab1_pending_id)

        -- Create enabled sibling tab 2.
        vim.cmd("tabnew")
        local fresh_buf2 = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = fresh_buf2 })
        vim.api.nvim_set_option_value("filetype", "", { buf = fresh_buf2 })
        vim.api.nvim_set_current_buf(fresh_buf2)
        local config2 = {
          ignore_filetypes = { "help" },
          ignore_buftypes = {},
          leftpad = 31,
          rightpad = 32,
        }
        centerpad.enable(config2)
        vim.wait(50)
        local tab2 = current_tab()

        -- Start distinct pending suspend debounce on tab 2.
        local nofile_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "nofile", { buf = nofile_buf })
        vim.api.nvim_set_current_buf(nofile_buf)
        local tab2_pending_id = state._tracker_store(tab2).debounce_timer
        assert.is_not_nil(tab2_pending_id)

        -- Close tab 1 without leaving tab 2.
        local tab1_num = vim.api.nvim_tabpage_get_number(tab1)
        vim.cmd("tabclose " .. tab1_num)
        assert.are.equal(tab2, current_tab())

        -- Capture tab 2's current pending timer after the close ripple.
        local tab2_current_pending_id =
          state._tracker_store(tab2).debounce_timer
        assert.is_not_nil(tab2_current_pending_id)

        -- Fire the dead owner's deferred callback.
        timer_callbacks[tab1_pending_id]()

        -- Surviving tab must be untouched.
        assert.are.equal(
          tab2_current_pending_id,
          state._tracker_store(tab2).debounce_timer
        )
        assert.is_false(stopped_timers[tab2_current_pending_id] or false)
        assert.is_true(state.pad_state.enabled)
        assert.is_true(state.pads_exist())
        assert.is_false(state.tracker.suspended)
        assert.is_true(vim.g.centerpad_enabled)

        vim.cmd("silent! tabonly")
      end
    )

    it(
      "retains suspend and resume behavior for a live current owner",
      function()
        local config = default_config()
        centerpad.enable(config)
        vim.wait(50)

        -- Switch to ignored context to start a suspend debounce.
        local help_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf })
        vim.api.nvim_set_current_buf(help_buf)

        local tab = current_tab()
        local pending_id = state._tracker_store(tab).debounce_timer
        assert.is_not_nil(pending_id)

        -- Fire the debounce callback while the owner is still current.
        timer_callbacks[pending_id]()

        assert.is_true(state._tracker_store(tab).suspended)
        assert.is_false(state.pad_state.enabled)
        assert.is_nil(state._tracker_store(tab).debounce_timer)

        -- Return to a valid context to start a resume debounce.
        local normal_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = normal_buf })
        vim.api.nvim_set_option_value("filetype", "", { buf = normal_buf })
        vim.api.nvim_set_current_buf(normal_buf)

        local resume_id = state._tracker_store(tab).debounce_timer
        assert.is_not_nil(resume_id)

        -- Fire the resume debounce callback while the owner is current.
        timer_callbacks[resume_id]()

        assert.is_false(state._tracker_store(tab).suspended)
        assert.is_true(state.pad_state.enabled)
        assert.is_true(state.pads_exist())
        assert.is_nil(state._tracker_store(tab).debounce_timer)
      end
    )
  end)

  describe("TabClosed lifecycle pruning", function()
    local function tracker_autocmd_count(event)
      return #vim.api.nvim_get_autocmds({
        group = autocmds.centerpad_tracker,
        event = event,
      })
    end

    it(
      "removes closed non-current tab callbacks immediately on TabClosed",
      function()
        local config1 = {
          ignore_filetypes = { "help" },
          ignore_buftypes = {},
          leftpad = 12,
          rightpad = 13,
        }
        centerpad.enable(config1)
        vim.wait(50)
        local tab1 = vim.api.nvim_get_current_tabpage()

        vim.cmd("tabnew")
        local fresh_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = fresh_buf })
        vim.api.nvim_set_option_value("filetype", "", { buf = fresh_buf })
        vim.api.nvim_set_current_buf(fresh_buf)
        local config2 = {
          ignore_filetypes = { "help" },
          ignore_buftypes = {},
          leftpad = 31,
          rightpad = 32,
        }
        centerpad.enable(config2)
        vim.wait(50)
        local tab2 = vim.api.nvim_get_current_tabpage()

        -- Close the non-current owner tab from the live sibling.
        local tab1_num = vim.api.nvim_tabpage_get_number(tab1)
        vim.cmd("tabclose " .. tab1_num)

        -- Registrations for the closed tab must be gone before any later
        -- lifecycle event is dispatched.
        assert.are.equal(1, tracker_autocmd_count("BufEnter"))
        assert.are.equal(1, tracker_autocmd_count("WinEnter"))
        assert.are.equal(1, tracker_autocmd_count("TabEnter"))

        -- The live sibling must remain fully functional.
        assert.are.equal(tab2, vim.api.nvim_get_current_tabpage())
        assert.is_true(state.pad_state.enabled)
        assert.is_true(state.pads_exist())
        assert.is_false(state.tracker.suspended)
        assert.are.equal(31, state.tracker.config.leftpad)
        assert.are.equal(32, state.tracker.config.rightpad)

        -- Dispatch later lifecycle events; they must not alter the live tab.
        vim.api.nvim_exec_autocmds("BufEnter", {})
        vim.api.nvim_exec_autocmds("WinEnter", {})
        assert.is_true(state.pad_state.enabled)
        assert.is_false(state.tracker.suspended)

        -- The live sibling must still observe automatic context tracking.
        local help_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = help_buf })
        vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf })
        vim.api.nvim_set_current_buf(help_buf)
        vim.wait(150)
        assert.is_true(state.tracker.suspended)
        assert.is_false(state.pad_state.enabled)

        vim.cmd("silent! tabonly")
      end
    )

    it(
      "removes closed current tab callbacks and preserves the surviving sibling",
      function()
        local config1 = {
          ignore_filetypes = { "help" },
          ignore_buftypes = {},
          leftpad = 12,
          rightpad = 13,
        }
        centerpad.enable(config1)
        vim.wait(50)
        local tab1 = vim.api.nvim_get_current_tabpage()

        vim.cmd("tabnew")
        local fresh_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = fresh_buf })
        vim.api.nvim_set_option_value("filetype", "", { buf = fresh_buf })
        vim.api.nvim_set_current_buf(fresh_buf)
        local config2 = {
          ignore_filetypes = { "help" },
          ignore_buftypes = {},
          leftpad = 31,
          rightpad = 32,
        }
        centerpad.enable(config2)
        vim.wait(50)
        local tab2 = vim.api.nvim_get_current_tabpage()

        -- Switch to the owner tab and close it.
        vim.cmd("tabprevious")
        assert.are.equal(tab1, vim.api.nvim_get_current_tabpage())
        vim.cmd("tabclose")

        -- Surviving sibling registrations and state must remain intact.
        assert.are.equal(1, tracker_autocmd_count("BufEnter"))
        assert.are.equal(1, tracker_autocmd_count("WinEnter"))
        assert.are.equal(1, tracker_autocmd_count("TabEnter"))
        assert.are.equal(tab2, vim.api.nvim_get_current_tabpage())
        assert.is_false(vim.api.nvim_tabpage_is_valid(tab1))

        assert.is_true(state.pad_state.enabled)
        assert.is_true(state.pads_exist())
        assert.is_false(state.tracker.suspended)
        assert.are.equal(
          31,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          32,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )

        vim.cmd("silent! tabonly")
      end
    )
  end)
end)
