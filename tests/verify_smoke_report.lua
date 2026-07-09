-- Standalone verifier for the real-terminal smoke report.
-- Usage: nvim -l tests/verify_smoke_report.lua <path> [<expected-location>]

local smoke_report = dofile(
  vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h")
    .. "/smoke_report.lua"
)

local script_path = debug.getinfo(1).source:sub(2)
local report_path = nil
local expected_location = nil

for i, arg in ipairs(vim.v.argv or {}) do
  if arg == script_path then
    report_path = vim.v.argv[i + 1]
    expected_location = vim.v.argv[i + 2]
    break
  end
end

if not report_path or report_path == "" then
  vim.api.nvim_err_writeln(
    "Usage: verify_smoke_report.lua <report-path> [expected-location]"
  )
  vim.cmd("cquit 1")
end

local report, read_err = smoke_report.read_report(report_path)
if not report then
  vim.api.nvim_err_writeln("Failed to read report: " .. read_err)
  vim.cmd("cquit 1")
end

local valid, err = smoke_report.validate(report, expected_location)
if not valid then
  vim.api.nvim_err_writeln("Report validation failed: " .. err)
  vim.cmd("cquit 1")
end

vim.api.nvim_out_write("Smoke report is valid.\n")
vim.cmd("cquit 0")
