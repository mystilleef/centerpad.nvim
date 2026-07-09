-- Terminal smoke test for centerpad.nvim
-- Runs inside a real TTY (tmux) and writes a JSON report to disk.

local centerpad = require("centerpad")
local state = require("centerpad.state")
local window = require("centerpad.window")
local autocmds = require("centerpad.autocmds")
local enabled = require("centerpad.enabled")

local smoke_report = dofile(
  vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h")
    .. "/smoke_report.lua"
)

local results = {}
local function record(name, passed, detail)
  table.insert(results, {
    name = name,
    passed = passed,
    detail = detail or "",
  })
end

local function wait_for_schedule()
  vim.wait(200, function()
    return false
  end)
end

local function wait_for_timer()
  vim.wait(200, function()
    return state.restore_timer == nil
  end, 10)
end

local function wait_for_recovery()
  vim.wait(3000, function()
    return state.pad_state.enabled
      and state.pad_state.main_win
      and vim.api.nvim_win_is_valid(state.pad_state.main_win)
      and window.are_pads_valid()
  end, 10)
end

local function get_pad_widths()
  return window.get_pad_width(state.pad_state.left_win),
    window.get_pad_width(state.pad_state.right_win)
end

local function ensure_normal_source_buffer()
  local cur = vim.api.nvim_get_current_win()
  pcall(vim.api.nvim_set_option_value, "winfixbuf", false, { win = cur })
  vim.cmd("enew")
  vim.bo.buftype = ""
  vim.bo.filetype = ""
end

local function count_autocmds()
  local ok, autocmd_list = pcall(vim.api.nvim_get_autocmds, {
    group = autocmds.padgroup,
  })
  if not ok then
    return 0
  end
  return #autocmd_list
end

local function is_source_focused()
  local main = state.pad_state.main_win
  if not main or not vim.api.nvim_win_is_valid(main) then
    return false
  end
  local ok, buf = pcall(vim.api.nvim_win_get_buf, main)
  if not ok then
    return false
  end
  return not window.is_pad_buffer(buf)
end

local function with_notify_capture(fn)
  local original = vim.notify
  local messages = {}
  vim.notify = function(msg, level)
    table.insert(messages, { msg = msg, level = level })
  end
  local ok, err = pcall(fn)
  vim.notify = original
  return messages, ok, err
end

local function has_invalid_width_notify(messages)
  for _, m in ipairs(messages) do
    if type(m.msg) == "string" and m.msg:match("Invalid width") then
      return true
    end
  end
  return false
end

local function count_pad_windows()
  local count = 0
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local ok, buf = pcall(vim.api.nvim_win_get_buf, win)
    if ok and window.is_pad_buffer(buf) then
      count = count + 1
    end
  end
  return count
end

local function run_invalid_width_scenario(name, command_or_opts)
  centerpad.disable()
  state.reset()
  ensure_normal_source_buffer()
  centerpad.setup({ leftpad = 25, rightpad = 25 })
  vim.cmd("Centerpad 30")
  wait_for_schedule()

  local old_left = state.pad_state.left_win
  local old_right = state.pad_state.right_win
  local old_config = {
    leftpad = centerpad.config.leftpad,
    rightpad = centerpad.config.rightpad,
  }

  local messages = with_notify_capture(function()
    if type(command_or_opts) == "string" then
      pcall(vim.cmd, command_or_opts)
    else
      centerpad.run(command_or_opts)
    end
  end)
  wait_for_schedule()

  local notified = has_invalid_width_notify(messages)
  local config_unchanged = centerpad.config.leftpad == old_config.leftpad
    and centerpad.config.rightpad == old_config.rightpad
  record(
    name,
    notified
      and state.pad_state.left_win == old_left
      and state.pad_state.right_win == old_right
      and window.are_pads_valid()
      and config_unchanged,
    string.format(
      "notified=%s left same=%s right same=%s valid=%s config unchanged=%s",
      notified,
      state.pad_state.left_win == old_left,
      state.pad_state.right_win == old_right,
      window.are_pads_valid(),
      config_unchanged
    )
  )
end

local function run_ignored_buffer_scenario(name, setup_buffer)
  centerpad.disable()
  state.reset()
  ensure_normal_source_buffer()
  setup_buffer()
  centerpad.setup({ leftpad = 25, rightpad = 25 })
  vim.cmd("Centerpad 30")
  wait_for_schedule()
  record(
    name,
    not state.pad_state.enabled
      and state.pad_state.left_win == nil
      and state.pad_state.right_win == nil,
    string.format(
      "enabled=%s left=%s right=%s",
      state.pad_state.enabled,
      state.pad_state.left_win,
      state.pad_state.right_win
    )
  )
end

-- Ensure clean state
centerpad.disable()
state.reset()
enabled._reset_warning()
vim.g.centerpad_enabled = nil
vim.g.center_buf_enabled = nil

-- Scenario 1: :Centerpad 30 sets both pads to 30 columns
centerpad.setup({ leftpad = 25, rightpad = 25 })
vim.cmd("Centerpad 30")
wait_for_schedule()
local left_w, right_w = get_pad_widths()
local valid = window.are_pads_valid()
record(
  "Centerpad 30 creates two 30-column pads",
  valid and left_w == 30 and right_w == 30,
  string.format("valid=%s left=%s right=%s", valid, left_w, right_w)
)

-- Scenario 2: Repeated :Centerpad 30 preserves identities
local left_id_before = state.pad_state.left_win
local right_id_before = state.pad_state.right_win
vim.cmd("Centerpad 30")
wait_for_schedule()
left_w, right_w = get_pad_widths()
record(
  "Repeated Centerpad 30 preserves pad identities",
  left_id_before == state.pad_state.left_win
    and right_id_before == state.pad_state.right_win
    and left_w == 30
    and right_w == 30,
  string.format(
    "left_id same=%s right_id same=%s left=%s right=%s",
    left_id_before == state.pad_state.left_win,
    right_id_before == state.pad_state.right_win,
    left_w,
    right_w
  )
)

-- Scenario 3: Close unrelated split preserves pads
vim.cmd("vsplit")
wait_for_schedule()
local split_win = vim.api.nvim_get_current_win()
local left_id_split_before = state.pad_state.left_win
local right_id_split_before = state.pad_state.right_win
vim.api.nvim_win_close(split_win, true)
wait_for_timer()
left_w, right_w = get_pad_widths()
local left_id_same = left_id_split_before == state.pad_state.left_win
local right_id_same = right_id_split_before == state.pad_state.right_win
record(
  "Closing unrelated split preserves healthy pads",
  window.are_pads_valid()
    and left_w == 30
    and right_w == 30
    and left_id_same
    and right_id_same,
  string.format(
    "valid=%s left=%s right=%s left_id_same=%s right_id_same=%s rebuild=%s flicker=none",
    window.are_pads_valid(),
    left_w,
    right_w,
    left_id_same,
    right_id_same,
    not state.pad_state.enabled
  )
)

-- Scenario 4: Closing one pad triggers cleanup + re-enable
local left_id_before_close = state.pad_state.left_win
local right_id_before_close = state.pad_state.right_win
local left_buf = vim.api.nvim_win_get_buf(state.pad_state.left_win)
pcall(vim.api.nvim_buf_delete, left_buf, { force = true })
wait_for_recovery()
left_w, right_w = get_pad_widths()
local fresh_ids = state.pad_state.left_win ~= left_id_before_close
  and state.pad_state.right_win ~= right_id_before_close
record(
  "Closing one pad recovers via cleanup + re-enable",
  window.are_pads_valid()
    and left_w == 30
    and right_w == 30
    and fresh_ids
    and is_source_focused()
    and state.restore_timer == nil,
  string.format(
    "valid=%s left=%s right=%s fresh_ids=%s source_focused=%s timer=%s",
    window.are_pads_valid(),
    left_w,
    right_w,
    fresh_ids,
    is_source_focused(),
    state.restore_timer
  )
)

-- Scenario 5: Closing main source window triggers cleanup + re-enable
local left_id_before_main_close = state.pad_state.left_win
local right_id_before_main_close = state.pad_state.right_win
local main_win = state.pad_state.main_win
pcall(vim.api.nvim_win_close, main_win, true)
wait_for_recovery()
left_w, right_w = get_pad_widths()
local main_fresh_ids = state.pad_state.left_win ~= left_id_before_main_close
  and state.pad_state.right_win ~= right_id_before_main_close
record(
  "Closing main source window recovers via cleanup + re-enable",
  window.are_pads_valid()
    and left_w == 30
    and right_w == 30
    and main_fresh_ids
    and is_source_focused()
    and state.restore_timer == nil,
  string.format(
    "valid=%s left=%s right=%s fresh_ids=%s source_focused=%s timer=%s",
    window.are_pads_valid(),
    left_w,
    right_w,
    main_fresh_ids,
    is_source_focused(),
    state.restore_timer
  )
)

-- Scenario 6: Closing both pads triggers cleanup + re-enable
centerpad.disable()
state.reset()
centerpad.setup({ leftpad = 25, rightpad = 25 })
vim.cmd("Centerpad 30")
wait_for_schedule()
local both_left_id_before = state.pad_state.left_win
local both_right_id_before = state.pad_state.right_win
local lb = vim.api.nvim_win_get_buf(state.pad_state.left_win)
local rb = vim.api.nvim_win_get_buf(state.pad_state.right_win)
pcall(vim.api.nvim_buf_delete, lb, { force = true })
pcall(vim.api.nvim_buf_delete, rb, { force = true })
wait_for_recovery()
left_w, right_w = get_pad_widths()
local both_fresh_ids = state.pad_state.left_win ~= both_left_id_before
  and state.pad_state.right_win ~= both_right_id_before
record(
  "Closing both pads recovers via cleanup + re-enable",
  window.are_pads_valid()
    and left_w == 30
    and right_w == 30
    and both_fresh_ids
    and is_source_focused()
    and state.restore_timer == nil,
  string.format(
    "valid=%s left=%s right=%s fresh_ids=%s source_focused=%s timer=%s",
    window.are_pads_valid(),
    left_w,
    right_w,
    both_fresh_ids,
    is_source_focused(),
    state.restore_timer
  )
)

-- Scenarios 7-10: Invalid widths notify and preserve state
run_invalid_width_scenario(
  "Invalid width 0 preserves existing windows and config and notifies error",
  "Centerpad 0"
)
run_invalid_width_scenario(
  "Invalid width 501 preserves existing windows and config and notifies error",
  "Centerpad 501"
)
run_invalid_width_scenario(
  "Invalid width empty preserves existing windows and config and notifies error",
  { fargs = { "" } }
)
run_invalid_width_scenario(
  "Invalid width non-numeric preserves existing windows and config and notifies error",
  "Centerpad abc"
)

-- Scenarios 11-15: Ignored buffers skip enablement
run_ignored_buffer_scenario("Ignored nofile buffer skips enablement", function()
  vim.bo.buftype = "nofile"
end)
run_ignored_buffer_scenario(
  "Ignored quickfix buffer skips enablement",
  function()
    vim.bo.buftype = "quickfix"
  end
)
run_ignored_buffer_scenario("Ignored help buffer skips enablement", function()
  vim.bo.buftype = "help"
  vim.bo.filetype = "help"
end)

-- Scenario 14: Terminal buffer skips enablement
centerpad.disable()
state.reset()
ensure_normal_source_buffer()
vim.cmd("terminal true")
local terminal_buf = vim.api.nvim_get_current_buf()
centerpad.setup({ leftpad = 25, rightpad = 25 })
vim.cmd("Centerpad 30")
wait_for_schedule()
record(
  "Ignored terminal buffer skips enablement",
  not state.pad_state.enabled
    and state.pad_state.left_win == nil
    and state.pad_state.right_win == nil,
  string.format(
    "enabled=%s left=%s right=%s",
    state.pad_state.enabled,
    state.pad_state.left_win,
    state.pad_state.right_win
  )
)
pcall(vim.api.nvim_buf_delete, terminal_buf, { force = true })

-- Scenario 15: Floating window skips enablement
centerpad.disable()
state.reset()
ensure_normal_source_buffer()
local float_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_option(float_buf, "buftype", "")
vim.api.nvim_buf_set_option(float_buf, "filetype", "")
local float_win = vim.api.nvim_open_win(float_buf, false, {
  relative = "editor",
  width = 10,
  height = 10,
  row = 0,
  col = 0,
})
vim.api.nvim_set_current_win(float_win)
centerpad.setup({ leftpad = 25, rightpad = 25 })
vim.cmd("Centerpad 30")
wait_for_schedule()
record(
  "Floating window skips enablement",
  not state.pad_state.enabled
    and state.pad_state.left_win == nil
    and state.pad_state.right_win == nil,
  string.format(
    "enabled=%s left=%s right=%s",
    state.pad_state.enabled,
    state.pad_state.left_win,
    state.pad_state.right_win
  )
)
vim.api.nvim_win_close(float_win, true)
vim.api.nvim_buf_delete(float_buf, { force = true })

-- Scenario 16: Centerpad pad buffer skips enablement
run_ignored_buffer_scenario("Centerpad pad buffer skips enablement", function()
  vim.bo.filetype = "centerpad"
end)

-- Scenario 17: No orphaned pads after normal enable
centerpad.disable()
state.reset()
ensure_normal_source_buffer()
centerpad.setup({ leftpad = 25, rightpad = 25 })
vim.cmd("Centerpad 30")
wait_for_schedule()
record(
  "No orphaned pads after normal enable",
  count_pad_windows() == 2,
  string.format("pad windows=%s", count_pad_windows())
)

-- Scenario 18: Cleanup deletes all pad windows
centerpad.disable()
record(
  "Cleanup deletes all pad windows",
  count_pad_windows() == 0,
  string.format("pad windows=%s", count_pad_windows())
)

-- Scenarios 19-21: Cleanup clears state
centerpad.disable()
state.reset()
ensure_normal_source_buffer()
centerpad.setup({ leftpad = 25, rightpad = 25 })
vim.cmd("Centerpad 30")
wait_for_schedule()
-- Force cleanup and verify no stale state
centerpad.disable()
record(
  "Cleanup clears enabled globals",
  vim.g.centerpad_enabled == false and vim.g.center_buf_enabled == false,
  string.format(
    "centerpad_enabled=%s center_buf_enabled=%s",
    vim.g.centerpad_enabled,
    vim.g.center_buf_enabled
  )
)
record(
  "Cleanup stops restore timer",
  state.restore_timer == nil,
  string.format("timer=%s", state.restore_timer)
)
record(
  "Cleanup removes autocmds",
  count_autocmds() == 0,
  string.format("autocmd count=%s", count_autocmds())
)

-- Write report
local report_path = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h")
  .. "/terminal_smoke_report.json"
local absolute_path = vim.fn.fnamemodify(report_path, ":p")
local report = smoke_report.build_report(results, absolute_path)
smoke_report.write_report(report, report_path)

-- Exit non-zero on failure so the calling shell can detect it
if report.failed > 0 then
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
