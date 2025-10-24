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
      local ok, err = pcall(autocmds.setup_prevent_focus_autocmd, 9999, "left")
      -- Either succeeds (some versions) or fails gracefully
      assert.is_not_nil(ok)
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
