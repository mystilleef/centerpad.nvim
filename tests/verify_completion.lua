-- Verification completion gate for centerpad.nvim
-- Runs automated gates, validates the real-terminal smoke report, and checks
-- that the scenario roster stays within the scoped remediation surface.
--
-- Design: combined gate runner and validator. /verify invokes this script with
-- an optional report path; it exits 0 only when the report is present, fresh,
-- non-headless, complete, passing, in-scope, and all automated gates succeed.

local M = {}

M.REPORT_DEFAULT_FILENAME = "terminal_smoke_report.json"

M.REQUIRED_GATES = {
  {
    name = "stylua format check",
    command = "env CI=true NO_COLOR=1 PAGER=cat TERM=dumb "
      .. "timeout 60 stylua --check . < /dev/null",
  },
  {
    name = "luacheck lint",
    command = "env CI=true NO_COLOR=1 PAGER=cat TERM=dumb "
      .. "timeout 60 luacheck . < /dev/null",
  },
  {
    name = "selene type check",
    command = "env CI=true NO_COLOR=1 PAGER=cat TERM=dumb "
      .. "timeout 60 selene . < /dev/null",
  },
  {
    name = "headless regression tests",
    command = "env CI=true NO_COLOR=1 PAGER=cat TERM=dumb "
      .. "timeout 60 nvim --headless -u tests/minimal_init.lua "
      .. "-l tests/run_all.lua < /dev/null",
  },
}

function M.default_runner(command)
  local handle = io.popen(command .. " 2>&1", "r")
  local output = handle:read("*a")
  local ok, status, code = handle:close()
  if ok and code == nil then
    -- Successful execution with no explicit exit code means exit 0.
    return true, 0, output
  end
  local exit_code = code or status or 1
  return ok and exit_code == 0, exit_code, output
end

function M.run_gate(gate, runner)
  runner = runner or M.default_runner
  local passed, exit_code, output = runner(gate.command)
  return {
    name = gate.name,
    passed = passed,
    exit_code = exit_code,
    output = output,
  }
end

function M.run_all_gates(gates, runner)
  gates = gates or M.REQUIRED_GATES
  local results = {}
  local all_passed = true
  for _, gate in ipairs(gates) do
    local result = M.run_gate(gate, runner)
    table.insert(results, result)
    if not result.passed then
      all_passed = false
    end
  end
  return all_passed, results
end

function M.load_smoke_report()
  return dofile(
    vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h")
      .. "/smoke_report.lua"
  )
end

function M.check_scope(report, smoke_report_mod)
  smoke_report_mod = smoke_report_mod or M.load_smoke_report()
  local allowed = {}
  for _, name in ipairs(smoke_report_mod.REQUIRED_SCENARIOS) do
    allowed[name] = true
  end
  for _, result in ipairs(report.results or {}) do
    if type(result.name) ~= "string" or not allowed[result.name] then
      return false, "out-of-scope scenario: " .. tostring(result.name)
    end
  end
  return true, ""
end

function M.verify(report_path, smoke_report_mod, runner)
  smoke_report_mod = smoke_report_mod or M.load_smoke_report()
  runner = runner or M.default_runner

  local report, read_err = smoke_report_mod.read_report(report_path)
  if not report then
    return false, { error = "failed to read report: " .. read_err }
  end

  local ok, err = smoke_report_mod.validate(report)
  if not ok then
    return false, { error = "report validation failed: " .. err }
  end

  ok, err = M.check_scope(report, smoke_report_mod)
  if not ok then
    return false, { error = err }
  end

  local gates_passed, gate_results = M.run_all_gates(M.REQUIRED_GATES, runner)
  return gates_passed,
    {
      report_path = report_path,
      gates = gate_results,
    }
end

function M.print_summary(passed, result, write)
  write = write
    or function(...)
      io.write(table.concat({ ... }, " ") .. "\n")
    end
  if not passed then
    if result.error then
      write("Verification failed: " .. result.error)
    else
      write("Verification failed: automated gates did not pass")
      for _, gate in ipairs(result.gates or {}) do
        local status = gate.passed and "PASS" or "FAIL"
        write(string.format("  [%s] %s", status, gate.name))
      end
    end
    return
  end

  write("Verification completed successfully.")
  for _, gate in ipairs(result.gates or {}) do
    write(string.format("  [PASS] %s", gate.name))
  end
end

function M.script_dir()
  return vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h")
end

function M.default_report_path()
  return M.script_dir() .. "/" .. M.REPORT_DEFAULT_FILENAME
end

function M.parse_args(argv)
  argv = argv or vim.v.argv or {}
  local args = {}
  local found_script = false
  for _, arg in ipairs(argv) do
    if found_script then
      table.insert(args, arg)
    elseif arg:match("verify_completion%.lua$") then
      found_script = true
    end
  end
  return args
end

function M.main()
  local args = M.parse_args()
  local report_path = args[1] or M.default_report_path()
  local passed, result = M.verify(report_path)
  M.print_summary(passed, result)
  if passed then
    vim.cmd("cquit 0")
  else
    vim.cmd("cquit 1")
  end
end

local function is_script_invocation()
  local source = debug.getinfo(1).source:sub(2)
  local source_name = vim.fn.fnamemodify(source, ":t")
  for _, arg in ipairs(vim.v.argv or {}) do
    if arg:match(source_name .. "$") then
      return true
    end
  end
  return false
end

if is_script_invocation() then
  M.main()
end

return M
