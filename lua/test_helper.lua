local M = {}

M.notify_spy = nil

function M.ensure_normal_source_window()
  local cur = vim.api.nvim_get_current_win()
  local ok, buf = pcall(vim.api.nvim_win_get_buf, cur)

  -- If current window is invalid or has a pad buffer, create a new one
  if not ok or require("centerpad.window").is_pad_buffer(buf) then
    vim.cmd("new")
    cur = vim.api.nvim_get_current_win()
    local new_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("buftype", "", { buf = new_buf })
    vim.api.nvim_set_option_value("filetype", "", { buf = new_buf })
    vim.api.nvim_win_set_buf(cur, new_buf)
  end

  -- Ensure winfixbuf is disabled and any stale window-local fillchars
  -- from a previous test are cleared so the source window inherits
  -- cleanly from global settings.
  pcall(vim.api.nvim_set_option_value, "winfixbuf", false, { win = cur })
  pcall(vim.api.nvim_set_option_value, "fillchars", nil, { win = cur })

  return cur
end

function M.clear_centerpad_autocmds()
  local ok, autocmds = pcall(require, "centerpad.autocmds")
  if ok and autocmds and autocmds.clear_autocmds then
    autocmds.clear_autocmds()
  end
  -- Prune any tab-specific pad groups that may have been created
  if ok and autocmds and autocmds.prune_pad_groups then
    autocmds.prune_pad_groups()
  end
end

function M.stop_restore_timers()
  local ok, state = pcall(require, "centerpad.state")
  if ok and state then
    local rt = state.get_restore_timer()
    if rt then
      pcall(vim.fn.timer_stop, rt)
      state.set_restore_timer(nil)
    end
  end
end

function M.close_extra_windows()
  local current = vim.api.nvim_get_current_win()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= current then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
end

function M.reset_centerpad_state()
  local ok, state = pcall(require, "centerpad.state")
  if ok and state and state.reset then
    state.reset()
  end
end

function M.drain_events(timeout)
  timeout = timeout or 100
  vim.wait(timeout)
end

function M.cleanup_headless_spec(timeout)
  M.ensure_normal_source_window()
  M.clear_centerpad_autocmds()
  M.stop_restore_timers()
  M.close_extra_windows()
  M.reset_centerpad_state()
  M.drain_events(timeout)
end

return M
