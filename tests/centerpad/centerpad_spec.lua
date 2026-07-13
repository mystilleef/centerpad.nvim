describe("centerpad.centerpad", function()
  local centerpad
  local state
  local autocmds

  before_each(function()
    -- Reload modules
    package.loaded["centerpad.state"] = nil
    package.loaded["centerpad.enabled"] = nil
    package.loaded["centerpad.window"] = nil
    package.loaded["centerpad.autocmds"] = nil
    package.loaded["centerpad.centerpad"] = nil

    state = require("centerpad.state")
    autocmds = require("centerpad.autocmds")
    centerpad = require("centerpad.centerpad")
    state.reset()

    -- Reset global flags
    vim.g.centerpad_enabled = false
    vim.g.center_buf_enabled = false
  end)

  after_each(function()
    centerpad.disable()
  end)

  describe("should_enable()", function()
    it("should return true for normal buffers", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local config = {
        ignore_filetypes = { "help" },
        ignore_buftypes = { "terminal" },
      }

      assert.is_true(centerpad.should_enable(config))
    end)

    it("should return false for ignored filetype", function()
      vim.bo.filetype = "help"
      vim.bo.buftype = ""

      local config = {
        ignore_filetypes = { "help" },
        ignore_buftypes = {},
      }

      assert.is_false(centerpad.should_enable(config))
    end)

    it("should return false for ignored buftype", function()
      -- Use a buffer option that can be set
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
      vim.api.nvim_set_current_buf(buf)

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = { "nofile" },
      }

      assert.is_false(centerpad.should_enable(config))

      -- Cleanup
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it(
      "should return false when both filetype and buftype are ignored",
      function()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
        vim.api.nvim_buf_set_option(buf, "filetype", "help")
        vim.api.nvim_set_current_buf(buf)

        local config = {
          ignore_filetypes = { "help" },
          ignore_buftypes = { "nofile" },
        }

        assert.is_false(centerpad.should_enable(config))

        -- Cleanup
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    )

    it("should return false for floating windows", function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(buf, "buftype", "")
      vim.api.nvim_buf_set_option(buf, "filetype", "")
      vim.api.nvim_set_current_buf(buf)

      local float_win = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      vim.api.nvim_set_current_win(float_win)

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
      }

      assert.is_false(centerpad.should_enable(config))

      vim.api.nvim_win_close(float_win, true)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should return false for terminal buftype", function()
      local normal_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(normal_buf, "buftype", "")
      vim.api.nvim_buf_set_option(normal_buf, "filetype", "")
      vim.api.nvim_set_current_buf(normal_buf)

      vim.cmd("vsplit")
      local terminal_win = vim.api.nvim_get_current_win()
      vim.cmd("terminal true")
      local terminal_buf = vim.api.nvim_get_current_buf()

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = { "terminal" },
      }

      assert.is_false(centerpad.should_enable(config))

      if vim.api.nvim_win_is_valid(terminal_win) then
        vim.api.nvim_win_close(terminal_win, true)
      end
      pcall(vim.api.nvim_buf_delete, terminal_buf, { force = true })
    end)

    it("should return false for quickfix buftype", function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(buf, "buftype", "quickfix")
      vim.api.nvim_set_current_buf(buf)

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = { "quickfix" },
      }

      assert.is_false(centerpad.should_enable(config))

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should return false for help filetype", function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(buf, "buftype", "")
      vim.api.nvim_buf_set_option(buf, "filetype", "help")
      vim.api.nvim_set_current_buf(buf)

      local config = {
        ignore_filetypes = { "help" },
        ignore_buftypes = {},
      }

      assert.is_false(centerpad.should_enable(config))

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should return false for centerpad pad filetype", function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(buf, "buftype", "")
      vim.api.nvim_buf_set_option(buf, "filetype", "centerpad")
      vim.api.nvim_set_current_buf(buf)

      local config = {
        ignore_filetypes = { "centerpad" },
        ignore_buftypes = {},
      }

      assert.is_false(centerpad.should_enable(config))

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should return true when ignore_filetypes is nil", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local config = {
        ignore_buftypes = {},
      }

      assert.is_true(centerpad.should_enable(config))
    end)

    it("should return true when ignore_buftypes is nil", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local config = {
        ignore_filetypes = {},
      }

      assert.is_true(centerpad.should_enable(config))
    end)

    it("should return true when both ignore fields are nil", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local config = {}

      assert.is_true(centerpad.should_enable(config))
    end)

    it(
      "should return true when ignore_filetypes is nil but filetype matches",
      function()
        -- nil ignore_filetypes means no filtering for filetypes
        vim.bo.filetype = "help"
        vim.bo.buftype = ""

        local config = {
          ignore_buftypes = {},
        }

        assert.is_true(centerpad.should_enable(config))
      end
    )

    it(
      "should return true when ignore_buftypes is nil but buftype matches",
      function()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
        vim.api.nvim_set_current_buf(buf)

        local config = {
          ignore_filetypes = {},
        }

        assert.is_true(centerpad.should_enable(config))

        vim.api.nvim_buf_delete(buf, { force = true })
      end
    )
  end)

  describe("enable()", function()
    it("should enable centerpad for valid buffer", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      centerpad.enable(config)

      -- Give some time for async operations
      vim.wait(50)

      assert.is_true(state.pad_state.enabled)
      assert.is_true(vim.g.centerpad_enabled)
      assert.is_true(vim.g.center_buf_enabled)
    end)

    it("should not enable for ignored filetype", function()
      vim.bo.filetype = "help"
      vim.bo.buftype = ""

      local config = {
        ignore_filetypes = { "help" },
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      centerpad.enable(config)

      assert.is_false(state.pad_state.enabled)
    end)

    it("should create pad windows", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 25,
        rightpad = 30,
      }

      centerpad.enable(config)
      vim.wait(50)

      assert.is_not_nil(state.pad_state.left_win)
      assert.is_not_nil(state.pad_state.right_win)
      assert.is_true(vim.api.nvim_win_is_valid(state.pad_state.left_win))
      assert.is_true(vim.api.nvim_win_is_valid(state.pad_state.right_win))
    end)

    it(
      "should clean up partial pad creation failure and leave globals false",
      function()
        local orig_open_win = vim.api.nvim_open_win
        local ok, err = pcall(function()
          vim.api.nvim_open_win = function(buffer, enter, win_config)
            if win_config.split == "right" then
              error("forced right pad failure")
            end
            return orig_open_win(buffer, enter, win_config)
          end

          package.loaded["centerpad.centerpad"] = nil
          local cp = require("centerpad.centerpad")

          vim.bo.filetype = ""
          vim.bo.buftype = ""

          local config = {
            ignore_filetypes = {},
            ignore_buftypes = {},
            leftpad = 20,
            rightpad = 20,
          }

          cp.enable(config)
          vim.wait(100)

          assert.is_false(state.pad_state.enabled)
          assert.is_nil(state.pad_state.left_win)
          assert.is_nil(state.pad_state.right_win)
          assert.is_nil(state.pad_state.main_win)
          assert.is_false(vim.g.centerpad_enabled)
          assert.is_false(vim.g.center_buf_enabled)
          assert.are.equal(
            0,
            #vim.api.nvim_get_autocmds({ group = autocmds.get_padgroup() })
          )
        end)

        vim.api.nvim_open_win = orig_open_win
        package.loaded["centerpad.centerpad"] = nil

        assert.is_true(ok, err)
      end
    )

    it(
      "should clear leaked winfixwidth and winfixbuf on main window before layout",
      function()
        -- Simulate leaked pad-local options from a previous
        -- pad-as-last-window scenario.
        local main_win = vim.api.nvim_get_current_win()
        pcall(
          vim.api.nvim_set_option_value,
          "winfixwidth",
          true,
          { win = main_win }
        )
        pcall(
          vim.api.nvim_set_option_value,
          "winfixbuf",
          true,
          { win = main_win }
        )

        vim.bo.filetype = ""
        vim.bo.buftype = ""

        local config = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 20,
          rightpad = 20,
        }

        centerpad.enable(config)
        vim.wait(50)

        -- Pads should exist
        assert.is_true(state.pad_state.enabled)
        assert.is_not_nil(state.pad_state.left_win)
        assert.is_not_nil(state.pad_state.right_win)

        -- Main window should have leaked options cleared
        assert.is_false(
          vim.api.nvim_get_option_value("winfixwidth", { win = main_win })
        )
        -- winfixbuf may not be supported in all Neovim versions;
        -- when supported it must be false; otherwise skip the check.
        local fixbuf_ok, fixbuf =
          pcall(vim.api.nvim_get_option_value, "winfixbuf", { win = main_win })
        if fixbuf_ok then
          assert.is_false(fixbuf)
        end
      end
    )
  end)

  describe("disable()", function()
    it("should disable centerpad", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      centerpad.enable(config)
      vim.wait(50)

      assert.is_true(state.pad_state.enabled)

      centerpad.disable()

      assert.is_false(state.pad_state.enabled)
      assert.is_false(vim.g.centerpad_enabled)
      assert.is_false(vim.g.center_buf_enabled)
    end)

    it("should delete pad windows", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      centerpad.enable(config)
      vim.wait(50)

      local left_win = state.pad_state.left_win
      local right_win = state.pad_state.right_win

      centerpad.disable()

      if left_win then
        assert.is_false(vim.api.nvim_win_is_valid(left_win))
      end
      if right_win then
        assert.is_false(vim.api.nvim_win_is_valid(right_win))
      end
    end)

    it("should leave no pad windows after cleanup", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      centerpad.enable(config)
      vim.wait(50)

      centerpad.disable()

      local pad_count = 0
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local ok, buf = pcall(vim.api.nvim_win_get_buf, win)
        if ok then
          local buf_ok, is_pad =
            pcall(vim.api.nvim_buf_get_var, buf, "is_centerpad")
          if buf_ok and is_pad then
            pad_count = pad_count + 1
          end
        end
      end

      assert.are.equal(0, pad_count)
    end)
  end)

  describe("toggle()", function()
    it("should enable when disabled", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      state.pad_state.enabled = false

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      centerpad.toggle(config)
      vim.wait(50)

      assert.is_true(state.pad_state.enabled)
    end)

    it("should disable when enabled", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      centerpad.enable(config)
      vim.wait(50)

      assert.is_true(state.pad_state.enabled)

      centerpad.toggle(config)

      assert.is_false(state.pad_state.enabled)
    end)

    it("should use default widths when config is nil", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      state.pad_state.enabled = false

      centerpad.toggle(nil)
      vim.wait(50)

      assert.is_true(state.pad_state.enabled)
      assert.is_not_nil(state.pad_state.left_win)
      assert.is_not_nil(state.pad_state.right_win)
      assert.are.equal(25, vim.api.nvim_win_get_width(state.pad_state.left_win))
      assert.are.equal(
        25,
        vim.api.nvim_win_get_width(state.pad_state.right_win)
      )
    end)

    it("should normalize nil config for tracker lifecycle events", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      state.pad_state.enabled = false

      local ok, err = pcall(function()
        centerpad.toggle(nil)
        vim.wait(50)

        assert.is_true(state.pad_state.enabled)
        assert.is_true(state.tracker.opted_in)

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

    it(
      "should preserve partial ignore lists during lifecycle events",
      function()
        vim.bo.filetype = ""
        vim.bo.buftype = ""

        state.pad_state.enabled = false

        local ok, err = pcall(function()
          -- Only filetype ignore list supplied; buftype ignore omitted.
          centerpad.toggle({ ignore_filetypes = { "help" }, leftpad = 20 })
          vim.wait(50)

          assert.is_true(state.pad_state.enabled)
          assert.is_true(state.tracker.opted_in)

          -- Help filetype is ignored and should suspend.
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

          -- Omitted buftype ignore list means no buftype filtering; nofile
          -- should be treated as a valid context, not suspended.
          local nofile_buf = vim.api.nvim_create_buf(false, true)
          vim.api.nvim_set_option_value(
            "buftype",
            "nofile",
            { buf = nofile_buf }
          )
          vim.api.nvim_set_option_value("filetype", "", { buf = nofile_buf })
          vim.api.nvim_set_current_buf(nofile_buf)
          vim.wait(150)

          assert.is_true(state.pad_state.enabled)
          assert.is_false(state.tracker.suspended)
        end)

        assert.is_true(ok, err)
      end
    )

    it("should preserve explicit widths and ignore lists", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      state.pad_state.enabled = false

      centerpad.toggle({
        ignore_filetypes = { "help" },
        ignore_buftypes = { "nofile" },
        leftpad = 15,
        rightpad = 35,
      })
      vim.wait(50)

      assert.is_true(state.pad_state.enabled)
      assert.are.equal(15, vim.api.nvim_win_get_width(state.pad_state.left_win))
      assert.are.equal(
        35,
        vim.api.nvim_win_get_width(state.pad_state.right_win)
      )
      assert.are.equal(15, state.config_snapshot.leftpad)
      assert.are.equal(35, state.config_snapshot.rightpad)
      assert.are.same({ "help" }, state.config_snapshot.ignore_filetypes)
      assert.are.same({ "nofile" }, state.config_snapshot.ignore_buftypes)
    end)
  end)

  describe("run()", function()
    it("should toggle with no arguments", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      local initial_state = state.pad_state.enabled

      centerpad.run(config, { fargs = {} })
      vim.wait(50)

      assert.are_not.equal(initial_state, state.pad_state.enabled)
    end)

    it("should set both pads with one argument", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      centerpad.run(config, { fargs = { "30" } })
      vim.wait(50)

      assert.are.equal(30, config.leftpad)
      assert.are.equal(30, config.rightpad)
    end)

    it("should set different pad widths with two arguments", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      centerpad.run(config, { fargs = { "15", "35" } })
      vim.wait(50)

      assert.are.equal(15, config.leftpad)
      assert.are.equal(35, config.rightpad)
    end)

    it("should reject invalid width (negative)", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      centerpad.run(config, { fargs = { "-5" } })

      -- Config should not change
      assert.are.equal(20, config.leftpad)
      assert.are.equal(20, config.rightpad)
    end)

    it("should reject invalid width (too large)", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      centerpad.run(config, { fargs = { "600" } })

      -- Config should not change
      assert.are.equal(20, config.leftpad)
      assert.are.equal(20, config.rightpad)
    end)

    it("should reject non-numeric width", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      centerpad.run(config, { fargs = { "abc" } })

      -- Config should not change
      assert.are.equal(20, config.leftpad)
      assert.are.equal(20, config.rightpad)
    end)

    it("should reject empty width", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      centerpad.run(config, { fargs = { "" } })

      assert.are.equal(20, config.leftpad)
      assert.are.equal(20, config.rightpad)
    end)

    it("should reject width 0", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      centerpad.run(config, { fargs = { "0" } })

      assert.are.equal(20, config.leftpad)
      assert.are.equal(20, config.rightpad)
    end)

    it("should reject width 501", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      centerpad.run(config, { fargs = { "501" } })

      assert.are.equal(20, config.leftpad)
      assert.are.equal(20, config.rightpad)
    end)

    it("should reject more than two arguments", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }
      local initial_enabled = state.pad_state.enabled

      local messages = {}
      local orig_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(messages, { msg = msg, level = level })
      end

      centerpad.run(config, { fargs = { "10", "20", "30" } })

      vim.notify = orig_notify

      assert.are.equal(initial_enabled, state.pad_state.enabled)
      assert.are.equal(20, config.leftpad)
      assert.are.equal(20, config.rightpad)
      assert.are.equal(1, #messages)
      assert.is_true(string.match(messages[1].msg, "Invalid arguments") ~= nil)
      assert.are.equal(vim.log.levels.ERROR, messages[1].level)
    end)

    it("should notify an error for invalid width", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      local messages = {}
      local orig_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(messages, { msg = msg, level = level })
      end

      centerpad.run(config, { fargs = { "abc" } })

      vim.notify = orig_notify

      assert.are.equal(1, #messages)
      assert.is_true(string.match(messages[1].msg, "Invalid width") ~= nil)
      assert.are.equal(vim.log.levels.ERROR, messages[1].level)
    end)

    it("should preserve existing state on invalid width", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      centerpad.enable(config)
      vim.wait(50)

      local left_win = state.pad_state.left_win
      local right_win = state.pad_state.right_win
      local left_buf = vim.api.nvim_win_get_buf(left_win)
      local right_buf = vim.api.nvim_win_get_buf(right_win)
      local autocmd_count =
        #vim.api.nvim_get_autocmds({ group = autocmds.get_padgroup() })
      state.set_restore_timer(12345)

      centerpad.run(config, { fargs = { "600" } })

      assert.are.equal(left_win, state.pad_state.left_win)
      assert.are.equal(right_win, state.pad_state.right_win)
      assert.are.equal(left_buf, vim.api.nvim_win_get_buf(left_win))
      assert.are.equal(right_buf, vim.api.nvim_win_get_buf(right_win))
      assert.are.equal(20, config.leftpad)
      assert.are.equal(20, config.rightpad)
      assert.is_true(state.pad_state.enabled)
      assert.is_true(vim.g.centerpad_enabled)
      assert.are.equal(
        autocmd_count,
        #vim.api.nvim_get_autocmds({ group = autocmds.get_padgroup() })
      )
      assert.are.equal(12345, state.get_restore_timer())
    end)

    it("should skip enablement for floating windows", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      centerpad.enable(config)
      vim.wait(50)
      centerpad.disable()

      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(buf, "buftype", "")
      vim.api.nvim_buf_set_option(buf, "filetype", "")
      vim.api.nvim_set_current_buf(buf)

      local float_win = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      vim.api.nvim_set_current_win(float_win)

      centerpad.run(config, { fargs = { "30" } })

      assert.is_false(state.pad_state.enabled)
      assert.are.equal(20, config.leftpad)
      assert.are.equal(20, config.rightpad)

      vim.api.nvim_win_close(float_win, true)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should reject invalid right width in two-arg form", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      local messages = {}
      local orig_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(messages, { msg = msg, level = level })
      end

      centerpad.run(config, { fargs = { "20", "abc" } })

      vim.notify = orig_notify

      assert.is_true(
        string.match(messages[1].msg, "Invalid right width") ~= nil
      )
      assert.are.equal(vim.log.levels.ERROR, messages[1].level)
      assert.are.equal(20, config.leftpad)
      assert.are.equal(20, config.rightpad)
    end)

    it("should reject right width too large in two-arg form", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      local messages = {}
      local orig_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(messages, { msg = msg, level = level })
      end

      centerpad.run(config, { fargs = { "20", "600" } })

      vim.notify = orig_notify

      assert.is_true(
        string.match(messages[1].msg, "Invalid right width") ~= nil
      )
      assert.are.equal(20, config.leftpad)
      assert.are.equal(20, config.rightpad)
    end)

    it("should reject right width zero in two-arg form", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      centerpad.run(config, { fargs = { "20", "0" } })

      assert.are.equal(20, config.leftpad)
      assert.are.equal(20, config.rightpad)
    end)

    it(
      "should reject left width invalid but right valid in two-arg form",
      function()
        local config = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 20,
          rightpad = 20,
        }

        local messages = {}
        local orig_notify = vim.notify
        vim.notify = function(msg, level)
          table.insert(messages, { msg = msg, level = level })
        end

        centerpad.run(config, { fargs = { "abc", "20" } })

        vim.notify = orig_notify

        assert.is_true(
          string.match(messages[1].msg, "Invalid left width") ~= nil
        )
        assert.are.equal(20, config.leftpad)
        assert.are.equal(20, config.rightpad)
      end
    )

    it("should skip two-arg enable when buffer is ignored", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local config = {
        ignore_filetypes = { "help" },
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      centerpad.enable(config)
      vim.wait(50)
      centerpad.disable()

      vim.bo.filetype = "help"

      centerpad.run(config, { fargs = { "30", "40" } })

      assert.are.equal(20, config.leftpad)
      assert.are.equal(20, config.rightpad)
      assert.is_false(state.pad_state.enabled)
    end)

    it("should skip one-arg enable when buffer is ignored buftype", function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
      vim.api.nvim_set_current_buf(buf)

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = { "nofile" },
        leftpad = 20,
        rightpad = 20,
      }

      centerpad.run(config, { fargs = { "30" } })

      assert.are.equal(20, config.leftpad)
      assert.are.equal(20, config.rightpad)
      assert.is_false(state.pad_state.enabled)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should reject right width 0 in two-arg form", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      centerpad.run(config, { fargs = { "20", "0" } })

      assert.are.equal(20, config.leftpad)
      assert.are.equal(20, config.rightpad)
    end)

    it("should reject right width 501 in two-arg form", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      local messages = {}
      local orig_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(messages, { msg = msg, level = level })
      end

      centerpad.run(config, { fargs = { "20", "501" } })

      vim.notify = orig_notify

      assert.is_true(
        string.match(messages[1].msg, "Invalid right width") ~= nil
      )
      assert.are.equal(20, config.leftpad)
      assert.are.equal(20, config.rightpad)
    end)

    it("should reject left width negative in two-arg form", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      local messages = {}
      local orig_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(messages, { msg = msg, level = level })
      end

      centerpad.run(config, { fargs = { "-5", "20" } })

      vim.notify = orig_notify

      assert.is_true(string.match(messages[1].msg, "Invalid left width") ~= nil)
      assert.are.equal(20, config.leftpad)
      assert.are.equal(20, config.rightpad)
    end)

    it("should preserve partial caller config on rejected width", function()
      local config = {
        ignore_filetypes = { "help" },
        leftpad = 15,
      }

      local messages = {}
      local orig_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(messages, { msg = msg, level = level })
      end

      centerpad.run(config, { fargs = { "abc" } })

      vim.notify = orig_notify

      assert.are.same({ "help" }, config.ignore_filetypes)
      assert.is_nil(config.ignore_buftypes)
      assert.are.equal(15, config.leftpad)
      assert.is_nil(config.rightpad)
      assert.are.equal(1, #messages)
      assert.is_true(string.match(messages[1].msg, "Invalid width") ~= nil)
      assert.are.equal(vim.log.levels.ERROR, messages[1].level)
    end)

    it("should preserve partial caller config on excess arguments", function()
      local config = {
        ignore_buftypes = { "terminal" },
      }

      local messages = {}
      local orig_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(messages, { msg = msg, level = level })
      end

      centerpad.run(config, { fargs = { "10", "20", "30" } })

      vim.notify = orig_notify

      assert.are.same({ "terminal" }, config.ignore_buftypes)
      assert.is_nil(config.ignore_filetypes)
      assert.is_nil(config.leftpad)
      assert.is_nil(config.rightpad)
      assert.are.equal(1, #messages)
      assert.is_true(string.match(messages[1].msg, "Invalid arguments") ~= nil)
      assert.are.equal(vim.log.levels.ERROR, messages[1].level)
    end)
  end)

  describe("run() atomic integer width parsing", function()
    before_each(function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      vim.o.columns = 1200
    end)

    it("accepts integer widths 1 and 500", function()
      local cases = {
        { "1" },
        { "500" },
        { "1", "500" },
        { "500", "1" },
      }

      for _, args in ipairs(cases) do
        centerpad.disable()
        state.reset()
        vim.g.centerpad_enabled = false
        vim.g.center_buf_enabled = false

        local config = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 20,
          rightpad = 20,
        }

        centerpad.run(config, { fargs = args })

        local expected_left = tonumber(args[1])
        local expected_right = tonumber(args[2] or args[1])
        assert.are.equal(expected_left, config.leftpad)
        assert.are.equal(expected_right, config.rightpad)
        assert.is_true(state.pad_state.enabled)
      end
    end)

    it("rejects fractional widths in one-arg form", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }
      local cases = { "1.5", "0.5", "500.0", "3.14159" }

      for _, raw in ipairs(cases) do
        config.leftpad = 20
        config.rightpad = 20

        local messages = {}
        local orig_notify = vim.notify
        vim.notify = function(msg, level)
          table.insert(messages, { msg = msg, level = level })
        end

        local ok, err = pcall(function()
          centerpad.run(config, { fargs = { raw } })

          assert.are.equal(20, config.leftpad)
          assert.are.equal(20, config.rightpad)
          assert.is_false(state.pad_state.enabled)
          assert.are.equal(1, #messages)
          assert.is_true(string.match(messages[1].msg, "Invalid width") ~= nil)
          assert.are.equal(vim.log.levels.ERROR, messages[1].level)
        end)

        vim.notify = orig_notify
        assert.is_true(ok, err)
      end
    end)

    it("rejects fractional widths in two-arg form", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }
      local cases = {
        { "1.5", "30" },
        { "30", "2.5" },
        { "500.0", "30" },
        { "30", "500.0" },
        { "0.0", "30" },
      }

      for _, args in ipairs(cases) do
        config.leftpad = 20
        config.rightpad = 20

        local messages = {}
        local orig_notify = vim.notify
        vim.notify = function(msg, level)
          table.insert(messages, { msg = msg, level = level })
        end

        local ok, err = pcall(function()
          centerpad.run(config, { fargs = args })

          assert.are.equal(20, config.leftpad)
          assert.are.equal(20, config.rightpad)
          assert.is_false(state.pad_state.enabled)
          assert.are.equal(1, #messages)
          assert.is_true(string.match(messages[1].msg, "Invalid") ~= nil)
          assert.are.equal(vim.log.levels.ERROR, messages[1].level)
        end)

        vim.notify = orig_notify
        assert.is_true(ok, err)
      end
    end)

    it("rejects every malformed form in both argument positions", function()
      local invalid = { "", "abc", "0", "-1", "501", "1.5" }

      for _, raw in ipairs(invalid) do
        local messages = {}
        local orig_notify = vim.notify
        vim.notify = function(msg, level)
          table.insert(messages, { msg = msg, level = level })
        end

        local ok_one, err_one = pcall(function()
          local config = {
            ignore_filetypes = {},
            ignore_buftypes = {},
            leftpad = 20,
            rightpad = 20,
          }

          centerpad.run(config, { fargs = { raw } })

          assert.are.equal(20, config.leftpad)
          assert.are.equal(20, config.rightpad)
          assert.is_false(state.pad_state.enabled)
          assert.are.equal(1, #messages)
          assert.is_true(string.match(messages[1].msg, "Invalid width") ~= nil)
          assert.are.equal(vim.log.levels.ERROR, messages[1].level)
        end)

        vim.notify = orig_notify
        assert.is_true(ok_one, err_one)

        messages = {}
        orig_notify = vim.notify
        vim.notify = function(msg, level)
          table.insert(messages, { msg = msg, level = level })
        end

        local ok_two, err_two = pcall(function()
          local config = {
            ignore_filetypes = {},
            ignore_buftypes = {},
            leftpad = 20,
            rightpad = 20,
          }

          centerpad.run(config, { fargs = { "20", raw } })

          assert.are.equal(20, config.leftpad)
          assert.are.equal(20, config.rightpad)
          assert.is_false(state.pad_state.enabled)
          assert.are.equal(1, #messages)
          assert.is_true(string.match(messages[1].msg, "Invalid") ~= nil)
          assert.are.equal(vim.log.levels.ERROR, messages[1].level)
        end)

        vim.notify = orig_notify
        assert.is_true(ok_two, err_two)
      end
    end)

    it("preserves first width when second argument is invalid", function()
      centerpad.enable({
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      })
      vim.wait(50)

      local left_win = state.pad_state.left_win
      local right_win = state.pad_state.right_win
      local autocmd_count =
        #vim.api.nvim_get_autocmds({ group = autocmds.get_padgroup() })
      state.set_restore_timer(12345)

      local messages = {}
      local orig_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(messages, { msg = msg, level = level })
      end

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }
      centerpad.run(config, { fargs = { "30", "abc" } })

      vim.notify = orig_notify

      assert.are.equal(20, config.leftpad)
      assert.are.equal(20, config.rightpad)
      assert.are.equal(left_win, state.pad_state.left_win)
      assert.are.equal(right_win, state.pad_state.right_win)
      assert.is_true(state.pad_state.enabled)
      assert.are.equal(
        autocmd_count,
        #vim.api.nvim_get_autocmds({ group = autocmds.get_padgroup() })
      )
      assert.are.equal(12345, state.get_restore_timer())
      assert.are.equal(1, #messages)
      assert.is_true(
        string.match(messages[1].msg, "Invalid right width") ~= nil
      )
      assert.are.equal(vim.log.levels.ERROR, messages[1].level)
    end)
  end)

  describe("run() partial-config rejection atomicity", function()
    local original_columns

    local function capture_baseline(config)
      return {
        caller = vim.deepcopy(config),
        snapshot = {
          leftpad = state.config_snapshot.leftpad,
          rightpad = state.config_snapshot.rightpad,
          ignore_filetypes = vim.deepcopy(
            state.config_snapshot.ignore_filetypes
          ),
          ignore_buftypes = vim.deepcopy(state.config_snapshot.ignore_buftypes),
        },
        tracker = {
          opted_in = state.tracker.opted_in,
          suspended = state.tracker.suspended,
          config = state.tracker.config and vim.deepcopy(state.tracker.config)
            or nil,
        },
        pads = {
          left_win = state.pad_state.left_win,
          right_win = state.pad_state.right_win,
          left_buf = state.pad_state.left_win and vim.api.nvim_win_get_buf(
            state.pad_state.left_win
          ) or nil,
          right_buf = state.pad_state.right_win and vim.api.nvim_win_get_buf(
            state.pad_state.right_win
          ) or nil,
        },
        globals = {
          centerpad = vim.g.centerpad_enabled,
          buf = vim.g.center_buf_enabled,
        },
        autocmd_count = #vim.api.nvim_get_autocmds({
          group = autocmds.get_padgroup(),
        }),
        restore_timer = state.get_restore_timer(),
      }
    end

    local function assert_preserves_baseline(config, baseline)
      assert.are.same(baseline.caller, config)
      assert.are.equal(baseline.snapshot.leftpad, state.config_snapshot.leftpad)
      assert.are.equal(
        baseline.snapshot.rightpad,
        state.config_snapshot.rightpad
      )
      assert.are.same(
        baseline.snapshot.ignore_filetypes,
        state.config_snapshot.ignore_filetypes
      )
      assert.are.same(
        baseline.snapshot.ignore_buftypes,
        state.config_snapshot.ignore_buftypes
      )
      assert.are.equal(baseline.tracker.opted_in, state.tracker.opted_in)
      assert.are.equal(baseline.tracker.suspended, state.tracker.suspended)
      assert.are.same(baseline.tracker.config, state.tracker.config)
      assert.are.equal(baseline.pads.left_win, state.pad_state.left_win)
      assert.are.equal(baseline.pads.right_win, state.pad_state.right_win)
      if baseline.pads.left_win then
        assert.are.equal(
          baseline.pads.left_buf,
          vim.api.nvim_win_get_buf(baseline.pads.left_win)
        )
      end
      if baseline.pads.right_win then
        assert.are.equal(
          baseline.pads.right_buf,
          vim.api.nvim_win_get_buf(baseline.pads.right_win)
        )
      end
      assert.are.equal(baseline.globals.centerpad, vim.g.centerpad_enabled)
      assert.are.equal(baseline.globals.buf, vim.g.center_buf_enabled)
      assert.are.equal(
        baseline.autocmd_count,
        #vim.api.nvim_get_autocmds({ group = autocmds.get_padgroup() })
      )
      assert.are.equal(baseline.restore_timer, state.get_restore_timer())
    end

    before_each(function()
      original_columns = vim.o.columns
      vim.o.columns = 1500
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local setup_config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 25,
      }
      centerpad.enable(setup_config)
      vim.wait(100)
      state.set_restore_timer(12345)
    end)

    after_each(function()
      vim.o.columns = original_columns
    end)

    local partial_configs = {
      filetypes_only = { ignore_filetypes = { "help" } },
      buftypes_only = { ignore_buftypes = { "terminal" } },
      neither = {},
      widths_only = { leftpad = 15 },
    }

    it(
      "rejects single-argument invalid widths without mutating partial caller config or layout",
      function()
        local cases = {
          { "", "Invalid width" },
          { "abc", "Invalid width" },
          { "0", "Invalid width" },
          { "-1", "Invalid width" },
          { "501", "Invalid width" },
          { "1.5", "Invalid width" },
        }

        for name, partial in pairs(partial_configs) do
          for _, case in ipairs(cases) do
            local raw = case[1]
            local pattern = case[2]
            local label = name .. " / " .. raw
            local config = vim.deepcopy(partial)
            local baseline = capture_baseline(config)

            local messages = {}
            local orig_notify = vim.notify
            vim.notify = function(msg, level)
              table.insert(messages, { msg = msg, level = level })
            end

            local ok, err = pcall(function()
              centerpad.run(config, { fargs = { raw } })
            end)

            vim.notify = orig_notify
            assert.is_true(ok, label .. ": " .. tostring(err))
            assert.are.equal(
              1,
              #messages,
              label .. ": expected exactly one notification"
            )
            assert.is_true(
              string.match(messages[1].msg, pattern) ~= nil,
              label
                .. ": expected pattern '"
                .. pattern
                .. "' in: "
                .. messages[1].msg
            )
            assert.are.equal(
              vim.log.levels.ERROR,
              messages[1].level,
              label .. ": expected error level"
            )

            local preserve_ok, preserve_err = pcall(function()
              assert_preserves_baseline(config, baseline)
            end)
            assert.is_true(
              preserve_ok,
              label
                .. ": baseline preservation failed: "
                .. tostring(preserve_err)
            )
          end
        end
      end
    )

    it(
      "rejects two-argument invalid widths without mutating partial caller config or layout",
      function()
        local cases = {
          { { "", "30" }, "Invalid left width" },
          { { "abc", "30" }, "Invalid left width" },
          { { "0", "30" }, "Invalid left width" },
          { { "-1", "30" }, "Invalid left width" },
          { { "501", "30" }, "Invalid left width" },
          { { "1.5", "30" }, "Invalid left width" },
          { { "30", "" }, "Invalid right width" },
          { { "30", "abc" }, "Invalid right width" },
          { { "30", "0" }, "Invalid right width" },
          { { "30", "-1" }, "Invalid right width" },
          { { "30", "501" }, "Invalid right width" },
          { { "30", "1.5" }, "Invalid right width" },
        }

        for name, partial in pairs(partial_configs) do
          for _, case in ipairs(cases) do
            local args = case[1]
            local pattern = case[2]
            local label = name .. " / " .. table.concat(args, ",")
            local config = vim.deepcopy(partial)
            local baseline = capture_baseline(config)

            local messages = {}
            local orig_notify = vim.notify
            vim.notify = function(msg, level)
              table.insert(messages, { msg = msg, level = level })
            end

            local ok, err = pcall(function()
              centerpad.run(config, { fargs = args })
            end)

            vim.notify = orig_notify
            assert.is_true(ok, label .. ": " .. tostring(err))
            assert.are.equal(
              1,
              #messages,
              label .. ": expected exactly one notification"
            )
            assert.is_true(
              string.match(messages[1].msg, pattern) ~= nil,
              label
                .. ": expected pattern '"
                .. pattern
                .. "' in: "
                .. messages[1].msg
            )
            assert.are.equal(
              vim.log.levels.ERROR,
              messages[1].level,
              label .. ": expected error level"
            )

            local preserve_ok, preserve_err = pcall(function()
              assert_preserves_baseline(config, baseline)
            end)
            assert.is_true(
              preserve_ok,
              label
                .. ": baseline preservation failed: "
                .. tostring(preserve_err)
            )
          end
        end
      end
    )

    it(
      "rejects excess arguments without mutating partial caller config or layout",
      function()
        for name, partial in pairs(partial_configs) do
          local label = name .. " / excess"
          local config = vim.deepcopy(partial)
          local baseline = capture_baseline(config)

          local messages = {}
          local orig_notify = vim.notify
          vim.notify = function(msg, level)
            table.insert(messages, { msg = msg, level = level })
          end

          local ok, err = pcall(function()
            centerpad.run(config, { fargs = { "10", "20", "30" } })
          end)

          vim.notify = orig_notify
          assert.is_true(ok, label .. ": " .. tostring(err))
          assert.are.equal(
            1,
            #messages,
            label .. ": expected exactly one notification"
          )
          assert.is_true(
            string.match(messages[1].msg, "Invalid arguments") ~= nil,
            label .. ": expected Invalid arguments in: " .. messages[1].msg
          )
          assert.are.equal(
            vim.log.levels.ERROR,
            messages[1].level,
            label .. ": expected error level"
          )

          local preserve_ok, preserve_err = pcall(function()
            assert_preserves_baseline(config, baseline)
          end)
          assert.is_true(
            preserve_ok,
            label
              .. ": baseline preservation failed: "
              .. tostring(preserve_err)
          )
        end
      end
    )

    it(
      "accepts boundary widths with partial caller tables without breaking in-place layout",
      function()
        local cases = {
          { { "1" }, 1, 1 },
          { { "500" }, 500, 500 },
          { { "1", "500" }, 1, 500 },
        }

        for name, partial in pairs(partial_configs) do
          for _, case in ipairs(cases) do
            local args = case[1]
            local expected_left = case[2]
            local expected_right = case[3]
            local label = name .. " / " .. table.concat(args, ",")

            local config = vim.deepcopy(partial)
            local left_win = state.pad_state.left_win
            local right_win = state.pad_state.right_win

            centerpad.run(config, { fargs = args })
            vim.wait(100)

            assert.are.equal(
              expected_left,
              config.leftpad,
              label .. ": leftpad"
            )
            assert.are.equal(
              expected_right,
              config.rightpad,
              label .. ": rightpad"
            )
            assert.are.equal(
              expected_left,
              vim.api.nvim_win_get_width(state.pad_state.left_win),
              label .. ": left width"
            )
            assert.are.equal(
              expected_right,
              vim.api.nvim_win_get_width(state.pad_state.right_win),
              label .. ": right width"
            )
            assert.are.equal(
              left_win,
              state.pad_state.left_win,
              label .. ": left pad ID changed"
            )
            assert.are.equal(
              right_win,
              state.pad_state.right_win,
              label .. ": right pad ID changed"
            )
            assert.is_true(state.pad_state.enabled, label .. ": enabled")
            assert.is_true(vim.g.centerpad_enabled, label .. ": global")
          end
        end
      end
    )
  end)

  describe("run() in-place resize", function()
    local config
    local original_columns

    before_each(function()
      original_columns = vim.o.columns
      vim.o.columns = 1200
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }
      centerpad.enable(config)
      vim.wait(100)
    end)

    after_each(function()
      vim.o.columns = original_columns
    end)

    it(
      "should keep pad window and buffer IDs stable for symmetric resize",
      function()
        local left_win = state.pad_state.left_win
        local right_win = state.pad_state.right_win
        local left_buf = vim.api.nvim_win_get_buf(left_win)
        local right_buf = vim.api.nvim_win_get_buf(right_win)

        centerpad.run(config, { fargs = { "30" } })
        vim.wait(50)

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
          30,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          30,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )
        assert.are.equal(30, config.leftpad)
        assert.are.equal(30, config.rightpad)
      end
    )

    it("should keep pad IDs stable for asymmetric resize", function()
      local left_win = state.pad_state.left_win
      local right_win = state.pad_state.right_win
      local left_buf = vim.api.nvim_win_get_buf(left_win)
      local right_buf = vim.api.nvim_win_get_buf(right_win)

      centerpad.run(config, { fargs = { "10", "40" } })
      vim.wait(50)

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
      assert.are.equal(10, vim.api.nvim_win_get_width(state.pad_state.left_win))
      assert.are.equal(
        40,
        vim.api.nvim_win_get_width(state.pad_state.right_win)
      )
      assert.are.equal(10, config.leftpad)
      assert.are.equal(40, config.rightpad)
    end)

    it("should accept minimum width 1", function()
      centerpad.run(config, { fargs = { "1" } })
      vim.wait(50)

      assert.are.equal(1, vim.api.nvim_win_get_width(state.pad_state.left_win))
      assert.are.equal(1, vim.api.nvim_win_get_width(state.pad_state.right_win))
    end)

    it("should accept maximum width 500", function()
      centerpad.run(config, { fargs = { "500" } })
      vim.wait(50)

      assert.is_true(state.pads_exist())
      assert.are.equal(500, config.leftpad)
      assert.are.equal(500, config.rightpad)
    end)

    it("should update config_snapshot before in-place resize", function()
      -- Verify initial snapshot matches enable-time widths
      assert.are.equal(20, state.config_snapshot.leftpad)
      assert.are.equal(20, state.config_snapshot.rightpad)

      centerpad.run(config, { fargs = { "30", "40" } })
      vim.wait(50)

      -- Snapshot must reflect the new widths
      assert.are.equal(30, state.config_snapshot.leftpad)
      assert.are.equal(40, state.config_snapshot.rightpad)

      -- Pads should still be the same windows (in-place resize)
      assert.is_true(state.pad_state.enabled)
    end)

    it("should leave config and pads unchanged for invalid width", function()
      local left_win = state.pad_state.left_win
      local right_win = state.pad_state.right_win

      centerpad.run(config, { fargs = { "600" } })
      vim.wait(50)

      assert.are.equal(left_win, state.pad_state.left_win)
      assert.are.equal(right_win, state.pad_state.right_win)
      assert.are.equal(20, config.leftpad)
      assert.are.equal(20, config.rightpad)
    end)

    it("should not resize or cleanup for ignored filetype", function()
      local left_win = state.pad_state.left_win
      local right_win = state.pad_state.right_win

      config.ignore_filetypes = { "help" }
      vim.bo.filetype = "help"
      centerpad.run(config, { fargs = { "30" } })
      vim.wait(50)

      assert.are.equal(left_win, state.pad_state.left_win)
      assert.are.equal(right_win, state.pad_state.right_win)
      assert.are.equal(20, vim.api.nvim_win_get_width(left_win))
      assert.are.equal(20, vim.api.nvim_win_get_width(right_win))
      assert.are.equal(20, config.leftpad)
      assert.are.equal(20, config.rightpad)
      assert.is_true(state.pad_state.enabled)
    end)

    it(
      "should recover by recreating pads when a tracked buffer is corrupted",
      function()
        local left_buf = vim.api.nvim_win_get_buf(state.pad_state.left_win)
        vim.api.nvim_buf_set_var(left_buf, "is_centerpad", false)

        centerpad.run(config, { fargs = { "35" } })
        vim.wait(100)

        assert.is_true(state.pad_state.enabled)
        assert.is_true(vim.api.nvim_win_is_valid(state.pad_state.left_win))
        assert.is_true(vim.api.nvim_win_is_valid(state.pad_state.right_win))
        assert.are.equal(
          35,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          35,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )
      end
    )

    it("should disable cleanly after resizing", function()
      centerpad.run(config, { fargs = { "30" } })
      vim.wait(50)

      centerpad.run(config, { fargs = {} })
      vim.wait(50)

      assert.is_false(state.pad_state.enabled)
      assert.is_nil(state.pad_state.left_win)
      assert.is_nil(state.pad_state.right_win)
    end)

    it(
      "should preserve autocmds, globals, and saved settings during healthy resize",
      function()
        local left_win = state.pad_state.left_win
        local right_win = state.pad_state.right_win
        local autocmd_count =
          #vim.api.nvim_get_autocmds({ group = autocmds.get_padgroup() })
        local original_fillchars = vim.o.fillchars

        centerpad.run(config, { fargs = { "30" } })
        vim.wait(50)

        assert.are.equal(left_win, state.pad_state.left_win)
        assert.are.equal(right_win, state.pad_state.right_win)
        assert.are.equal(autocmd_count, #vim.api.nvim_get_autocmds({
          group = autocmds.get_padgroup(),
        }))
        assert.is_true(vim.g.centerpad_enabled)
        assert.is_true(vim.g.center_buf_enabled)
        assert.are.equal(original_fillchars, vim.o.fillchars)
      end
    )

    it("should recover when tracked main window is stale", function()
      state.pad_state.main_win = 99999

      centerpad.run(config, { fargs = { "35" } })
      vim.wait(100)

      assert.is_true(state.pad_state.enabled)
      assert.is_true(vim.api.nvim_win_is_valid(state.pad_state.left_win))
      assert.is_true(vim.api.nvim_win_is_valid(state.pad_state.right_win))
      assert.are.equal(35, vim.api.nvim_win_get_width(state.pad_state.left_win))
      assert.are.equal(
        35,
        vim.api.nvim_win_get_width(state.pad_state.right_win)
      )
    end)

    it("should recover when main_win is nil", function()
      state.pad_state.main_win = nil

      centerpad.run(config, { fargs = { "35" } })
      vim.wait(100)

      assert.is_true(state.pad_state.enabled)
      assert.is_not_nil(state.pad_state.main_win)
      assert.is_true(vim.api.nvim_win_is_valid(state.pad_state.left_win))
      assert.is_true(vim.api.nvim_win_is_valid(state.pad_state.right_win))
      assert.are.equal(35, vim.api.nvim_win_get_width(state.pad_state.left_win))
      assert.are.equal(
        35,
        vim.api.nvim_win_get_width(state.pad_state.right_win)
      )
    end)

    it("should recover when left pad is missing", function()
      local left_buf = vim.api.nvim_win_get_buf(state.pad_state.left_win)
      vim.api.nvim_buf_delete(left_buf, { force = true })
      state.pad_state.left_win = nil

      centerpad.run(config, { fargs = { "40" } })
      vim.wait(100)

      assert.is_true(state.pad_state.enabled)
      assert.is_not_nil(state.pad_state.left_win)
      assert.is_not_nil(state.pad_state.right_win)
      assert.are.equal(40, vim.api.nvim_win_get_width(state.pad_state.left_win))
      assert.are.equal(
        40,
        vim.api.nvim_win_get_width(state.pad_state.right_win)
      )
    end)

    it("should recover when right pad is missing", function()
      local right_buf = vim.api.nvim_win_get_buf(state.pad_state.right_win)
      vim.api.nvim_buf_delete(right_buf, { force = true })
      state.pad_state.right_win = nil

      centerpad.run(config, { fargs = { "45" } })
      vim.wait(100)

      assert.is_true(state.pad_state.enabled)
      assert.is_not_nil(state.pad_state.left_win)
      assert.is_not_nil(state.pad_state.right_win)
      assert.are.equal(45, vim.api.nvim_win_get_width(state.pad_state.left_win))
      assert.are.equal(
        45,
        vim.api.nvim_win_get_width(state.pad_state.right_win)
      )
    end)

    it("should enable pads when no active pads exist", function()
      centerpad.disable()
      vim.wait(50)

      assert.is_false(state.pad_state.enabled)
      assert.is_nil(state.pad_state.left_win)
      assert.is_nil(state.pad_state.right_win)

      centerpad.run(config, { fargs = { "25" } })
      vim.wait(100)

      assert.is_true(state.pad_state.enabled)
      assert.is_not_nil(state.pad_state.left_win)
      assert.is_not_nil(state.pad_state.right_win)
      assert.are.equal(25, vim.api.nvim_win_get_width(state.pad_state.left_win))
      assert.are.equal(
        25,
        vim.api.nvim_win_get_width(state.pad_state.right_win)
      )
    end)

    it("should recover via re-enable when one pad resize fails", function()
      local window_mod = require("centerpad.window")
      local orig_resize_pad = window_mod.resize_pad

      -- Make right-pad resize fail once, forcing try_resize_or_enable to
      -- fall through to M.enable (full recreation).
      local right_failed = false
      window_mod.resize_pad = function(win, size)
        if not right_failed and win == state.pad_state.right_win then
          right_failed = true
          return false
        end
        return orig_resize_pad(win, size)
      end

      centerpad.run(config, { fargs = { "15" } })

      window_mod.resize_pad = orig_resize_pad
      vim.wait(100)

      -- After recovery, pads should exist with the requested widths.
      assert.is_true(right_failed)
      assert.is_true(state.pad_state.enabled)
      assert.is_true(state.pads_exist())
      assert.are.equal(15, config.leftpad)
      assert.are.equal(15, config.rightpad)
    end)

    it(
      "should commit width snapshot without updating tracker config "
        .. "when not opted in",
      function()
        -- Clear tracker opt-in so commit_widths skips the tracker update.
        state.tracker.opted_in = false
        state.tracker.config = nil

        centerpad.run(config, { fargs = { "12", "34" } })
        vim.wait(50)

        -- config_snapshot is always updated.
        assert.are.equal(12, state.config_snapshot.leftpad)
        assert.are.equal(34, state.config_snapshot.rightpad)
        -- tracker.config stays nil because tracker.opted_in is false.
        assert.is_nil(state.tracker.config)

        -- Now opt in and resize again.
        state.tracker.opted_in = true
        state.tracker.config = {
          leftpad = 20,
          rightpad = 20,
          ignore_filetypes = config.ignore_filetypes,
          ignore_buftypes = config.ignore_buftypes,
        }
        centerpad.run(config, { fargs = { "7", "8" } })
        vim.wait(50)

        assert.are.equal(7, state.config_snapshot.leftpad)
        assert.are.equal(8, state.config_snapshot.rightpad)
        -- With opted_in true, tracker.config must also be updated.
        assert.are.equal(7, state.tracker.config.leftpad)
        assert.are.equal(8, state.tracker.config.rightpad)
      end
    )
  end)

  describe("set_debug()", function()
    it("should enable debug mode", function()
      assert.is_false(state.debug)

      centerpad.set_debug(true)

      assert.is_true(state.debug)
    end)

    it("should disable debug mode", function()
      state.debug = true

      centerpad.set_debug(false)

      assert.is_false(state.debug)
    end)
  end)

  describe("get_state()", function()
    it("should return current state", function()
      local current_state = centerpad.get_state()

      assert.is_not_nil(current_state)
      assert.is_not_nil(current_state.pad_state)
      assert.is_not_nil(current_state.validation)
    end)

    it("should include pads_exist result", function()
      local current_state = centerpad.get_state()

      assert.is_not_nil(current_state)
      assert.is_table(current_state)
      -- pads_exist is nil/false when no pads exist
      assert.is_falsy(current_state.pads_exist)
    end)

    it("should expose real, enumerable window IDs after enable", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      centerpad.enable({
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      })
      vim.wait(50)

      local current_state = centerpad.get_state()

      assert.are.equal(
        state.pad_state.main_win,
        current_state.pad_state.main_win
      )
      assert.are.equal(
        state.pad_state.left_win,
        current_state.pad_state.left_win
      )
      assert.are.equal(
        state.pad_state.right_win,
        current_state.pad_state.right_win
      )
      assert.is_true(current_state.pad_state.enabled)

      -- Guards against pad_state regressing to an opaque proxy: dot
      -- access alone doesn't catch that regression (metatable
      -- __index still resolves named fields), only enumeration does.
      assert.is_true(#vim.tbl_keys(current_state.pad_state) >= 3)
    end)
  end)

  describe("validate_state()", function()
    it("should return valid for clean state", function()
      local valid, issues = centerpad.validate_state()

      assert.is_true(valid)
      assert.are.equal(0, #issues)
    end)

    it("should detect invalid state", function()
      -- Set up invalid state (only left pad)
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

      local valid, issues = centerpad.validate_state()

      assert.is_false(valid)
      assert.is_true(#issues > 0)

      -- Cleanup
      vim.api.nvim_win_close(win, true)
    end)
  end)
end)
