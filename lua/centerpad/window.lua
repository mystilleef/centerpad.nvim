-- Window manipulation module for centerpad
-- Pure functions for creating, configuring, and deleting pad windows

local state = require("centerpad.state")

local M = {}

-- Check if a buffer is a centerpad buffer
function M.is_pad_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  local ok, is_pad = pcall(vim.api.nvim_buf_get_var, bufnr, "is_centerpad")
  return ok and is_pad
end

-- Safely set current window
function M.set_current_window(window)
  if vim.api.nvim_win_is_valid(window) then
    local ok, err = pcall(vim.api.nvim_set_current_win, window)
    if not ok then
      state.log_error("set_current_window", err)
    end
  end
end

-- Window options to make a pad completely blank regardless of the
-- user's own global settings. statusline/winbar are global-local
-- options: an empty string locally means "no override" and silently
-- falls back to the global value, so both use a single space instead
-- to force a genuine local override.
local window_opts = {
  winfixwidth = true,
  winfixbuf = true,
  statusline = " ",
  winbar = " ",
  signcolumn = "no",
  number = false,
  relativenumber = false,
  foldcolumn = "0",
  cursorline = false,
  cursorcolumn = false,
  list = false,
  spell = false,
  colorcolumn = "",
  wrap = false,
  linebreak = false,
  conceallevel = 0,
}

-- Buffer options: unlisted, unmodifiable, wiped on hide.
local buffer_opts = {
  filetype = "centerpad",
  buftype = "nofile",
  bufhidden = "wipe",
  modifiable = false,
  readonly = true,
  buflisted = false,
  swapfile = false,
}

-- Set all required options for a pad buffer/window
local function set_pad_options(window, buffer)
  for name, value in pairs(window_opts) do
    pcall(vim.api.nvim_set_option_value, name, value, { win = window })
  end
  for name, value in pairs(buffer_opts) do
    pcall(vim.api.nvim_set_option_value, name, value, { buf = buffer })
  end
end

-- Pad-local fillchars value
local function pad_fillchars()
  return table.concat({
    "eob: ",
    "fold: ",
    "foldopen: ",
    "foldclose: ",
    "foldsep: ",
    "diff: ",
    "vert: ",
    "horiz: ",
    "horizup: ",
    "horizdown: ",
    "vertleft: ",
    "vertright: ",
    "verthoriz: ",
  }, ",")
end

-- Apply all pad window/buffer configuration except split creation
local function configure_pad(window, buffer, size)
  set_pad_options(window, buffer)

  local width_ok = pcall(vim.api.nvim_win_set_width, window, size)
  if not width_ok then
    return false
  end

  pcall(
    vim.api.nvim_set_option_value,
    "fillchars",
    pad_fillchars(),
    { win = window }
  )

  return true
end

-- Create a split window for a pad
local function create_split_for_pad(buffer, position)
  return vim.api.nvim_open_win(buffer, false, {
    split = position,
    focusable = false,
    style = "minimal",
    noautocmd = true,
  })
end

-- Create a pad window (left or right)
-- Returns window ID on success, nil on failure
function M.create_pad_window(name, position, size)
  local ok, buffer = pcall(vim.api.nvim_create_buf, false, true)
  if not ok then
    state.log_error("create_pad_window", "Failed to create buffer")
    return nil
  end

  local win_ok, window = pcall(create_split_for_pad, buffer, position)
  if not win_ok then
    state.log_error("create_pad_window", "Failed to create split")
    pcall(vim.api.nvim_buf_delete, buffer, { force = true })
    return nil
  end

  pcall(vim.api.nvim_buf_set_name, buffer, name)

  -- Mark buffer as a centerpad buffer with metadata
  pcall(vim.api.nvim_buf_set_var, buffer, "is_centerpad", true)
  pcall(vim.api.nvim_buf_set_var, buffer, "pad_side", position)

  if not configure_pad(window, buffer, size) then
    state.log_error("create_pad_window", "Failed to configure pad window")
    pcall(vim.api.nvim_win_close, window, true)
    pcall(vim.api.nvim_buf_delete, buffer, { force = true })
    return nil
  end

  state.log_info("create_pad_window", "Created " .. position .. " pad")
  return window
end

-- Check if both tracked pads are valid centerpad windows
function M.are_pads_valid()
  local left_win = state.pad_state.left_win
  local right_win = state.pad_state.right_win

  if not left_win or not right_win then
    return false
  end
  if
    not vim.api.nvim_win_is_valid(left_win)
    or not vim.api.nvim_win_is_valid(right_win)
  then
    return false
  end

  local ok_l, left_buf = pcall(vim.api.nvim_win_get_buf, left_win)
  local ok_r, right_buf = pcall(vim.api.nvim_win_get_buf, right_win)
  if not ok_l or not ok_r then
    return false
  end

  return M.is_pad_buffer(left_buf) and M.is_pad_buffer(right_buf)
end

-- Resize an existing pad window in place
function M.resize_pad(window, size)
  if not vim.api.nvim_win_is_valid(window) then
    return false
  end

  local ok, buf = pcall(vim.api.nvim_win_get_buf, window)
  if not ok or not M.is_pad_buffer(buf) then
    return false
  end

  return configure_pad(window, buf, size)
end

-- Return the width of a valid pad window, or nil otherwise
function M.get_pad_width(window)
  if not window or not vim.api.nvim_win_is_valid(window) then
    return nil
  end

  local ok, buf = pcall(vim.api.nvim_win_get_buf, window)
  if not ok or not M.is_pad_buffer(buf) then
    return nil
  end

  local width_ok, width = pcall(vim.api.nvim_win_get_width, window)
  if not width_ok then
    return nil
  end

  return width
end

-- Delete pads using tracked window IDs (efficient)
function M.delete_pads()
  state.log_info("delete_pads", "Deleting pads")

  -- Delete left pad if it exists
  if
    state.pad_state.left_win
    and vim.api.nvim_win_is_valid(state.pad_state.left_win)
  then
    local ok, bufnr = pcall(vim.api.nvim_win_get_buf, state.pad_state.left_win)
    if ok then
      local del_ok, err =
        pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
      if not del_ok then
        state.log_error("delete_pads", "Failed to delete left pad: " .. err)
      end
    end
  end

  -- Delete right pad if it exists
  if
    state.pad_state.right_win
    and vim.api.nvim_win_is_valid(state.pad_state.right_win)
  then
    local ok, bufnr = pcall(vim.api.nvim_win_get_buf, state.pad_state.right_win)
    if ok then
      local del_ok, err =
        pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
      if not del_ok then
        state.log_error("delete_pads", "Failed to delete right pad: " .. err)
      end
    end
  end

  -- Clear tracked window IDs
  state.pad_state.left_win = nil
  state.pad_state.right_win = nil
end

-- Save global settings before modification
function M.save_global_settings()
  if not state.saved_settings.fillchars then
    state.saved_settings.fillchars = vim.o.fillchars
    state.log_info("save_settings", "Saved fillchars")
  end
end

-- Restore global settings
function M.restore_global_settings()
  -- Restore fillchars
  if state.saved_settings.fillchars ~= nil then
    pcall(function()
      vim.o.fillchars = state.saved_settings.fillchars
    end)
    state.saved_settings.fillchars = nil
    state.log_info("restore_settings", "Restored fillchars")
  end
end

return M
