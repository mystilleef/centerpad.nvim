local state = require("centerpad.state")

local M = {}

-- Explicit Normal highlight for global-local options (statusline,
-- winbar) where an empty string silently falls back to the global
-- value instead of producing a genuine local override.
M.NORMAL_HIGHLIGHT = "%#Normal#"

function M.is_floating(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return false
  end
  local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
  return ok and cfg.relative and cfg.relative ~= ""
end

-- Returns true when the window is a non-floating, non-pad source window.
-- Used for recovery and validation logic.
function M.is_source_window(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return false
  end
  local cfg_ok, cfg = pcall(vim.api.nvim_win_get_config, win)
  if not cfg_ok or (cfg.relative and cfg.relative ~= "") then
    return false
  end
  local buf_ok, buf = pcall(vim.api.nvim_win_get_buf, win)
  return buf_ok and not M.is_pad_buffer(buf)
end

-- Returns true when the window belongs to the specified tabpage.
function M.is_window_on_tab(win, tab)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return false
  end
  local win_tab_ok, win_tab = pcall(vim.api.nvim_win_get_tabpage, win)
  return win_tab_ok and win_tab == tab
end

function M.is_pad_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  local ok, is_pad = pcall(vim.api.nvim_buf_get_var, bufnr, "is_centerpad")
  return ok and is_pad
end

-- Returns true when the buffer's filetype or buftype appears in the
-- corresponding ignore list. Uses pcall so callers never see errors
-- from invalid or wiped buffers.
function M.is_buffer_ignored(bufnr, config)
  local ft_ok, filetype =
    pcall(vim.api.nvim_get_option_value, "filetype", { buf = bufnr })
  if
    ft_ok
    and config.ignore_filetypes
    and vim.tbl_contains(config.ignore_filetypes, filetype)
  then
    return true
  end

  local bt_ok, buftype =
    pcall(vim.api.nvim_get_option_value, "buftype", { buf = bufnr })
  if
    bt_ok
    and config.ignore_buftypes
    and vim.tbl_contains(config.ignore_buftypes, buftype)
  then
    return true
  end

  return false
end

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
-- falls back to the global value, so both use an explicit Normal
-- highlight instead to force a genuine local override that isn't
-- dependent on whatever highlight group a bare space would inherit.
local window_opts = {
  winfixwidth = true,
  winfixbuf = true,
  statusline = M.NORMAL_HIGHLIGHT,
  winbar = M.NORMAL_HIGHLIGHT,
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

local buffer_opts = {
  filetype = "centerpad",
  buftype = "nofile",
  bufhidden = "wipe",
  modifiable = false,
  readonly = true,
  buflisted = false,
  swapfile = false,
}

local function get_window_buffer(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return nil
  end
  local ok, buf = pcall(vim.api.nvim_win_get_buf, win)
  return ok and buf or nil
end

local function get_pad_buffer(win)
  local buf = get_window_buffer(win)
  if not buf or not M.is_pad_buffer(buf) then
    return nil
  end
  return buf
end

local function set_pad_options(win, buffer)
  for name, value in pairs(window_opts) do
    pcall(vim.api.nvim_set_option_value, name, value, { win = win })
  end
  for name, value in pairs(buffer_opts) do
    pcall(vim.api.nvim_set_option_value, name, value, { buf = buffer })
  end
end

local PAD_FILLCHARS = table.concat({
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

-- Border-separator keys to blank on the source window so the pad reads
-- as a seamless margin. Items a window's local "fillchars" omits fall
-- back to Neovim's hardcoded per-item default (see :h 'fillchars'), NOT
-- the user's global custom value — so these keys are merged on top of
-- the window's current effective value rather than set standalone,
-- preserving any custom fold/diff/eob symbols the user has configured.
local SOURCE_BORDER_KEYS = {
  "vert",
  "horiz",
  "horizup",
  "horizdown",
  "vertleft",
  "vertright",
  "verthoriz",
}

local function parse_fillchars(value)
  local items = {}
  if not value or value == "" then
    return items
  end
  for item in value:gmatch("[^,]+") do
    local key, char = item:match("^([^:]+):(.*)$")
    if key then
      items[key] = char
    end
  end
  return items
end

local function serialize_fillchars(items)
  local parts = {}
  for key, char in pairs(items) do
    parts[#parts + 1] = key .. ":" .. char
  end
  table.sort(parts)
  return table.concat(parts, ",")
end

-- Builds the source window's local fillchars by blanking only the
-- border-separator keys on top of `base` (the window's current
-- effective fillchars), so every other item keeps its existing value.
local function build_source_fillchars(base)
  local items = parse_fillchars(base)
  for _, key in ipairs(SOURCE_BORDER_KEYS) do
    items[key] = " "
  end
  return serialize_fillchars(items)
end

local function configure_pad(win, buffer, size)
  set_pad_options(win, buffer)

  local width_ok = pcall(vim.api.nvim_win_set_width, win, size)
  if not width_ok then
    return false
  end

  pcall(
    vim.api.nvim_set_option_value,
    "fillchars",
    PAD_FILLCHARS,
    { win = win }
  )

  return true
end

local function create_split_for_pad(buffer, position)
  return vim.api.nvim_open_win(buffer, false, {
    split = position,
    focusable = false,
    style = "minimal",
    noautocmd = true,
  })
end

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

function M.resize_pad(window, size)
  local buf = get_pad_buffer(window)
  if not buf then
    return false
  end

  return configure_pad(window, buf, size)
end

function M.get_pad_width(window)
  local buf = get_pad_buffer(window)
  if not buf then
    return nil
  end

  local width_ok, width = pcall(vim.api.nvim_win_get_width, window)
  if not width_ok then
    return nil
  end

  return width
end

local function delete_pad_buffer(win, label)
  local buf = get_window_buffer(win)
  if not buf then
    return
  end
  local ok, err = pcall(vim.api.nvim_buf_delete, buf, { force = true })
  if not ok then
    state.log_error(
      "delete_pads",
      "Failed to delete " .. label .. " pad: " .. err
    )
  end
end

function M.delete_pads(owner_tab, left_win, right_win)
  state.log_info("delete_pads", "Deleting pads")

  local tab = owner_tab or select(2, state.get_current_tab())

  -- Resolve window IDs: explicit args take priority, then tab store,
  -- then current-tab proxy as final fallback.
  local left, right
  if left_win ~= nil or right_win ~= nil then
    left, right = left_win, right_win
  else
    local ps = tab and state._get_pad_state(tab)
    if ps then
      left, right = ps.left_win, ps.right_win
    else
      left, right = state.pad_state.left_win, state.pad_state.right_win
    end
  end

  delete_pad_buffer(left, "left")
  delete_pad_buffer(right, "right")

  -- Always clear the captured owner's tracked pad IDs through direct
  -- store access; never rely on the current-tab proxy after deletion.
  if tab then
    state._clear_pad_state(tab)
  end
end

local function clear_source_options()
  state.source_options.win = nil
  state.source_options.fillchars = nil
end

function M.apply_source_fillchars(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    clear_source_options()
    return false
  end

  -- scope="local" returns "" when the window inherits from the
  -- global option; otherwise returns the explicit local value.
  local capture_ok, captured = pcall(
    vim.api.nvim_get_option_value,
    "fillchars",
    { win = win, scope = "local" }
  )
  if not capture_ok then
    state.log_error("apply_source_fillchars", captured)
    clear_source_options()
    return false
  end

  -- No scope: the value currently in effect for this window (local if
  -- already set, else the user's global custom fillchars). Used as the
  -- base so non-separator items keep whatever they already render as.
  local effective_ok, effective =
    pcall(vim.api.nvim_get_option_value, "fillchars", { win = win })
  if not effective_ok then
    state.log_error("apply_source_fillchars", effective)
    clear_source_options()
    return false
  end

  local ok, err = pcall(
    vim.api.nvim_set_option_value,
    "fillchars",
    build_source_fillchars(effective),
    { win = win }
  )
  if not ok then
    state.log_error("apply_source_fillchars", err)
    clear_source_options()
    return false
  end

  state.source_options.win = win
  state.source_options.fillchars = captured

  state.log_info("apply_source_fillchars", "Applied to source window")
  return true
end

function M.restore_source_fillchars(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    clear_source_options()
    return false
  end

  local opts = state.source_options
  if opts.win ~= win then
    -- Stale metadata for a different source window; drop it without
    -- touching the current window.
    clear_source_options()
    return false
  end

  local captured = opts.fillchars
  if captured == nil then
    clear_source_options()
    return false
  end

  -- Empty string means the window inherited fillchars from global;
  -- nil removes the Centerpad local override to resume inheritance.
  -- Non-empty values are explicit local settings, restored verbatim.
  local value = captured == "" and nil or captured
  local ok, err =
    pcall(vim.api.nvim_set_option_value, "fillchars", value, { win = win })

  clear_source_options()

  if not ok then
    state.log_error("restore_source_fillchars", err)
    return false
  end

  state.log_info("restore_source_fillchars", "Restored source window fillchars")
  return true
end

return M
