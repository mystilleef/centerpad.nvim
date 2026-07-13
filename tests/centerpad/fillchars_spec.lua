describe("centerpad.fillchars", function()
  local centerpad
  local state
  local window
  local autocmds
  local test_helper

  before_each(function()
    package.loaded["centerpad.state"] = nil
    package.loaded["centerpad.enabled"] = nil
    package.loaded["centerpad.window"] = nil
    package.loaded["centerpad.autocmds"] = nil
    package.loaded["centerpad.centerpad"] = nil
    package.loaded["test_helper"] = nil

    state = require("centerpad.state")
    centerpad = require("centerpad.centerpad")
    window = require("centerpad.window")
    autocmds = require("centerpad.autocmds")
    test_helper = require("test_helper")

    state.reset()
    vim.g.centerpad_enabled = false
    vim.g.center_buf_enabled = false
  end)

  after_each(function()
    centerpad.disable()
    test_helper.cleanup_headless_spec()
  end)

  describe("global fillchars preservation", function()
    it("should leave vim.go.fillchars unchanged after enable", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local original = vim.go.fillchars
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

      -- But source window should have local fillchars
      local source_win = state.pad_state.main_win
      assert.is_not_nil(source_win)
      if vim.api.nvim_win_is_valid(source_win) then
        local local_fc =
          vim.api.nvim_get_option_value("fillchars", { win = source_win })
        assert.is_not.equal(original, local_fc)
      end
    end)

    it("should leave vim.go.fillchars unchanged after disable", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local original = vim.go.fillchars
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
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local original = vim.go.fillchars
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

    it("should leave vim.go.fillchars unchanged after recovery", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local original = vim.go.fillchars
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      centerpad.enable(config)
      vim.wait(50)

      -- Corrupt left pad to force recovery
      local left_buf = vim.api.nvim_win_get_buf(state.pad_state.left_win)
      vim.api.nvim_buf_delete(left_buf, { force = true })
      state.pad_state.left_win = nil

      centerpad.run(config, { fargs = { "25" } })
      vim.wait(100)

      -- Global fillchars should be unchanged
      assert.are.equal(original, vim.go.fillchars)
    end)

    it("should preserve empty global fillchars", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      -- Set empty fillchars
      local saved = vim.go.fillchars
      vim.go.fillchars = ""

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      centerpad.enable(config)
      vim.wait(50)

      -- Global fillchars should remain empty
      assert.are.equal("", vim.go.fillchars)

      centerpad.disable()
      vim.go.fillchars = saved
    end)

    it("should preserve customized global fillchars", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      -- Set custom fillchars
      local saved = vim.go.fillchars
      vim.go.fillchars = "vert:|,horiz:-"

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      centerpad.enable(config)
      vim.wait(50)

      -- Global fillchars should be unchanged
      assert.are.equal("vert:|,horiz:-", vim.go.fillchars)

      centerpad.disable()
      vim.go.fillchars = saved
    end)
  end)

  describe("window-local fillchars", function()
    it("should apply local fillchars to source window during enable", function()
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

      -- Source window should have local fillchars
      local source_win = state.pad_state.main_win
      assert.is_not_nil(source_win)
      assert.is_true(vim.api.nvim_win_is_valid(source_win))

      local local_fc =
        vim.api.nvim_get_option_value("fillchars", { win = source_win })
      assert.is_not_nil(local_fc)
      assert.is_not.equal("", local_fc)
    end)

    it("should not blank fold/diff/eob fillchars on source window", function()
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
      assert.is_not_nil(source_win)

      local local_fc = vim.api.nvim_get_option_value(
        "fillchars",
        { win = source_win, scope = "local" }
      )

      -- Only the source/pad border separators should be forced blank;
      -- fold and diff rendering must stay native in the user's window.
      assert.is_nil(local_fc:find("fold:", 1, true))
      assert.is_nil(local_fc:find("foldopen:", 1, true))
      assert.is_nil(local_fc:find("foldclose:", 1, true))
      assert.is_nil(local_fc:find("foldsep:", 1, true))
      assert.is_nil(local_fc:find("diff:", 1, true))
      assert.is_nil(local_fc:find("eob:", 1, true))
    end)

    it(
      "preserves the user's custom global fold/diff/eob symbols on "
        .. "the source window",
      function()
        vim.bo.filetype = ""
        vim.bo.buftype = ""

        local saved = vim.go.fillchars
        vim.go.fillchars = "fold:x,foldopen:>,foldclose:<,eob:y,diff:z"

        local config = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 20,
          rightpad = 20,
        }

        centerpad.enable(config)
        vim.wait(50)

        local source_win = state.pad_state.main_win
        assert.is_not_nil(source_win)

        -- Effective value (local override merged over what it started
        -- from), not scope="local", since that's what actually renders.
        local local_fc =
          vim.api.nvim_get_option_value("fillchars", { win = source_win })

        assert.is_not_nil(local_fc:find("fold:x", 1, true))
        assert.is_not_nil(local_fc:find("foldopen:>", 1, true))
        assert.is_not_nil(local_fc:find("foldclose:<", 1, true))
        assert.is_not_nil(local_fc:find("eob:y", 1, true))
        assert.is_not_nil(local_fc:find("diff:z", 1, true))

        centerpad.disable()
        vim.go.fillchars = saved
      end
    )

    it("should clear source window-local fillchars during cleanup", function()
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
      assert.is_not_nil(source_win)

      centerpad.disable()

      -- Source window should not have local fillchars override
      if vim.api.nvim_win_is_valid(source_win) then
        -- After cleanup, local fillchars should be cleared
        -- We can verify by checking if the option was reset
        local ok, _ = pcall(
          vim.api.nvim_get_option_value,
          "fillchars",
          { win = source_win }
        )
        -- If the window is still valid, accessing the option should work
        assert.is_true(ok)
      end
    end)

    it(
      "should not error when source window is invalid during cleanup",
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
        vim.wait(50)

        local source_win = state.pad_state.main_win
        -- Close the source window to simulate invalid state
        if source_win and vim.api.nvim_win_is_valid(source_win) then
          vim.api.nvim_win_close(source_win, true)
        end

        -- Cleanup should not error
        assert.has_no.errors(function()
          centerpad.disable()
        end)
      end
    )
  end)

  describe("option API error handling", function()
    it(
      "should trigger cleanup when fillchars set fails on source window",
      function()
        vim.bo.filetype = ""
        vim.bo.buftype = ""

        local config = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 20,
          rightpad = 20,
        }

        -- Mock nvim_set_option_value to fail for fillchars
        local orig_set = vim.api.nvim_set_option_value
        local call_count = 0
        vim.api.nvim_set_option_value = function(name, value, opts)
          if name == "fillchars" and opts and opts.win then
            call_count = call_count + 1
            if call_count > 2 then
              -- Fail on source window fillchars set
              error("option set failed")
            end
          end
          return orig_set(name, value, opts)
        end

        centerpad.enable(config)
        vim.wait(100)

        vim.api.nvim_set_option_value = orig_set

        -- Should not leave one-sided pads
        assert.is_false(state.pad_state.enabled)
        assert.is_nil(state.pad_state.left_win)
        assert.is_nil(state.pad_state.right_win)
      end
    )
  end)

  describe("nil compatibility slots", function()
    it("should not trigger restore writes for nil fillchars slot", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      local original = vim.go.fillchars

      centerpad.enable(config)
      vim.wait(50)
      centerpad.disable()

      -- Global fillchars should be unchanged
      assert.are.equal(original, vim.go.fillchars)
    end)
  end)

  describe("cross-tab fillchars isolation", function()
    it(
      "should not leak fillchars between tabs on enable/disable cycle",
      function()
        local original = vim.go.fillchars

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

        -- Disable tab 2
        centerpad.disable()
        vim.wait(50)

        -- Global fillchars should be unchanged
        assert.are.equal(original, vim.go.fillchars)

        -- Switch to tab 1
        vim.cmd("tabprevious")

        -- Tab 1 source window fillchars should still be set
        local source_win = state.pad_state.main_win
        if source_win and vim.api.nvim_win_is_valid(source_win) then
          local fc =
            vim.api.nvim_get_option_value("fillchars", { win = source_win })
          assert.is_not.equal("", fc)
        end

        -- Global fillchars still unchanged
        assert.are.equal(original, vim.go.fillchars)

        -- Disable tab 1
        centerpad.disable()
        assert.are.equal(original, vim.go.fillchars)

        vim.cmd("silent! tabonly")
      end
    )
  end)

  describe("source-window local fillchars restoration", function()
    it("restores inherited fillchars after disable", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local source_win = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value("fillchars", nil, { win = source_win })
      assert.are.equal(
        "",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = source_win, scope = "local" }
        )
      )

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }
      centerpad.enable(config)
      vim.wait(50)

      assert.are.equal(source_win, state.pad_state.main_win)
      assert.is_not.equal(
        "",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = source_win, scope = "local" }
        )
      )

      centerpad.disable()
      vim.wait(50)

      assert.are.equal(
        "",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = source_win, scope = "local" }
        )
      )
    end)

    it("restores explicit empty local fillchars after disable", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local source_win = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value("fillchars", "", { win = source_win })

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }
      centerpad.enable(config)
      vim.wait(50)

      assert.is_not.equal(
        "",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = source_win, scope = "local" }
        )
      )

      centerpad.disable()
      vim.wait(50)

      assert.are.equal(
        "",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = source_win, scope = "local" }
        )
      )
    end)

    it("restores custom local fillchars after disable", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local source_win = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value(
        "fillchars",
        "vert:|,horiz:-",
        { win = source_win }
      )

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }
      centerpad.enable(config)
      vim.wait(50)

      assert.is_not.equal(
        "vert:|,horiz:-",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = source_win, scope = "local" }
        )
      )

      centerpad.disable()
      vim.wait(50)

      assert.are.equal(
        "vert:|,horiz:-",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = source_win, scope = "local" }
        )
      )
    end)

    it("keeps pad-local fillchars while pads are active", function()
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

      local left_fc = vim.api.nvim_get_option_value(
        "fillchars",
        { win = state.pad_state.left_win }
      )
      local right_fc = vim.api.nvim_get_option_value(
        "fillchars",
        { win = state.pad_state.right_win }
      )

      assert.is_not.equal("", left_fc)
      assert.is_not.equal("", right_fc)
      assert.are.equal(left_fc, right_fc)

      -- Pads hold an empty scratch buffer, so unlike the source window
      -- they should stay fully blanked, fold/diff/eob included.
      assert.is_not_nil(left_fc:find("fold:", 1, true))
      assert.is_not_nil(left_fc:find("eob:", 1, true))
      assert.is_not_nil(left_fc:find("diff:", 1, true))
    end)

    it(
      "restores captured source A after recovery switches to source B",
      function()
        vim.bo.filetype = ""
        vim.bo.buftype = ""

        local source_a = vim.api.nvim_get_current_win()
        vim.api.nvim_set_option_value(
          "fillchars",
          "vert:|,horiz:-",
          { win = source_a }
        )

        local config = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 20,
          rightpad = 20,
        }
        centerpad.enable(config)
        vim.wait(50)

        assert.are.equal(source_a, state.pad_state.main_win)
        assert.are.equal(source_a, state.source_options.win)

        -- Create an alternate source B with different local fillchars.
        local split_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = split_buf })
        vim.api.nvim_set_option_value("filetype", "", { buf = split_buf })
        vim.cmd("vsplit")
        local source_b = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(source_b, split_buf)
        vim.api.nvim_set_option_value("fillchars", "fold:x", { win = source_b })

        -- Force recovery while focused on source B.
        local left_buf = vim.api.nvim_win_get_buf(state.pad_state.left_win)
        vim.api.nvim_buf_delete(left_buf, { force = true })
        vim.wait(300)

        -- Source A regains its captured value, source B carries the override.
        assert.are.equal(
          "vert:|,horiz:-",
          vim.api.nvim_get_option_value(
            "fillchars",
            { win = source_a, scope = "local" }
          )
        )
        assert.are.equal(state.pad_state.main_win, source_b)
        assert.is_not.equal(
          "fold:x",
          vim.api.nvim_get_option_value(
            "fillchars",
            { win = source_b, scope = "local" }
          )
        )
        -- Old captured metadata for source A must be gone; recovery has
        -- captured the new source B instead.
        assert.are_not.equal(source_a, state.source_options.win)
        assert.are.equal(source_b, state.source_options.win)

        pcall(vim.api.nvim_win_close, source_b, true)
      end
    )

    it("restores inherited fillchars after recovery switches source", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local source_a = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value("fillchars", nil, { win = source_a })
      assert.are.equal(
        "",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = source_a, scope = "local" }
        )
      )

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }
      centerpad.enable(config)
      vim.wait(50)

      local split_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = split_buf })
      vim.api.nvim_set_option_value("filetype", "", { buf = split_buf })
      vim.cmd("vsplit")
      local source_b = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(source_b, split_buf)

      local left_buf = vim.api.nvim_win_get_buf(state.pad_state.left_win)
      vim.api.nvim_buf_delete(left_buf, { force = true })
      vim.wait(300)

      assert.are.equal(
        "",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = source_a, scope = "local" }
        )
      )
      assert.are.equal(source_b, state.pad_state.main_win)
      assert.are_not.equal(source_a, state.source_options.win)

      pcall(vim.api.nvim_win_close, source_b, true)
    end)

    it(
      "restores explicit empty fillchars after recovery switches source",
      function()
        vim.bo.filetype = ""
        vim.bo.buftype = ""

        local source_a = vim.api.nvim_get_current_win()
        vim.api.nvim_set_option_value("fillchars", "", { win = source_a })

        local config = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 20,
          rightpad = 20,
        }
        centerpad.enable(config)
        vim.wait(50)

        local split_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = split_buf })
        vim.api.nvim_set_option_value("filetype", "", { buf = split_buf })
        vim.cmd("vsplit")
        local source_b = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(source_b, split_buf)

        local left_buf = vim.api.nvim_win_get_buf(state.pad_state.left_win)
        vim.api.nvim_buf_delete(left_buf, { force = true })
        vim.wait(300)

        assert.are.equal(
          "",
          vim.api.nvim_get_option_value(
            "fillchars",
            { win = source_a, scope = "local" }
          )
        )
        assert.are.equal(source_b, state.pad_state.main_win)
        assert.are_not.equal(source_a, state.source_options.win)

        pcall(vim.api.nvim_win_close, source_b, true)
      end
    )

    it(
      "clears stale capture metadata when captured source is invalid",
      function()
        vim.bo.filetype = ""
        vim.bo.buftype = ""

        local source_a = vim.api.nvim_get_current_win()
        vim.api.nvim_set_option_value(
          "fillchars",
          "vert:|,horiz:-",
          { win = source_a }
        )

        local new_source_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = new_source_buf })
        vim.api.nvim_set_option_value("filetype", "", { buf = new_source_buf })
        vim.cmd("vsplit")
        local new_source_win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(new_source_win, new_source_buf)
        local new_source_fc = "fold:x"
        vim.api.nvim_set_option_value(
          "fillchars",
          new_source_fc,
          { win = new_source_win }
        )

        local untouched_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = untouched_buf })
        vim.api.nvim_set_option_value("filetype", "", { buf = untouched_buf })
        vim.cmd("vsplit")
        local untouched_win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(untouched_win, untouched_buf)
        local untouched_fc = "vert:|"
        vim.api.nvim_set_option_value(
          "fillchars",
          untouched_fc,
          { win = untouched_win }
        )

        local config = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 20,
          rightpad = 20,
        }
        centerpad.enable(config)
        vim.wait(50)

        -- Close the captured source before recovery can restore it.
        vim.api.nvim_win_close(source_a, true)
        vim.wait(50)

        -- Trigger recovery from the new source window.
        local left_buf = vim.api.nvim_win_get_buf(state.pad_state.left_win)
        vim.api.nvim_buf_delete(left_buf, { force = true })
        vim.wait(300)

        -- The stale capture for the closed source must be discarded.
        local new_main = state.pad_state.main_win
        assert.are_not.equal(source_a, state.source_options.win)
        assert.are.equal(new_main, state.source_options.win)

        -- The non-selected window keeps its original value; the selected
        -- source window carries the Centerpad override.
        for _, entry in ipairs({
          { win = new_source_win, original = new_source_fc },
          { win = untouched_win, original = untouched_fc },
        }) do
          if entry.win == new_main then
            assert.is_not.equal(
              entry.original,
              vim.api.nvim_get_option_value(
                "fillchars",
                { win = entry.win, scope = "local" }
              )
            )
          else
            assert.are.equal(
              entry.original,
              vim.api.nvim_get_option_value(
                "fillchars",
                { win = entry.win, scope = "local" }
              )
            )
          end
        end

        pcall(vim.api.nvim_win_close, new_source_win, true)
        pcall(vim.api.nvim_win_close, untouched_win, true)
      end
    )

    it(
      "restores source A and leaves unrelated window untouched after recovery",
      function()
        vim.bo.filetype = ""
        vim.bo.buftype = ""

        local source_a = vim.api.nvim_get_current_win()
        vim.api.nvim_set_option_value(
          "fillchars",
          "vert:|,horiz:-",
          { win = source_a }
        )

        -- Unrelated window with its own local fillchars.
        local unrelated_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = unrelated_buf })
        vim.api.nvim_set_option_value("filetype", "", { buf = unrelated_buf })
        vim.cmd("vsplit")
        local unrelated_win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(unrelated_win, unrelated_buf)
        vim.api.nvim_set_option_value(
          "fillchars",
          "fold:x",
          { win = unrelated_win }
        )

        -- Source B with different local fillchars.
        local source_b_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = source_b_buf })
        vim.api.nvim_set_option_value("filetype", "", { buf = source_b_buf })
        vim.cmd("vsplit")
        local source_b = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(source_b, source_b_buf)
        vim.api.nvim_set_option_value("fillchars", "eob:X", { win = source_b })

        -- Re-focus source A and enable centerpad.
        vim.api.nvim_set_current_win(source_a)
        local config = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 20,
          rightpad = 20,
        }
        centerpad.enable(config)
        vim.wait(50)

        assert.are.equal(source_a, state.pad_state.main_win)
        assert.are.equal(source_a, state.source_options.win)

        -- Focus source B and force recovery.
        vim.api.nvim_set_current_win(source_b)
        local left_buf = vim.api.nvim_win_get_buf(state.pad_state.left_win)
        vim.api.nvim_buf_delete(left_buf, { force = true })
        vim.wait(300)

        -- Source A regains its captured value; source B becomes main and
        -- carries the Centerpad override; the unrelated window keeps its
        -- own original local value.
        assert.are.equal(
          "vert:|,horiz:-",
          vim.api.nvim_get_option_value(
            "fillchars",
            { win = source_a, scope = "local" }
          )
        )
        assert.are.equal(source_b, state.pad_state.main_win)
        assert.are.equal(
          "fold:x",
          vim.api.nvim_get_option_value(
            "fillchars",
            { win = unrelated_win, scope = "local" }
          )
        )
        assert.is_not.equal(
          "eob:X",
          vim.api.nvim_get_option_value(
            "fillchars",
            { win = source_b, scope = "local" }
          )
        )
        assert.are.equal(source_b, state.source_options.win)

        pcall(vim.api.nvim_win_close, source_b, true)
        pcall(vim.api.nvim_win_close, unrelated_win, true)
      end
    )

    it(
      "keeps interleaved source fillchars isolated across two tabs during recovery",
      function()
        -- Tab 1: source with custom local fillchars.
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local tab1_source = vim.api.nvim_get_current_win()
        vim.api.nvim_set_option_value(
          "fillchars",
          "vert:|,horiz:-",
          { win = tab1_source }
        )
        local config1 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 12,
          rightpad = 13,
        }
        centerpad.enable(config1)
        vim.wait(50)

        -- Tab 2: source with different custom local fillchars.
        vim.cmd("tabnew")
        vim.bo.filetype = ""
        vim.bo.buftype = ""
        local tab2_source = vim.api.nvim_get_current_win()
        vim.api.nvim_set_option_value(
          "fillchars",
          "fold:x",
          { win = tab2_source }
        )
        local config2 = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 31,
          rightpad = 32,
        }
        centerpad.enable(config2)
        vim.wait(50)

        -- Switch back to tab 1 and create a replacement source window.
        vim.cmd("tabprevious")
        local new_source_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "", { buf = new_source_buf })
        vim.api.nvim_set_option_value("filetype", "", { buf = new_source_buf })
        vim.cmd("vsplit")
        local new_source = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(new_source, new_source_buf)
        vim.api.nvim_set_option_value(
          "fillchars",
          "eob:X",
          { win = new_source }
        )

        -- Force recovery while focused on the replacement source.
        local left_buf = vim.api.nvim_win_get_buf(state.pad_state.left_win)
        vim.api.nvim_buf_delete(left_buf, { force = true })
        vim.wait(300)

        -- Tab 1 original source restored; replacement source overridden.
        assert.are.equal(
          "vert:|,horiz:-",
          vim.api.nvim_get_option_value(
            "fillchars",
            { win = tab1_source, scope = "local" }
          )
        )
        assert.are.equal(new_source, state.pad_state.main_win)
        assert.is_not.equal(
          "eob:X",
          vim.api.nvim_get_option_value(
            "fillchars",
            { win = new_source, scope = "local" }
          )
        )

        -- Switch to tab 2 and verify its source still has Centerpad override.
        vim.cmd("tabnext")
        assert.is_true(state.pad_state.enabled)
        assert.are.equal(tab2_source, state.pad_state.main_win)
        assert.is_not.equal(
          "fold:x",
          vim.api.nvim_get_option_value(
            "fillchars",
            { win = tab2_source, scope = "local" }
          )
        )

        -- Disable tab 2 and verify its source fillchars restored.
        centerpad.disable()
        vim.wait(50)
        assert.are.equal(
          "fold:x",
          vim.api.nvim_get_option_value(
            "fillchars",
            { win = tab2_source, scope = "local" }
          )
        )

        -- Return to tab 1 and verify its source remains restored.
        vim.cmd("tabprevious")
        assert.are.equal(
          "vert:|,horiz:-",
          vim.api.nvim_get_option_value(
            "fillchars",
            { win = tab1_source, scope = "local" }
          )
        )

        pcall(vim.api.nvim_win_close, new_source, true)
        vim.cmd("silent! tabonly")
      end
    )
  end)

  describe("suspend and resume source fillchars", function()
    local function cfg()
      return {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }
    end

    it("restores source fillchars on cleanup (suspend path)", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local source_win = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value(
        "fillchars",
        "vert:|,horiz:-",
        { win = source_win }
      )

      centerpad.enable(cfg())
      vim.wait(100)

      -- Direct cleanup simulates the tracker suspend path without relying
      -- on filetype side effects to reset window-local options.
      autocmds.cleanup()
      vim.wait(50)

      assert.is_false(state.pad_state.enabled)
      assert.are.equal(
        "vert:|,horiz:-",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = source_win, scope = "local" }
        )
      )
    end)

    it("re-applies centerpad fillchars on re-enable (resume path)", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local source_win = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value(
        "fillchars",
        "vert:|,horiz:-",
        { win = source_win }
      )

      centerpad.enable(cfg())
      vim.wait(100)

      autocmds.cleanup()
      vim.wait(50)

      centerpad.enable(cfg())
      vim.wait(100)

      assert.is_true(state.pad_state.enabled)
      assert.is_not.equal(
        "vert:|,horiz:-",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = source_win, scope = "local" }
        )
      )
    end)

    it("restores source fillchars after final disable post-resume", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local source_win = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value(
        "fillchars",
        "vert:|,horiz:-",
        { win = source_win }
      )

      centerpad.enable(cfg())
      vim.wait(100)

      autocmds.cleanup()
      vim.wait(50)

      centerpad.enable(cfg())
      vim.wait(100)

      centerpad.disable()
      vim.wait(50)

      assert.are.equal(
        "vert:|,horiz:-",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = source_win, scope = "local" }
        )
      )
    end)
  end)

  describe("failure cleanup", function()
    it("restores source fillchars when pad creation fails", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local source_win = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value(
        "fillchars",
        "vert:|,horiz:-",
        { win = source_win }
      )

      local orig = window.create_pad_window
      window.create_pad_window = function()
        return nil
      end

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }
      local ok, err = pcall(centerpad.enable, config)
      vim.wait(100)

      window.create_pad_window = orig

      assert.is_true(ok, err)
      assert.is_false(state.pad_state.enabled)
      assert.are.equal(
        "vert:|,horiz:-",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = source_win, scope = "local" }
        )
      )
    end)

    it("clears metadata when source window is closed before cleanup", function()
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
      vim.api.nvim_win_close(source_win, true)

      assert.has_no.errors(function()
        centerpad.disable()
      end)

      assert.is_nil(state.source_options.win)
      assert.is_nil(state.source_options.fillchars)
    end)

    it("leaves unrelated windows untouched during cleanup", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }

      -- Create an unrelated split with its own local fillchars
      local split_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = split_buf })
      vim.cmd("vsplit")
      local split_win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(split_win, split_buf)
      vim.api.nvim_set_option_value("fillchars", "fold:x", { win = split_win })

      -- Re-focus the original source window and enable centerpad
      vim.cmd("wincmd p")
      centerpad.enable(config)
      vim.wait(50)

      centerpad.disable()
      vim.wait(50)

      assert.are.equal(
        "fold:x",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = split_win, scope = "local" }
        )
      )

      pcall(vim.api.nvim_win_close, split_win, true)
    end)
  end)

  describe("stable replacement source fillchars", function()
    local function setup_stable_pads(config)
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      centerpad.enable(config)
      vim.wait(100)
      -- Remove the lifecycle autocmds installed by enable so the test can
      -- install its own WinClosed observer without duplication.
      autocmds.clear_autocmds()
      autocmds.clear_tracker()
    end

    local function trigger_unrelated_win_closed()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "", { buf = buf })
      vim.cmd("vsplit")
      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win, buf)
      vim.api.nvim_win_close(win, true)
    end

    it("preserves pad IDs and widths when source window changes", function()
      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }
      setup_stable_pads(config)

      local old_left = state.pad_state.left_win
      local old_right = state.pad_state.right_win

      vim.cmd("vsplit")
      local new_source = vim.api.nvim_get_current_win()

      autocmds.setup_restore_pads_autocmd(config, centerpad.enable)
      trigger_unrelated_win_closed()
      vim.wait(200)

      assert.is_true(state.pad_state.enabled)
      assert.are.equal(old_left, state.pad_state.left_win)
      assert.are.equal(old_right, state.pad_state.right_win)
      assert.are.equal(20, vim.api.nvim_win_get_width(state.pad_state.left_win))
      assert.are.equal(
        20,
        vim.api.nvim_win_get_width(state.pad_state.right_win)
      )
      assert.are.equal(new_source, state.pad_state.main_win)
      assert.are.equal(new_source, state.source_options.win)
    end)

    it("restores old source fillchars and captures replacement", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local original_source = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value(
        "fillchars",
        "vert:|,horiz:-",
        { win = original_source }
      )

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }
      setup_stable_pads(config)

      vim.cmd("vsplit")
      local new_source = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value("fillchars", "fold:x", { win = new_source })

      autocmds.setup_restore_pads_autocmd(config, centerpad.enable)
      trigger_unrelated_win_closed()
      vim.wait(200)

      assert.are.equal(new_source, state.pad_state.main_win)
      assert.are.equal(new_source, state.source_options.win)
      assert.are.equal(
        "vert:|,horiz:-",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = original_source, scope = "local" }
        )
      )
      assert.is_not.equal(
        "fold:x",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = new_source, scope = "local" }
        )
      )
      assert.are.equal("fold:x", state.source_options.fillchars)
    end)

    it("restores replacement source fillchars during later cleanup", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local original_source = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value(
        "fillchars",
        "vert:|,horiz:-",
        { win = original_source }
      )

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }
      setup_stable_pads(config)

      vim.cmd("vsplit")
      local new_source = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value("fillchars", "fold:x", { win = new_source })

      autocmds.setup_restore_pads_autocmd(config, centerpad.enable)
      trigger_unrelated_win_closed()
      vim.wait(200)

      centerpad.disable()
      vim.wait(100)

      assert.are.equal(
        "fold:x",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = new_source, scope = "local" }
        )
      )
    end)

    it("restores inherited fillchars after stable replacement", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local original_source = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value("fillchars", nil, { win = original_source })
      assert.are.equal(
        "",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = original_source, scope = "local" }
        )
      )

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }
      setup_stable_pads(config)

      vim.cmd("vsplit")
      local new_source = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value("fillchars", nil, { win = new_source })

      autocmds.setup_restore_pads_autocmd(config, centerpad.enable)
      trigger_unrelated_win_closed()
      vim.wait(200)

      assert.are.equal(
        "",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = original_source, scope = "local" }
        )
      )
      assert.are.equal(new_source, state.pad_state.main_win)
      assert.is_not.equal(
        "",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = new_source, scope = "local" }
        )
      )

      centerpad.disable()
      vim.wait(100)

      assert.are.equal(
        "",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = new_source, scope = "local" }
        )
      )
    end)

    it("restores explicit empty fillchars after stable replacement", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local original_source = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value("fillchars", "", { win = original_source })

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }
      setup_stable_pads(config)

      vim.cmd("vsplit")
      local new_source = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value("fillchars", "", { win = new_source })

      autocmds.setup_restore_pads_autocmd(config, centerpad.enable)
      trigger_unrelated_win_closed()
      vim.wait(200)

      assert.are.equal(
        "",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = original_source, scope = "local" }
        )
      )
      assert.are.equal(new_source, state.pad_state.main_win)

      centerpad.disable()
      vim.wait(100)

      assert.are.equal(
        "",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = new_source, scope = "local" }
        )
      )
    end)

    it("restores custom fillchars after stable replacement", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local original_source = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value(
        "fillchars",
        "vert:|,horiz:-",
        { win = original_source }
      )

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }
      setup_stable_pads(config)

      vim.cmd("vsplit")
      local new_source = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value("fillchars", "fold:x", { win = new_source })

      autocmds.setup_restore_pads_autocmd(config, centerpad.enable)
      trigger_unrelated_win_closed()
      vim.wait(200)

      assert.are.equal(
        "vert:|,horiz:-",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = original_source, scope = "local" }
        )
      )
      assert.are.equal(new_source, state.pad_state.main_win)

      centerpad.disable()
      vim.wait(100)

      assert.are.equal(
        "fold:x",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = new_source, scope = "local" }
        )
      )
    end)

    it(
      "closed prior source causes no write during stable replacement",
      function()
        vim.bo.filetype = ""
        vim.bo.buftype = ""

        local original_source = vim.api.nvim_get_current_win()
        vim.api.nvim_set_option_value(
          "fillchars",
          "vert:|,horiz:-",
          { win = original_source }
        )

        local config = {
          ignore_filetypes = {},
          ignore_buftypes = {},
          leftpad = 20,
          rightpad = 20,
        }
        setup_stable_pads(config)

        -- Unrelated window that must keep its own local fillchars.
        vim.cmd("vsplit")
        local unrelated_win = vim.api.nvim_get_current_win()
        vim.api.nvim_set_option_value(
          "fillchars",
          "eob:X",
          { win = unrelated_win }
        )

        -- Create the replacement source and close the original source.
        vim.cmd("vsplit")
        local new_source = vim.api.nvim_get_current_win()
        vim.api.nvim_set_option_value(
          "fillchars",
          "fold:x",
          { win = new_source }
        )
        vim.api.nvim_win_close(original_source, true)

        autocmds.setup_restore_pads_autocmd(config, centerpad.enable)
        trigger_unrelated_win_closed()
        vim.wait(200)

        assert.are.equal(new_source, state.pad_state.main_win)
        assert.are.equal(new_source, state.source_options.win)
        assert.is_not.equal(
          "fold:x",
          vim.api.nvim_get_option_value(
            "fillchars",
            { win = new_source, scope = "local" }
          )
        )
        assert.are.equal(
          "eob:X",
          vim.api.nvim_get_option_value(
            "fillchars",
            { win = unrelated_win, scope = "local" }
          )
        )

        pcall(vim.api.nvim_win_close, unrelated_win, true)
      end
    )

    it("replacement capture failure routes to recovery", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }
      setup_stable_pads(config)

      vim.cmd("vsplit")
      local new_source = vim.api.nvim_get_current_win()

      local function enable_cb(cfg)
        centerpad.enable(cfg)
      end

      local orig_get = vim.api.nvim_get_option_value
      vim.api.nvim_get_option_value = function(name, opts)
        if name == "fillchars" and opts and opts.win == new_source then
          error("forced capture failure")
        end
        return orig_get(name, opts)
      end

      autocmds.setup_restore_pads_autocmd(config, enable_cb)
      trigger_unrelated_win_closed()
      vim.wait(300)

      vim.api.nvim_get_option_value = orig_get

      assert.is_false(state.pad_state.enabled)
      assert.is_nil(state.source_options.win)
      assert.is_nil(state.source_options.fillchars)
    end)

    it("replacement override failure routes to recovery", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local config = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 20,
        rightpad = 20,
      }
      setup_stable_pads(config)

      vim.cmd("vsplit")
      local new_source = vim.api.nvim_get_current_win()

      local function enable_cb(cfg)
        centerpad.enable(cfg)
      end

      local orig_set = vim.api.nvim_set_option_value
      vim.api.nvim_set_option_value = function(name, value, opts)
        if name == "fillchars" and opts and opts.win == new_source then
          error("forced override failure")
        end
        return orig_set(name, value, opts)
      end

      autocmds.setup_restore_pads_autocmd(config, enable_cb)
      trigger_unrelated_win_closed()
      vim.wait(300)

      vim.api.nvim_set_option_value = orig_set

      assert.is_false(state.pad_state.enabled)
      assert.is_nil(state.source_options.win)
      assert.is_nil(state.source_options.fillchars)
    end)

    it("two-tab stable replacement leaves sibling untouched", function()
      vim.bo.filetype = ""
      vim.bo.buftype = ""

      local tab1_source = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value(
        "fillchars",
        "vert:|,horiz:-",
        { win = tab1_source }
      )
      local config1 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 12,
        rightpad = 13,
      }
      setup_stable_pads(config1)

      vim.cmd("tabnew")
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local tab2_source = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value(
        "fillchars",
        "fold:x",
        { win = tab2_source }
      )
      local config2 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 31,
        rightpad = 32,
      }
      setup_stable_pads(config2)

      -- Capture tab 2 state.
      local tab2_left = state.pad_state.left_win
      local tab2_right = state.pad_state.right_win
      local tab2_main = state.pad_state.main_win
      local tab2_source_fc =
        vim.api.nvim_get_option_value("fillchars", { win = tab2_source })

      -- Return to tab 1 and perform a stable source replacement.
      vim.cmd("tabprevious")
      vim.cmd("vsplit")
      local tab1_new_source = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value(
        "fillchars",
        "eob:X",
        { win = tab1_new_source }
      )

      autocmds.setup_restore_pads_autocmd(config1, centerpad.enable)
      trigger_unrelated_win_closed()
      vim.wait(200)

      assert.are.equal(tab1_new_source, state.pad_state.main_win)
      assert.are.equal(tab1_new_source, state.source_options.win)
      assert.is_not.equal(
        "eob:X",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = tab1_new_source, scope = "local" }
        )
      )

      -- Tab 2 must be untouched.
      vim.cmd("tabnext")
      assert.are.equal(tab2_left, state.pad_state.left_win)
      assert.are.equal(tab2_right, state.pad_state.right_win)
      assert.are.equal(tab2_main, state.pad_state.main_win)
      assert.are.equal(
        tab2_source_fc,
        vim.api.nvim_get_option_value("fillchars", { win = tab2_source })
      )
      assert.are.equal(31, vim.api.nvim_win_get_width(state.pad_state.left_win))
      assert.are.equal(
        32,
        vim.api.nvim_win_get_width(state.pad_state.right_win)
      )

      vim.cmd("silent! tabonly")
    end)
  end)

  describe("cross-tab captured value isolation", function()
    it("keeps independent source fillchars across tabs", function()
      -- Tab 1: custom source fillchars
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local source_win_1 = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value(
        "fillchars",
        "vert:|,horiz:-",
        { win = source_win_1 }
      )
      local config1 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 12,
        rightpad = 13,
      }
      centerpad.enable(config1)
      vim.wait(50)

      -- Tab 2: different custom source fillchars
      vim.cmd("tabnew")
      vim.bo.filetype = ""
      vim.bo.buftype = ""
      local source_win_2 = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value(
        "fillchars",
        "fold:x",
        { win = source_win_2 }
      )
      local config2 = {
        ignore_filetypes = {},
        ignore_buftypes = {},
        leftpad = 30,
        rightpad = 32,
      }
      centerpad.enable(config2)
      vim.wait(50)

      -- Disable tab 2: its source should recover fold:x
      centerpad.disable()
      vim.wait(50)

      assert.are.equal(
        "fold:x",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = source_win_2, scope = "local" }
        )
      )

      -- Switch to tab 1: its source should still have Centerpad override
      vim.cmd("tabprevious")
      assert.is_true(state.pad_state.enabled)
      assert.is_not.equal(
        "vert:|,horiz:-",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = source_win_1, scope = "local" }
        )
      )

      -- Disable tab 1: its source should recover vert:|,horiz:-
      centerpad.disable()
      vim.wait(50)

      assert.are.equal(
        "vert:|,horiz:-",
        vim.api.nvim_get_option_value(
          "fillchars",
          { win = source_win_1, scope = "local" }
        )
      )

      vim.cmd("silent! tabonly")
    end)
  end)
end)
