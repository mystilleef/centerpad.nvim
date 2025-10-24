-- State management module for centerpad
-- Centralizes all mutable state in one place

local M = {}

-- Track window IDs for proper navigation
M.pad_state = {
  main_win = nil,
  left_win = nil,
  right_win = nil,
  enabled = false,
}

-- Store original global settings to restore later
M.saved_settings = {
  fillchars = nil,
  lazyredraw = nil,
}

-- Debounce timer for WinClosed autocmd
M.restore_timer = nil

-- Debug mode flag
M.debug = false

-- Reset all state to initial values
function M.reset()
  M.pad_state = {
    main_win = nil,
    left_win = nil,
    right_win = nil,
    enabled = false,
  }
  M.saved_settings = {
    fillchars = nil,
    lazyredraw = nil,
  }
  M.restore_timer = nil
end

-- Check if pads currently exist and are valid
function M.pads_exist()
  return M.pad_state.left_win
    and vim.api.nvim_win_is_valid(M.pad_state.left_win)
    and M.pad_state.right_win
    and vim.api.nvim_win_is_valid(M.pad_state.right_win)
end

-- Validate current state and return issues
function M.validate()
  local issues = {}

  -- Check if only one pad exists (invalid state)
  local left_valid = M.pad_state.left_win
    and vim.api.nvim_win_is_valid(M.pad_state.left_win)
  local right_valid = M.pad_state.right_win
    and vim.api.nvim_win_is_valid(M.pad_state.right_win)

  if left_valid and not right_valid then
    table.insert(issues, "Right pad missing")
  elseif right_valid and not left_valid then
    table.insert(issues, "Left pad missing")
  end

  -- Check if main window is gone
  if
    M.pad_state.main_win
    and not vim.api.nvim_win_is_valid(M.pad_state.main_win)
  then
    table.insert(issues, "Main window invalid")
  end

  -- Check if enabled flag matches actual state
  if M.pad_state.enabled and not M.pads_exist() then
    table.insert(issues, "Enabled flag set but pads don't exist")
  elseif not M.pad_state.enabled and M.pads_exist() then
    table.insert(issues, "Pads exist but enabled flag not set")
  end

  return #issues == 0, issues
end

-- Log error if debug mode is enabled
function M.log_error(context, err)
  if M.debug then
    vim.notify(
      "Centerpad [" .. context .. "]: " .. tostring(err),
      vim.log.levels.WARN
    )
  end
end

-- Log info if debug mode is enabled
function M.log_info(context, msg)
  if M.debug then
    vim.notify(
      "Centerpad [" .. context .. "]: " .. tostring(msg),
      vim.log.levels.INFO
    )
  end
end

return M
