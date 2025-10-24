-- Main coordinator module for centerpad
-- Orchestrates state, window, and autocmd modules

local state = require("centerpad.state")
local window = require("centerpad.window")
local autocmds = require("centerpad.autocmds")

local M = {}

-- Check if centerpad should be enabled for current buffer
function M.should_enable(config)
  local filetype_ignored =
    vim.tbl_contains(config.ignore_filetypes, vim.bo.filetype)
  local buftype_ignored =
    vim.tbl_contains(config.ignore_buftypes, vim.bo.buftype)
  return not filetype_ignored and not buftype_ignored
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

  -- Track main window ID for navigation
  state.pad_state.main_win = main_win

  -- Create pads and track their window IDs
  state.pad_state.left_win =
    window.create_pad_window("leftpad", "left", config.leftpad)
  window.set_current_window(main_win)
  state.pad_state.right_win =
    window.create_pad_window("rightpad", "right", config.rightpad)
  window.set_current_window(main_win)

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

  state.pad_state.enabled = true
  vim.g.center_buf_enabled = true

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

-- Run command with optional arguments
function M.run(config, command_opts)
  local args = command_opts.fargs

  if #args == 1 then
    local width = tonumber(args[1])
    if not width or width < 1 or width > 500 then
      vim.notify(
        "Centerpad: Invalid width '" .. args[1] .. "'. Must be between 1-500.",
        vim.log.levels.ERROR
      )
      return
    end
    config.leftpad = width
    config.rightpad = width
    M.enable(config)
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
    config.leftpad = left_width
    config.rightpad = right_width
    M.enable(config)
  else
    M.toggle(config)
  end
end

-- Enable debug mode
function M.set_debug(enabled)
  state.debug = enabled
  if enabled then
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
