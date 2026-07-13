local M = {}

function M.get_current_tab()
  return pcall(vim.api.nvim_get_current_tabpage)
end

function M.is_tab_valid(tab)
  local ok, valid = pcall(vim.api.nvim_tabpage_is_valid, tab)
  return ok and valid
end

local tab_stores = {}

local function new_store()
  return {
    pad_state = {
      main_win = nil,
      left_win = nil,
      right_win = nil,
      enabled = false,
    },
    -- Context tracker: per-tab opt-in, config snapshot, and timers
    tracker = {
      opted_in = false,
      config = nil,
      suspended = false,
      debounce_timer = nil,
    },
    -- Captured at enable time so recovery and resume use stable
    -- widths even after shared-config mutation.
    config_snapshot = {
      leftpad = nil,
      rightpad = nil,
      ignore_filetypes = nil,
      ignore_buftypes = nil,
    },
    -- Per-tab restore debounce timer for WinClosed recovery
    restore_timer = nil,
    -- Captured before Centerpad override so cleanup can return
    -- the source window to its pre-enable local state.
    source_options = {
      win = nil,
      fillchars = nil,
    },
  }
end

local function get_store()
  local tab = vim.api.nvim_get_current_tabpage()
  if not tab_stores[tab] then
    tab_stores[tab] = new_store()
  end
  return tab_stores[tab]
end

local function prune_invalid_tabs()
  for tab, _ in pairs(tab_stores) do
    if not M.is_tab_valid(tab) then
      tab_stores[tab] = nil
    end
  end
end

local function get_tab_field(tab, field)
  if not tab_stores[tab] then
    return nil
  end
  return tab_stores[tab][field]
end

local function make_proxy(get_key)
  return setmetatable({}, {
    __index = function(_, field)
      prune_invalid_tabs()
      return get_store()[get_key][field]
    end,
    __newindex = function(_, field, value)
      prune_invalid_tabs()
      get_store()[get_key][field] = value
    end,
  })
end

M.pad_state = make_proxy("pad_state")
M.tracker = make_proxy("tracker")
M.config_snapshot = make_proxy("config_snapshot")
M.source_options = make_proxy("source_options")

M.debug = false

function M._tab_store_count()
  local count = 0
  for _ in pairs(tab_stores) do
    count = count + 1
  end
  return count
end

function M._tab_store_keys()
  local keys = {}
  for tab, _ in pairs(tab_stores) do
    table.insert(keys, tab)
  end
  return keys
end

function M._has_store(tab)
  return tab_stores[tab] ~= nil
end

function M._get_pad_state(tab)
  if not tab_stores[tab] then
    return nil
  end
  local ps = tab_stores[tab].pad_state
  return {
    left_win = ps.left_win,
    right_win = ps.right_win,
    main_win = ps.main_win,
    enabled = ps.enabled,
  }
end

function M._clear_pad_state(tab)
  if not tab_stores[tab] then
    return
  end
  local ps = tab_stores[tab].pad_state
  ps.left_win = nil
  ps.right_win = nil
end

function M.get_restore_timer()
  return get_store().restore_timer
end

function M.set_restore_timer(id)
  get_store().restore_timer = id
end

-- Safely stop a timer and return its id, or nil if none existed.
-- Callers clear the reference after this returns.
function M.stop_timer(timer_id)
  if timer_id then
    pcall(vim.fn.timer_stop, timer_id)
  end
  return timer_id
end

-- Direct tab-scoped accessors for owner-aware teardown. These bypass the
-- current-tab proxy so cleanup can target a captured tab even after Neovim
-- switches to a surviving sibling.
function M._tracker_store(tab)
  return get_tab_field(tab, "tracker")
end

function M._restore_timer(tab)
  return get_tab_field(tab, "restore_timer")
end

function M._set_restore_timer(tab, id)
  if tab_stores[tab] then
    tab_stores[tab].restore_timer = id
  end
end

function M._source_options(tab)
  return get_tab_field(tab, "source_options")
end

-- Does not clear stores for other tabpages.
function M.reset()
  local tab = vim.api.nvim_get_current_tabpage()
  tab_stores[tab] = nil
end

function M.pads_exist()
  return M.pad_state.left_win
    and vim.api.nvim_win_is_valid(M.pad_state.left_win)
    and M.pad_state.right_win
    and vim.api.nvim_win_is_valid(M.pad_state.right_win)
end

function M.validate()
  local issues = {}

  local left_valid = M.pad_state.left_win
    and vim.api.nvim_win_is_valid(M.pad_state.left_win)
  local right_valid = M.pad_state.right_win
    and vim.api.nvim_win_is_valid(M.pad_state.right_win)

  if left_valid and not right_valid then
    table.insert(issues, "Right pad missing")
  elseif right_valid and not left_valid then
    table.insert(issues, "Left pad missing")
  end

  if
    M.pad_state.main_win
    and not vim.api.nvim_win_is_valid(M.pad_state.main_win)
  then
    table.insert(issues, "Main window invalid")
  end

  if M.pad_state.enabled and not M.pads_exist() then
    table.insert(issues, "Enabled flag set but pads don't exist")
  elseif not M.pad_state.enabled and M.pads_exist() then
    table.insert(issues, "Pads exist but enabled flag not set")
  end

  return #issues == 0, issues
end

function M.log_error(context, err)
  if M.debug then
    vim.notify(
      "Centerpad [" .. context .. "]: " .. tostring(err),
      vim.log.levels.WARN
    )
  end
end

function M.log_info(context, msg)
  if M.debug then
    vim.notify(
      "Centerpad [" .. context .. "]: " .. tostring(msg),
      vim.log.levels.INFO
    )
  end
end

return M
