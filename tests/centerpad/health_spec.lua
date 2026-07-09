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
  end)
end)
