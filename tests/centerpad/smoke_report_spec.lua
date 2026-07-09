describe("smoke_report contract", function()
  local smoke_report = dofile(
    vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h:h")
      .. "/smoke_report.lua"
  )

  local function valid_result(name, passed)
    return { name = name, passed = passed, detail = "" }
  end

  local function make_valid_results()
    local results = {}
    for _, name in ipairs(smoke_report.REQUIRED_SCENARIOS) do
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
      passed = overrides.passed or #smoke_report.REQUIRED_SCENARIOS,
      failed = overrides.failed or 0,
      results = overrides.results or make_valid_results(),
    }
  end

  describe("is_tty_proof_present()", function()
    it("returns true for a real /dev TTY name", function()
      assert.is_true(smoke_report.is_tty_proof_present({
        tty_proof = { tty_name = "/dev/pts/5" },
      }))
    end)

    it("returns false when tty_name is missing", function()
      assert.is_false(smoke_report.is_tty_proof_present({ tty_proof = {} }))
    end)

    it("returns false when tty_name is empty", function()
      assert.is_false(
        smoke_report.is_tty_proof_present({ tty_proof = { tty_name = "" } })
      )
    end)

    it(
      "returns false when tty_name is an unrecognised non-empty string",
      function()
        assert.is_false(smoke_report.is_tty_proof_present({
          tty_proof = { tty_name = "garbage" },
        }))
      end
    )

    it("returns true when tty_name reports the not-a-tty diagnostic", function()
      assert.is_true(smoke_report.is_tty_proof_present({
        tty_proof = { tty_name = "not a tty" },
      }))
    end)

    it("returns false when tty_proof is not a table", function()
      assert.is_false(
        smoke_report.is_tty_proof_present({ tty_proof = "/dev/pts/5" })
      )
    end)

    it("returns false when report has no tty_proof field", function()
      assert.is_false(smoke_report.is_tty_proof_present({}))
    end)
  end)

  describe("is_headless()", function()
    it("returns true when headless flag is true", function()
      assert.is_true(smoke_report.is_headless({ headless = true }))
    end)

    it("returns false when headless flag is false", function()
      assert.is_false(smoke_report.is_headless({ headless = false }))
    end)

    it("returns false when headless flag is missing", function()
      assert.is_false(smoke_report.is_headless({}))
    end)
  end)

  describe("is_fresh()", function()
    it("returns true for a report created now", function()
      local now = 1000
      assert.is_true(smoke_report.is_fresh({ timestamp = 1000 }, now))
    end)

    it("returns true for a report within the max age window", function()
      local now = 1000 + smoke_report.REPORT_MAX_AGE_SECONDS
      assert.is_true(smoke_report.is_fresh({ timestamp = 1000 }, now))
    end)

    it("returns false for a stale report", function()
      local now = 1000 + smoke_report.REPORT_MAX_AGE_SECONDS + 1
      assert.is_false(smoke_report.is_fresh({ timestamp = 1000 }, now))
    end)

    it("returns false for a future-dated report", function()
      local now = 500
      assert.is_false(smoke_report.is_fresh({ timestamp = 1000 }, now))
    end)

    it("returns false when timestamp is missing", function()
      assert.is_false(smoke_report.is_fresh({}))
    end)

    it("returns false when timestamp is not a number", function()
      assert.is_false(smoke_report.is_fresh({ timestamp = "now" }))
    end)
  end)

  describe("has_required_metadata()", function()
    it("passes for a complete real-terminal report", function()
      local ok, err = smoke_report.has_required_metadata(make_valid_report())
      assert.is_true(ok)
      assert.are.equal("", err)
    end)

    it("fails when a metadata field is missing", function()
      local report = make_valid_report()
      report.neovim_version = nil
      local ok, err = smoke_report.has_required_metadata(report)
      assert.is_false(ok)
      assert.is_true(err:match("missing metadata field") ~= nil)
    end)

    it("fails when TTY proof is invalid", function()
      local report = make_valid_report({ tty_proof = { tty_name = "" } })
      local ok, err = smoke_report.has_required_metadata(report)
      assert.is_false(ok)
      assert.is_true(err:match("TTY proof") ~= nil)
    end)

    it("fails when report is headless-only", function()
      local report = make_valid_report({ headless = true })
      local ok, err = smoke_report.has_required_metadata(report)
      assert.is_false(ok)
      assert.is_true(err:match("headless") ~= nil)
    end)

    it("fails when report is stale", function()
      local report = make_valid_report({ timestamp = 1 })
      local ok, err = smoke_report.has_required_metadata(report, 10000)
      assert.is_false(ok)
      assert.is_true(err:match("stale") ~= nil)
    end)
  end)

  describe("has_valid_result_shape()", function()
    it("passes when every result has required fields", function()
      local ok, err = smoke_report.has_valid_result_shape(make_valid_results())
      assert.is_true(ok)
      assert.are.equal("", err)
    end)

    it("fails when a result is missing its detail field", function()
      local results = make_valid_results()
      results[2].detail = nil
      local ok, err = smoke_report.has_valid_result_shape(results)
      assert.is_false(ok)
      assert.is_true(err:match("detail") ~= nil)
    end)

    it("fails when a result detail is not a string", function()
      local results = make_valid_results()
      results[2].detail = 42
      local ok, err = smoke_report.has_valid_result_shape(results)
      assert.is_false(ok)
      assert.is_true(err:match("detail") ~= nil)
    end)

    it("fails when a result name is not a string", function()
      local results = make_valid_results()
      results[2].name = 123
      local ok, err = smoke_report.has_valid_result_shape(results)
      assert.is_false(ok)
      assert.is_true(err:match("name") ~= nil)
    end)

    it("fails when a result passed flag is not a boolean", function()
      local results = make_valid_results()
      results[2].passed = "yes"
      local ok, err = smoke_report.has_valid_result_shape(results)
      assert.is_false(ok)
      assert.is_true(err:match("passed") ~= nil)
    end)

    it("fails when a result entry is not a table", function()
      local results = make_valid_results()
      results[2] = "bad"
      local ok, err = smoke_report.has_valid_result_shape(results)
      assert.is_false(ok)
      assert.is_true(err:match("not a table") ~= nil)
    end)
  end)

  describe("has_all_scenarios()", function()
    it("passes when every required scenario is present", function()
      local ok, err = smoke_report.has_all_scenarios(make_valid_report())
      assert.is_true(ok)
      assert.are.equal("", err)
    end)

    it("fails when a required scenario is missing", function()
      local results = make_valid_results()
      table.remove(results, 1)
      local ok, err = smoke_report.has_all_scenarios(make_valid_report({
        results = results,
      }))
      assert.is_false(ok)
      assert.is_true(err:match("missing scenario") ~= nil)
    end)

    it("fails when results array is empty", function()
      local ok, err =
        smoke_report.has_all_scenarios(make_valid_report({ results = {} }))
      assert.is_false(ok)
      assert.is_true(err:match("missing scenario") ~= nil)
    end)
  end)

  describe("has_no_extra_scenarios()", function()
    it("passes when every scenario is in the required roster", function()
      local ok, err = smoke_report.has_no_extra_scenarios(make_valid_report())
      assert.is_true(ok)
      assert.are.equal("", err)
    end)

    it("fails when a scenario is outside the required roster", function()
      local results = make_valid_results()
      table.insert(results, {
        name = "Zen mode should be supported",
        passed = true,
        detail = "",
      })
      local ok, err = smoke_report.has_no_extra_scenarios(make_valid_report({
        results = results,
      }))
      assert.is_false(ok)
      assert.is_true(err:match("out%-of%-scope scenario") ~= nil)
    end)

    it("fails when a result name is not a string", function()
      local results = make_valid_results()
      results[1].name = 123
      local ok, err = smoke_report.has_no_extra_scenarios(make_valid_report({
        results = results,
      }))
      assert.is_false(ok)
      assert.is_true(err:match("out%-of%-scope scenario") ~= nil)
    end)
  end)

  describe("all_scenarios_passed()", function()
    it("passes when all scenarios passed", function()
      local ok, err = smoke_report.all_scenarios_passed(make_valid_report())
      assert.is_true(ok)
      assert.are.equal("", err)
    end)

    it("fails when any scenario failed", function()
      local results = make_valid_results()
      results[3].passed = false
      local ok, err = smoke_report.all_scenarios_passed(
        make_valid_report({ results = results })
      )
      assert.is_false(ok)
      assert.is_true(err:match("scenario failed") ~= nil)
    end)
  end)

  describe("validate()", function()
    it("accepts a complete valid report", function()
      local ok, err = smoke_report.validate(make_valid_report())
      assert.is_true(ok)
      assert.are.equal("", err)
    end)

    it("rejects a non-table report", function()
      local ok, err = smoke_report.validate("bad")
      assert.is_false(ok)
      assert.is_true(err:match("not a table") ~= nil)
    end)

    it("rejects empty results", function()
      local ok, err = smoke_report.validate(make_valid_report({ results = {} }))
      assert.is_false(ok)
      assert.is_true(err:match("empty") ~= nil)
    end)

    it("rejects missing metadata", function()
      local report = make_valid_report()
      report.command_sequence = nil
      local ok, err = smoke_report.validate(report)
      assert.is_false(ok)
      assert.is_true(err:match("metadata") ~= nil)
    end)

    it("rejects headless reports", function()
      local ok, err =
        smoke_report.validate(make_valid_report({ headless = true }))
      assert.is_false(ok)
      assert.is_true(err:match("headless") ~= nil)
    end)

    it("rejects stale reports", function()
      local ok, err =
        smoke_report.validate(make_valid_report({ timestamp = 1 }), nil, 10000)
      assert.is_false(ok)
      assert.is_true(err:match("stale") ~= nil)
    end)

    it("rejects missing scenarios", function()
      local results = make_valid_results()
      table.remove(results, 1)
      local ok, err = smoke_report.validate(make_valid_report({
        results = results,
      }))
      assert.is_false(ok)
      assert.is_true(err:match("missing scenario") ~= nil)
    end)

    it("rejects invalid result shape", function()
      local results = make_valid_results()
      results[3].detail = nil
      local ok, err = smoke_report.validate(make_valid_report({
        results = results,
      }))
      assert.is_false(ok)
      assert.is_true(err:match("detail") ~= nil)
    end)

    it("rejects failed scenarios", function()
      local results = make_valid_results()
      results[1].passed = false
      local ok, err = smoke_report.validate(make_valid_report({
        results = results,
      }))
      assert.is_false(ok)
      assert.is_true(err:match("scenario failed") ~= nil)
    end)

    it("rejects mismatched report location", function()
      local ok, err = smoke_report.validate(
        make_valid_report({ report_location = "/tmp/a.json" }),
        "/tmp/b.json"
      )
      assert.is_false(ok)
      assert.is_true(err:match("location mismatch") ~= nil)
    end)

    it("accepts matching report location", function()
      local ok, err = smoke_report.validate(
        make_valid_report({ report_location = "/tmp/a.json" }),
        "/tmp/a.json"
      )
      assert.is_true(ok)
      assert.are.equal("", err)
    end)

    it(
      "accepts an expected location that resolves to the report location",
      function()
        if vim.fn.has("unix") ~= 1 then
          return
        end
        local real_path = os.tmpname() .. "_real_report.json"
        local link_path = os.tmpname() .. "_link_report.json"
        os.remove(real_path)
        os.remove(link_path)

        local file = io.open(real_path, "w")
        file:write("{}")
        file:close()
        vim.loop.fs_symlink(real_path, link_path)

        local ok, err = smoke_report.validate(
          make_valid_report({ report_location = real_path }),
          link_path
        )

        os.remove(real_path)
        os.remove(link_path)

        assert.is_true(ok, err)
        assert.are.equal("", err)
      end
    )
  end)

  describe("build_report()", function()
    it("includes all required metadata fields", function()
      local results = make_valid_results()
      local report = smoke_report.build_report(results, "/tmp/report.json", {
        timestamp = 1234,
        neovim_version = "0.12.0",
        tty_proof = { tty_name = "/dev/pts/1" },
        command_sequence = { "nvim", "-l", "smoke.lua" },
        headless = false,
      })

      assert.are.equal(1234, report.timestamp)
      assert.are.equal("0.12.0", report.neovim_version)
      assert.are.equal("/dev/pts/1", report.tty_proof.tty_name)
      assert.are.equal("/tmp/report.json", report.report_location)
      assert.is_false(report.headless)
      assert.are.equal(#results, report.passed)
      assert.are.equal(0, report.failed)
    end)

    it("counts failed scenarios", function()
      local results = {
        valid_result("a", true),
        valid_result("b", false),
        valid_result("c", true),
      }
      local report = smoke_report.build_report(results, "/tmp/report.json", {
        timestamp = 1,
        neovim_version = "0.12.0",
        tty_proof = { tty_name = "/dev/pts/1" },
        command_sequence = {},
        headless = false,
      })
      assert.are.equal(2, report.passed)
      assert.are.equal(1, report.failed)
    end)

    it("defaults headless from argv when override is absent", function()
      local report = smoke_report.build_report({}, "/tmp/report.json", {
        timestamp = 1,
        neovim_version = "0.12.0",
        tty_proof = { tty_name = "/dev/pts/1" },
        command_sequence = {},
        argv = { "--headless" },
      })

      assert.is_true(report.headless)
    end)
  end)

  describe("is_running_headless()", function()
    it("returns true when --headless is present in argv", function()
      assert.is_true(smoke_report.is_running_headless({ "--headless" }))
    end)

    it("returns false when --headless is absent from argv", function()
      assert.is_false(smoke_report.is_running_headless({ "-u", "init.lua" }))
    end)
  end)

  describe("write_report() and read_report()", function()
    local temp_path

    before_each(function()
      temp_path = os.tmpname() .. "_smoke_report.json"
    end)

    after_each(function()
      os.remove(temp_path)
    end)

    it("round-trips a report through the filesystem", function()
      local original = make_valid_report()
      local write_ok, write_err = smoke_report.write_report(original, temp_path)
      assert.is_true(write_ok, write_err)

      local decoded, read_err = smoke_report.read_report(temp_path)
      assert.is_not_nil(decoded, read_err)
      assert.are.equal(original.timestamp, decoded.timestamp)
      assert.are.equal(original.neovim_version, decoded.neovim_version)
      assert.are.equal(original.report_location, decoded.report_location)
      assert.are.equal(original.headless, decoded.headless)
      assert.are.equal(#original.results, #decoded.results)
    end)

    it("returns an error for a missing file", function()
      local decoded, read_err =
        smoke_report.read_report("/nonexistent/path/report.json")
      assert.is_nil(decoded)
      assert.is_true(read_err:match("failed to open") ~= nil)
    end)

    it("returns an error for invalid JSON", function()
      local file = io.open(temp_path, "w")
      file:write("not json")
      file:close()

      local decoded, read_err = smoke_report.read_report(temp_path)
      assert.is_nil(decoded)
      assert.is_true(read_err:match("json_decode") ~= nil)
    end)

    it("returns an error for an unreadable directory path", function()
      local dir_path = os.tmpname() .. "_smoke_report_dir"
      os.remove(dir_path)
      vim.loop.fs_mkdir(dir_path, 493)

      local decoded, read_err = smoke_report.read_report(dir_path)

      vim.loop.fs_rmdir(dir_path)

      assert.is_nil(decoded)
      assert.is_true(read_err:match("failed to read") ~= nil)
    end)
  end)

  describe("required constants", function()
    it("lists required metadata fields", function()
      assert.is_true(#smoke_report.REQUIRED_METADATA_FIELDS > 0)
    end)

    it("lists required scenarios", function()
      assert.is_true(#smoke_report.REQUIRED_SCENARIOS > 0)
    end)

    it("defines a positive max age", function()
      assert.is_true(smoke_report.REPORT_MAX_AGE_SECONDS > 0)
    end)
  end)
end)
