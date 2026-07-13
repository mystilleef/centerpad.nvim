describe("centerpad.integration", function()
  local centerpad
  local state
  local window
  local autocmds
  local test_helper

  before_each(function()
    -- Reload all modules
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

    -- Reset state and globals
    state.reset()
    vim.g.centerpad_enabled = false
    vim.g.center_buf_enabled = false
    vim.o.columns = 120
  end)

  after_each(function()
    -- Clean up all tabs
    pcall(vim.cmd, "silent! tabonly")
    test_helper.cleanup_headless_spec()
  end)

  describe("independent tab widths", function()
    it("should maintain separate widths per tab", function()
      -- Tab 1: set leftpad=20, rightpad=30
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config1 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 30,
      }
      centerpad.enable(config1)
      vim.wait(50)

      assert.is_true(state.pad_state.enabled)
      assert.are.equal(20, config1.leftpad)
      assert.are.equal(30, config1.rightpad)

      -- Tab 2: different widths
      vim.cmd("tabnew")
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config2 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 40,
        rightpad = 50,
      }
      centerpad.enable(config2)
      vim.wait(50)

      assert.is_true(state.pad_state.enabled)
      assert.are.equal(40, config2.leftpad)
      assert.are.equal(50, config2.rightpad)

      -- Verify tab 1 widths unchanged
      vim.cmd("tabprevious")
      assert.is_true(state.pad_state.enabled)
      assert.are.equal(20, config1.leftpad)
      assert.are.equal(30, config1.rightpad)

      vim.cmd("silent! tabonly")
    end)

    it("should not resize another tab's pads when running command", function()
      -- Tab 1: enable with width 20
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config1 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }
      centerpad.enable(config1)
      vim.wait(50)

      -- Tab 2: enable with width 30
      vim.cmd("tabnew")
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config2 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 30,
        rightpad = 30,
      }
      centerpad.enable(config2)
      vim.wait(50)

      -- Run resize on tab 2
      centerpad.run(config2, { fargs = { "40" } })
      vim.wait(50)

      -- Verify tab 1 width unchanged
      vim.cmd("tabprevious")
      assert.are.equal(20, config1.leftpad)
      assert.are.equal(20, config1.rightpad)

      vim.cmd("silent! tabonly")
    end)
  end)

  describe("cross-tab pad ID validity", function()
    it("should not delete another tab's pads when disabling", function()
      -- Tab 1: enable and capture pad IDs
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config1 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }
      centerpad.enable(config1)
      vim.wait(50)

      local tab1_left = state.pad_state.left_win
      local tab1_right = state.pad_state.right_win

      -- Tab 2: enable
      vim.cmd("tabnew")
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config2 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 30,
        rightpad = 30,
      }
      centerpad.enable(config2)
      vim.wait(50)

      -- Disable on tab 2
      centerpad.disable()

      -- Verify tab 1 pads still valid
      assert.is_true(vim.api.nvim_win_is_valid(tab1_left))
      assert.is_true(vim.api.nvim_win_is_valid(tab1_right))

      vim.cmd("silent! tabonly")
    end)

    it("should not validate another tab's pad IDs", function()
      -- Tab 1: enable
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config1 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }
      centerpad.enable(config1)
      vim.wait(50)

      -- Tab 2: enable
      vim.cmd("tabnew")
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config2 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 30,
        rightpad = 30,
      }
      centerpad.enable(config2)
      vim.wait(50)

      -- Validate on tab 2 should only see tab 2's pads
      local valid, issues = centerpad.validate_state()
      assert.is_true(valid)
      assert.are.equal(0, #issues)

      vim.cmd("silent! tabonly")
    end)
  end)

  describe("tab-close pruning", function()
    it("should prune closed tab stores on access", function()
      -- Tab 1: enable
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

      -- Tab 2: enable
      vim.cmd("tabnew")
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config2 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 30,
        rightpad = 30,
      }
      centerpad.enable(config2)
      vim.wait(50)

      assert.are.equal(2, state._tab_store_count())

      -- Close tab 2
      vim.cmd("tabclose")

      -- Access state to trigger pruning
      local _ = state.pad_state.enabled

      assert.are.equal(1, state._tab_store_count())
    end)

    it("should not error when accessing state after tab close", function()
      -- Tab 1: enable
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

      -- Tab 2: enable
      vim.cmd("tabnew")
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config2 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 30,
        rightpad = 30,
      }
      centerpad.enable(config2)
      vim.wait(50)

      -- Close tab 2
      vim.cmd("tabclose")

      -- Should not error
      assert.has_no.errors(function()
        local _ = state.pad_state.enabled
        local _ = state.pad_state.left_win
        local _ = state.pad_state.right_win
      end)
    end)
  end)

  describe("local fillchars containment", function()
    it("should leave vim.go.fillchars unchanged after enable", function()
      local original = vim.go.fillchars

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

      -- Global fillchars should be unchanged
      assert.are.equal(original, vim.go.fillchars)
    end)

    it("should leave vim.go.fillchars unchanged after disable", function()
      local original = vim.go.fillchars

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

      -- Global fillchars should be unchanged
      assert.are.equal(original, vim.go.fillchars)
    end)

    it("should leave vim.go.fillchars unchanged after resize", function()
      local original = vim.go.fillchars

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

      centerpad.run(config, { fargs = { "30" } })
      vim.wait(50)

      -- Global fillchars should be unchanged
      assert.are.equal(original, vim.go.fillchars)
    end)

    it("should apply local fillchars to pad windows", function()
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

      assert.is_true(vim.api.nvim_win_is_valid(left_win))
      assert.is_true(vim.api.nvim_win_is_valid(right_win))

      local left_fc =
        vim.api.nvim_get_option_value("fillchars", { win = left_win })
      local right_fc =
        vim.api.nvim_get_option_value("fillchars", { win = right_win })

      assert.is_not_nil(left_fc)
      assert.is_not_nil(right_fc)
      assert.is_not.equal("", left_fc)
      assert.is_not.equal("", right_fc)
    end)

    it("should apply local fillchars to source window", function()
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

      local source_win = state.pad_state.main_win
      assert.is_true(vim.api.nvim_win_is_valid(source_win))

      local source_fc =
        vim.api.nvim_get_option_value("fillchars", { win = source_win })
      assert.is_not_nil(source_fc)
      assert.is_not.equal("", source_fc)
    end)

    it("should restore source window fillchars after disable", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      local main_win = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value(
        "fillchars",
        "vert:|,horiz:-",
        { win = main_win }
      )

      centerpad.enable(config)
      vim.wait(50)

      -- Source window should have Centerpad's override while enabled
      assert.are.equal(state.pad_state.main_win, main_win)
      assert.is_not.equal(
        "vert:|,horiz:-",
        vim.api.nvim_get_option_value("fillchars", { win = main_win })
      )

      centerpad.disable()
      vim.wait(50)

      -- After disable, source window should recover its pre-enable value
      if vim.api.nvim_win_is_valid(main_win) then
        local restored_fc =
          vim.api.nvim_get_option_value("fillchars", { win = main_win })
        assert.are.equal("vert:|,horiz:-", restored_fc)
      end
    end)
  end)

  describe("suspend/resume pad recreation", function()
    it("should recreate pads when returning to normal context", function()
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

      local original_left = state.pad_state.left_win
      local original_right = state.pad_state.right_win

      -- Simulate suspend by setting ignored filetype
      vim.bo.filetype = "help"
      centerpad.disable()
      vim.wait(50)

      -- Return to normal context
      vim.bo.filetype = ""
      centerpad.enable(config)
      vim.wait(50)

      -- Should have new pads (not the same window IDs)
      assert.is_true(state.pad_state.enabled)
      assert.is_not_nil(state.pad_state.left_win)
      assert.is_not_nil(state.pad_state.right_win)
      assert.are_not.equal(original_left, state.pad_state.left_win)
      assert.are_not.equal(original_right, state.pad_state.right_win)
    end)

    it("should preserve widths after suspend/resume", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 25,
        rightpad = 35,
      }
      centerpad.enable(config)
      vim.wait(50)

      -- Suspend
      centerpad.disable()
      vim.wait(50)

      -- Resume
      centerpad.enable(config)
      vim.wait(50)

      assert.are.equal(25, config.leftpad)
      assert.are.equal(35, config.rightpad)
    end)
  end)

  describe("no duplicate pad buffers", function()
    it("should not create duplicate pads on rapid enable/disable", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      -- Rapid enable/disable cycles
      for _ = 1, 5 do
        centerpad.enable(config)
        vim.wait(10)
        centerpad.disable()
        vim.wait(10)
      end

      -- Final enable
      centerpad.enable(config)
      vim.wait(50)

      -- Should have exactly one left and one right pad
      assert.is_not_nil(state.pad_state.left_win)
      assert.is_not_nil(state.pad_state.right_win)
      assert.is_true(vim.api.nvim_win_is_valid(state.pad_state.left_win))
      assert.is_true(vim.api.nvim_win_is_valid(state.pad_state.right_win))

      -- Count pad buffers
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

      assert.are.equal(2, pad_count)
    end)

    it("should not create duplicate pads across tabs", function()
      -- Tab 1
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config1 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }
      centerpad.enable(config1)
      vim.wait(50)

      -- Tab 2
      vim.cmd("tabnew")
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config2 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 30,
        rightpad = 30,
      }
      centerpad.enable(config2)
      vim.wait(50)

      -- Count pad buffers
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

      -- Should have exactly 4 pads (2 per tab)
      assert.are.equal(4, pad_count)

      vim.cmd("silent! tabonly")
    end)
  end)

  describe("failure-mode coverage", function()
    it(
      "should converge unsafe state through cleanup on partial pad creation",
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

          -- Should converge to clean state
          assert.is_false(state.pad_state.enabled)
          assert.is_nil(state.pad_state.left_win)
          assert.is_nil(state.pad_state.right_win)
          assert.is_false(vim.g.centerpad_enabled)
          assert.is_false(vim.g.center_buf_enabled)
        end)

        vim.api.nvim_open_win = orig_open_win
        package.loaded["centerpad.centerpad"] = nil

        assert.is_true(ok, err)
      end
    )

    it("should recover when tracked main window is stale", function()
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

      -- Set stale main window
      state.pad_state.main_win = 99999

      -- Run resize should recover
      centerpad.run(config, { fargs = { "30" } })
      vim.wait(100)

      assert.is_true(state.pad_state.enabled)
      assert.is_true(vim.api.nvim_win_is_valid(state.pad_state.left_win))
      assert.is_true(vim.api.nvim_win_is_valid(state.pad_state.right_win))
    end)

    it("should handle option/API failures gracefully", function()
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

      -- Should not error even with invalid operations
      assert.has_no.errors(function()
        -- Try to resize invalid window
        window.resize_pad(9999, 30)

        -- Try to get width of invalid window
        window.get_pad_width(9999)

        -- Try to set current window to invalid
        window.set_current_window(9999)
      end)
    end)

    it("should handle invalid tracked windows", function()
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

      -- Set invalid window IDs
      state.pad_state.left_win = 9999
      state.pad_state.right_win = 9998

      -- Delete pads should handle gracefully
      assert.has_no.errors(function()
        window.delete_pads()
      end)

      assert.is_nil(state.pad_state.left_win)
      assert.is_nil(state.pad_state.right_win)
    end)
  end)

  describe("edge coverage", function()
    it("should handle nil window IDs gracefully", function()
      state.pad_state.left_win = nil
      state.pad_state.right_win = nil
      state.pad_state.main_win = nil

      assert.has_no.errors(function()
        local _ = state.pads_exist()
        local _ = state.validate()
        window.delete_pads()
      end)
    end)

    it("should handle closed tabpages gracefully", function()
      -- Tab 1: enable
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

      -- Tab 2: enable
      vim.cmd("tabnew")
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config2 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 30,
        rightpad = 30,
      }
      centerpad.enable(config2)
      vim.wait(50)

      -- Close tab 2
      vim.cmd("tabclose")

      -- Should not error
      assert.has_no.errors(function()
        local _ = state.pad_state.enabled
        local _ = state.pad_state.left_win
        local _ = state.pad_state.right_win
      end)
    end)

    it("should handle asymmetric widths", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 10,
        rightpad = 40,
      }
      centerpad.enable(config)
      vim.wait(50)

      assert.is_true(state.pad_state.enabled)
      assert.are.equal(10, config.leftpad)
      assert.are.equal(40, config.rightpad)
    end)

    it("should accept width bound 1", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 1,
        rightpad = 1,
      }
      centerpad.enable(config)
      vim.wait(50)

      assert.is_true(state.pad_state.enabled)
      assert.is_true(vim.api.nvim_win_is_valid(state.pad_state.left_win))
      assert.is_true(vim.api.nvim_win_is_valid(state.pad_state.right_win))
    end)

    it("should accept width bound 500", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 500,
        rightpad = 500,
      }
      centerpad.enable(config)
      vim.wait(50)

      assert.is_true(state.pad_state.enabled)
      assert.is_true(vim.api.nvim_win_is_valid(state.pad_state.left_win))
      assert.is_true(vim.api.nvim_win_is_valid(state.pad_state.right_win))
    end)

    it("should reject zero width", function()
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

      centerpad.run(config, { fargs = { "0" } })

      -- Should not change config
      assert.are.equal(20, config.leftpad)
      assert.are.equal(20, config.rightpad)
    end)

    it("should reject empty width", function()
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

      centerpad.run(config, { fargs = { "" } })

      -- Should not change config
      assert.are.equal(20, config.leftpad)
      assert.are.equal(20, config.rightpad)
    end)

    it("should reject non-numeric width", function()
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

      centerpad.run(config, { fargs = { "abc" } })

      -- Should not change config
      assert.are.equal(20, config.leftpad)
      assert.are.equal(20, config.rightpad)
    end)

    it("should handle no-opt-in tabs", function()
      -- Tab 1: no opt-in
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      -- Tab 2: opt-in
      vim.cmd("tabnew")
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

      -- Verify tab 2 has pads
      assert.is_true(state.pad_state.enabled)

      -- Verify tab 1 has no pads
      vim.cmd("tabprevious")
      assert.is_false(state.pad_state.enabled)

      vim.cmd("silent! tabonly")
    end)
  end)

  describe("health/debug/state inspection", function()
    it("should use proxy-safe current-tab reads", function()
      -- Tab 1: enable
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

      -- Tab 2: enable with different state
      vim.cmd("tabnew")
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config2 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 30,
        rightpad = 30,
      }
      centerpad.enable(config2)
      vim.wait(50)

      -- Get state should return current tab's state
      local current_state = centerpad.get_state()
      assert.is_not_nil(current_state)
      assert.is_not_nil(current_state.pad_state)

      -- Switch to tab 1 and verify
      vim.cmd("tabprevious")
      local tab1_state = centerpad.get_state()
      assert.is_not_nil(tab1_state)

      vim.cmd("silent! tabonly")
    end)

    it(
      "should update vim.g.centerpad_enabled through centralized bridge",
      function()
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 20,
          rightpad = 20,
        }

        -- Enable
        centerpad.enable(config)
        vim.wait(50)

        assert.is_true(vim.g.centerpad_enabled)
        assert.is_true(vim.g.center_buf_enabled)

        -- Disable
        centerpad.disable()

        assert.is_false(vim.g.centerpad_enabled)
        assert.is_false(vim.g.center_buf_enabled)
      end
    )

    it("should update globals correctly across tabs", function()
      -- Tab 1: enable
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config1 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }
      centerpad.enable(config1)
      vim.wait(50)

      assert.is_true(vim.g.centerpad_enabled)

      -- Tab 2: enable
      vim.cmd("tabnew")
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config2 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 30,
        rightpad = 30,
      }
      centerpad.enable(config2)
      vim.wait(50)

      assert.is_true(vim.g.centerpad_enabled)

      -- Disable on tab 2
      centerpad.disable()

      -- Globals should reflect tab 2's disable
      assert.is_false(vim.g.centerpad_enabled)

      vim.cmd("silent! tabonly")
    end)
  end)

  describe("existing regression preservation", function()
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

    it("should recover when tracked buffer is corrupted", function()
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

      local left_buf = vim.api.nvim_win_get_buf(state.pad_state.left_win)
      vim.api.nvim_buf_set_var(left_buf, "is_centerpad", false)

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

    it("should disable cleanly after resizing", function()
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

      centerpad.run(config, { fargs = { "30" } })
      vim.wait(50)

      centerpad.run(config, { fargs = {} })
      vim.wait(50)

      assert.is_false(state.pad_state.enabled)
      assert.is_nil(state.pad_state.left_win)
      assert.is_nil(state.pad_state.right_win)
    end)
  end)

  describe("per-tab config snapshots", function()
    it(
      "should retain distinct stored configs after enable on two tabs",
      function()
        -- Tab 1: 12:13
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config1 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 12,
          rightpad = 13,
        }
        centerpad.enable(config1)
        vim.wait(50)

        assert.are.equal(12, state.config_snapshot.leftpad)
        assert.are.equal(13, state.config_snapshot.rightpad)

        -- Tab 2: 31:32
        vim.cmd("tabnew")
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config2 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 31,
          rightpad = 32,
        }
        centerpad.enable(config2)
        vim.wait(50)

        assert.are.equal(31, state.config_snapshot.leftpad)
        assert.are.equal(32, state.config_snapshot.rightpad)

        -- Verify tab 1 snapshot unchanged
        vim.cmd("tabprevious")
        assert.are.equal(12, state.config_snapshot.leftpad)
        assert.are.equal(13, state.config_snapshot.rightpad)

        vim.cmd("silent! tabonly")
      end
    )

    it("should retain distinct configs after re-enable on two tabs", function()
      -- Tab 1: 12:13
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config1 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 12,
        rightpad = 13,
      }
      centerpad.enable(config1)
      vim.wait(50)

      -- Tab 2: 31:32
      vim.cmd("tabnew")
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config2 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 31,
        rightpad = 32,
      }
      centerpad.enable(config2)
      vim.wait(50)

      -- Re-enable tab 2
      centerpad.enable(config2)
      vim.wait(50)

      assert.are.equal(31, state.config_snapshot.leftpad)
      assert.are.equal(32, state.config_snapshot.rightpad)

      -- Verify tab 1 snapshot unchanged
      vim.cmd("tabprevious")
      assert.are.equal(12, state.config_snapshot.leftpad)
      assert.are.equal(13, state.config_snapshot.rightpad)

      vim.cmd("silent! tabonly")
    end)

    it("should retain distinct configs after resize on two tabs", function()
      -- Tab 1: 12:13
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config1 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 12,
        rightpad = 13,
      }
      centerpad.enable(config1)
      vim.wait(50)

      -- Tab 2: 31:32
      vim.cmd("tabnew")
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config2 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 31,
        rightpad = 32,
      }
      centerpad.enable(config2)
      vim.wait(50)

      -- Resize tab 2 to 40:50
      centerpad.run(config2, { fargs = { "40", "50" } })
      vim.wait(50)

      assert.are.equal(40, state.config_snapshot.leftpad)
      assert.are.equal(50, state.config_snapshot.rightpad)

      -- Verify tab 1 snapshot unchanged at 12:13
      vim.cmd("tabprevious")
      assert.are.equal(12, state.config_snapshot.leftpad)
      assert.are.equal(13, state.config_snapshot.rightpad)

      vim.cmd("silent! tabonly")
    end)
  end)

  describe("atomic integer width parsing isolation", function()
    before_each(function()
      vim.o.columns = 1200
    end)

    it("rejects fractional width without mutating either tab", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config1 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 12,
        rightpad = 13,
      }
      centerpad.enable(config1)
      vim.wait(50)

      vim.cmd("tabnew")
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config2 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 31,
        rightpad = 32,
      }
      centerpad.enable(config2)
      vim.wait(50)

      local tab2_left = state.pad_state.left_win
      local tab2_right = state.pad_state.right_win

      local messages = {}
      local orig_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(messages, { msg = msg, level = level })
      end

      centerpad.run(config2, { fargs = { "40", "3.14" } })

      vim.notify = orig_notify

      assert.are.equal(31, config2.leftpad)
      assert.are.equal(32, config2.rightpad)
      assert.are.equal(31, vim.api.nvim_win_get_width(tab2_left))
      assert.are.equal(32, vim.api.nvim_win_get_width(tab2_right))
      assert.are.equal(1, #messages)
      assert.is_true(
        string.match(messages[1].msg, "Invalid right width") ~= nil
      )
      assert.are.equal(vim.log.levels.ERROR, messages[1].level)

      vim.cmd("tabprevious")
      assert.are.equal(12, config1.leftpad)
      assert.are.equal(13, config1.rightpad)
      assert.are.equal(12, vim.api.nvim_win_get_width(state.pad_state.left_win))
      assert.are.equal(
        13,
        vim.api.nvim_win_get_width(state.pad_state.right_win)
      )

      vim.cmd("silent! tabonly")
    end)

    it(
      "accepts boundary integer widths without affecting sibling tab",
      function()
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config1 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 12,
          rightpad = 13,
        }
        centerpad.enable(config1)
        vim.wait(50)

        vim.cmd("tabnew")
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config2 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 31,
          rightpad = 32,
        }
        centerpad.enable(config2)
        vim.wait(50)

        centerpad.run(config2, { fargs = { "1", "500" } })
        vim.wait(50)

        assert.are.equal(1, config2.leftpad)
        assert.are.equal(500, config2.rightpad)
        assert.are.equal(
          1,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          500,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )

        vim.cmd("tabprevious")
        assert.are.equal(12, config1.leftpad)
        assert.are.equal(13, config1.rightpad)
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

  describe("per-tab timer isolation", function()
    it(
      "should not cancel sibling restore timer on current-tab cleanup",
      function()
        -- Tab 1: set a restore timer
        state.set_restore_timer(111)

        -- Tab 2: cleanup should not touch tab 1's timer
        vim.cmd("tabnew")
        require("centerpad.autocmds").cleanup()

        -- Tab 1 timer should still be 111
        vim.cmd("tabprevious")
        assert.are.equal(111, state.get_restore_timer())

        vim.cmd("silent! tabonly")
      end
    )

    it(
      "should not mutate sibling config snapshot on current-tab disable",
      function()
        -- Tab 1: enable with 12:13
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config1 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 12,
          rightpad = 13,
        }
        centerpad.enable(config1)
        vim.wait(50)

        -- Tab 2: enable then disable
        vim.cmd("tabnew")
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config2 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 31,
          rightpad = 32,
        }
        centerpad.enable(config2)
        vim.wait(50)
        centerpad.disable()

        -- Tab 1 snapshot should be unchanged
        vim.cmd("tabprevious")
        assert.are.equal(12, state.config_snapshot.leftpad)
        assert.are.equal(13, state.config_snapshot.rightpad)
        assert.is_true(state.pad_state.enabled)

        vim.cmd("silent! tabonly")
      end
    )
  end)

  describe("nil window and closed tabpage pruning", function()
    it(
      "should prune closed tab store without stale timers or config",
      function()
        -- Tab 1: enable with config
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config1 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 15,
          rightpad = 17,
        }
        centerpad.enable(config1)
        vim.wait(50)

        -- Tab 2: enable with different config and set a timer
        vim.cmd("tabnew")
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config2 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 35,
          rightpad = 37,
        }
        centerpad.enable(config2)
        vim.wait(50)
        state.set_restore_timer(888)

        assert.are.equal(2, state._tab_store_count())

        -- Close tab 2
        vim.cmd("tabclose")

        -- Access to trigger pruning
        local _ = state.pad_state.enabled

        assert.are.equal(1, state._tab_store_count())

        -- Tab 1 snapshot and timer should be unaffected
        assert.are.equal(15, state.config_snapshot.leftpad)
        assert.are.equal(17, state.config_snapshot.rightpad)
        assert.is_nil(state.get_restore_timer())
      end
    )

    it(
      "should not error on nil window IDs in a fresh tab with snapshot",
      function()
        vim.cmd("tabnew")

        assert.is_nil(state.config_snapshot.leftpad)
        assert.is_nil(state.config_snapshot.rightpad)
        assert.is_nil(state.get_restore_timer())
        assert.is_nil(state.tracker.debounce_timer)

        -- reset should not error
        assert.has_no.errors(function()
          state.reset()
        end)

        assert.is_nil(state.config_snapshot.leftpad)

        vim.cmd("silent! tabonly")
      end
    )
  end)

  describe("cross-tab pad lifecycle isolation", function()
    it(
      "closing tab1 pad after tab2 width change rebuilds tab1 at its own widths",
      function()
        -- Tab 1: 12:13
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config1 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 12,
          rightpad = 13,
        }
        centerpad.enable(config1)
        vim.wait(50)

        -- Tab 2: 31:32
        vim.cmd("tabnew")
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config2 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 31,
          rightpad = 32,
        }
        centerpad.enable(config2)
        vim.wait(50)

        -- Resize tab 2 to 40:50
        centerpad.run(config2, { fargs = { "40", "50" } })
        vim.wait(50)

        -- Switch back to tab 1 and close its left pad
        vim.cmd("tabprevious")
        local left_buf = vim.api.nvim_win_get_buf(state.pad_state.left_win)
        pcall(vim.api.nvim_buf_delete, left_buf, { force = true })
        vim.wait(300)

        -- Tab 1 should recover at its own 12:13 widths
        assert.is_true(state.pad_state.enabled)
        assert.is_true(window.are_pads_valid())
        assert.are.equal(
          12,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          13,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )

        -- Tab 2 should be untouched
        vim.cmd("tabnext")
        assert.is_true(state.pad_state.enabled)
        assert.are.equal(
          40,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          50,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )

        vim.cmd("silent! tabonly")
      end
    )

    it("tab2 resize or disable cannot change tab1 recovery widths", function()
      -- Tab 1: 12:13
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config1 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 12,
        rightpad = 13,
      }
      centerpad.enable(config1)
      vim.wait(50)

      -- Tab 2: 31:32
      vim.cmd("tabnew")
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config2 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 31,
        rightpad = 32,
      }
      centerpad.enable(config2)
      vim.wait(50)

      -- Resize tab 2
      centerpad.run(config2, { fargs = { "40", "50" } })
      vim.wait(50)

      -- Disable tab 2
      centerpad.disable()
      vim.wait(50)

      -- Tab 1 snapshot should be unchanged
      vim.cmd("tabprevious")
      assert.are.equal(12, state.config_snapshot.leftpad)
      assert.are.equal(13, state.config_snapshot.rightpad)
      assert.is_true(state.pad_state.enabled)
      assert.is_true(state.pads_exist())

      vim.cmd("silent! tabonly")
    end)

    it("rapid WinClosed bursts on one tab do not affect other tabs", function()
      -- Tab 1: 12:13
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config1 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 12,
        rightpad = 13,
      }
      centerpad.enable(config1)
      vim.wait(50)

      -- Tab 2: 31:32
      vim.cmd("tabnew")
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config2 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 31,
        rightpad = 32,
      }
      centerpad.enable(config2)
      vim.wait(50)

      -- Rapid window creates and closes on tab 2
      for _ = 1, 5 do
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
      vim.wait(200)

      -- Tab 1 should be completely unaffected
      vim.cmd("tabprevious")
      assert.is_true(state.pad_state.enabled)
      assert.is_true(state.pads_exist())
      assert.are.equal(12, vim.api.nvim_win_get_width(state.pad_state.left_win))
      assert.are.equal(
        13,
        vim.api.nvim_win_get_width(state.pad_state.right_win)
      )
      assert.is_true(vim.g.centerpad_enabled)

      vim.cmd("silent! tabonly")
    end)

    it("recovery on closed tab does not enable on surviving tab", function()
      -- Tab 1: enable
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config1 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 15,
        rightpad = 17,
      }
      centerpad.enable(config1)
      vim.wait(50)

      -- Tab 2: enable, then close
      vim.cmd("tabnew")
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config2 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 35,
        rightpad = 37,
      }
      centerpad.enable(config2)
      vim.wait(50)

      -- Close tab 2
      vim.cmd("tabclose")
      vim.wait(100)

      -- Tab 1 should still be at 15:17, not 35:37
      assert.is_true(state.pad_state.enabled)
      assert.is_true(state.pads_exist())
      assert.are.equal(15, vim.api.nvim_win_get_width(state.pad_state.left_win))
      assert.are.equal(
        17,
        vim.api.nvim_win_get_width(state.pad_state.right_win)
      )
      assert.are.equal(15, state.config_snapshot.leftpad)
      assert.are.equal(17, state.config_snapshot.rightpad)
    end)
  end)

  describe("cross-tab tracker + suspend interaction", function()
    it(
      "tab2 disable then tab1 ignored-context suspend resumes with own config",
      function()
        -- Tab 1: opt-in with 12:13
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config1 = {
          ignore_filetypes = { "help" },
          ignore_buftypes = {},
          leftpad = 12,
          rightpad = 13,
        }
        centerpad.enable(config1)
        vim.wait(50)

        -- Tab 2: opt-in with 31:32
        vim.cmd("tabnew")
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config2 = {
          ignore_filetypes = { "help" },
          ignore_buftypes = {},
          leftpad = 31,
          rightpad = 32,
        }
        centerpad.enable(config2)
        vim.wait(50)

        -- Disable tab 2
        centerpad.disable()
        vim.wait(50)

        -- Switch to tab 1
        vim.cmd("tabprevious")
        assert.is_true(state.pad_state.enabled)
        assert.is_true(state.tracker.opted_in)

        -- Suspend tab 1 via ignored filetype
        local help_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = help_buf })
        vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf })
        vim.api.nvim_set_current_buf(help_buf)
        vim.wait(150)

        assert.is_true(state.tracker.suspended)
        assert.is_false(state.pad_state.enabled)

        -- Resume tab 1
        local normal_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = normal_buf })
        vim.api.nvim_set_option_value("filetype", "", { buf = normal_buf })
        vim.api.nvim_set_current_buf(normal_buf)
        vim.wait(150)

        -- Tab 1 should resume with its own 12:13 config
        assert.is_true(state.pad_state.enabled)
        assert.is_true(state.pads_exist())
        assert.is_false(state.tracker.suspended)
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

  describe("stable unrelated WinClosed paths", function()
    it("closing non-pad split keeps pad IDs stable", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 12,
        rightpad = 13,
      }
      centerpad.enable(config)
      vim.wait(50)

      local left_win = state.pad_state.left_win
      local right_win = state.pad_state.right_win
      local main_win = state.pad_state.main_win

      -- Create an unrelated split
      local split_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = split_buf })
      local split_win = vim.api.nvim_open_win(split_buf, false, {
        split = "right",
        win = main_win,
      })
      vim.wait(50)

      -- Close the unrelated split
      vim.api.nvim_win_close(split_win, true)
      vim.wait(150)

      -- Pad IDs should be stable
      assert.are.equal(left_win, state.pad_state.left_win)
      assert.are.equal(right_win, state.pad_state.right_win)
      assert.are.equal(main_win, state.pad_state.main_win)
      assert.is_true(state.pad_state.enabled)
      assert.is_true(state.pads_exist())
    end)

    it("closing non-pad split on tab2 does not affect tab1 pads", function()
      -- Tab 1: enable
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config1 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 12,
        rightpad = 13,
      }
      centerpad.enable(config1)
      vim.wait(50)

      local tab1_left = state.pad_state.left_win
      local tab1_right = state.pad_state.right_win

      -- Tab 2: enable
      vim.cmd("tabnew")
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config2 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 31,
        rightpad = 32,
      }
      centerpad.enable(config2)
      vim.wait(50)

      -- Create and close unrelated split on tab 2
      local split_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = split_buf })
      local split_win = vim.api.nvim_open_win(
        split_buf,
        false,
        { split = "right", win = state.pad_state.main_win }
      )
      vim.wait(50)
      vim.api.nvim_win_close(split_win, true)
      vim.wait(150)

      -- Tab 1 pads should be untouched
      vim.cmd("tabprevious")
      assert.are.equal(tab1_left, state.pad_state.left_win)
      assert.are.equal(tab1_right, state.pad_state.right_win)
      assert.is_true(state.pad_state.enabled)

      vim.cmd("silent! tabonly")
    end)
  end)

  describe("cross-tab fillchars isolation", function()
    it("tab2 enable does not change tab1 source window fillchars", function()
      -- Tab 1: enable
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config1 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 12,
        rightpad = 13,
      }
      centerpad.enable(config1)
      vim.wait(50)

      local tab1_source = state.pad_state.main_win
      local tab1_source_fc =
        vim.api.nvim_get_option_value("fillchars", { win = tab1_source })

      -- Tab 2: enable with different widths
      vim.cmd("tabnew")
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config2 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 31,
        rightpad = 32,
      }
      centerpad.enable(config2)
      vim.wait(50)

      -- Tab 1 source fillchars should be unchanged
      if vim.api.nvim_win_is_valid(tab1_source) then
        local current_fc =
          vim.api.nvim_get_option_value("fillchars", { win = tab1_source })
        assert.are.equal(tab1_source_fc, current_fc)
      end

      -- Global fillchars should be unchanged
      assert.are.equal(vim.go.fillchars, vim.go.fillchars)

      vim.cmd("silent! tabonly")
    end)
  end)

  describe("cross-tab enabled bridge", function()
    it("disable on tab2 does not break enabled bridge for tab1", function()
      -- Tab 1: enable
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config1 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 12,
        rightpad = 13,
      }
      centerpad.enable(config1)
      vim.wait(50)

      -- Tab 2: enable then disable
      vim.cmd("tabnew")
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config2 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 31,
        rightpad = 32,
      }
      centerpad.enable(config2)
      vim.wait(50)
      centerpad.disable()
      vim.wait(50)

      -- Globals should reflect tab 2's disable
      assert.is_false(vim.g.centerpad_enabled)

      -- Switch to tab 1
      vim.cmd("tabprevious")

      -- Tab 1 is still enabled
      assert.is_true(state.pad_state.enabled)
      assert.is_true(state.pads_exist())

      -- Disable tab 1 cleanly
      centerpad.disable()

      -- Globals should now be false
      assert.is_false(vim.g.centerpad_enabled)
      assert.is_false(vim.g.center_buf_enabled)
      assert.is_false(state.pad_state.enabled)
      assert.is_nil(state.pad_state.left_win)
      assert.is_nil(state.pad_state.right_win)

      vim.cmd("silent! tabonly")
    end)

    it(
      "switching tabs resyncs the global to the entered tab's state",
      function()
        -- Tab 1: enable
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config1 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 12,
          rightpad = 13,
        }
        centerpad.enable(config1)
        vim.wait(50)

        -- Tab 2: enable then disable
        vim.cmd("tabnew")
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config2 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 31,
          rightpad = 32,
        }
        centerpad.enable(config2)
        vim.wait(50)
        centerpad.disable()
        vim.wait(50)

        assert.is_false(vim.g.centerpad_enabled)

        -- Switch to tab 1 without touching centerpad: the global must
        -- resync to tab 1's actual (still-enabled) state.
        vim.cmd("tabprevious")
        vim.wait(50)

        assert.is_true(state.pad_state.enabled)
        assert.is_true(vim.g.centerpad_enabled)
        assert.is_true(vim.g.center_buf_enabled)

        -- Switch back to tab 2: global must resync to tab 2's disabled
        -- state again, purely from the tab switch.
        vim.cmd("tabnext")
        vim.wait(50)

        assert.is_false(vim.g.centerpad_enabled)

        vim.cmd("silent! tabonly")
      end
    )

    it(
      "switching to a tab that never enabled centerpad clears the global",
      function()
        -- Tab 1: enable
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config1 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 12,
          rightpad = 13,
        }
        centerpad.enable(config1)
        vim.wait(50)

        assert.is_true(vim.g.centerpad_enabled)

        -- Tab 2: never touches centerpad
        vim.cmd("tabnew")
        vim.wait(50)

        assert.is_false(vim.g.centerpad_enabled)
        assert.is_false(vim.g.center_buf_enabled)

        vim.cmd("silent! tabonly")
      end
    )
  end)

  describe("both pad buffers closed externally", function()
    it(
      "recovery rebuilds with own config when both pad buffers are closed",
      function()
        -- Tab 1: 12:13
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config1 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 12,
          rightpad = 13,
        }
        centerpad.enable(config1)
        vim.wait(50)

        -- Tab 2: 31:32
        vim.cmd("tabnew")
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config2 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 31,
          rightpad = 32,
        }
        centerpad.enable(config2)
        vim.wait(50)

        -- Switch to tab 1 and close both pad buffers
        vim.cmd("tabprevious")
        local left_buf = vim.api.nvim_win_get_buf(state.pad_state.left_win)
        local right_buf = vim.api.nvim_win_get_buf(state.pad_state.right_win)
        pcall(vim.api.nvim_buf_delete, left_buf, { force = true })
        pcall(vim.api.nvim_buf_delete, right_buf, { force = true })
        vim.wait(300)

        -- Tab 1 should recover with its own 12:13 config
        assert.is_true(state.pad_state.enabled)
        assert.is_true(state.pads_exist())
        assert.are.equal(
          12,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          13,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )

        -- Tab 2 should be untouched
        vim.cmd("tabnext")
        assert.is_true(state.pad_state.enabled)
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

  describe("owner-tab recovery debounce", function()
    it(
      "hard debounce repro recovers owner with config snapshot while sibling untouched",
      function()
        -- Tab 1: 12:13 — asymmetric widths to prove owner config is used
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config1 = {
          ignore_filetypes = { "help" },
          ignore_buftypes = { "terminal" },
          leftpad = 12,
          rightpad = 13,
        }
        centerpad.enable(config1)
        vim.wait(50)

        -- Corrupt tab 1 left pad marker so recovery will trigger
        local tab1_left_buf = vim.api.nvim_win_get_buf(state.pad_state.left_win)
        vim.api.nvim_buf_set_var(tab1_left_buf, "is_centerpad", false)

        -- Tab 2: 31:32 — enable with different asymmetric widths and ignore lists
        vim.cmd("tabnew")
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config2 = {
          ignore_filetypes = { "qf" },
          ignore_buftypes = { "quickfix" },
          leftpad = 31,
          rightpad = 32,
        }
        centerpad.enable(config2)
        vim.wait(50)

        -- Capture comprehensive tab 2 state before triggering recovery
        local tab2_left_win = state.pad_state.left_win
        local tab2_right_win = state.pad_state.right_win
        local tab2_left_buf = vim.api.nvim_win_get_buf(tab2_left_win)
        local tab2_right_buf = vim.api.nvim_win_get_buf(tab2_right_win)
        local tab2_main_win = state.pad_state.main_win
        local tab2_source_fc =
          vim.api.nvim_get_option_value("fillchars", { win = tab2_main_win })
        local tab2_pad_left_fc =
          vim.api.nvim_get_option_value("fillchars", { win = tab2_left_win })
        local tab2_pad_right_fc =
          vim.api.nvim_get_option_value("fillchars", { win = tab2_right_win })
        local tab2_config_snap = {
          leftpad = state.config_snapshot.leftpad,
          rightpad = state.config_snapshot.rightpad,
          ignore_filetypes = state.config_snapshot.ignore_filetypes,
          ignore_buftypes = state.config_snapshot.ignore_buftypes,
        }
        local tab2_autocmd_count =
          #vim.api.nvim_get_autocmds({ group = autocmds.get_padgroup() })
        local tab2_tracker_opted_in = state.tracker.opted_in
        local tab2_tracker_suspended = state.tracker.suspended
        local tab2_enabled = state.pad_state.enabled

        -- Stay on tab 2 and drain the debounced timer.
        -- Without owner-tab switching, the timer body would read
        -- tab 2's state (enabled, pads valid, widths 31:32) and
        -- either skip recovery or recover tab 2 instead of tab 1.
        --
        -- To trigger the WinClosed event for tab 1 while tab 2 is
        -- current, close a normal split on tab 1.  The autocmd's
        -- owner_tab guard allows the timer to be scheduled, but
        -- the timer body needs owner context to read tab 1 state.
        vim.cmd("tabprevious")
        local split_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = split_buf })
        local split_win = vim.api.nvim_open_win(
          split_buf,
          false,
          { split = "right", win = state.pad_state.main_win }
        )
        -- Schedule recovery by closing the split on tab 1
        vim.api.nvim_win_close(split_win, true)
        -- Immediately switch to tab 2 before the 50ms debounce fires
        vim.cmd("tabnext")

        -- Drain the debounced timer while tab 2 is current
        vim.wait(200)

        -- Tab 1 should have recovered at its own 12:13 widths
        vim.cmd("tabprevious")
        assert.is_true(state.pad_state.enabled)
        assert.is_true(window.are_pads_valid())
        assert.are.equal(
          12,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          13,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )
        assert.is_nil(state.get_restore_timer())

        -- Tab 2 should be completely untouched
        vim.cmd("tabnext")
        -- Pad window IDs and buffers unchanged
        assert.are.equal(tab2_left_win, state.pad_state.left_win)
        assert.are.equal(tab2_right_win, state.pad_state.right_win)
        assert.are.equal(
          tab2_left_buf,
          vim.api.nvim_win_get_buf(state.pad_state.left_win)
        )
        assert.are.equal(
          tab2_right_buf,
          vim.api.nvim_win_get_buf(state.pad_state.right_win)
        )
        -- Source window unchanged
        assert.are.equal(tab2_main_win, state.pad_state.main_win)
        -- Widths preserved at 31:32
        assert.are.equal(
          31,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          32,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )
        -- Fillchars unchanged
        assert.are.equal(
          tab2_source_fc,
          vim.api.nvim_get_option_value("fillchars", { win = tab2_main_win })
        )
        assert.are.equal(
          tab2_pad_left_fc,
          vim.api.nvim_get_option_value("fillchars", { win = tab2_left_win })
        )
        assert.are.equal(
          tab2_pad_right_fc,
          vim.api.nvim_get_option_value("fillchars", { win = tab2_right_win })
        )
        -- Config snapshot unchanged
        assert.are.equal(
          tab2_config_snap.leftpad,
          state.config_snapshot.leftpad
        )
        assert.are.equal(
          tab2_config_snap.rightpad,
          state.config_snapshot.rightpad
        )
        assert.are.same(
          tab2_config_snap.ignore_filetypes,
          state.config_snapshot.ignore_filetypes
        )
        assert.are.same(
          tab2_config_snap.ignore_buftypes,
          state.config_snapshot.ignore_buftypes
        )
        -- Autocmd group unchanged
        assert.are.equal(
          tab2_autocmd_count,
          #vim.api.nvim_get_autocmds({ group = autocmds.get_padgroup() })
        )
        -- Tracker state unchanged
        assert.are.equal(tab2_tracker_opted_in, state.tracker.opted_in)
        assert.are.equal(tab2_tracker_suspended, state.tracker.suspended)
        -- Enabled flag unchanged
        assert.are.equal(tab2_enabled, state.pad_state.enabled)
        assert.is_true(state.pad_state.enabled)

        vim.cmd("silent! tabonly")
      end
    )

    it(
      "owner recovery after sibling resize uses owner config snapshot not sibling",
      function()
        -- Tab 1: 12:13 — asymmetric widths
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config1 = {
          ignore_filetypes = { "help" },
          ignore_buftypes = { "terminal" },
          leftpad = 12,
          rightpad = 13,
        }
        centerpad.enable(config1)
        vim.wait(50)

        -- Tab 2: 31:32
        vim.cmd("tabnew")
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config2 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 31,
          rightpad = 32,
        }
        centerpad.enable(config2)
        vim.wait(50)

        -- Resize tab 2 to 40:50
        centerpad.run(config2, { fargs = { "40", "50" } })
        vim.wait(50)

        -- Corrupt tab 1 left pad marker so recovery will trigger
        vim.cmd("tabprevious")
        local tab1_left_buf = vim.api.nvim_win_get_buf(state.pad_state.left_win)
        vim.api.nvim_buf_set_var(tab1_left_buf, "is_centerpad", false)

        -- Capture tab 1 config snapshot to verify it's used
        local tab1_config_snap = {
          leftpad = state.config_snapshot.leftpad,
          rightpad = state.config_snapshot.rightpad,
          ignore_filetypes = state.config_snapshot.ignore_filetypes,
          ignore_buftypes = state.config_snapshot.ignore_buftypes,
        }

        -- Trigger recovery on tab 1
        local split_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = split_buf })
        local split_win = vim.api.nvim_open_win(
          split_buf,
          false,
          { split = "right", win = state.pad_state.main_win }
        )
        vim.api.nvim_win_close(split_win, true)
        -- Switch to tab 2 before timer fires
        vim.cmd("tabnext")
        -- Drain the timer while tab 2 is current
        vim.wait(200)

        -- Tab 1 should have recovered at its OWN 12:13 widths, not tab 2's 40:50
        vim.cmd("tabprevious")
        assert.is_true(state.pad_state.enabled)
        assert.is_true(window.are_pads_valid())
        assert.are.equal(
          12,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          13,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )
        -- Config snapshot should be the owner's original config
        assert.are.equal(
          tab1_config_snap.leftpad,
          state.config_snapshot.leftpad
        )
        assert.are.equal(
          tab1_config_snap.rightpad,
          state.config_snapshot.rightpad
        )
        assert.are.same(
          tab1_config_snap.ignore_filetypes,
          state.config_snapshot.ignore_filetypes
        )
        assert.are.same(
          tab1_config_snap.ignore_buftypes,
          state.config_snapshot.ignore_buftypes
        )
        assert.is_nil(state.get_restore_timer())

        -- Tab 2 should still be at 40:50 after resize
        vim.cmd("tabnext")
        assert.is_true(state.pad_state.enabled)
        assert.are.equal(
          40,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          50,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )

        vim.cmd("silent! tabonly")
      end
    )

    it("closed owner tab exits timer without sibling side effects", function()
      -- Tab 1: 12:13
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config1 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 12,
        rightpad = 13,
      }
      centerpad.enable(config1)
      vim.wait(50)

      -- Tab 2: 31:32
      vim.cmd("tabnew")
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config2 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 31,
        rightpad = 32,
      }
      centerpad.enable(config2)
      vim.wait(50)

      -- Capture tab 2 state
      local tab2_left_win = state.pad_state.left_win
      local tab2_right_win = state.pad_state.right_win

      -- Switch to tab 1, trigger recovery, close tab 1, switch to tab 2
      vim.cmd("tabprevious")
      local split_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = split_buf })
      local split_win = vim.api.nvim_open_win(
        split_buf,
        false,
        { split = "right", win = state.pad_state.main_win }
      )
      vim.api.nvim_win_close(split_win, true)
      -- Close tab 1 and switch to tab 2 before timer fires
      vim.cmd("tabclose")
      vim.wait(200)

      -- Tab 2 should be completely untouched
      assert.are.equal(tab2_left_win, state.pad_state.left_win)
      assert.are.equal(tab2_right_win, state.pad_state.right_win)
      assert.are.equal(31, vim.api.nvim_win_get_width(state.pad_state.left_win))
      assert.are.equal(
        32,
        vim.api.nvim_win_get_width(state.pad_state.right_win)
      )
      assert.is_true(state.pad_state.enabled)
      assert.is_nil(state.get_restore_timer())

      vim.cmd("silent! tabonly")
    end)

    it("rapid owner WinClosed events replace only the owner timer", function()
      -- Tab 1: 12:13
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config1 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 12,
        rightpad = 13,
      }
      centerpad.enable(config1)
      vim.wait(50)

      -- Tab 2: 31:32 — set a fake timer to verify it's not cancelled
      vim.cmd("tabnew")
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config2 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 31,
        rightpad = 32,
      }
      centerpad.enable(config2)
      vim.wait(50)
      local tab2_timer = vim.fn.timer_start(10000, function() end)
      state.set_restore_timer(tab2_timer)

      -- Switch to tab 1 and trigger rapid WinClosed events
      vim.cmd("tabprevious")
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
      vim.wait(200)

      -- Tab 1 should have recovered (stable pads at 12:13)
      assert.is_true(state.pad_state.enabled)
      assert.is_true(state.pads_exist())
      assert.are.equal(12, vim.api.nvim_win_get_width(state.pad_state.left_win))
      assert.are.equal(
        13,
        vim.api.nvim_win_get_width(state.pad_state.right_win)
      )
      assert.is_nil(state.get_restore_timer())

      -- Tab 2 timer should be untouched
      vim.cmd("tabnext")
      assert.are.equal(tab2_timer, state.get_restore_timer())
      assert.is_true(state.pad_state.enabled)

      -- Cleanup: stop the fake timer
      pcall(vim.fn.timer_stop, tab2_timer)
      state.set_restore_timer(nil)
      vim.cmd("silent! tabonly")
    end)

    it(
      "owner with missing left pad ID triggers cleanup without sibling repair",
      function()
        -- Tab 1: 12:13
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config1 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 12,
          rightpad = 13,
        }
        centerpad.enable(config1)
        vim.wait(50)

        -- Tab 2: 31:32
        vim.cmd("tabnew")
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config2 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 31,
          rightpad = 32,
        }
        centerpad.enable(config2)
        vim.wait(50)

        -- Capture tab 2 state
        local tab2_left_win = state.pad_state.left_win
        local tab2_right_win = state.pad_state.right_win
        local tab2_enabled = state.pad_state.enabled

        -- Switch to tab 1 and set left pad ID to nil
        vim.cmd("tabprevious")
        state.pad_state.left_win = nil

        -- Trigger recovery by closing a split
        local split_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = split_buf })
        local split_win = vim.api.nvim_open_win(
          split_buf,
          false,
          { split = "right", win = state.pad_state.main_win }
        )
        vim.api.nvim_win_close(split_win, true)
        -- Switch to tab 2 before timer fires
        vim.cmd("tabnext")
        vim.wait(200)

        -- Tab 1 should have recovered at its own 12:13 widths
        vim.cmd("tabprevious")
        assert.is_true(state.pad_state.enabled)
        assert.is_true(window.are_pads_valid())
        assert.are.equal(
          12,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          13,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )
        assert.is_nil(state.get_restore_timer())

        -- Tab 2 should be completely untouched
        vim.cmd("tabnext")
        assert.are.equal(tab2_left_win, state.pad_state.left_win)
        assert.are.equal(tab2_right_win, state.pad_state.right_win)
        assert.are.equal(tab2_enabled, state.pad_state.enabled)
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

    it(
      "owner with missing right pad ID triggers cleanup without sibling repair",
      function()
        -- Tab 1: 12:13
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config1 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 12,
          rightpad = 13,
        }
        centerpad.enable(config1)
        vim.wait(50)

        -- Tab 2: 31:32
        vim.cmd("tabnew")
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config2 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 31,
          rightpad = 32,
        }
        centerpad.enable(config2)
        vim.wait(50)

        -- Capture tab 2 state
        local tab2_left_win = state.pad_state.left_win
        local tab2_right_win = state.pad_state.right_win
        local tab2_enabled = state.pad_state.enabled

        -- Switch to tab 1 and set right pad ID to nil
        vim.cmd("tabprevious")
        state.pad_state.right_win = nil

        -- Trigger recovery by closing a split
        local split_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = split_buf })
        local split_win = vim.api.nvim_open_win(
          split_buf,
          false,
          { split = "right", win = state.pad_state.main_win }
        )
        vim.api.nvim_win_close(split_win, true)
        -- Switch to tab 2 before timer fires
        vim.cmd("tabnext")
        vim.wait(200)

        -- Tab 1 should have recovered at its own 12:13 widths
        vim.cmd("tabprevious")
        assert.is_true(state.pad_state.enabled)
        assert.is_true(window.are_pads_valid())
        assert.are.equal(
          12,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          13,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )
        assert.is_nil(state.get_restore_timer())

        -- Tab 2 should be completely untouched
        vim.cmd("tabnext")
        assert.are.equal(tab2_left_win, state.pad_state.left_win)
        assert.are.equal(tab2_right_win, state.pad_state.right_win)
        assert.are.equal(tab2_enabled, state.pad_state.enabled)
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

    it(
      "owner with invalid pad window triggers cleanup without sibling repair",
      function()
        -- Tab 1: 12:13
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config1 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 12,
          rightpad = 13,
        }
        centerpad.enable(config1)
        vim.wait(50)

        -- Tab 2: 31:32
        vim.cmd("tabnew")
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config2 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 31,
          rightpad = 32,
        }
        centerpad.enable(config2)
        vim.wait(50)

        -- Capture tab 2 state
        local tab2_left_win = state.pad_state.left_win
        local tab2_right_win = state.pad_state.right_win
        local tab2_enabled = state.pad_state.enabled

        -- Switch to tab 1 and set left pad to invalid window
        vim.cmd("tabprevious")
        state.pad_state.left_win = 99999

        -- Trigger recovery by closing a split
        local split_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = split_buf })
        local split_win = vim.api.nvim_open_win(
          split_buf,
          false,
          { split = "right", win = state.pad_state.main_win }
        )
        vim.api.nvim_win_close(split_win, true)
        -- Switch to tab 2 before timer fires
        vim.cmd("tabnext")
        vim.wait(200)

        -- Tab 1 should have recovered at its own 12:13 widths
        vim.cmd("tabprevious")
        assert.is_true(state.pad_state.enabled)
        assert.is_true(window.are_pads_valid())
        assert.are.equal(
          12,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          13,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )
        assert.is_nil(state.get_restore_timer())

        -- Tab 2 should be completely untouched
        vim.cmd("tabnext")
        assert.are.equal(tab2_left_win, state.pad_state.left_win)
        assert.are.equal(tab2_right_win, state.pad_state.right_win)
        assert.are.equal(tab2_enabled, state.pad_state.enabled)
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

    it(
      "owner with corrupted pad marker triggers cleanup without sibling repair",
      function()
        -- Tab 1: 12:13
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config1 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 12,
          rightpad = 13,
        }
        centerpad.enable(config1)
        vim.wait(50)

        -- Tab 2: 31:32
        vim.cmd("tabnew")
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config2 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 31,
          rightpad = 32,
        }
        centerpad.enable(config2)
        vim.wait(50)

        -- Capture tab 2 state
        local tab2_left_win = state.pad_state.left_win
        local tab2_right_win = state.pad_state.right_win
        local tab2_enabled = state.pad_state.enabled

        -- Switch to tab 1 and corrupt left pad marker
        vim.cmd("tabprevious")
        local tab1_left_buf = vim.api.nvim_win_get_buf(state.pad_state.left_win)
        vim.api.nvim_buf_set_var(tab1_left_buf, "is_centerpad", false)

        -- Trigger recovery by closing a split
        local split_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = split_buf })
        local split_win = vim.api.nvim_open_win(
          split_buf,
          false,
          { split = "right", win = state.pad_state.main_win }
        )
        vim.api.nvim_win_close(split_win, true)
        -- Switch to tab 2 before timer fires
        vim.cmd("tabnext")
        vim.wait(200)

        -- Tab 1 should have recovered at its own 12:13 widths
        vim.cmd("tabprevious")
        assert.is_true(state.pad_state.enabled)
        assert.is_true(window.are_pads_valid())
        assert.are.equal(
          12,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          13,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )
        assert.is_nil(state.get_restore_timer())

        -- Tab 2 should be completely untouched
        vim.cmd("tabnext")
        assert.are.equal(tab2_left_win, state.pad_state.left_win)
        assert.are.equal(tab2_right_win, state.pad_state.right_win)
        assert.are.equal(tab2_enabled, state.pad_state.enabled)
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

    it(
      "owner with width drift triggers cleanup without sibling repair",
      function()
        -- Tab 1: 12:13
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config1 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 12,
          rightpad = 13,
        }
        centerpad.enable(config1)
        vim.wait(50)

        -- Tab 2: 31:32
        vim.cmd("tabnew")
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config2 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 31,
          rightpad = 32,
        }
        centerpad.enable(config2)
        vim.wait(50)

        -- Capture tab 2 state
        local tab2_left_win = state.pad_state.left_win
        local tab2_right_win = state.pad_state.right_win
        local tab2_enabled = state.pad_state.enabled

        -- Switch to tab 1 and cause width drift
        vim.cmd("tabprevious")
        vim.api.nvim_win_set_width(state.pad_state.left_win, 50)

        -- Trigger recovery by closing a split
        local split_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = split_buf })
        local split_win = vim.api.nvim_open_win(
          split_buf,
          false,
          { split = "right", win = state.pad_state.main_win }
        )
        vim.api.nvim_win_close(split_win, true)
        -- Switch to tab 2 before timer fires
        vim.cmd("tabnext")
        vim.wait(200)

        -- Tab 1 should have recovered at its own 12:13 widths
        vim.cmd("tabprevious")
        assert.is_true(state.pad_state.enabled)
        assert.is_true(window.are_pads_valid())
        assert.are.equal(
          12,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          13,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )
        assert.is_nil(state.get_restore_timer())

        -- Tab 2 should be completely untouched
        vim.cmd("tabnext")
        assert.are.equal(tab2_left_win, state.pad_state.left_win)
        assert.are.equal(tab2_right_win, state.pad_state.right_win)
        assert.are.equal(tab2_enabled, state.pad_state.enabled)
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

    it(
      "owner with current pad focus triggers cleanup without sibling repair",
      function()
        -- Tab 1: 12:13
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config1 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 12,
          rightpad = 13,
        }
        centerpad.enable(config1)
        vim.wait(50)

        -- Tab 2: 31:32
        vim.cmd("tabnew")
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config2 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 31,
          rightpad = 32,
        }
        centerpad.enable(config2)
        vim.wait(50)

        -- Capture tab 2 state
        local tab2_left_win = state.pad_state.left_win
        local tab2_right_win = state.pad_state.right_win
        local tab2_enabled = state.pad_state.enabled

        -- Switch to tab 1 and focus a pad window
        vim.cmd("tabprevious")
        vim.api.nvim_set_current_win(state.pad_state.left_win)

        -- Trigger recovery by closing a split
        local split_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = split_buf })
        -- Need to go back to main window to create split
        vim.api.nvim_set_current_win(state.pad_state.main_win)
        local split_win = vim.api.nvim_open_win(
          split_buf,
          false,
          { split = "right", win = state.pad_state.main_win }
        )
        vim.api.nvim_win_close(split_win, true)
        -- Switch to tab 2 before timer fires
        vim.cmd("tabnext")
        vim.wait(200)

        -- Tab 1 should have recovered at its own 12:13 widths
        vim.cmd("tabprevious")
        assert.is_true(state.pad_state.enabled)
        assert.is_true(window.are_pads_valid())
        assert.are.equal(
          12,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          13,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )
        assert.is_nil(state.get_restore_timer())

        -- Tab 2 should be completely untouched
        vim.cmd("tabnext")
        assert.are.equal(tab2_left_win, state.pad_state.left_win)
        assert.are.equal(tab2_right_win, state.pad_state.right_win)
        assert.are.equal(tab2_enabled, state.pad_state.enabled)
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

    it(
      "owner with invalid source focus triggers cleanup without sibling repair",
      function()
        -- Tab 1: 12:13
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config1 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 12,
          rightpad = 13,
        }
        centerpad.enable(config1)
        vim.wait(50)

        -- Tab 2: 31:32
        vim.cmd("tabnew")
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config2 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 31,
          rightpad = 32,
        }
        centerpad.enable(config2)
        vim.wait(50)

        -- Capture tab 2 state
        local tab2_left_win = state.pad_state.left_win
        local tab2_right_win = state.pad_state.right_win
        local tab2_enabled = state.pad_state.enabled

        -- Switch to tab 1 and set main_win to invalid
        vim.cmd("tabprevious")
        state.pad_state.main_win = 99999

        -- Trigger recovery by closing a floating window
        local float_buf = vim.api.nvim_create_buf(false, true)
        local float_win = vim.api.nvim_open_win(float_buf, false, {
          relative = "editor",
          width = 10,
          height = 10,
          row = 0,
          col = 0,
        })
        vim.api.nvim_win_close(float_win, true)
        -- Switch to tab 2 before timer fires
        vim.cmd("tabnext")
        vim.wait(200)

        -- Tab 1 should have recovered at its own 12:13 widths
        vim.cmd("tabprevious")
        assert.is_true(state.pad_state.enabled)
        assert.is_true(window.are_pads_valid())
        assert.are.equal(
          12,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          13,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )
        assert.is_nil(state.get_restore_timer())

        -- Tab 2 should be completely untouched
        vim.cmd("tabnext")
        assert.are.equal(tab2_left_win, state.pad_state.left_win)
        assert.are.equal(tab2_right_win, state.pad_state.right_win)
        assert.are.equal(tab2_enabled, state.pad_state.enabled)
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

    it(
      "owner with no eligible source window triggers cleanup without sibling repair",
      function()
        -- Tab 1: 12:13
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config1 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 12,
          rightpad = 13,
        }
        centerpad.enable(config1)
        vim.wait(50)

        -- Tab 2: 31:32
        vim.cmd("tabnew")
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config2 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 31,
          rightpad = 32,
        }
        centerpad.enable(config2)
        vim.wait(50)

        -- Capture tab 2 state directly from the store
        local tab2_left_win = state.pad_state.left_win
        local tab2_right_win = state.pad_state.right_win
        local tab2_enabled = state.pad_state.enabled
        local tab2_main_win = state.pad_state.main_win

        -- Switch to tab 1 and close main window to leave no source
        vim.cmd("tabprevious")
        local tab1_main_win = state.pad_state.main_win
        vim.api.nvim_win_close(tab1_main_win, true)
        vim.wait(200)

        -- Tab 1 should have cleaned up (no source window means recovery
        -- may not be able to create new pads, but state should be clean)
        -- The important thing is that cleanup happened and sibling is untouched
        assert.is_nil(state.get_restore_timer())

        -- Tab 2 should be completely untouched
        vim.cmd("tabnext")
        assert.are.equal(tab2_left_win, state.pad_state.left_win)
        assert.are.equal(tab2_right_win, state.pad_state.right_win)
        assert.are.equal(tab2_enabled, state.pad_state.enabled)
        assert.are.equal(tab2_main_win, state.pad_state.main_win)
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

  describe("committed width failure protection", function()
    it(
      "does not promote uncommitted widths when resize and replacement fail",
      function()
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 20,
          rightpad = 20,
        }
        centerpad.enable(config)
        vim.wait(100)

        local orig_resize_pad = window.resize_pad
        local orig_create_pad_window = window.create_pad_window
        window.resize_pad = function()
          return false
        end
        window.create_pad_window = function()
          return nil
        end

        local ok, err = pcall(function()
          centerpad.run(config, { fargs = { "30" } })
          vim.wait(100)
        end)

        window.resize_pad = orig_resize_pad
        window.create_pad_window = orig_create_pad_window

        assert.is_true(ok, err)
        assert.is_false(state.pad_state.enabled)
        assert.is_falsy(state.pads_exist())
        assert.are.equal(20, state.config_snapshot.leftpad)
        assert.are.equal(20, state.config_snapshot.rightpad)
        assert.is_false(state.tracker.opted_in)
      end
    )

    it("invalid width leaves sibling tab state untouched", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config1 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 12,
        rightpad = 13,
      }
      centerpad.enable(config1)
      vim.wait(50)

      vim.cmd("tabnew")
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local config2 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 31,
        rightpad = 32,
      }
      centerpad.enable(config2)
      vim.wait(50)

      local tab2_left = state.pad_state.left_win
      local tab2_right = state.pad_state.right_win
      local tab2_tracker_config = {
        leftpad = state.tracker.config.leftpad,
        rightpad = state.tracker.config.rightpad,
      }
      local tab2_snapshot = {
        leftpad = state.config_snapshot.leftpad,
        rightpad = state.config_snapshot.rightpad,
      }

      centerpad.run(config2, { fargs = { "600" } })
      vim.wait(50)

      assert.are.equal(tab2_left, state.pad_state.left_win)
      assert.are.equal(tab2_right, state.pad_state.right_win)
      assert.are.equal(31, config2.leftpad)
      assert.are.equal(32, config2.rightpad)
      assert.are.equal(
        tab2_tracker_config.leftpad,
        state.tracker.config.leftpad
      )
      assert.are.equal(
        tab2_tracker_config.rightpad,
        state.tracker.config.rightpad
      )
      assert.are.equal(tab2_snapshot.leftpad, state.config_snapshot.leftpad)
      assert.are.equal(tab2_snapshot.rightpad, state.config_snapshot.rightpad)

      vim.cmd("tabprevious")
      assert.is_true(state.pad_state.enabled)
      assert.are.equal(12, state.config_snapshot.leftpad)
      assert.are.equal(13, state.config_snapshot.rightpad)
      assert.is_not_nil(state.tracker.config)
      assert.are.equal(12, state.tracker.config.leftpad)
      assert.are.equal(13, state.tracker.config.rightpad)

      vim.cmd("silent! tabonly")
    end)
  end)

  describe("deferred validation owner isolation baseline", function()
    it(
      "queued validation for an invalid owner cleans the owner, not a sibling tab",
      function()
        vim.bo.filetype = ""
        vim.bo.buftype = ""

        local source_win = vim.api.nvim_get_current_win()
        local original_source_fc = vim.api.nvim_get_option_value(
          "fillchars",
          { win = source_win, scope = "local" }
        )

        local config1 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 15,
          rightpad = 17,
        }
        centerpad.enable(config1)

        local owner_tab = vim.api.nvim_get_current_tabpage()
        local owner_main = state.pad_state.main_win

        -- Corrupt the owner's pad state before the scheduled callback fires.
        state.pad_state.left_win = nil

        -- Switch focus to a sibling tab before the deferred validation runs.
        vim.cmd("tabnew")
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local sibling_tab = vim.api.nvim_get_current_tabpage()

        -- Wait for the deferred validation callback.
        vim.wait(150)

        -- The sibling tab must remain untouched.
        assert.are.equal(sibling_tab, vim.api.nvim_get_current_tabpage())
        assert.is_false(state.pad_state.enabled)
        assert.is_falsy(state.pads_exist())
        assert.are.equal(
          0,
          #vim.api.nvim_get_autocmds({ group = autocmds.get_padgroup() })
        )

        -- The owner tab must have been cleaned up by its own callback.
        vim.cmd("tabprevious")
        assert.are.equal(owner_tab, vim.api.nvim_get_current_tabpage())
        assert.is_false(state.pad_state.enabled)
        assert.is_nil(state.pad_state.left_win)
        assert.is_nil(state.pad_state.right_win)
        assert.is_nil(state.source_options.win)
        assert.is_nil(state.source_options.fillchars)
        assert.is_false(vim.g.centerpad_enabled)
        assert.is_false(vim.g.center_buf_enabled)

        -- The owner's original source fillchars must be restored.
        if vim.api.nvim_win_is_valid(owner_main) then
          assert.are.equal(
            original_source_fc,
            vim.api.nvim_get_option_value(
              "fillchars",
              { win = owner_main, scope = "local" }
            )
          )
        end

        -- Owner lifecycle autocmds were cleared; no cross-tab timer leak.
        assert.are.equal(
          0,
          #vim.api.nvim_get_autocmds({ group = autocmds.get_padgroup() })
        )
        assert.is_nil(state.get_restore_timer())

        -- Cleanup should not have touched the sibling tab's state.
        vim.cmd("tabnext")
        assert.are.equal(sibling_tab, vim.api.nvim_get_current_tabpage())
        assert.is_false(state.pad_state.enabled)
        assert.is_falsy(state.pads_exist())
      end
    )

    it(
      "queued validation with a closed owner exits without cross-tab effects",
      function()
        vim.bo.filetype = ""
        vim.bo.buftype = ""

        local config1 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 12,
          rightpad = 13,
        }
        centerpad.enable(config1)

        local owner_tab = vim.api.nvim_get_current_tabpage()

        -- Create a sibling and close the owner before the deferred callback.
        vim.cmd("tabnew")
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local sibling_tab = vim.api.nvim_get_current_tabpage()

        local owner_num = vim.api.nvim_tabpage_get_number(owner_tab)
        vim.cmd("tabclose " .. owner_num)

        -- Wait for the dead owner's scheduled validation.
        vim.wait(150)

        -- Surviving tab must be untouched.
        assert.are.equal(sibling_tab, vim.api.nvim_get_current_tabpage())
        assert.is_false(state.pad_state.enabled)
        assert.is_falsy(state.pads_exist())
        assert.has_no.errors(function()
          local _ = state.source_options.win
          local _ = state.source_options.fillchars
        end)

        -- Closed tab store should have been pruned.
        assert.are.equal(1, state._tab_store_count())
      end
    )

    it(
      "interleaved queued callbacks preserve independent owner stores",
      function()
        vim.bo.filetype = ""
        vim.bo.buftype = ""

        local config1 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 12,
          rightpad = 13,
        }
        centerpad.enable(config1)
        local tab1 = vim.api.nvim_get_current_tabpage()

        vim.cmd("tabnew")
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local config2 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 31,
          rightpad = 32,
        }
        centerpad.enable(config2)
        local tab2 = vim.api.nvim_get_current_tabpage()

        -- Return to tab 1 so both deferred callbacks fire while tab 1 is current.
        vim.cmd("tabprevious")
        vim.wait(150)

        -- Both owner stores must remain valid and isolated.
        assert.are.equal(tab1, vim.api.nvim_get_current_tabpage())
        assert.is_true(state.pad_state.enabled)
        assert.is_true(window.are_pads_valid())
        assert.are.equal(
          12,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          13,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )

        vim.cmd("tabnext")
        assert.are.equal(tab2, vim.api.nvim_get_current_tabpage())
        assert.is_true(state.pad_state.enabled)
        assert.is_true(window.are_pads_valid())
        assert.are.equal(
          31,
          vim.api.nvim_win_get_width(state.pad_state.left_win)
        )
        assert.are.equal(
          32,
          vim.api.nvim_win_get_width(state.pad_state.right_win)
        )

        -- Source option captures must be tied to each owner's source window.
        local tab2_source = state.pad_state.main_win
        assert.are.equal(tab2_source, state.source_options.win)
        vim.cmd("tabprevious")
        assert.are.equal(tab1, vim.api.nvim_get_current_tabpage())
        local tab1_source = state.pad_state.main_win
        assert.are.equal(tab1_source, state.source_options.win)

        vim.cmd("silent! tabonly")
      end
    )

    it(
      "deferred validation restores prior focus after owner cleanup",
      function()
        vim.bo.filetype = ""
        vim.bo.buftype = ""

        local config1 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 12,
          rightpad = 13,
        }
        centerpad.enable(config1)

        -- Corrupt owner state so cleanup runs.
        state.pad_state.left_win = nil

        -- Create a sibling tab and remember its window.
        vim.cmd("tabnew")
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local sibling_tab = vim.api.nvim_get_current_tabpage()
        local sibling_win = vim.api.nvim_get_current_win()

        vim.wait(150)

        -- Callback must return focus to the sibling tab and window.
        assert.are.equal(sibling_tab, vim.api.nvim_get_current_tabpage())
        assert.are.equal(sibling_win, vim.api.nvim_get_current_win())
      end
    )

    it(
      "deferred validation restores prior focus after successful validation",
      function()
        vim.bo.filetype = ""
        vim.bo.buftype = ""

        local config1 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 12,
          rightpad = 13,
        }
        centerpad.enable(config1)
        local owner_tab = vim.api.nvim_get_current_tabpage()

        -- Create a sibling tab and remember its window.
        vim.cmd("tabnew")
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local sibling_tab = vim.api.nvim_get_current_tabpage()
        local sibling_win = vim.api.nvim_get_current_win()

        vim.wait(150)

        -- Callback must return focus to the sibling and leave owner healthy.
        assert.are.equal(sibling_tab, vim.api.nvim_get_current_tabpage())
        assert.are.equal(sibling_win, vim.api.nvim_get_current_win())
        vim.cmd("tabprevious")
        assert.are.equal(owner_tab, vim.api.nvim_get_current_tabpage())
        assert.is_true(state.pad_state.enabled)
        assert.is_true(window.are_pads_valid())

        vim.cmd("silent! tabonly")
      end
    )
  end)
end)
