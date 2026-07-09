-- Real-terminal smoke report contract for centerpad.nvim
-- Defines required metadata, scenario roster, and validation rules.

local M = {}

M.REPORT_MAX_AGE_SECONDS = 300

M.REQUIRED_METADATA_FIELDS = {
  "timestamp",
  "neovim_version",
  "tty_proof",
  "command_sequence",
  "report_location",
  "headless",
}

M.REQUIRED_SCENARIOS = {
  "Centerpad 30 creates two 30-column pads",
  "Repeated Centerpad 30 preserves pad identities",
  "Closing unrelated split preserves healthy pads",
  "Closing one pad recovers via cleanup + re-enable",
  "Closing main source window recovers via cleanup + re-enable",
  "Closing both pads recovers via cleanup + re-enable",
  "Invalid width 0 preserves existing windows and config and notifies error",
  "Invalid width 501 preserves existing windows and config and notifies error",
  "Invalid width empty preserves existing windows and config and notifies error",
  "Invalid width non-numeric preserves existing windows and config and notifies error",
  "Ignored nofile buffer skips enablement",
  "Ignored terminal buffer skips enablement",
  "Ignored quickfix buffer skips enablement",
  "Ignored help buffer skips enablement",
  "Floating window skips enablement",
  "Centerpad pad buffer skips enablement",
  "No orphaned pads after normal enable",
  "Cleanup deletes all pad windows",
  "Cleanup clears enabled globals",
  "Cleanup stops restore timer",
  "Cleanup removes autocmds",
}

M.REQUIRED_RESULT_FIELDS = {
  "name",
  "passed",
  "detail",
}

function M.is_tty_proof_present(report)
  local proof = report.tty_proof
  if type(proof) ~= "table" then
    return false
  end
  local tty_name = proof.tty_name
  if type(tty_name) ~= "string" or tty_name == "" then
    return false
  end
  return tty_name:match("^/dev/") ~= nil or tty_name == "not a tty"
end

function M.is_headless(report)
  return report.headless == true
end

function M.is_fresh(report, now)
  now = now or os.time()
  local timestamp = report.timestamp
  if type(timestamp) ~= "number" then
    return false
  end
  local age = now - timestamp
  return age >= 0 and age <= M.REPORT_MAX_AGE_SECONDS
end

function M.has_required_metadata(report, now)
  for _, field in ipairs(M.REQUIRED_METADATA_FIELDS) do
    if report[field] == nil then
      return false, "missing metadata field: " .. field
    end
  end
  if not M.is_tty_proof_present(report) then
    return false, "missing or invalid TTY proof"
  end
  if M.is_headless(report) then
    return false, "report is headless-only"
  end
  if not M.is_fresh(report, now) then
    return false, "report is stale"
  end
  return true, ""
end

function M.collect_scenario_names(results)
  local names = {}
  for _, result in ipairs(results or {}) do
    table.insert(names, result.name)
  end
  return names
end

function M.has_valid_result_shape(results)
  for _, result in ipairs(results or {}) do
    if type(result) ~= "table" then
      return false, "result entry is not a table"
    end
    for _, field in ipairs(M.REQUIRED_RESULT_FIELDS) do
      if result[field] == nil then
        return false, "missing result field: " .. field
      end
    end
    if type(result.name) ~= "string" then
      return false, "result name is not a string"
    end
    if type(result.passed) ~= "boolean" then
      return false, "result passed flag is not a boolean"
    end
    if type(result.detail) ~= "string" then
      return false, "result detail is not a string"
    end
  end
  return true, ""
end

function M.has_all_scenarios(report)
  local present = {}
  for _, result in ipairs(report.results or {}) do
    present[result.name] = true
  end
  for _, name in ipairs(M.REQUIRED_SCENARIOS) do
    if not present[name] then
      return false, "missing scenario: " .. name
    end
  end
  return true, ""
end

function M.has_no_extra_scenarios(report)
  local allowed = {}
  for _, name in ipairs(M.REQUIRED_SCENARIOS) do
    allowed[name] = true
  end
  for _, result in ipairs(report.results or {}) do
    if type(result.name) ~= "string" or not allowed[result.name] then
      return false, "out-of-scope scenario: " .. tostring(result.name)
    end
  end
  return true, ""
end

function M.all_scenarios_passed(report)
  for _, result in ipairs(report.results or {}) do
    if not result.passed then
      return false, "scenario failed: " .. result.name
    end
  end
  return true, ""
end

function M.validate(report, expected_location, now)
  if type(report) ~= "table" then
    return false, "report is not a table"
  end
  if type(report.results) ~= "table" or #report.results == 0 then
    return false, "report results are empty"
  end

  local ok, err = M.has_required_metadata(report, now)
  if not ok then
    return false, err
  end

  ok, err = M.has_valid_result_shape(report.results)
  if not ok then
    return false, err
  end

  ok, err = M.has_all_scenarios(report)
  if not ok then
    return false, err
  end

  ok, err = M.all_scenarios_passed(report)
  if not ok then
    return false, err
  end

  if expected_location then
    local real_report_location = vim.loop.fs_realpath(report.report_location)
      or report.report_location
    local real_expected_location = vim.loop.fs_realpath(expected_location)
      or expected_location
    if real_report_location ~= real_expected_location then
      return false, "report location mismatch"
    end
  end

  return true, ""
end

function M.gather_tty_proof()
  local tty_name = ""
  local ok, output = pcall(vim.fn.system, "tty")
  if ok and output then
    tty_name = vim.trim(output)
  end
  return { tty_name = tty_name }
end

function M.gather_command_sequence()
  return vim.v.argv or {}
end

function M.gather_neovim_version()
  return tostring(vim.version())
end

-- argv defaults to vim.v.argv, which is read-only in Neovim and cannot be
-- stubbed directly; accepting it as a parameter keeps this testable.
function M.is_running_headless(argv)
  return vim.tbl_contains(argv or vim.v.argv or {}, "--headless")
end

function M.build_report(results, location, overrides)
  overrides = overrides or {}
  local report = {
    timestamp = overrides.timestamp or os.time(),
    neovim_version = overrides.neovim_version or M.gather_neovim_version(),
    tty_proof = overrides.tty_proof or M.gather_tty_proof(),
    command_sequence = overrides.command_sequence
      or M.gather_command_sequence(),
    report_location = location,
    headless = (function()
      if overrides.headless ~= nil then
        return overrides.headless
      end
      return M.is_running_headless(overrides.argv)
    end)(),
    passed = 0,
    failed = 0,
    results = results,
  }
  for _, result in ipairs(results or {}) do
    if result.passed then
      report.passed = report.passed + 1
    else
      report.failed = report.failed + 1
    end
  end
  return report
end

function M.write_report(report, path)
  local ok, encoded = pcall(vim.fn.json_encode, report)
  if not ok then
    return false, "json_encode failed: " .. tostring(encoded)
  end
  local file, open_err = io.open(path, "w")
  if not file then
    return false, "failed to open " .. path .. ": " .. tostring(open_err)
  end
  file:write(encoded)
  file:close()
  return true, ""
end

function M.read_report(path)
  local file, open_err = io.open(path, "r")
  if not file then
    return nil, "failed to open " .. path .. ": " .. tostring(open_err)
  end
  local content = file:read("*a")
  file:close()
  if content == nil or content == "" then
    return nil, "failed to read " .. path
  end
  local ok, decoded = pcall(vim.fn.json_decode, content)
  if not ok then
    return nil, "json_decode failed: " .. tostring(decoded)
  end
  return decoded, ""
end

return M
