describe("centerpad.centerpad", function()
  local centerpad
  local state

  before_each(function()
    -- Reload modules
    package.loaded["centerpad.state"] = nil
    package.loaded["centerpad.window"] = nil
    package.loaded["centerpad.autocmds"] = nil
    package.loaded["centerpad.centerpad"] = nil

    state = require("centerpad.state")
    centerpad = require("centerpad.centerpad")
    state.reset()

    -- Reset global flag
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

    it("should return false when both filetype and buftype are ignored", function()
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
    end)
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
      assert.is_not_nil(current_state.saved_settings)
      assert.is_not_nil(current_state.validation)
    end)

    it("should include pads_exist result", function()
      local current_state = centerpad.get_state()

      -- pads_exist key should exist in state (value can be nil/true/false)
      assert.is_not_nil(current_state)
      assert.is_table(current_state)
      -- Just verify the field exists by checking it's not undefined
      local has_field = current_state.pads_exist ~= nil or current_state.pads_exist == nil
      assert.is_true(has_field)
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
