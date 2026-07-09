describe("verify_completion gate", function()
  local verify_completion = dofile(
    vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h:h")
      .. "/verify_completion.lua"
  )

  local smoke_report = dofile(
    vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h:h")
      .. "/smoke_report.lua"
  )

  local REQUIRED_SCENARIOS = smoke_report.REQUIRED_SCENARIOS

  local function valid_result(name, passed)
    return { name = name, passed = passed, detail = "" }
  end

  local function make_valid_results()
    local results = {}
    for _, name in ipairs(REQUIRED_SCENARIOS) do
      table.insert(results, valid_result(name, true))
    end
    return results
  end

  local function make_valid_report(overrides)
    overrides = overrides or {}
    return {
      timestamp = overrides.timestamp or os.time(),
      neovim_version = overrides.neovim_version or "0.13.0-dev",
      tty_proof = overrides.tty_proof or { tty_name = "/dev/pts/0" },
      command_sequence = overrides.command_sequence or {
        "nvim",
        "-u",
        "tests/minimal_init.lua",
        "-l",
        "tests/terminal_smoke.lua",
      },
      report_location = overrides.report_location
        or "/tmp/terminal_smoke_report.json",
      headless = overrides.headless ~= nil and overrides.headless or false,
      passed = overrides.passed or #REQUIRED_SCENARIOS,
      failed = overrides.failed or 0,
      results = overrides.results or make_valid_results(),
    }
  end

  local function make_mock_smoke_report(report_to_return)
    return {
      REQUIRED_SCENARIOS = REQUIRED_SCENARIOS,
      read_report = function(_path)
        if report_to_return then
          return report_to_return, ""
        end
        return nil, "report not found"
      end,
      validate = function(report)
        if report.error then
          return false, report.error
        end
        return true, ""
      end,
    }
  end

  describe("run_gate()", function()
    it("passes when the runner reports exit code 0", function()
      local runner = function(_command)
        return true, 0, "ok"
      end
      local result = verify_completion.run_gate(
        { name = "test gate", command = "echo ok" },
        runner
      )
      assert.is_true(result.passed)
      assert.are.equal(0, result.exit_code)
      assert.are.equal("ok", result.output)
    end)

    it("fails when the runner reports a non-zero exit code", function()
      local runner = function(_command)
        return false, 1, "error"
      end
      local result = verify_completion.run_gate(
        { name = "test gate", command = "false" },
        runner
      )
      assert.is_false(result.passed)
      assert.are.equal(1, result.exit_code)
    end)
  end)

  describe("run_all_gates()", function()
    it("passes when every gate passes", function()
      local runner = function(_command)
        return true, 0, "ok"
      end
      local all_passed, results = verify_completion.run_all_gates(
        verify_completion.REQUIRED_GATES,
        runner
      )
      assert.is_true(all_passed)
      assert.are.equal(#verify_completion.REQUIRED_GATES, #results)
      for _, result in ipairs(results) do
        assert.is_true(result.passed)
      end
    end)

    it("fails when any gate fails", function()
      local call_count = 0
      local runner = function(_command)
        call_count = call_count + 1
        if call_count == 2 then
          return false, 1, "lint error"
        end
        return true, 0, "ok"
      end
      local all_passed, results = verify_completion.run_all_gates(
        verify_completion.REQUIRED_GATES,
        runner
      )
      assert.is_false(all_passed)
      assert.is_false(results[2].passed)
      assert.is_true(results[1].passed)
    end)
  end)

  describe("check_scope()", function()
    it("passes when all scenarios are in the required roster", function()
      local ok, err =
        verify_completion.check_scope(make_valid_report(), smoke_report)
      assert.is_true(ok)
      assert.are.equal("", err)
    end)

    it("fails when a scenario is outside the required roster", function()
      local report = make_valid_report()
      table.insert(report.results, {
        name = "Zen mode layout test",
        passed = true,
        detail = "",
      })
      local ok, err = verify_completion.check_scope(report, smoke_report)
      assert.is_false(ok)
      assert.is_true(err:match("out%-of%-scope scenario") ~= nil)
    end)

    it("fails when a result name is not a string", function()
      local report = make_valid_report()
      report.results[1].name = 123
      local ok, err = verify_completion.check_scope(report, smoke_report)
      assert.is_false(ok)
      assert.is_true(err:match("out%-of%-scope scenario") ~= nil)
    end)
  end)

  describe("verify()", function()
    it("returns true when report and all gates pass", function()
      local report = make_valid_report()
      local mock_report_mod = make_mock_smoke_report(report)
      local runner = function(_command)
        return true, 0, "ok"
      end
      local passed, result =
        verify_completion.verify("/tmp/report.json", mock_report_mod, runner)
      assert.is_true(passed)
      assert.are.equal("/tmp/report.json", result.report_path)
      assert.are.equal(#verify_completion.REQUIRED_GATES, #result.gates)
    end)

    it("returns false when the report cannot be read", function()
      local mock_report_mod = make_mock_smoke_report(nil)
      local passed, result =
        verify_completion.verify("/missing.json", mock_report_mod, nil)
      assert.is_false(passed)
      assert.is_true(result.error:match("failed to read report") ~= nil)
    end)

    it("returns false when report validation fails", function()
      local report = { error = "headless-only" }
      local mock_report_mod = make_mock_smoke_report(report)
      local passed, result =
        verify_completion.verify("/tmp/report.json", mock_report_mod, nil)
      assert.is_false(passed)
      assert.is_true(result.error:match("report validation failed") ~= nil)
    end)

    it("returns false when scope check fails", function()
      local report = make_valid_report()
      table.insert(report.results, {
        name = "Extra out-of-scope scenario",
        passed = true,
        detail = "",
      })
      local mock_report_mod = make_mock_smoke_report(report)
      local passed, result =
        verify_completion.verify("/tmp/report.json", mock_report_mod, nil)
      assert.is_false(passed)
      assert.is_true(result.error:match("out%-of%-scope scenario") ~= nil)
    end)

    it("returns false when a gate fails", function()
      local report = make_valid_report()
      local mock_report_mod = make_mock_smoke_report(report)
      local runner = function(_command)
        return false, 1, "gate failed"
      end
      local passed, result =
        verify_completion.verify("/tmp/report.json", mock_report_mod, runner)
      assert.is_false(passed)
      assert.is_false(result.gates[1].passed)
    end)
  end)

  describe("print_summary()", function()
    local captured = {}

    local function capture_write(...)
      table.insert(captured, table.concat({ ... }, " "))
    end

    before_each(function()
      captured = {}
    end)

    it("prints success for a passing result", function()
      verify_completion.print_summary(true, {
        gates = {
          { name = "format", passed = true },
        },
      }, capture_write)
      assert.is_true(captured[1]:match("completed successfully") ~= nil)
      assert.is_true(captured[2]:match("%[PASS%] format") ~= nil)
    end)

    it("prints an error message for a report error", function()
      verify_completion.print_summary(
        false,
        { error = "stale report" },
        capture_write
      )
      assert.is_true(captured[1]:match("Verification failed") ~= nil)
      assert.is_true(captured[1]:match("stale report") ~= nil)
    end)

    it("prints gate status for a failing gate result", function()
      verify_completion.print_summary(false, {
        gates = {
          { name = "lint", passed = false },
        },
      }, capture_write)
      assert.is_true(captured[1]:match("Verification failed") ~= nil)
      assert.is_true(captured[2]:match("%[FAIL%] lint") ~= nil)
    end)
  end)

  describe("parse_args()", function()
    it("returns arguments that follow the script name in argv", function()
      local args = verify_completion.parse_args({
        "nvim",
        "-l",
        "tests/verify_completion.lua",
        "/custom/report.json",
      })
      assert.are.equal("/custom/report.json", args[1])
    end)

    it("returns an empty table when no extra arguments are provided", function()
      local args = verify_completion.parse_args({
        "nvim",
        "-l",
        "tests/verify_completion.lua",
      })
      assert.are.equal(0, #args)
    end)
  end)
end)
