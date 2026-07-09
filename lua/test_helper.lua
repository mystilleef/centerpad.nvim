-- Shared test helper for headless window-heavy specs
-- Provides consistent cleanup and state management for tests

local M = {}

-- Ensure current window holds a normal, non-pad source buffer
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

  -- Ensure winfixbuf is disabled
  pcall(vim.api.nvim_set_option_value, "winfixbuf", false, { win = cur })

  return cur
end

-- Clear centerpad autocmds safely
function M.clear_centerpad_autocmds()
  local ok, autocmds = pcall(require, "centerpad.autocmds")
  if ok and autocmds and autocmds.clear_autocmds then
    autocmds.clear_autocmds()
  end
end

-- Stop restore timers
function M.stop_restore_timers()
  local ok, state = pcall(require, "centerpad.state")
  if ok and state and state.restore_timer then
    pcall(vim.fn.timer_stop, state.restore_timer)
    state.restore_timer = nil
  end
end

-- Close extra windows safely (keep only current window)
function M.close_extra_windows()
  local current = vim.api.nvim_get_current_win()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= current then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
end

-- Restore modified globals/options
function M.restore_globals()
  local ok, state = pcall(require, "centerpad.state")
  if ok and state then
    -- Restore fillchars if saved
    if state.saved_settings and state.saved_settings.fillchars then
      pcall(function()
        vim.o.fillchars = state.saved_settings.fillchars
      end)
      state.saved_settings.fillchars = nil
    end
  end
end

-- Reset centerpad state
function M.reset_centerpad_state()
  local ok, state = pcall(require, "centerpad.state")
  if ok and state and state.reset then
    state.reset()
  end
end

-- Drain events through one named helper
function M.drain_events(timeout)
  timeout = timeout or 100
  vim.wait(timeout)
end

-- Full cleanup sequence for headless window-heavy specs
function M.cleanup_headless_spec(timeout)
  M.ensure_normal_source_window()
  M.clear_centerpad_autocmds()
  M.stop_restore_timers()
  M.close_extra_windows()
  M.restore_globals()
  M.reset_centerpad_state()
  M.drain_events(timeout)
end

return M
