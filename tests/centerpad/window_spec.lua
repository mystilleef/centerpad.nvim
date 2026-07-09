describe("centerpad.window", function()
  local window
  local state

  before_each(function()
    -- Reload modules
    package.loaded["centerpad.state"] = nil
    package.loaded["centerpad.window"] = nil
    state = require("centerpad.state")
    window = require("centerpad.window")
    state.reset()
  end)

  after_each(function()
    -- Cleanup any created windows/buffers
    window.delete_pads()
  end)

  describe("is_pad_buffer()", function()
    it("should return false for invalid buffer", function()
      local result = window.is_pad_buffer(9999)
      assert.is_false(result)
    end)

    it("should return false for normal buffer", function()
      local buf = vim.api.nvim_create_buf(false, true)
      local result = window.is_pad_buffer(buf)
      assert.is_false(result)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should return true for pad buffer", function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_var(buf, "is_centerpad", true)
      local result = window.is_pad_buffer(buf)
      assert.is_true(result)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should return false for buffer with is_centerpad = false", function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_var(buf, "is_centerpad", false)
      local result = window.is_pad_buffer(buf)
      assert.is_false(result)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("set_current_window()", function()
    it("should set current window when valid", function()
      local buf = vim.api.nvim_create_buf(false, true)
      local win = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })

      window.set_current_window(win)
      assert.are.equal(win, vim.api.nvim_get_current_win())

      vim.api.nvim_win_close(win, true)
    end)

    it("should not error when window is invalid", function()
      -- Should not throw error
      window.set_current_window(9999)
    end)
  end)

  describe("create_pad_window()", function()
    it("should create a valid pad window", function()
      local win = window.create_pad_window("testpad", "left", 20)

      assert.is_not_nil(win)
      assert.is_true(vim.api.nvim_win_is_valid(win))

      -- Check buffer properties
      local buf = vim.api.nvim_win_get_buf(win)
      assert.is_true(window.is_pad_buffer(buf))

      -- Check window width
      local width = vim.api.nvim_win_get_width(win)
      assert.are.equal(20, width)

      -- Cleanup
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should mark buffer with metadata", function()
      local win = window.create_pad_window("testpad", "right", 25)
      local buf = vim.api.nvim_win_get_buf(win)

      local ok, is_centerpad =
        pcall(vim.api.nvim_buf_get_var, buf, "is_centerpad")
      assert.is_true(ok)
      assert.is_true(is_centerpad)

      local ok2, pad_side = pcall(vim.api.nvim_buf_get_var, buf, "pad_side")
      assert.is_true(ok2)
      assert.are.equal("right", pad_side)

      -- Cleanup
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should set correct buffer options", function()
      local win = window.create_pad_window("testpad", "left", 20)
      local buf = vim.api.nvim_win_get_buf(win)

      -- Check buffer options
      assert.are.equal(
        "nofile",
        vim.api.nvim_get_option_value("buftype", { buf = buf })
      )
      assert.is_false(
        vim.api.nvim_get_option_value("modifiable", { buf = buf })
      )
      assert.is_true(vim.api.nvim_get_option_value("readonly", { buf = buf }))
      assert.is_false(vim.api.nvim_get_option_value("buflisted", { buf = buf }))
      assert.are.equal(
        "wipe",
        vim.api.nvim_get_option_value("bufhidden", { buf = buf })
      )
      assert.is_false(vim.api.nvim_get_option_value("swapfile", { buf = buf }))
      assert.are.equal(
        "centerpad",
        vim.api.nvim_get_option_value("filetype", { buf = buf })
      )

      -- Cleanup
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should set correct window options", function()
      local win = window.create_pad_window("testpad", "left", 20)

      -- Check window options
      assert.is_true(
        vim.api.nvim_get_option_value("winfixwidth", { win = win })
      )

      local fixbuf_ok, fixbuf =
        pcall(vim.api.nvim_get_option_value, "winfixbuf", { win = win })
      if fixbuf_ok then
        assert.is_true(fixbuf)
      end

      local cfg = vim.api.nvim_win_get_config(win)
      assert.is_false(cfg.focusable)
      assert.are.equal("minimal", cfg.style)

      -- Cleanup
      local buf = vim.api.nvim_win_get_buf(win)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("are_pads_valid()", function()
    it(
      "should return true when both tracked pads are valid pad buffers",
      function()
        local left_win = window.create_pad_window("leftpad", "left", 20)
        local right_win = window.create_pad_window("rightpad", "right", 20)
        state.pad_state.left_win = left_win
        state.pad_state.right_win = right_win

        assert.is_true(window.are_pads_valid())

        vim.api.nvim_buf_delete(
          vim.api.nvim_win_get_buf(left_win),
          { force = true }
        )
        vim.api.nvim_buf_delete(
          vim.api.nvim_win_get_buf(right_win),
          { force = true }
        )
      end
    )

    it("should return false when left pad is missing", function()
      state.pad_state.left_win = nil
      state.pad_state.right_win =
        window.create_pad_window("rightpad", "right", 20)

      assert.is_false(window.are_pads_valid())

      vim.api.nvim_buf_delete(
        vim.api.nvim_win_get_buf(state.pad_state.right_win),
        { force = true }
      )
    end)

    it(
      "should return false when a tracked buffer is not a pad buffer",
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

        assert.is_false(window.are_pads_valid())

        vim.api.nvim_win_close(win1, true)
        vim.api.nvim_win_close(win2, true)
      end
    )
  end)

  describe("resize_pad()", function()
    it("should update pad width and preserve buffer", function()
      local win = window.create_pad_window("leftpad", "left", 20)
      local buf = vim.api.nvim_win_get_buf(win)
      state.pad_state.left_win = win

      local ok = window.resize_pad(win, 40)

      assert.is_true(ok)
      assert.are.equal(40, vim.api.nvim_win_get_width(win))
      assert.are.equal(buf, vim.api.nvim_win_get_buf(win))

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should return false for invalid window", function()
      assert.is_false(window.resize_pad(9999, 20))
    end)

    it("should return false for non-pad buffer", function()
      local buf = vim.api.nvim_create_buf(false, true)
      local win = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })

      assert.is_false(window.resize_pad(win, 20))

      vim.api.nvim_win_close(win, true)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("get_pad_width()", function()
    it("should return width for a valid pad window", function()
      local win = window.create_pad_window("leftpad", "left", 20)
      assert.are.equal(20, window.get_pad_width(win))

      local buf = vim.api.nvim_win_get_buf(win)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should return nil for an invalid window", function()
      assert.is_nil(window.get_pad_width(9999))
    end)

    it("should return nil for a non-pad buffer window", function()
      local buf = vim.api.nvim_create_buf(false, true)
      local win = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })

      assert.is_nil(window.get_pad_width(win))

      vim.api.nvim_win_close(win, true)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("delete_pads()", function()
    it("should delete tracked pad windows", function()
      -- Create pads
      local left_win = window.create_pad_window("leftpad", "left", 20)
      local right_win = window.create_pad_window("rightpad", "right", 20)

      state.pad_state.left_win = left_win
      state.pad_state.right_win = right_win

      local left_buf = vim.api.nvim_win_get_buf(left_win)
      local right_buf = vim.api.nvim_win_get_buf(right_win)

      -- Verify windows and buffers exist
      assert.is_true(vim.api.nvim_win_is_valid(left_win))
      assert.is_true(vim.api.nvim_win_is_valid(right_win))
      assert.is_true(vim.api.nvim_buf_is_valid(left_buf))
      assert.is_true(vim.api.nvim_buf_is_valid(right_buf))

      -- Delete pads
      window.delete_pads()

      -- Windows should be closed and buffers deleted
      assert.is_false(vim.api.nvim_win_is_valid(left_win))
      assert.is_false(vim.api.nvim_win_is_valid(right_win))
      assert.is_false(vim.api.nvim_buf_is_valid(left_buf))
      assert.is_false(vim.api.nvim_buf_is_valid(right_buf))

      -- State should be cleared
      assert.is_nil(state.pad_state.left_win)
      assert.is_nil(state.pad_state.right_win)
    end)

    it("should delete only left pad when only left exists", function()
      local left_win = window.create_pad_window("leftpad", "left", 20)
      state.pad_state.left_win = left_win
      state.pad_state.right_win = nil

      local left_buf = vim.api.nvim_win_get_buf(left_win)

      window.delete_pads()

      assert.is_false(vim.api.nvim_win_is_valid(left_win))
      assert.is_false(vim.api.nvim_buf_is_valid(left_buf))
      assert.is_nil(state.pad_state.left_win)
    end)

    it("should delete only right pad when only right exists", function()
      local right_win = window.create_pad_window("rightpad", "right", 20)
      state.pad_state.left_win = nil
      state.pad_state.right_win = right_win

      local right_buf = vim.api.nvim_win_get_buf(right_win)

      window.delete_pads()

      assert.is_false(vim.api.nvim_win_is_valid(right_win))
      assert.is_false(vim.api.nvim_buf_is_valid(right_buf))
      assert.is_nil(state.pad_state.right_win)
    end)

    it("should handle missing pads gracefully", function()
      state.pad_state.left_win = nil
      state.pad_state.right_win = nil

      -- Should not error
      window.delete_pads()

      assert.is_nil(state.pad_state.left_win)
      assert.is_nil(state.pad_state.right_win)
    end)

    it("should handle invalid window IDs gracefully", function()
      state.pad_state.left_win = 9999
      state.pad_state.right_win = 9998

      -- Should not error
      window.delete_pads()

      assert.is_nil(state.pad_state.left_win)
      assert.is_nil(state.pad_state.right_win)
    end)
  end)

  describe("save_global_settings()", function()
    it("should save fillchars", function()
      local original_fillchars = vim.o.fillchars
      state.saved_settings.fillchars = nil

      window.save_global_settings()

      assert.is_not_nil(state.saved_settings.fillchars)
      assert.are.equal(original_fillchars, state.saved_settings.fillchars)

      -- Cleanup
      state.saved_settings.fillchars = nil
    end)

    it("should not overwrite already saved settings", function()
      state.saved_settings.fillchars = "test_value"

      window.save_global_settings()

      assert.are.equal("test_value", state.saved_settings.fillchars)

      -- Cleanup
      state.saved_settings.fillchars = nil
    end)

    it("should save fillchars when initially nil", function()
      state.saved_settings.fillchars = nil
      local before = vim.o.fillchars

      window.save_global_settings()

      local saved = state.saved_settings.fillchars
      assert.is_not_nil(saved)
      assert.are.equal(before, saved)

      -- Cleanup
      state.saved_settings.fillchars = nil
    end)
  end)

  describe("restore_global_settings()", function()
    it("should restore fillchars when saved", function()
      local original = vim.o.fillchars
      state.saved_settings.fillchars = original
      -- Set to a valid fillchars value
      vim.o.fillchars = "vert:|"

      window.restore_global_settings()

      assert.are.equal(original, vim.o.fillchars)
      assert.is_nil(state.saved_settings.fillchars)
    end)

    it("should handle missing saved settings gracefully", function()
      state.saved_settings.fillchars = nil

      -- Should not error
      window.restore_global_settings()

      assert.is_nil(state.saved_settings.fillchars)
    end)

    it("should restore fillchars and clear saved value", function()
      local saved_value = "vert:|"
      state.saved_settings.fillchars = saved_value
      vim.o.fillchars = "eob: "

      window.restore_global_settings()

      assert.are.equal(saved_value, vim.o.fillchars)
      assert.is_nil(state.saved_settings.fillchars)
    end)

    it("should restore empty fillchars value", function()
      local original = vim.o.fillchars
      state.saved_settings.fillchars = ""
      vim.o.fillchars = "vert:|"

      window.restore_global_settings()

      assert.are.equal("", vim.o.fillchars)
      assert.is_nil(state.saved_settings.fillchars)

      -- Cleanup
      vim.o.fillchars = original
    end)

    it("should clear saved state when fillchars restore fails", function()
      state.saved_settings.fillchars = "invalid_fillchars_value"

      -- Should not error
      window.restore_global_settings()

      assert.is_nil(state.saved_settings.fillchars)
    end)

    it("should handle repeated restore calls without error", function()
      local original = vim.o.fillchars
      state.saved_settings.fillchars = original
      vim.o.fillchars = "vert:|"

      window.restore_global_settings()
      window.restore_global_settings()

      assert.are.equal(original, vim.o.fillchars)
      assert.is_nil(state.saved_settings.fillchars)
    end)
  end)
end)
