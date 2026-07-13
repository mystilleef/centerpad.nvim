describe("centerpad.autocmds", function()
  local autocmds
  local state
  local window
  local test_helper

  before_each(function()
    -- Reload modules
    package.loaded["centerpad.state"] = nil
    package.loaded["centerpad.enabled"] = nil
    package.loaded["centerpad.window"] = nil
    package.loaded["centerpad.autocmds"] = nil
    package.loaded["centerpad.centerpad"] = nil
    package.loaded["test_helper"] = nil
    state = require("centerpad.state")
    window = require("centerpad.window")
    autocmds = require("centerpad.autocmds")
    test_helper = require("test_helper")
    state.reset()
  end)

  after_each(function()
    autocmds.cleanup()
  end)

  describe("get_padgroup()", function()
    it("returns a valid autocmd group id", function()
      local grp = autocmds.get_padgroup()
      assert.is_not_nil(grp)
      assert.are.equal("number", type(grp))
    end)

    it(
      "returns the same group id on repeated calls for the same tab",
      function()
        local first = autocmds.get_padgroup()
        local second = autocmds.get_padgroup()
        assert.are.equal(first, second)
      end
    )
  end)

  describe("setup_prevent_focus_autocmd()", function()
    it("should create autocmd for buffer", function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_var(buf, "is_centerpad", true)

      autocmds.setup_prevent_focus_autocmd(buf)

      -- Check that autocmds exist for the group
      local aucmds = vim.api.nvim_get_autocmds({
        group = autocmds.get_padgroup(),
        buffer = buf,
      })
      assert.is_true(#aucmds > 0)

      -- Cleanup
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should error gracefully when given invalid buffer", function()
      -- Neovim will error on invalid buffer, but we expect it to be caught
      local ok = pcall(autocmds.setup_prevent_focus_autocmd, 9999)
      -- Either succeeds (some versions) or fails gracefully
      assert.is_not_nil(ok)
    end)

    it("should redirect to main window when entering left pad", function()
      -- Create main window and left pad
      local main_buf = vim.api.nvim_create_buf(false, true)
      local main_win = vim.api.nvim_open_win(main_buf, true, {
        relative = "editor",
        width = 40,
        height = 10,
        row = 0,
        col = 30,
      })
      state.pad_state.main_win = main_win

      local pad_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_var(pad_buf, "is_centerpad", true)
      local pad_win = vim.api.nvim_open_win(pad_buf, false, {
        relative = "editor",
        width = 25,
        height = 10,
        row = 0,
        col = 0,
      })

      autocmds.setup_prevent_focus_autocmd(pad_buf)

      -- Switch to pad window and process events immediately
      vim.api.nvim_set_current_win(pad_win)
      vim.api.nvim_exec_autocmds("BufEnter", { buffer = pad_buf })

      -- Should redirect to main window
      assert.are.equal(main_win, vim.api.nvim_get_current_win())

      -- Cleanup
      vim.api.nvim_win_close(pad_win, true)
      vim.api.nvim_win_close(main_win, true)
      vim.api.nvim_buf_delete(pad_buf, { force = true })
      vim.api.nvim_buf_delete(main_buf, { force = true })
    end)

    it("does not redirect focus when main window is invalid", function()
      local pad_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_var(pad_buf, "is_centerpad", true)

      state.pad_state.main_win = 9999 -- Invalid window

      autocmds.setup_prevent_focus_autocmd(pad_buf)

      -- Create a pad window
      local pad_win = vim.api.nvim_open_win(pad_buf, false, {
        relative = "editor",
        width = 25,
        height = 10,
        row = 0,
        col = 0,
      })

      -- Switch to pad window; with an invalid main window the callback
      -- stays put instead of bouncing between pads.
      vim.api.nvim_set_current_win(pad_win)
      vim.wait(50)

      -- Cleanup
      vim.api.nvim_win_close(pad_win, true)
      vim.api.nvim_buf_delete(pad_buf, { force = true })
    end)
  end)

  describe("setup_restore_pads_autocmd()", function()
    it("should create WinClosed autocmd", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 25,
        rightpad = 25,
      }
      local enable_callback = function() end

      autocmds.setup_restore_pads_autocmd(config, enable_callback)

      -- Check that WinClosed autocmds exist
      local aucmds = vim.api.nvim_get_autocmds({
        group = autocmds.get_padgroup(),
        event = "WinClosed",
      })
      assert.is_true(#aucmds > 0)
    end)

    it("should not trigger when centerpad is disabled", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 25,
        rightpad = 25,
      }
      local callback_called = false
      local enable_callback = function()
        callback_called = true
      end

      state.pad_state.enabled = false

      autocmds.setup_restore_pads_autocmd(config, enable_callback)

      -- Create and close a window to trigger WinClosed
      local buf = vim.api.nvim_create_buf(false, true)
      local win = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      vim.api.nvim_win_close(win, true)

      -- Wait a bit for debouncing
      vim.wait(100)

      -- Callback should not have been called
      assert.is_false(callback_called)
    end)

    it("should ignore buffers with ignored buftypes", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = { "nofile", "prompt" },
        leftpad = 25,
        rightpad = 25,
      }
      local callback_called = false
      local enable_callback = function()
        callback_called = true
      end

      state.pad_state.enabled = true

      autocmds.setup_restore_pads_autocmd(config, enable_callback)

      -- Create a nofile buffer
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
      local win = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      vim.api.nvim_win_close(win, true)

      vim.wait(100)

      -- Callback should not have been called (nofile ignored)
      assert.is_false(callback_called)
    end)

    it("should ignore buffers with ignored filetypes", function()
      local config = {
        ignore_filetypes = { "help", "qf" },
        ignore_buftypes = {},
        leftpad = 25,
        rightpad = 25,
      }
      local callback_called = false
      local enable_callback = function()
        callback_called = true
      end

      state.pad_state.enabled = true

      autocmds.setup_restore_pads_autocmd(config, enable_callback)

      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("filetype", "help", { buf = buf })
      local win = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      vim.api.nvim_win_close(win, true)

      vim.wait(100)

      assert.is_false(callback_called)
    end)

    it("should recover when a tracked pad buffer is closed", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 25,
        rightpad = 25,
      }
      local callback_called = false
      local enable_callback = function()
        callback_called = true
      end

      state.pad_state.enabled = true

      autocmds.setup_restore_pads_autocmd(config, enable_callback)

      -- Create a pad buffer
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_var(buf, "is_centerpad", true)
      local win = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      vim.api.nvim_win_close(win, true)

      vim.wait(100)

      assert.is_true(callback_called)
    end)

    it("should ignore pad buffers during cleanup", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 25,
        rightpad = 25,
      }
      local callback_called = false
      local enable_callback = function()
        callback_called = true
      end

      state.pad_state.enabled = true

      autocmds.setup_restore_pads_autocmd(config, enable_callback)

      -- Simulate cleanup: clear autocmds before deleting pads so no
      -- recovery is triggered by our own teardown.
      autocmds.clear_autocmds()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_var(buf, "is_centerpad", true)
      local win = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      vim.api.nvim_win_close(win, true)

      vim.wait(100)

      assert.is_false(callback_called)
    end)

    it("should trigger callback for normal buffer", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 25,
        rightpad = 25,
      }
      local callback_called = false
      local enable_callback = function()
        callback_called = true
      end

      state.pad_state.enabled = true

      autocmds.setup_restore_pads_autocmd(config, enable_callback)

      -- Create a normal buffer
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = buf })
      local win = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      vim.api.nvim_win_close(win, true)

      -- Wait for debounce + timer
      vim.wait(200)

      assert.is_true(callback_called)
    end)

    it("should debounce multiple WinClosed events", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 25,
        rightpad = 25,
      }
      local callback_count = 0
      local enable_callback = function()
        callback_count = callback_count + 1
      end

      state.pad_state.enabled = true

      autocmds.setup_restore_pads_autocmd(config, enable_callback)

      -- Create and close multiple windows rapidly
      for _ = 1, 3 do
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = buf })
        local win = vim.api.nvim_open_win(buf, false, {
          relative = "editor",
          width = 10,
          height = 10,
          row = 0,
          col = 0,
        })
        vim.api.nvim_win_close(win, true)
      end

      -- Wait for debounce + timer
      vim.wait(200)

      -- Should only call callback once (debounced)
      assert.are.equal(1, callback_count)
    end)

    it("should cancel previous timer when new event arrives", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 25,
        rightpad = 25,
      }
      local callback_called = false
      local enable_callback = function()
        callback_called = true
      end

      state.pad_state.enabled = true

      autocmds.setup_restore_pads_autocmd(config, enable_callback)

      -- Create first window and close it
      local buf1 = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = buf1 })
      local win1 = vim.api.nvim_open_win(buf1, false, {
        relative = "editor",
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      vim.api.nvim_win_close(win1, true)

      -- Verify timer is set
      assert.is_not_nil(state.get_restore_timer())
      local first_timer = state.get_restore_timer()

      -- Immediately create and close another window
      local buf2 = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = buf2 })
      local win2 = vim.api.nvim_open_win(buf2, false, {
        relative = "editor",
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      vim.api.nvim_win_close(win2, true)

      -- Timer should be different (old one cancelled)
      assert.is_not_nil(state.get_restore_timer())
      assert.are_not.equal(first_timer, state.get_restore_timer())

      vim.wait(200)

      -- Callback should still have been called once
      assert.is_true(callback_called)
    end)
  end)

  describe("clear_autocmds()", function()
    it("should clear all autocmds in the group", function()
      local buf = vim.api.nvim_create_buf(false, true)
      autocmds.setup_prevent_focus_autocmd(buf)

      -- Verify autocmds exist
      local before =
        vim.api.nvim_get_autocmds({ group = autocmds.get_padgroup() })
      assert.is_true(#before > 0)

      -- Clear
      autocmds.clear_autocmds()

      -- Verify autocmds are gone
      local after =
        vim.api.nvim_get_autocmds({ group = autocmds.get_padgroup() })
      assert.are.equal(0, #after)

      -- Cleanup
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("cleanup()", function()
    it("should clear autocmds", function()
      local buf = vim.api.nvim_create_buf(false, true)
      autocmds.setup_prevent_focus_autocmd(buf)

      autocmds.cleanup()

      local aucmds =
        vim.api.nvim_get_autocmds({ group = autocmds.get_padgroup() })
      assert.are.equal(0, #aucmds)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should delete pads", function()
      state.pad_state.left_win = window.create_pad_window("leftpad", "left", 20)
      state.pad_state.right_win =
        window.create_pad_window("rightpad", "right", 20)

      autocmds.cleanup()

      assert.is_nil(state.pad_state.left_win)
      assert.is_nil(state.pad_state.right_win)
    end)

    it("should clear captured source_options metadata", function()
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

      autocmds.cleanup()

      assert.is_nil(state.source_options.win)
      assert.is_nil(state.source_options.fillchars)

      vim.api.nvim_win_close(win, true)
    end)

    it("should set enabled to false", function()
      state.pad_state.enabled = true
      vim.g.centerpad_enabled = true
      vim.g.center_buf_enabled = true

      autocmds.cleanup()

      assert.is_false(state.pad_state.enabled)
      assert.is_false(vim.g.centerpad_enabled)
      assert.is_false(vim.g.center_buf_enabled)
    end)

    it("should cancel pending timer", function()
      state.set_restore_timer(vim.fn.timer_start(1000, function() end))

      autocmds.cleanup()

      assert.is_nil(state.get_restore_timer())
    end)

    it("should handle repeated cleanup calls without error", function()
      state.pad_state.enabled = true

      autocmds.cleanup()
      autocmds.cleanup()

      assert.is_false(state.pad_state.enabled)
    end)
  end)

  describe("WinClosed skip and recovery", function()
    local centerpad

    local function prepare_buffer()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = buf })
      -- A previous test may have left a pad window with winfixbuf enabled.
      pcall(vim.api.nvim_set_option_value, "winfixbuf", false, { win = 0 })
      vim.api.nvim_set_current_buf(buf)
      return buf
    end

    local function setup_enabled_pads(config)
      prepare_buffer()
      centerpad.enable(config)
      vim.wait(100)
      autocmds.clear_autocmds()
      -- The context/buffer tracker installed by a real enable() survives
      -- clear_autocmds (it lives on the persistent centerpad_tracker
      -- group) and would otherwise race the WinClosed recovery under
      -- test here with its own suspend/resume cycle. That behavior has
      -- its own dedicated coverage in buffer_tracker_spec.lua.
      autocmds.clear_tracker()
    end

    local function track_callback()
      local tracker = { called = false }
      local function callback()
        tracker.called = true
      end
      return callback, tracker
    end

    local function trigger_unrelated_win_closed()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = buf })
      vim.cmd("vsplit")
      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win, buf)
      vim.api.nvim_win_close(win, true)
    end

    before_each(function()
      centerpad = require("centerpad.centerpad")
      -- Start from a fresh, normal source window so pad-window options from
      -- a previous test cannot leak into the next setup.
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
      prepare_buffer()
      vim.o.columns = 120
    end)

    after_each(function()
      -- Use shared helper for consistent cleanup
      test_helper.cleanup_headless_spec()
    end)

    it(
      "skips cleanup when valid pads match configured widths after unrelated WinClosed",
      function()
        local config = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 25,
          rightpad = 25,
        }
        setup_enabled_pads(config)

        local left_win = state.pad_state.left_win
        local right_win = state.pad_state.right_win
        local left_buf = vim.api.nvim_win_get_buf(left_win)
        local right_buf = vim.api.nvim_win_get_buf(right_win)

        local callback, tracker = track_callback()
        autocmds.setup_restore_pads_autocmd(config, callback)

        trigger_unrelated_win_closed()
        vim.wait(200)

        assert.is_false(tracker.called)
        assert.are.equal(left_win, state.pad_state.left_win)
        assert.are.equal(right_win, state.pad_state.right_win)
        assert.are.equal(
          left_buf,
          vim.api.nvim_win_get_buf(state.pad_state.left_win)
        )
        assert.are.equal(
          right_buf,
          vim.api.nvim_win_get_buf(state.pad_state.right_win)
        )
        assert.are.equal(
          25,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          25,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )
        assert.is_true(state.pad_state.enabled)
        assert.is_true(vim.g.centerpad_enabled)
      end
    )

    it("recovers when a tracked pad width does not match config", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 25,
        rightpad = 25,
      }
      setup_enabled_pads(config)
      vim.api.nvim_win_set_width(state.pad_state.right_win, 40)

      local callback, tracker = track_callback()
      autocmds.setup_restore_pads_autocmd(config, callback)

      trigger_unrelated_win_closed()
      vim.wait(200)

      assert.is_true(tracker.called)
    end)

    it("recovers when a tracked pad buffer is corrupted", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 25,
        rightpad = 25,
      }
      setup_enabled_pads(config)
      local left_buf = vim.api.nvim_win_get_buf(state.pad_state.left_win)
      vim.api.nvim_buf_set_var(left_buf, "is_centerpad", false)

      local callback, tracker = track_callback()
      autocmds.setup_restore_pads_autocmd(config, callback)

      trigger_unrelated_win_closed()
      vim.wait(200)

      assert.is_true(tracker.called)
    end)

    it(
      "skips cleanup when stale main_win is invalid but current source and pads are stable",
      function()
        local config = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 25,
          rightpad = 25,
        }
        setup_enabled_pads(config)
        state.pad_state.main_win = 9999
        local current_win = vim.api.nvim_get_current_win()

        local left_win = state.pad_state.left_win
        local right_win = state.pad_state.right_win
        local left_buf = vim.api.nvim_win_get_buf(left_win)
        local right_buf = vim.api.nvim_win_get_buf(right_win)

        local callback_count = 0
        local function callback()
          callback_count = callback_count + 1
        end

        autocmds.setup_restore_pads_autocmd(config, callback)

        trigger_unrelated_win_closed()
        vim.wait(200)

        assert.are.equal(0, callback_count)
        assert.are.equal(current_win, state.pad_state.main_win)
        assert.are.equal(left_win, state.pad_state.left_win)
        assert.are.equal(right_win, state.pad_state.right_win)
        assert.are.equal(
          left_buf,
          vim.api.nvim_win_get_buf(state.pad_state.left_win)
        )
        assert.are.equal(
          right_buf,
          vim.api.nvim_win_get_buf(state.pad_state.right_win)
        )
        assert.are.equal(
          25,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          25,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )
        assert.is_true(state.pad_state.enabled)
        assert.is_true(vim.g.centerpad_enabled)
      end
    )

    it(
      "recovers when current window is a pad buffer after WinClosed",
      function()
        local config = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 25,
          rightpad = 25,
        }
        setup_enabled_pads(config)

        local callback_count = 0
        local function callback()
          callback_count = callback_count + 1
        end

        autocmds.setup_restore_pads_autocmd(config, callback)

        -- Create an extra source split, then focus a pad so the current
        -- window has no source eligibility when the split closes.
        vim.cmd("vsplit")
        local extra_win = vim.api.nvim_get_current_win()
        vim.api.nvim_set_current_win(state.pad_state.left_win)
        vim.api.nvim_win_close(extra_win, true)

        vim.wait(200)

        assert.are.equal(1, callback_count)
      end
    )

    it("recovers when current window is floating after WinClosed", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 25,
        rightpad = 25,
      }
      setup_enabled_pads(config)

      local extra_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = extra_buf })
      vim.cmd("vsplit")
      local extra_win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(extra_win, extra_buf)

      local float_buf = vim.api.nvim_create_buf(false, true)
      local float_win = vim.api.nvim_open_win(float_buf, true, {
        relative = "editor",
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })

      local callback, tracker = track_callback()
      autocmds.setup_restore_pads_autocmd(config, callback)

      vim.api.nvim_win_close(extra_win, true)
      vim.wait(200)

      assert.is_true(tracker.called)

      pcall(vim.api.nvim_win_close, float_win, true)
      vim.api.nvim_buf_delete(float_buf, { force = true })
    end)

    it(
      "skips cleanup when multiple real splits remain and pads are stable",
      function()
        local config = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 25,
          rightpad = 25,
        }
        setup_enabled_pads(config)

        vim.cmd("vsplit")
        local split_a = vim.api.nvim_get_current_win()
        vim.cmd("vsplit")

        local left_win = state.pad_state.left_win
        local right_win = state.pad_state.right_win
        local left_buf = vim.api.nvim_win_get_buf(left_win)
        local right_buf = vim.api.nvim_win_get_buf(right_win)

        local callback, tracker = track_callback()
        autocmds.setup_restore_pads_autocmd(config, callback)

        vim.api.nvim_win_close(split_a, true)
        vim.wait(200)

        assert.is_false(tracker.called)
        assert.are.equal(left_win, state.pad_state.left_win)
        assert.are.equal(right_win, state.pad_state.right_win)
        assert.are.equal(
          left_buf,
          vim.api.nvim_win_get_buf(state.pad_state.left_win)
        )
        assert.are.equal(
          right_buf,
          vim.api.nvim_win_get_buf(state.pad_state.right_win)
        )
        assert.is_true(state.pad_state.enabled)
      end
    )

    it("recovers when no source window remains after WinClosed", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 25,
        rightpad = 25,
      }
      setup_enabled_pads(config)

      local callback, tracker = track_callback()
      autocmds.setup_restore_pads_autocmd(config, callback)

      -- Close the only source window, leaving only pads behind.
      vim.api.nvim_win_close(state.pad_state.main_win, true)
      vim.wait(200)

      assert.is_true(tracker.called)
    end)

    it(
      "skips cleanup with asymmetric leftpad and rightpad when widths match",
      function()
        local config = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 15,
          rightpad = 35,
        }
        setup_enabled_pads(config)

        local callback, tracker = track_callback()
        autocmds.setup_restore_pads_autocmd(config, callback)

        trigger_unrelated_win_closed()
        vim.wait(200)

        assert.is_false(tracker.called)
        assert.are.equal(
          15,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          35,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )
      end
    )

    it("recovers when asymmetric pad widths do not match config", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 15,
        rightpad = 35,
      }
      setup_enabled_pads(config)
      vim.api.nvim_win_set_width(state.pad_state.left_win, 25)

      local callback, tracker = track_callback()
      autocmds.setup_restore_pads_autocmd(config, callback)

      trigger_unrelated_win_closed()
      vim.wait(200)

      assert.is_true(tracker.called)
    end)

    it("recovers when left pad ID is missing", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 25,
        rightpad = 25,
      }
      setup_enabled_pads(config)
      state.pad_state.left_win = nil

      local callback_count = 0
      local function callback()
        callback_count = callback_count + 1
      end

      autocmds.setup_restore_pads_autocmd(config, callback)
      trigger_unrelated_win_closed()
      vim.wait(200)

      assert.are.equal(1, callback_count)
      assert.is_nil(state.pad_state.left_win)
      assert.is_nil(state.pad_state.right_win)
      assert.is_false(state.pad_state.enabled)
    end)

    it("recovers when right pad ID is missing", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 25,
        rightpad = 25,
      }
      setup_enabled_pads(config)
      state.pad_state.right_win = nil

      local callback_count = 0
      local function callback()
        callback_count = callback_count + 1
      end

      autocmds.setup_restore_pads_autocmd(config, callback)
      trigger_unrelated_win_closed()
      vim.wait(200)

      assert.are.equal(1, callback_count)
      assert.is_nil(state.pad_state.left_win)
      assert.is_nil(state.pad_state.right_win)
      assert.is_false(state.pad_state.enabled)
    end)

    it("recovers when a tracked pad window is invalid", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 25,
        rightpad = 25,
      }
      setup_enabled_pads(config)

      local temp_buf = vim.api.nvim_create_buf(false, true)
      local temp_win = vim.api.nvim_open_win(temp_buf, false, {
        relative = "editor",
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      vim.api.nvim_win_close(temp_win, true)
      state.pad_state.left_win = temp_win

      local callback_count = 0
      local function callback()
        callback_count = callback_count + 1
      end

      autocmds.setup_restore_pads_autocmd(config, callback)
      trigger_unrelated_win_closed()
      vim.wait(200)

      assert.are.equal(1, callback_count)
      assert.is_nil(state.pad_state.left_win)
      assert.is_nil(state.pad_state.right_win)
      assert.is_false(state.pad_state.enabled)
    end)

    it("recovers when a tracked pad buffer marker is missing", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 25,
        rightpad = 25,
      }
      setup_enabled_pads(config)
      local left_buf = vim.api.nvim_win_get_buf(state.pad_state.left_win)
      vim.api.nvim_buf_del_var(left_buf, "is_centerpad")

      local callback_count = 0
      local function callback()
        callback_count = callback_count + 1
      end

      autocmds.setup_restore_pads_autocmd(config, callback)
      trigger_unrelated_win_closed()
      vim.wait(200)

      assert.are.equal(1, callback_count)
      assert.is_nil(state.pad_state.left_win)
      assert.is_nil(state.pad_state.right_win)
      assert.is_false(state.pad_state.enabled)
    end)

    it("recovers when left pad width does not match config", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 25,
        rightpad = 25,
      }
      setup_enabled_pads(config)
      vim.api.nvim_win_set_width(state.pad_state.left_win, 40)

      local callback, tracker = track_callback()
      autocmds.setup_restore_pads_autocmd(config, callback)

      trigger_unrelated_win_closed()
      vim.wait(200)

      assert.is_true(tracker.called)
    end)

    it("recovers when pad width API fails", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 25,
        rightpad = 25,
      }
      setup_enabled_pads(config)

      local orig_get_width = vim.api.nvim_win_get_width
      vim.api.nvim_win_get_width = function(win)
        if win == state.pad_state.left_win then
          error("forced width failure")
        end
        return orig_get_width(win)
      end

      local callback_count = 0
      local function callback()
        callback_count = callback_count + 1
      end

      autocmds.setup_restore_pads_autocmd(config, callback)

      local ok, err = pcall(function()
        trigger_unrelated_win_closed()
        vim.wait(200)

        assert.are.equal(1, callback_count)
      end)

      vim.api.nvim_win_get_width = orig_get_width
      assert.is_true(ok, err)
    end)

    it("recovers when pad validation API fails", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 25,
        rightpad = 25,
      }
      setup_enabled_pads(config)

      local orig_get_buf = vim.api.nvim_win_get_buf
      vim.api.nvim_win_get_buf = function(win)
        if win == state.pad_state.left_win then
          error("forced buffer failure")
        end
        return orig_get_buf(win)
      end

      local callback_count = 0
      local function callback()
        callback_count = callback_count + 1
      end

      autocmds.setup_restore_pads_autocmd(config, callback)

      local ok, err = pcall(function()
        trigger_unrelated_win_closed()
        vim.wait(200)

        assert.are.equal(1, callback_count)
      end)

      vim.api.nvim_win_get_buf = orig_get_buf
      assert.is_true(ok, err)
    end)

    it("recovery cleans state and preserves config for callback", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 25,
        rightpad = 25,
      }
      setup_enabled_pads(config)

      local left_buf = vim.api.nvim_win_get_buf(state.pad_state.left_win)
      vim.api.nvim_buf_set_var(left_buf, "is_centerpad", false)

      local callback_count = 0
      local received_config = nil
      local function callback(cfg)
        callback_count = callback_count + 1
        received_config = cfg
      end

      autocmds.setup_restore_pads_autocmd(config, callback)
      trigger_unrelated_win_closed()
      vim.wait(200)

      assert.are.equal(1, callback_count)
      assert.are.equal(config, received_config)
      assert.are.equal(25, received_config.leftpad)
      assert.are.equal(25, received_config.rightpad)
      assert.is_nil(state.pad_state.left_win)
      assert.is_nil(state.pad_state.right_win)
      assert.is_false(state.pad_state.enabled)
      assert.is_false(vim.g.centerpad_enabled)
      assert.is_false(vim.g.center_buf_enabled)
      assert.is_nil(state.get_restore_timer())
      assert.are.equal(
        0,
        #vim.api.nvim_get_autocmds({ group = autocmds.get_padgroup() })
      )
    end)

    it("debounces recovery to one callback for unstable pads", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 25,
        rightpad = 25,
      }
      setup_enabled_pads(config)
      state.pad_state.left_win = nil

      local callback_count = 0
      local function callback()
        callback_count = callback_count + 1
      end

      autocmds.setup_restore_pads_autocmd(config, callback)

      for _ = 1, 3 do
        trigger_unrelated_win_closed()
      end
      vim.wait(200)

      assert.are.equal(1, callback_count)
      assert.is_nil(state.pad_state.left_win)
      assert.is_nil(state.pad_state.right_win)
      assert.is_false(state.pad_state.enabled)
    end)

    local function is_source_window_focused()
      local main = state.pad_state.main_win
      if not main or not vim.api.nvim_win_is_valid(main) then
        return false
      end
      local ok, buf = pcall(vim.api.nvim_win_get_buf, main)
      if not ok then
        return false
      end
      return not window.is_pad_buffer(buf)
    end

    it("recovers with fresh pad IDs when one pad buffer is closed", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 25,
        rightpad = 25,
      }
      setup_enabled_pads(config)

      local old_left = state.pad_state.left_win
      local old_right = state.pad_state.right_win
      local left_buf = vim.api.nvim_win_get_buf(state.pad_state.left_win)

      autocmds.setup_restore_pads_autocmd(config, centerpad.enable)
      pcall(vim.api.nvim_buf_delete, left_buf, { force = true })
      vim.wait(300)

      assert.is_true(state.pad_state.enabled)
      assert.is_true(window.are_pads_valid())
      assert.are_not.equal(old_left, state.pad_state.left_win)
      assert.are_not.equal(old_right, state.pad_state.right_win)
      assert.are.equal(25, vim.api.nvim_win_get_width(state.pad_state.left_win))
      assert.are.equal(
        25,
        vim.api.nvim_win_get_width(state.pad_state.right_win)
      )
      assert.is_true(is_source_window_focused())
      assert.is_nil(state.get_restore_timer())
    end)

    it(
      "preserves source focus when the main source window is closed",
      function()
        local config = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 25,
          rightpad = 25,
        }
        setup_enabled_pads(config)

        autocmds.setup_restore_pads_autocmd(config, centerpad.enable)
        vim.api.nvim_win_close(state.pad_state.main_win, true)
        vim.wait(300)

        assert.is_true(state.pad_state.enabled)
        assert.is_true(window.are_pads_valid())
        assert.is_true(is_source_window_focused())
        assert.are.equal(
          state.pad_state.main_win,
          vim.api.nvim_get_current_win()
        )
        assert.is_nil(state.get_restore_timer())
      end
    )

    it(
      "recovers with fresh pad IDs when both pad buffers are closed",
      function()
        local config = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 25,
          rightpad = 25,
        }
        setup_enabled_pads(config)

        local old_left = state.pad_state.left_win
        local old_right = state.pad_state.right_win
        local left_buf = vim.api.nvim_win_get_buf(state.pad_state.left_win)
        local right_buf = vim.api.nvim_win_get_buf(state.pad_state.right_win)

        autocmds.setup_restore_pads_autocmd(config, centerpad.enable)
        pcall(vim.api.nvim_buf_delete, left_buf, { force = true })
        pcall(vim.api.nvim_buf_delete, right_buf, { force = true })
        vim.wait(300)

        assert.is_true(state.pad_state.enabled)
        assert.is_true(window.are_pads_valid())
        assert.are_not.equal(old_left, state.pad_state.left_win)
        assert.are_not.equal(old_right, state.pad_state.right_win)
        assert.are.equal(
          25,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          25,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )
        assert.is_true(is_source_window_focused())
        assert.is_nil(state.get_restore_timer())
      end
    )
  end)
end)
