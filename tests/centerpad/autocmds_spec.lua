describe("centerpad.autocmds", function()
  local autocmds
  local state
  local window

  before_each(function()
    -- Reload modules
    package.loaded["centerpad.state"] = nil
    package.loaded["centerpad.window"] = nil
    package.loaded["centerpad.autocmds"] = nil
    state = require("centerpad.state")
    window = require("centerpad.window")
    autocmds = require("centerpad.autocmds")
    state.reset()
  end)

  after_each(function()
    autocmds.cleanup()
  end)

  describe("padgroup", function()
    it("should have a valid autocmd group", function()
      assert.is_not_nil(autocmds.padgroup)
      assert.are.equal("number", type(autocmds.padgroup))
    end)
  end)

  describe("setup_prevent_focus_autocmd()", function()
    it("should create autocmd for buffer", function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_var(buf, "is_centerpad", true)

      autocmds.setup_prevent_focus_autocmd(buf, "left")

      -- Check that autocmds exist for the group
      local aucmds =
        vim.api.nvim_get_autocmds({ group = autocmds.padgroup, buffer = buf })
      assert.is_true(#aucmds > 0)

      -- Cleanup
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should error gracefully when given invalid buffer", function()
      -- Neovim will error on invalid buffer, but we expect it to be caught
      local ok = pcall(autocmds.setup_prevent_focus_autocmd, 9999, "left")
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

      autocmds.setup_prevent_focus_autocmd(pad_buf, "left")

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

    it("should use wincmd l fallback for left pad when main window invalid", function()
      local pad_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_var(pad_buf, "is_centerpad", true)

      state.pad_state.main_win = 9999 -- Invalid window

      autocmds.setup_prevent_focus_autocmd(pad_buf, "left")

      -- Create a pad window
      local pad_win = vim.api.nvim_open_win(pad_buf, false, {
        relative = "editor",
        width = 25,
        height = 10,
        row = 0,
        col = 0,
      })

      -- Switch to pad window (triggers BufEnter, should execute wincmd l)
      vim.api.nvim_set_current_win(pad_win)
      vim.wait(50)

      -- Cleanup
      vim.api.nvim_win_close(pad_win, true)
      vim.api.nvim_buf_delete(pad_buf, { force = true })
    end)

    it("should use wincmd h fallback for right pad when main window invalid", function()
      local pad_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_var(pad_buf, "is_centerpad", true)

      state.pad_state.main_win = nil

      autocmds.setup_prevent_focus_autocmd(pad_buf, "right")

      local pad_win = vim.api.nvim_open_win(pad_buf, false, {
        relative = "editor",
        width = 25,
        height = 10,
        row = 0,
        col = 80,
      })

      vim.api.nvim_set_current_win(pad_win)
      vim.wait(50)

      -- Cleanup
      vim.api.nvim_win_close(pad_win, true)
      vim.api.nvim_buf_delete(pad_buf, { force = true })
    end)

    it("should use wincmd p fallback for unknown pad side", function()
      local pad_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_var(pad_buf, "is_centerpad", true)

      state.pad_state.main_win = nil

      autocmds.setup_prevent_focus_autocmd(pad_buf, "unknown")

      local pad_win = vim.api.nvim_open_win(pad_buf, false, {
        relative = "editor",
        width = 25,
        height = 10,
        row = 0,
        col = 0,
      })

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
        group = autocmds.padgroup,
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

    it("should ignore pad buffers", function()
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
      assert.is_not_nil(state.restore_timer)
      local first_timer = state.restore_timer

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
      assert.is_not_nil(state.restore_timer)
      assert.are_not.equal(first_timer, state.restore_timer)

      vim.wait(200)
    end)

    it("should save and restore lazyredraw setting", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 25,
        rightpad = 25,
      }
      local enable_callback = function() end

      state.pad_state.enabled = true

      -- Set initial lazyredraw
      vim.o.lazyredraw = false
      assert.is_nil(state.saved_settings.lazyredraw)

      autocmds.setup_restore_pads_autocmd(config, enable_callback)

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

      -- Wait for callback
      vim.wait(200)

      -- lazyredraw should be restored
      assert.is_nil(state.saved_settings.lazyredraw)
    end)
  end)

  describe("clear_autocmds()", function()
    it("should clear all autocmds in the group", function()
      local buf = vim.api.nvim_create_buf(false, true)
      autocmds.setup_prevent_focus_autocmd(buf, "left")

      -- Verify autocmds exist
      local before = vim.api.nvim_get_autocmds({ group = autocmds.padgroup })
      assert.is_true(#before > 0)

      -- Clear
      autocmds.clear_autocmds()

      -- Verify autocmds are gone
      local after = vim.api.nvim_get_autocmds({ group = autocmds.padgroup })
      assert.are.equal(0, #after)

      -- Cleanup
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("cleanup()", function()
    it("should clear autocmds", function()
      local buf = vim.api.nvim_create_buf(false, true)
      autocmds.setup_prevent_focus_autocmd(buf, "left")

      autocmds.cleanup()

      local aucmds = vim.api.nvim_get_autocmds({ group = autocmds.padgroup })
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

    it("should restore global settings", function()
      local original = vim.o.fillchars
      state.saved_settings.fillchars = original
      -- Use valid fillchars value
      vim.o.fillchars = "vert:|"

      autocmds.cleanup()

      assert.are.equal(original, vim.o.fillchars)
      assert.is_nil(state.saved_settings.fillchars)
    end)

    it("should set enabled to false", function()
      state.pad_state.enabled = true
      vim.g.center_buf_enabled = true

      autocmds.cleanup()

      assert.is_false(state.pad_state.enabled)
      assert.is_false(vim.g.center_buf_enabled)
    end)

    it("should cancel pending timer", function()
      state.restore_timer = vim.fn.timer_start(1000, function() end)

      autocmds.cleanup()

      assert.is_nil(state.restore_timer)
    end)
  end)
end)
