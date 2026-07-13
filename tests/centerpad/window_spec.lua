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

  describe("is_floating()", function()
    it("should return false for nil window", function()
      assert.is_false(window.is_floating(nil))
    end)

    it("should return false for invalid window", function()
      assert.is_false(window.is_floating(9999))
    end)

    it("should return true for floating window", function()
      local buf = vim.api.nvim_create_buf(false, true)
      local win = vim.api.nvim_open_win(buf, false, {
        relative = "cursor",
        width = 10,
        height = 5,
        row = 1,
        col = 1,
      })

      assert.is_true(window.is_floating(win))

      vim.api.nvim_win_close(win, true)
    end)

    it("should return false for non-floating window", function()
      local cur = vim.api.nvim_get_current_win()
      vim.cmd("vsplit")
      local win = vim.api.nvim_get_current_win()

      assert.is_false(window.is_floating(win))

      vim.api.nvim_win_close(win, true)
      vim.api.nvim_set_current_win(cur)
    end)

    it("should return false when nvim_win_get_config throws", function()
      local buf = vim.api.nvim_create_buf(false, true)
      local win = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })

      local orig_get_config = vim.api.nvim_win_get_config
      vim.api.nvim_win_get_config = function()
        error("forced config failure")
      end

      assert.is_false(window.is_floating(win))

      vim.api.nvim_win_get_config = orig_get_config
      vim.api.nvim_win_close(win, true)
    end)
  end)

  describe("is_pad_buffer()", function()
    it("should error on nil buffer", function()
      local ok, _ = pcall(window.is_pad_buffer, nil)
      assert.is_false(ok)
    end)

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

      assert.are.equal(
        "%#Normal#",
        vim.api.nvim_get_option_value("statusline", { win = win })
      )
      assert.are.equal(
        "%#Normal#",
        vim.api.nvim_get_option_value("winbar", { win = win })
      )
      assert.are.equal(
        "no",
        vim.api.nvim_get_option_value("signcolumn", { win = win })
      )
      assert.is_false(vim.api.nvim_get_option_value("number", { win = win }))
      assert.is_false(
        vim.api.nvim_get_option_value("relativenumber", { win = win })
      )
      assert.are.equal(
        "0",
        vim.api.nvim_get_option_value("foldcolumn", { win = win })
      )
      assert.is_false(
        vim.api.nvim_get_option_value("cursorline", { win = win })
      )
      assert.is_false(
        vim.api.nvim_get_option_value("cursorcolumn", { win = win })
      )
      assert.is_false(vim.api.nvim_get_option_value("list", { win = win }))
      assert.is_false(vim.api.nvim_get_option_value("spell", { win = win }))
      assert.are.equal(
        "",
        vim.api.nvim_get_option_value("colorcolumn", { win = win })
      )
      assert.is_false(vim.api.nvim_get_option_value("wrap", { win = win }))
      assert.is_false(vim.api.nvim_get_option_value("linebreak", { win = win }))
      assert.are.equal(
        0,
        vim.api.nvim_get_option_value("conceallevel", { win = win })
      )

      local cfg = vim.api.nvim_win_get_config(win)
      assert.is_false(cfg.focusable)
      assert.are.equal("minimal", cfg.style)

      -- Cleanup
      local buf = vim.api.nvim_win_get_buf(win)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it(
      "should override winbar and statusline even when globals are non-empty",
      function()
        -- statusline and winbar are global-local options: an empty
        -- local value means "no override" and falls back to the
        -- global value. A naive assert against an empty global
        -- baseline would not catch that fallback, so pre-set
        -- non-empty sentinels here to force the real behavior.
        local original_winbar = vim.o.winbar
        local original_statusline = vim.o.statusline

        vim.o.winbar = "GLOBAL-WINBAR-SENTINEL"
        vim.o.statusline = "GLOBAL-STATUSLINE-SENTINEL"

        local win = window.create_pad_window("testpad", "left", 20)
        local winbar = vim.api.nvim_get_option_value("winbar", { win = win })
        local statusline =
          vim.api.nvim_get_option_value("statusline", { win = win })

        vim.o.winbar = original_winbar
        vim.o.statusline = original_statusline

        assert.are.equal("%#Normal#", winbar)
        assert.are.equal("%#Normal#", statusline)

        -- Cleanup
        local buf = vim.api.nvim_win_get_buf(win)
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    )

    it("should handle buffer creation failure gracefully", function()
      local orig_create_buf = vim.api.nvim_create_buf
      vim.api.nvim_create_buf = function()
        error("forced buffer creation failure")
      end

      state.debug = true
      local result = window.create_pad_window("testpad", "left", 20)
      state.debug = false

      vim.api.nvim_create_buf = orig_create_buf

      assert.is_nil(result)
    end)

    it("should handle split creation failure gracefully", function()
      local orig_open_win = vim.api.nvim_open_win
      vim.api.nvim_open_win = function()
        error("forced split creation failure")
      end

      state.debug = true
      local result = window.create_pad_window("testpad", "left", 20)
      state.debug = false

      vim.api.nvim_open_win = orig_open_win

      assert.is_nil(result)
    end)

    it("should handle configure_pad failure gracefully", function()
      local orig_set_width = vim.api.nvim_win_set_width
      vim.api.nvim_win_set_width = function()
        error("forced width set failure")
      end

      state.debug = true
      local result = window.create_pad_window("testpad", "right", 20)
      state.debug = false

      vim.api.nvim_win_set_width = orig_set_width

      assert.is_nil(result)
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

    it("should return false when right pad is missing", function()
      state.pad_state.left_win = window.create_pad_window("leftpad", "left", 20)
      state.pad_state.right_win = nil

      assert.is_false(window.are_pads_valid())

      vim.api.nvim_buf_delete(
        vim.api.nvim_win_get_buf(state.pad_state.left_win),
        { force = true }
      )
    end)

    it("should return false when both pads are nil", function()
      state.pad_state.left_win = nil
      state.pad_state.right_win = nil

      assert.is_false(window.are_pads_valid())
    end)

    it("should return false when left window is invalid", function()
      local right_win = window.create_pad_window("rightpad", "right", 20)
      state.pad_state.left_win = 9999 -- Invalid window handle
      state.pad_state.right_win = right_win

      assert.is_false(window.are_pads_valid())

      vim.api.nvim_buf_delete(
        vim.api.nvim_win_get_buf(right_win),
        { force = true }
      )
    end)

    it("should return false when right window is invalid", function()
      local left_win = window.create_pad_window("leftpad", "left", 20)
      state.pad_state.left_win = left_win
      state.pad_state.right_win = 9998 -- Invalid window handle

      assert.is_false(window.are_pads_valid())

      vim.api.nvim_buf_delete(
        vim.api.nvim_win_get_buf(left_win),
        { force = true }
      )
    end)

    it("should return false when nvim_win_get_buf throws", function()
      local left_win = window.create_pad_window("leftpad", "left", 20)
      local right_win = window.create_pad_window("rightpad", "right", 20)
      state.pad_state.left_win = left_win
      state.pad_state.right_win = right_win

      local orig_get_buf = vim.api.nvim_win_get_buf
      vim.api.nvim_win_get_buf = function()
        error("forced get_buf failure")
      end

      assert.is_false(window.are_pads_valid())

      vim.api.nvim_win_get_buf = orig_get_buf

      vim.api.nvim_buf_delete(
        vim.api.nvim_win_get_buf(left_win),
        { force = true }
      )
      vim.api.nvim_buf_delete(
        vim.api.nvim_win_get_buf(right_win),
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

    it("should return nil for nil window", function()
      assert.is_nil(window.get_pad_width(nil))
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

    it("should return nil when nvim_win_get_width throws", function()
      local win = window.create_pad_window("leftpad", "left", 20)

      local orig_get_width = vim.api.nvim_win_get_width
      vim.api.nvim_win_get_width = function()
        error("forced width failure")
      end

      assert.is_nil(window.get_pad_width(win))

      vim.api.nvim_win_get_width = orig_get_width

      local buf = vim.api.nvim_win_get_buf(win)
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

    it("should handle mixed valid and invalid pad windows", function()
      local left_win = window.create_pad_window("leftpad", "left", 20)
      state.pad_state.left_win = left_win
      state.pad_state.right_win = 9998

      local left_buf = vim.api.nvim_win_get_buf(left_win)

      -- Should not error and should clear both tracked IDs
      window.delete_pads()

      assert.is_false(vim.api.nvim_win_is_valid(left_win))
      assert.is_false(vim.api.nvim_buf_is_valid(left_buf))
      assert.is_nil(state.pad_state.left_win)
      assert.is_nil(state.pad_state.right_win)
    end)
  end)

  describe("apply_source_fillchars()", function()
    it("should apply local fillchars to valid window", function()
      local win = vim.api.nvim_get_current_win()

      local result = window.apply_source_fillchars(win)

      assert.is_true(result)
      -- Window should have local fillchars
      local local_fc = vim.api.nvim_get_option_value("fillchars", { win = win })
      assert.is_not_nil(local_fc)
    end)

    it("records source metadata after successful capture", function()
      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value(
        "fillchars",
        "vert:|,horiz:-",
        { win = win }
      )

      local result = window.apply_source_fillchars(win)

      assert.is_true(result)
      assert.are.equal(win, state.source_options.win)
      assert.are.equal("vert:|,horiz:-", state.source_options.fillchars)
    end)

    it("records inherited fillchars as empty string", function()
      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value("fillchars", nil, { win = win })
      assert.are.equal(
        "",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = win, scope = "local" }
        )
      )

      local result = window.apply_source_fillchars(win)

      assert.is_true(result)
      assert.are.equal(win, state.source_options.win)
      assert.are.equal("", state.source_options.fillchars)
    end)

    it("records explicit empty fillchars as empty string", function()
      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value("fillchars", "", { win = win })
      assert.are.equal(
        "",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = win, scope = "local" }
        )
      )

      local result = window.apply_source_fillchars(win)

      assert.is_true(result)
      assert.are.equal(win, state.source_options.win)
      assert.are.equal("", state.source_options.fillchars)
    end)

    it("should return false and clear metadata for invalid window", function()
      state.source_options.win = vim.api.nvim_get_current_win()
      state.source_options.fillchars = "vert:|"

      local result = window.apply_source_fillchars(9999)

      assert.is_false(result)
      assert.is_nil(state.source_options.win)
      assert.is_nil(state.source_options.fillchars)
    end)

    it("should return false and clear metadata for nil window", function()
      state.source_options.win = vim.api.nvim_get_current_win()
      state.source_options.fillchars = "vert:|"

      local result = window.apply_source_fillchars(nil)

      assert.is_false(result)
      assert.is_nil(state.source_options.win)
      assert.is_nil(state.source_options.fillchars)
    end)

    it("clears metadata when capture fails", function()
      local win = vim.api.nvim_get_current_win()
      state.source_options.win = 9999
      state.source_options.fillchars = "stale"

      local orig_get = vim.api.nvim_get_option_value
      vim.api.nvim_get_option_value = function(name, opts)
        if name == "fillchars" and opts and opts.win then
          error("forced capture failure")
        end
        return orig_get(name, opts)
      end

      local result = window.apply_source_fillchars(win)

      vim.api.nvim_get_option_value = orig_get

      assert.is_false(result)
      assert.is_nil(state.source_options.win)
      assert.is_nil(state.source_options.fillchars)
    end)

    it("clears metadata when override fails", function()
      local win = vim.api.nvim_get_current_win()
      state.source_options.win = 9999
      state.source_options.fillchars = "stale"

      local orig_set = vim.api.nvim_set_option_value
      vim.api.nvim_set_option_value = function(name, value, opts)
        if name == "fillchars" and opts and opts.win then
          error("forced override failure")
        end
        return orig_set(name, value, opts)
      end

      local result = window.apply_source_fillchars(win)

      vim.api.nvim_set_option_value = orig_set

      assert.is_false(result)
      assert.is_nil(state.source_options.win)
      assert.is_nil(state.source_options.fillchars)
    end)

    it("replaces stale metadata on successful new capture", function()
      local old_win = vim.api.nvim_get_current_win()
      vim.cmd("vsplit")
      local new_win = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value("fillchars", "fold:x", { win = new_win })

      state.source_options.win = old_win
      state.source_options.fillchars = "old-value"

      local result = window.apply_source_fillchars(new_win)

      assert.is_true(result)
      assert.are.equal(new_win, state.source_options.win)
      assert.are.equal("fold:x", state.source_options.fillchars)

      vim.api.nvim_win_close(new_win, true)
      vim.api.nvim_set_current_win(old_win)
    end)

    it("leaves unrelated window fillchars unchanged on failure", function()
      local source_win = vim.api.nvim_get_current_win()
      vim.cmd("vsplit")
      local unrelated_win = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value(
        "fillchars",
        "fold:x",
        { win = unrelated_win }
      )
      vim.api.nvim_set_current_win(source_win)

      local orig_set = vim.api.nvim_set_option_value
      vim.api.nvim_set_option_value = function(name, value, opts)
        if name == "fillchars" and opts and opts.win == source_win then
          error("forced override failure")
        end
        return orig_set(name, value, opts)
      end

      local result = window.apply_source_fillchars(source_win)

      vim.api.nvim_set_option_value = orig_set

      assert.is_false(result)
      assert.are.equal(
        "fold:x",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = unrelated_win, scope = "local" }
        )
      )

      vim.api.nvim_win_close(unrelated_win, true)
      vim.api.nvim_set_current_win(source_win)
    end)
  end)

  describe("restore_source_fillchars()", function()
    it("restores inherited fillchars by removing local override", function()
      local win = vim.api.nvim_get_current_win()

      -- Pre-enable: no local override (inherits from global)
      vim.api.nvim_set_option_value("fillchars", nil, { win = win })
      assert.are.equal(
        "",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = win, scope = "local" }
        )
      )

      window.apply_source_fillchars(win)
      assert.is_not.equal(
        "",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = win, scope = "local" }
        )
      )

      local result = window.restore_source_fillchars(win)

      assert.is_true(result)
      assert.are.equal(
        "",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = win, scope = "local" }
        )
      )
    end)

    it("restores explicit custom local fillchars", function()
      local win = vim.api.nvim_get_current_win()

      vim.api.nvim_set_option_value(
        "fillchars",
        "vert:|,horiz:-",
        { win = win }
      )

      window.apply_source_fillchars(win)
      assert.is_not.equal(
        "vert:|,horiz:-",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = win, scope = "local" }
        )
      )

      local result = window.restore_source_fillchars(win)

      assert.is_true(result)
      assert.are.equal(
        "vert:|,horiz:-",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = win, scope = "local" }
        )
      )
    end)

    it("restores explicit empty local fillchars", function()
      local win = vim.api.nvim_get_current_win()

      -- Explicit local empty value (different from inherited nil)
      vim.api.nvim_set_option_value("fillchars", "", { win = win })
      assert.are.equal(
        "",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = win, scope = "local" }
        )
      )

      window.apply_source_fillchars(win)
      assert.is_not.equal(
        "",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = win, scope = "local" }
        )
      )

      local result = window.restore_source_fillchars(win)

      assert.is_true(result)
      assert.are.equal(
        "",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = win, scope = "local" }
        )
      )
    end)

    it("returns false and drops metadata for invalid window", function()
      state.source_options.win = 9999
      state.source_options.fillchars = "vert:|"

      local result = window.restore_source_fillchars(9999)

      assert.is_false(result)
      assert.is_nil(state.source_options.win)
      assert.is_nil(state.source_options.fillchars)
    end)

    it("returns false and drops metadata for nil window", function()
      state.source_options.win = 9999
      state.source_options.fillchars = "vert:|"

      local result = window.restore_source_fillchars(nil)

      assert.is_false(result)
      assert.is_nil(state.source_options.win)
      assert.is_nil(state.source_options.fillchars)
    end)

    it(
      "returns false and drops stale metadata for mismatched window",
      function()
        local win = vim.api.nvim_get_current_win()
        state.source_options.win = 9999
        state.source_options.fillchars = "vert:|"

        local result = window.restore_source_fillchars(win)

        assert.is_false(result)
        assert.is_nil(state.source_options.win)
        assert.is_nil(state.source_options.fillchars)
      end
    )

    it("returns false when no capture exists", function()
      local win = vim.api.nvim_get_current_win()
      state.source_options.win = win
      state.source_options.fillchars = nil

      local result = window.restore_source_fillchars(win)

      assert.is_false(result)
      assert.is_nil(state.source_options.win)
      assert.is_nil(state.source_options.fillchars)
    end)
  end)
end)
