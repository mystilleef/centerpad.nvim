local state = require("centerpad.state")
local window = require("centerpad.window")
local autocmds = require("centerpad.autocmds")
local enabled = require("centerpad.enabled")

local M = {}

function M.should_enable(config)
  local buf = vim.api.nvim_get_current_buf()
  local cur_win = vim.api.nvim_get_current_win()

  return not window.is_buffer_ignored(buf, config)
    and not window.is_floating(cur_win)
end

local DEFAULT_PAD_WIDTH = 25
local MIN_WIDTH = 1
local MAX_WIDTH = 500

local function normalize_config(config)
  config = config or {}
  config.leftpad = config.leftpad or DEFAULT_PAD_WIDTH
  config.rightpad = config.rightpad or DEFAULT_PAD_WIDTH
  config.ignore_filetypes = config.ignore_filetypes or {}
  config.ignore_buftypes = config.ignore_buftypes or {}
  return config
end

-- Log error, notify user, and clean up after a failed enable.
local function abort_enable(context, message)
  state.log_error(context, message)
  vim.notify(
    "Centerpad: " .. message .. " Cleaning up...",
    vim.log.levels.ERROR
  )
  M.disable()
  state.pad_state.main_win = nil
end

local function copy_config_to(target, config)
  target.leftpad = config.leftpad
  target.rightpad = config.rightpad
  target.ignore_filetypes = config.ignore_filetypes
  target.ignore_buftypes = config.ignore_buftypes
end

local function commit_snapshot(config)
  copy_config_to(state.config_snapshot, config)
end

local function schedule_post_enable_validation()
  local owner_tab_ok, owner_tab = state.get_current_tab()
  if not owner_tab_ok then
    return
  end

  vim.schedule(function()
    if not state.is_tab_valid(owner_tab) then
      return
    end

    local prev_tab_ok, prev_tab = state.get_current_tab()
    local prev_win = vim.api.nvim_get_current_win()

    if not pcall(vim.api.nvim_set_current_tabpage, owner_tab) then
      return
    end

    local valid, issues = state.validate()
    if not valid then
      state.log_error("validate", table.concat(issues, ", "))
      vim.notify(
        "Centerpad: State validation failed. Attempting recovery...",
        vim.log.levels.WARN
      )
      M.disable()
    end

    if prev_tab_ok and state.is_tab_valid(prev_tab) then
      pcall(vim.api.nvim_set_current_tabpage, prev_tab)
      if prev_win and vim.api.nvim_win_is_valid(prev_win) then
        pcall(vim.api.nvim_set_current_win, prev_win)
      end
    end
  end)
end

local function add_pads(config)
  local main_win = vim.api.nvim_get_current_win()

  autocmds.clear_autocmds()
  window.delete_pads()

  pcall(vim.api.nvim_set_option_value, "winfixwidth", false, { win = main_win })
  pcall(vim.api.nvim_set_option_value, "winfixbuf", false, { win = main_win })

  state.pad_state.main_win = main_win

  state.pad_state.left_win =
    window.create_pad_window("leftpad", "left", config.leftpad)
  state.pad_state.right_win =
    window.create_pad_window("rightpad", "right", config.rightpad)
  window.set_current_window(main_win)

  if not state.pad_state.left_win or not state.pad_state.right_win then
    abort_enable("add_pads", "Failed to create pad windows.")
    return
  end

  commit_snapshot(config)

  autocmds.setup_prevent_focus_autocmd(
    vim.api.nvim_win_get_buf(state.pad_state.left_win)
  )

  autocmds.setup_prevent_focus_autocmd(
    vim.api.nvim_win_get_buf(state.pad_state.right_win)
  )

  autocmds.setup_restore_pads_autocmd(state.config_snapshot, M.enable)

  if not window.apply_source_fillchars(main_win) then
    abort_enable("add_pads", "Failed to apply source fillchars.")
    return
  end

  enabled.set(true)

  state.log_info("add_pads", "Pads added successfully")

  schedule_post_enable_validation()
end

local function suspend()
  state.log_info("suspend", "Suspending centerpad")
  autocmds.cleanup()
end

function M.enable(config)
  config = normalize_config(config)
  state.log_info("enable", "Attempting to enable centerpad")

  if M.should_enable(config) then
    M.disable()
    add_pads(config)

    if state.pad_state.enabled then
      autocmds.setup_buffer_tracker(config, suspend, M.enable)
    end
  else
    state.log_info("enable", "Skipping enable due to ignored filetype/buftype")
  end
end

function M.disable()
  state.log_info("disable", "Disabling centerpad")
  autocmds.full_reset()
end

function M.setup_auto_enable()
  autocmds.setup_auto_enable()
end

function M.toggle(config)
  if state.pad_state.enabled then
    state.log_info("toggle", "Toggling off")
    M.disable()
  else
    state.log_info("toggle", "Toggling on")
    M.enable(config)
  end
end

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

  return left_ok and right_ok
end

local function commit_widths(config)
  commit_snapshot(config)

  if state.tracker.opted_in and state.tracker.config then
    copy_config_to(state.tracker.config, config)
  end
end

local function try_resize_or_enable(config)
  if state.pad_state.enabled and window.are_pads_valid() then
    if resize_pads(config) then
      commit_widths(config)
      return
    end
  end
  M.enable(config)
end

local function parse_width(raw, label)
  local width = tonumber(raw)
  local valid = type(raw) == "string"
    and string.match(raw, "^%d+$")
    and width
    and width >= MIN_WIDTH
    and width <= MAX_WIDTH
  if not valid then
    local prefix = label == "" and "" or (label .. " ")
    vim.notify(
      "Centerpad: Invalid "
        .. prefix
        .. "width '"
        .. tostring(raw)
        .. "'. Must be an integer between "
        .. MIN_WIDTH
        .. "-"
        .. MAX_WIDTH
        .. ".",
      vim.log.levels.ERROR
    )
    return nil
  end
  return width
end

function M.run(config, command_opts)
  local args = command_opts.fargs

  if #args == 0 then
    M.toggle(config)
    return
  end

  local left, right
  if #args == 1 then
    local width = parse_width(args[1], "")
    if not width then
      return
    end
    left, right = width, width
  elseif #args == 2 then
    left = parse_width(args[1], "left")
    if not left then
      return
    end
    right = parse_width(args[2], "right")
    if not right then
      return
    end
  else
    vim.notify(
      "Centerpad: Invalid arguments. Use :Centerpad, :Centerpad <width>, or :Centerpad <left> <right>.",
      vim.log.levels.ERROR
    )
    return
  end

  config = normalize_config(config)

  if not M.should_enable(config) then
    return
  end
  config.leftpad = left
  config.rightpad = right
  try_resize_or_enable(config)
end

function M.set_debug(debug_enabled)
  state.debug = debug_enabled
  if debug_enabled then
    vim.notify("Centerpad: Debug mode enabled", vim.log.levels.INFO)
  end
end

function M.get_state()
  return {
    pad_state = state._get_pad_state(vim.api.nvim_get_current_tabpage())
      or { main_win = nil, left_win = nil, right_win = nil, enabled = false },
    restore_timer = state.get_restore_timer(),
    pads_exist = state.pads_exist(),
    validation = { state.validate() },
  }
end

function M.validate_state()
  return state.validate()
end

return M
