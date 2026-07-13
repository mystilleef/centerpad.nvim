describe("centerpad.health", function()
  local health
  local state
  local calls

  local function record(tbl)
    return function(msg, advice)
      table.insert(tbl, { msg = msg, advice = advice })
    end
  end

  before_each(function()
    package.loaded["centerpad.state"] = nil
    package.loaded["centerpad.enabled"] = nil
    package.loaded["centerpad.centerpad"] = nil
    package.loaded["centerpad.window"] = nil
    package.loaded["centerpad.autocmds"] = nil
    package.loaded["centerpad.health"] = nil

    state = require("centerpad.state")
    health = require("centerpad.health")

    state.reset()
    vim.g.centerpad_enabled = false
    vim.g.center_buf_enabled = false

    calls = { ok = {}, warn = {}, info = {}, error = {}, start = {} }
    vim.health.start = record(calls.start)
    vim.health.ok = record(calls.ok)
    vim.health.warn = record(calls.warn)
    vim.health.info = record(calls.info)
    vim.health.error = record(calls.error)
  end)

  local function contains_call(tbl, pattern)
    for _, c in ipairs(tbl) do
      if string.match(c.msg, pattern) then
        return true
      end
    end
    return false
  end

  local function count_calls(tbl, pattern)
    local count = 0
    for _, c in ipairs(tbl) do
      if string.match(c.msg, pattern) then
        count = count + 1
      end
    end
    return count
  end

  describe("Neovim version", function()
    it("should report ok for supported Neovim version", function()
      health.check()

      assert.is_true(contains_call(calls.ok, "Neovim"))
    end)
  end)

  describe("module loading", function()
    it("should report ok for all modules when loaded", function()
      health.check()

      assert.is_true(contains_call(calls.ok, "state"))
      assert.is_true(contains_call(calls.ok, "window"))
      assert.is_true(contains_call(calls.ok, "autocmds"))
      assert.is_true(contains_call(calls.ok, "centerpad"))
    end)

    it("should report error for failed module load", function()
      -- Use package.preload to force a module load failure.
      -- This works reliably because require() always checks preload first.
      package.loaded["centerpad.window"] = nil
      package.preload["centerpad.window"] = function()
        error("simulated load failure")
      end

      health.check()

      package.preload["centerpad.window"] = nil

      assert.is_true(contains_call(calls.error, "centerpad.window"))
    end)

    it("should halt reporting after module load failure", function()
      -- Force the first module (state) to fail. The health check
      -- tests all modules, then returns early before pad/flag checks.
      package.loaded["centerpad.state"] = nil
      package.preload["centerpad.state"] = function()
        error("simulated load failure")
      end
      -- Ensure other modules are also unloaded so they don't skip
      -- the preload check via package.loaded cache.
      package.loaded["centerpad.window"] = nil
      package.loaded["centerpad.autocmds"] = nil
      package.loaded["centerpad.centerpad"] = nil

      health.check()

      package.preload["centerpad.state"] = nil

      -- All modules are checked before the early return.
      -- state failing causes transitive failures in the other modules
      -- because they all require("centerpad.state").
      assert.is_true(contains_call(calls.error, "centerpad.state"))
      -- The early return prevents enabled/disabled state checks
      assert.is_false(contains_call(calls.info, "currently enabled"))
      assert.is_false(contains_call(calls.info, "currently disabled"))
    end)
  end)

  describe("enabled state diagnostics", function()
    it("should report enabled with valid pads", function()
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

      state.pad_state.enabled = true
      state.pad_state.left_win = win1
      state.pad_state.right_win = win2
      state.pad_state.main_win = vim.api.nvim_get_current_win()
      vim.g.centerpad_enabled = true

      health.check()

      assert.is_true(contains_call(calls.info, "currently enabled"))
      assert.is_true(contains_call(calls.ok, "Pad state is valid"))
      assert.is_true(contains_call(calls.ok, "Pad windows"))
      assert.is_true(contains_call(calls.ok, "Main window"))

      vim.api.nvim_win_close(win1, true)
      vim.api.nvim_win_close(win2, true)
    end)

    it(
      "should report validation issues when enabled but pads invalid",
      function()
        state.pad_state.enabled = true
        state.pad_state.left_win = nil
        state.pad_state.right_win = nil
        vim.g.centerpad_enabled = true

        health.check()

        assert.is_true(contains_call(calls.warn, "validation issues"))
        assert.is_true(contains_call(calls.error, "pad windows don't exist"))
      end
    )

    it("should warn when main window is nil while enabled", function()
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

      state.pad_state.enabled = true
      state.pad_state.left_win = win1
      state.pad_state.right_win = win2
      state.pad_state.main_win = nil
      vim.g.centerpad_enabled = true

      health.check()

      assert.is_true(contains_call(calls.warn, "Main window is not valid"))

      vim.api.nvim_win_close(win1, true)
      vim.api.nvim_win_close(win2, true)
    end)

    it("should warn when main window is invalid while enabled", function()
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

      state.pad_state.enabled = true
      state.pad_state.left_win = win1
      state.pad_state.right_win = win2
      state.pad_state.main_win = 9999
      vim.g.centerpad_enabled = true

      health.check()

      assert.is_true(contains_call(calls.warn, "Main window is not valid"))

      vim.api.nvim_win_close(win1, true)
      vim.api.nvim_win_close(win2, true)
    end)

    it("should report pending restore timer when enabled", function()
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

      local timer_id = vim.fn.timer_start(10000, function() end)
      state.set_restore_timer(timer_id)
      state.pad_state.enabled = true
      state.pad_state.left_win = win1
      state.pad_state.right_win = win2
      state.pad_state.main_win = vim.api.nvim_get_current_win()
      vim.g.centerpad_enabled = true

      health.check()

      assert.is_true(contains_call(calls.info, "Restore timer"))

      pcall(vim.fn.timer_stop, timer_id)
      state.set_restore_timer(nil)
      vim.api.nvim_win_close(win1, true)
      vim.api.nvim_win_close(win2, true)
    end)
  end)

  describe("disabled state diagnostics", function()
    it("should report disabled", function()
      state.pad_state.enabled = false
      vim.g.centerpad_enabled = false

      health.check()

      assert.is_true(contains_call(calls.info, "currently disabled"))
    end)

    it(
      "should warn about orphaned pads when disabled but pads exist",
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

        state.pad_state.enabled = false
        state.pad_state.left_win = win1
        state.pad_state.right_win = win2
        vim.g.centerpad_enabled = false

        health.check()

        assert.is_true(contains_call(calls.warn, "pad windows still exist"))

        vim.api.nvim_win_close(win1, true)
        vim.api.nvim_win_close(win2, true)
      end
    )
  end)

  describe("debug mode", function()
    it("should report debug mode enabled", function()
      state.debug = true

      health.check()

      assert.is_true(contains_call(calls.info, "Debug mode is enabled"))
    end)

    it("should report debug mode disabled", function()
      state.debug = false

      health.check()

      assert.is_true(contains_call(calls.info, "Debug mode is disabled"))
    end)
  end)

  describe("global flag consistency", function()
    it("should report ok when centerpad_enabled matches state", function()
      state.pad_state.enabled = true
      vim.g.centerpad_enabled = true

      health.check()

      assert.is_true(contains_call(calls.ok, "centerpad_enabled"))
    end)

    it("should warn when centerpad_enabled mismatches state", function()
      state.pad_state.enabled = true
      vim.g.centerpad_enabled = false

      health.check()

      assert.is_true(contains_call(calls.warn, "centerpad_enabled"))
    end)

    it(
      "should warn when centerpad_enabled is false but state is true",
      function()
        state.pad_state.enabled = true
        vim.g.centerpad_enabled = false
        vim.g.center_buf_enabled = false

        health.check()

        assert.is_true(contains_call(calls.warn, "Global flag mismatch"))
      end
    )

    it(
      "should report ok when centerpad_enabled and state are both false",
      function()
        state.pad_state.enabled = false
        vim.g.centerpad_enabled = false

        health.check()

        assert.is_true(contains_call(calls.ok, "centerpad_enabled"))
      end
    )
  end)

  describe("legacy bridge", function()
    it("should report legacy bridge status when set", function()
      state.pad_state.enabled = true
      vim.g.centerpad_enabled = true
      vim.g.center_buf_enabled = true

      health.check()

      assert.is_true(contains_call(calls.info, "center_buf_enabled"))
      assert.is_true(contains_call(calls.info, "deprecated"))
    end)

    it("should warn on legacy bridge mismatch", function()
      state.pad_state.enabled = true
      vim.g.centerpad_enabled = true
      vim.g.center_buf_enabled = false

      health.check()

      assert.is_true(contains_call(calls.warn, "center_buf_enabled"))
    end)

    it("should mirror legacy-only global and warn once", function()
      vim.g.centerpad_enabled = nil
      vim.g.center_buf_enabled = true

      local warnings = {}
      local orig_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(warnings, { msg = msg, level = level })
      end

      health.check()

      vim.notify = orig_notify

      assert.are.equal(1, #warnings)
      assert.is_true(string.match(warnings[1].msg, "deprecated") ~= nil)
      assert.are.equal(true, vim.g.centerpad_enabled)
    end)

    it("should not report legacy bridge when legacy global is nil", function()
      state.pad_state.enabled = false
      vim.g.centerpad_enabled = false
      vim.g.center_buf_enabled = nil

      health.check()

      local legacy_calls = count_calls(calls.info, "center_buf_enabled")
      assert.are.equal(0, legacy_calls)
    end)
  end)

  describe("start call", function()
    it("should call vim.health.start with plugin name", function()
      health.check()

      assert.are.equal(1, #calls.start)
      assert.is_true(string.match(calls.start[1].msg, "centerpad") ~= nil)
    end)
  end)
end)
