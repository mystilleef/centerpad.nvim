-- Main coordinator module for centerpad
-- Orchestrates state, window, and autocmd modules

local state = require("centerpad.state")
local window = require("centerpad.window")
local autocmds = require("centerpad.autocmds")
local enabled = require("centerpad.enabled")

local M = {}

-- Check if centerpad should be enabled for current buffer/window
function M.should_enable(config)
  local filetype_ignored =
    vim.tbl_contains(config.ignore_filetypes, vim.bo.filetype)
  local buftype_ignored =
    vim.tbl_contains(config.ignore_buftypes, vim.bo.buftype)

  local cur_win = vim.api.nvim_get_current_win()
  local cfg_ok, cfg = pcall(vim.api.nvim_win_get_config, cur_win)
  local floating = cfg_ok and cfg.relative and cfg.relative ~= ""

  return not filetype_ignored and not buftype_ignored and not floating
end

-- Validate state and recover if needed
local function validate_and_recover()
  local valid, issues = state.validate()
  if not valid then
    state.log_error("validate", table.concat(issues, ", "))
    vim.notify(
      "Centerpad: State validation failed. Attempting recovery...",
      vim.log.levels.WARN
    )
    M.disable()
    return false
  end
  return true
end

-- Create and configure pad windows
local function add_pads(config)
  local main_win = vim.api.nvim_get_current_win()

  autocmds.clear_autocmds()
  window.delete_pads()

  -- Save original settings before modifying
  window.save_global_settings()

  -- Ensure the main window is free of leaked pad-local options before
  -- building the layout, so recovery from a pad-as-last-window situation
  -- does not leave winfixwidth/winfixbuf on the new source window.
  pcall(vim.api.nvim_set_option_value, "winfixwidth", false, { win = main_win })
  pcall(vim.api.nvim_set_option_value, "winfixbuf", false, { win = main_win })

  -- Track main window ID for navigation
  state.pad_state.main_win = main_win

  -- Create pads and track their window IDs
  state.pad_state.left_win =
    window.create_pad_window("leftpad", "left", config.leftpad)
  window.set_current_window(main_win)
  state.pad_state.right_win =
    window.create_pad_window("rightpad", "right", config.rightpad)
  window.set_current_window(main_win)

  -- Partial pad creation is invalid; clean up any orphan and stay disabled.
  if not state.pad_state.left_win or not state.pad_state.right_win then
    state.log_error("add_pads", "Failed to create both pad windows")
    vim.notify(
      "Centerpad: Failed to create pad windows. Cleaning up...",
      vim.log.levels.ERROR
    )
    M.disable()
    state.pad_state.main_win = nil
    return
  end

  -- Setup autocmds for both pads
  if state.pad_state.left_win then
    autocmds.setup_prevent_focus_autocmd(
      vim.api.nvim_win_get_buf(state.pad_state.left_win),
      "left"
    )
  end

  if state.pad_state.right_win then
    autocmds.setup_prevent_focus_autocmd(
      vim.api.nvim_win_get_buf(state.pad_state.right_win),
      "right"
    )
  end

  -- Setup restore autocmd
  autocmds.setup_restore_pads_autocmd(config, M.enable)

  -- Modify fillchars for clean appearance
  vim.opt.fillchars:append({ vert = " " })

  enabled.set(true)

  state.log_info("add_pads", "Pads added successfully")

  -- Validate state after creation
  vim.schedule(function()
    validate_and_recover()
  end)
end

-- Enable centerpad
function M.enable(config)
  state.log_info("enable", "Attempting to enable centerpad")

  if M.should_enable(config) then
    M.disable()
    add_pads(config)
  else
    state.log_info("enable", "Skipping enable due to ignored filetype/buftype")
  end
end

-- Disable centerpad
function M.disable()
  state.log_info("disable", "Disabling centerpad")
  autocmds.cleanup()
end

-- Toggle centerpad on/off
function M.toggle(config)
  if state.pad_state.enabled then
    state.log_info("toggle", "Toggling off")
    M.disable()
  else
    state.log_info("toggle", "Toggling on")
    M.enable(config or { leftpad = 25, rightpad = 25 })
  end
end

-- Resize existing pads in place when they are healthy
local function resize_pads(config)
  if not window.are_pads_valid() then
    return false
  end
  if
    not state.pad_state.main_win
    or not vim.api.nvim_win_is_valid(state.pad_state.main_win)
  then
    return false
  end

  window.set_current_window(state.pad_state.main_win)

  local left_ok = window.resize_pad(state.pad_state.left_win, config.leftpad)
  local right_ok = window.resize_pad(state.pad_state.right_win, config.rightpad)

  window.set_current_window(state.pad_state.main_win)

  return left_ok and right_ok
end

-- Resize pads in place if possible; otherwise recreate them
local function try_resize_or_enable(config)
  if state.pad_state.enabled and window.are_pads_valid() then
    if resize_pads(config) then
      state.log_info("try_resize_or_enable", "Resized pads in place")
      return
    end
    state.log_info("try_resize_or_enable", "In-place resize failed, recreating")
  end
  M.enable(config)
end

-- Run command with optional arguments
function M.run(config, command_opts)
  local args = command_opts.fargs

  if #args == 0 then
    M.toggle(config)
  elseif #args == 1 then
    local width = tonumber(args[1])
    if not width or width < 1 or width > 500 then
      vim.notify(
        "Centerpad: Invalid width '" .. args[1] .. "'. Must be between 1-500.",
        vim.log.levels.ERROR
      )
      return
    end
    if not M.should_enable(config) then
      return
    end
    config.leftpad = width
    config.rightpad = width
    try_resize_or_enable(config)
  elseif #args == 2 then
    local left_width = tonumber(args[1])
    local right_width = tonumber(args[2])
    if not left_width or left_width < 1 or left_width > 500 then
      vim.notify(
        "Centerpad: Invalid left width '"
          .. args[1]
          .. "'. Must be between 1-500.",
        vim.log.levels.ERROR
      )
      return
    end
    if not right_width or right_width < 1 or right_width > 500 then
      vim.notify(
        "Centerpad: Invalid right width '"
          .. args[2]
          .. "'. Must be between 1-500.",
        vim.log.levels.ERROR
      )
      return
    end
    if not M.should_enable(config) then
      return
    end
    config.leftpad = left_width
    config.rightpad = right_width
    try_resize_or_enable(config)
  else
    vim.notify(
      "Centerpad: Invalid arguments. Use :Centerpad, :Centerpad <width>, or :Centerpad <left> <right>.",
      vim.log.levels.ERROR
    )
    return
  end
end

-- Enable debug mode
function M.set_debug(debug_enabled)
  state.debug = debug_enabled
  if debug_enabled then
    vim.notify("Centerpad: Debug mode enabled", vim.log.levels.INFO)
  end
end

-- Get current state (for debugging/health checks)
function M.get_state()
  return {
    pad_state = state.pad_state,
    saved_settings = state.saved_settings,
    restore_timer = state.restore_timer,
    pads_exist = state.pads_exist(),
    validation = { state.validate() },
  }
end

-- Validate current state
function M.validate_state()
  return state.validate()
end

return M
