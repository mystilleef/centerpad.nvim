describe("centerpad.init", function()
  local init
  local centerpad
  local state

  before_each(function()
    package.loaded["centerpad.state"] = nil
    package.loaded["centerpad.enabled"] = nil
    package.loaded["centerpad.window"] = nil
    package.loaded["centerpad.autocmds"] = nil
    package.loaded["centerpad.centerpad"] = nil
    package.loaded["centerpad.init"] = nil
    state = require("centerpad.state")
    centerpad = require("centerpad.centerpad")
    init = require("centerpad.init")
    state.reset()
    vim.g.centerpad_enabled = false
    vim.g.center_buf_enabled = false
  end)

  after_each(function()
    centerpad.disable()
  end)

  describe("setup()", function()
    it("should merge user config with defaults", function()
      init.setup({
        leftpad = 30,
        rightpad = 30,
      })

      assert.are.equal(30, init.config.leftpad)
      assert.are.equal(30, init.config.rightpad)
      -- Defaults preserved
      assert.is_false(init.config.enable_by_default)
      assert.is_not_nil(init.config.ignore_filetypes)
      assert.is_not_nil(init.config.ignore_buftypes)
    end)

    it(
      "should not enable by default when enable_by_default is false",
      function()
        init.setup({
          leftpad = 20,
          rightpad = 20,
        })

        assert.is_false(state.pad_state.enabled)
      end
    )

    it(
      "should arm auto-enable, deferred to the first FileType event, "
        .. "when enable_by_default is true",
      function()
        vim.bo.filetype = ""
        vim.bo.buftype = ""

        init.setup({
          leftpad = 20,
          rightpad = 20,
          enable_by_default = true,
          ignore_filetypes = {},
          ignore_buftypes = {},
        })

        -- Not enabled synchronously: deferring to FileType avoids
        -- creating pads around the empty startup buffer on an
        -- eager-loaded consumer.
        assert.is_false(state.pad_state.enabled)

        vim.api.nvim_exec_autocmds("FileType", {})

        assert.is_true(state.pad_state.enabled)
      end
    )

    it("should not override existing config fields with nil", function()
      init.setup({
        leftpad = 40,
      })

      assert.are.equal(40, init.config.leftpad)
      -- rightpad should still be the default 25
      assert.are.equal(25, init.config.rightpad)
    end)

    it("should accept empty config", function()
      init.setup({})

      assert.are.equal(25, init.config.leftpad)
      assert.are.equal(25, init.config.rightpad)
      assert.is_false(init.config.enable_by_default)
    end)

    it("should accept nil config", function()
      init.setup(nil)

      assert.are.equal(25, init.config.leftpad)
      assert.are.equal(25, init.config.rightpad)
      assert.is_false(init.config.enable_by_default)
    end)

    it("should not enable by default when current buffer is ignored", function()
      vim.bo.filetype = "help"
      vim.bo.buftype = ""

      init.setup({
        leftpad = 20,
        rightpad = 20,
        enable_by_default = true,
      })

      -- Default ignore_filetypes includes "help"
      assert.is_false(state.pad_state.enabled)
    end)

    it("should merge but not replace inner table defaults", function()
      init.setup({
        ignore_filetypes = { "custom_type" },
      })

      -- User-specified overrides
      assert.is_true(
        vim.tbl_contains(init.config.ignore_filetypes, "custom_type")
      )
      -- Default ignore_buftypes should still exist
      assert.is_not_nil(init.config.ignore_buftypes)
      assert.is_true(vim.tbl_contains(init.config.ignore_buftypes, "terminal"))
    end)
  end)

  describe("enable()", function()
    it("should delegate to centerpad.enable with init config", function()
      init.setup({ leftpad = 35, rightpad = 35 })
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      init.config.ignore_filetypes = {}
      init.config.ignore_buftypes = {}

      init.enable()
      vim.wait(50)

      assert.is_true(state.pad_state.enabled)
    end)
  end)

  describe("disable()", function()
    it("should delegate to centerpad.disable", function()
      init.setup({ leftpad = 20, rightpad = 20 })
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      init.config.ignore_filetypes = {}
      init.config.ignore_buftypes = {}

      init.enable()
      vim.wait(50)
      assert.is_true(state.pad_state.enabled)

      init.disable()
      assert.is_false(state.pad_state.enabled)
    end)
  end)

  describe("toggle()", function()
    it("should enable when currently disabled", function()
      init.setup({ leftpad = 20, rightpad = 20 })
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      init.config.ignore_filetypes = {}
      init.config.ignore_buftypes = {}

      init.toggle()
      vim.wait(50)

      assert.is_true(state.pad_state.enabled)
    end)

    it("should disable when currently enabled", function()
      init.setup({ leftpad = 20, rightpad = 20 })
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      init.config.ignore_filetypes = {}
      init.config.ignore_buftypes = {}

      init.enable()
      vim.wait(50)
      assert.is_true(state.pad_state.enabled)

      init.toggle()
      assert.is_false(state.pad_state.enabled)
    end)
  end)

  describe("run()", function()
    it("should delegate to centerpad.run with init config", function()
      init.setup({ leftpad = 20, rightpad = 20 })
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      init.config.ignore_filetypes = {}
      init.config.ignore_buftypes = {}

      init.run({ fargs = { "15" } })
      vim.wait(50)

      assert.is_true(state.pad_state.enabled)
    end)

    it("should reject invalid widths via delegated call", function()
      init.setup({ leftpad = 20, rightpad = 20 })
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      init.config.ignore_filetypes = {}
      init.config.ignore_buftypes = {}

      -- Enable first
      init.enable()
      vim.wait(50)

      -- Invalid width should leave existing state intact
      init.run({ fargs = { "abc" } })
      vim.wait(50)

      assert.are.equal(20, init.config.leftpad)
      assert.are.equal(20, init.config.rightpad)
    end)
  end)

  describe("set_debug()", function()
    it("should delegate to centerpad.set_debug", function()
      init.set_debug(true)
      assert.is_true(state.debug)

      init.set_debug(false)
      assert.is_false(state.debug)
    end)
  end)

  describe("get_state()", function()
    it("should delegate to centerpad.get_state", function()
      init.setup({ leftpad = 20, rightpad = 20 })
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      init.config.ignore_filetypes = {}
      init.config.ignore_buftypes = {}

      init.enable()
      vim.wait(50)

      local result = init.get_state()

      assert.is_not_nil(result)
      assert.is_not_nil(result.pad_state)
      assert.is_true(result.pad_state.enabled)
    end)

    it("should return correct state when disabled", function()
      local result = init.get_state()

      assert.is_not_nil(result)
      assert.is_false(result.pad_state.enabled)
    end)
  end)
end)
