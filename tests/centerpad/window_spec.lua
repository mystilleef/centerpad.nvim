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
      assert.is_false(window.is_pad_buffer(9999))
    end)

    it("should return false for normal buffer", function()
      local buf = vim.api.nvim_create_buf(false, true)
      assert.is_false(window.is_pad_buffer(buf))
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should return true for pad buffer", function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_var(buf, "is_centerpad", true)
      assert.is_true(window.is_pad_buffer(buf))
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

      -- Cleanup
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should set correct window options", function()
      local win = window.create_pad_window("testpad", "left", 20)

      -- Check window options
      assert.is_true(
        vim.api.nvim_get_option_value("winfixwidth", { win = win })
      )

      -- Cleanup
      local buf = vim.api.nvim_win_get_buf(win)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("delete_pads()", function()
    it("should delete tracked pad windows", function()
      -- Create pads
      state.pad_state.left_win = window.create_pad_window("leftpad", "left", 20)
      state.pad_state.right_win =
        window.create_pad_window("rightpad", "right", 20)

      local left_win = state.pad_state.left_win
      local right_win = state.pad_state.right_win
      local left_buf, right_buf

      if left_win then
        left_buf = vim.api.nvim_win_get_buf(left_win)
      end
      if right_win then
        right_buf = vim.api.nvim_win_get_buf(right_win)
      end

      -- Delete pads
      window.delete_pads()

      -- Windows should be closed and buffers deleted
      if left_win then
        assert.is_false(vim.api.nvim_win_is_valid(left_win))
      end
      if right_win then
        assert.is_false(vim.api.nvim_win_is_valid(right_win))
      end
      if left_buf then
        assert.is_false(vim.api.nvim_buf_is_valid(left_buf))
      end
      if right_buf then
        assert.is_false(vim.api.nvim_buf_is_valid(right_buf))
      end

      -- State should be cleared
      assert.is_nil(state.pad_state.left_win)
      assert.is_nil(state.pad_state.right_win)
    end)

    it("should handle missing pads gracefully", function()
      state.pad_state.left_win = nil
      state.pad_state.right_win = nil

      -- Should not error
      window.delete_pads()
    end)

    it("should handle invalid window IDs gracefully", function()
      state.pad_state.left_win = 9999
      state.pad_state.right_win = 9998

      -- Should not error
      window.delete_pads()
    end)
  end)

  describe("save_global_settings()", function()
    it("should save fillchars", function()
      local original_fillchars = vim.o.fillchars
      state.saved_settings.fillchars = nil

      window.save_global_settings()

      assert.is_not_nil(state.saved_settings.fillchars)
      assert.are.equal(original_fillchars, state.saved_settings.fillchars)
    end)

    it("should not overwrite already saved settings", function()
      state.saved_settings.fillchars = "test_value"

      window.save_global_settings()

      assert.are.equal("test_value", state.saved_settings.fillchars)
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

    it("should restore lazyredraw when saved", function()
      local original = vim.o.lazyredraw
      state.saved_settings.lazyredraw = original
      vim.o.lazyredraw = not original

      window.restore_global_settings()

      assert.are.equal(original, vim.o.lazyredraw)
      assert.is_nil(state.saved_settings.lazyredraw)
    end)

    it("should handle missing saved settings gracefully", function()
      state.saved_settings.fillchars = nil
      state.saved_settings.lazyredraw = nil

      -- Should not error
      window.restore_global_settings()
    end)
  end)
end)
