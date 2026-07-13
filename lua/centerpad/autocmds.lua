local state = require("centerpad.state")
local window = require("centerpad.window")
local enabled = require("centerpad.enabled")

local M = {}

-- Each tab gets its own augroup so cleanup on one tab cannot destroy
-- another tab's pad callbacks.
local pad_groups = {}

-- Per-tab ownership registry for context-tracking BufEnter/WinEnter
-- callbacks. Stored separately from the shared centerpad_tracker so owner
-- replacement and closed-tab pruning never touch the TabEnter bridge.
local tracker_callbacks = {}

local function delete_owner_callbacks(tab)
  local ids = tracker_callbacks[tab]
  if not ids then
    return
  end
  for _, id in ipairs(ids) do
    pcall(vim.api.nvim_del_autocmd, id)
  end
  tracker_callbacks[tab] = nil
end

function M.get_padgroup(tab)
  local target = tab
  if not target then
    local ok, t = state.get_current_tab()
    if not ok then
      return nil
    end
    target = t
  end
  if not pad_groups[target] then
    pad_groups[target] =
      vim.api.nvim_create_augroup("centerpad_pad_" .. target, { clear = true })
  end
  return pad_groups[target]
end

-- Survives cleanup so context tracking continues across disable/enable.
M.centerpad_tracker =
  vim.api.nvim_create_augroup("centerpad_tracker", { clear = true })

-- Keep the public enabled-state bridge tab-correct. pad_state.enabled is
-- tab-scoped, but vim.g.centerpad_enabled/center_buf_enabled are single
-- shared globals. Without this, switching tabs leaves the globals
-- reflecting whichever tab last called enabled.set(), not the tab
-- currently being viewed — including tabs that never enabled centerpad
-- at all. TabEnter fires after the switch completes, so the proxy read
-- below always resolves to the tab actually being entered.
vim.api.nvim_create_autocmd("TabEnter", {
  group = M.centerpad_tracker,
  callback = function()
    enabled.set(state.pad_state.enabled)
    M.prune_tracker_callbacks()
    M.repair_pad_widths()
  end,
})

vim.api.nvim_create_autocmd("TabClosed", {
  group = M.centerpad_tracker,
  callback = function()
    M.prune_tracker_callbacks()
    M.prune_pad_groups()
  end,
})

-- Returns true when owner_tab is nil (no owner captured) or when it
-- is the current valid tabpage.
local function validate_owner_tab(owner_tab)
  if not owner_tab then
    return true
  end
  local cur_ok, cur_tab = state.get_current_tab()
  return cur_ok and cur_tab == owner_tab
end

local function is_closed_window_on_owner_tab(args, owner_tab)
  if not owner_tab then
    return true
  end
  local closed_win = tonumber(args.match)
  if closed_win then
    return window.is_window_on_tab(closed_win, owner_tab)
  end
  return true
end

-- Captures the affected tabpage so the scheduled enable runs in the
-- correct tab context even when a different tab is active.
local function recover_pads(config, enable_callback)
  local recovery_tab_ok, recovery_tab = state.get_current_tab()
  state.log_info("restore_pads_autocmd", "Pad state unsafe, recovering")
  M.full_reset()
  vim.schedule(function()
    local prev_tab_ok, prev_tab = state.get_current_tab()
    if recovery_tab_ok then
      if
        not state.is_tab_valid(recovery_tab)
        or not pcall(vim.api.nvim_set_current_tabpage, recovery_tab)
      then
        return
      end
    end
    enable_callback(config)
    if prev_tab_ok and state.is_tab_valid(prev_tab) then
      pcall(vim.api.nvim_set_current_tabpage, prev_tab)
    end
  end)
end

-- Returns true if pads are stable, false if recovery was triggered.
local function attempt_recovery(config, enable_callback)
  state.set_restore_timer(nil)

  if not state.pad_state.enabled then
    return true
  end

  -- Refresh main window from current source.
  local cur = vim.api.nvim_get_current_win()
  if
    not window.is_source_window(cur)
    or not window.are_pads_valid()
    or window.get_pad_width(state.pad_state.left_win) ~= config.leftpad
    or window.get_pad_width(state.pad_state.right_win) ~= config.rightpad
  then
    recover_pads(config, enable_callback)
    return false
  end

  -- Atomic swap: retire old source fillchars before capturing the new
  -- one so a crash mid-swap never leaves two windows with pad fillchars.
  local old_main = state.pad_state.main_win
  if cur ~= old_main then
    window.restore_source_fillchars(old_main)

    if not window.apply_source_fillchars(cur) then
      state.log_error(
        "restore_pads_autocmd",
        "Failed to apply fillchars to replacement source"
      )
      recover_pads(config, enable_callback)
      return false
    end

    state.pad_state.main_win = cur
  end

  state.log_info("restore_pads_autocmd", "Pads stable")
  return true
end

function M.setup_prevent_focus_autocmd(buffer)
  vim.api.nvim_create_autocmd("BufEnter", {
    buffer = buffer,
    group = M.get_padgroup(),
    callback = function(args)
      local win = vim.fn.bufwinid(args.buf)
      if win ~= -1 then
        pcall(
          vim.api.nvim_set_option_value,
          "statusline",
          window.NORMAL_HIGHLIGHT,
          { win = win }
        )
        pcall(
          vim.api.nvim_set_option_value,
          "winbar",
          window.NORMAL_HIGHLIGHT,
          { win = win }
        )
      end

      if
        state.pad_state.main_win
        and vim.api.nvim_win_is_valid(state.pad_state.main_win)
      then
        pcall(vim.api.nvim_set_current_win, state.pad_state.main_win)
      end
    end,
  })
end

function M.setup_restore_pads_autocmd(config, enable_callback)
  local owner_tab_ok, owner_tab = state.get_current_tab()
  local owner_tab_handle = owner_tab_ok and owner_tab or nil

  vim.api.nvim_create_autocmd({ "WinClosed" }, {
    group = M.get_padgroup(),
    callback = function(args)
      if not validate_owner_tab(owner_tab_handle) then
        return
      end

      local bufnr = args.buf
      if not state.pad_state.enabled then
        return
      end

      if window.is_pad_buffer(bufnr) then
        if not is_closed_window_on_owner_tab(args, owner_tab_handle) then
          return
        end
        state.log_info("restore_pads_autocmd", "Pad buffer closed")
        recover_pads(config, enable_callback)
        return
      end

      local ok, buftype =
        pcall(vim.api.nvim_get_option_value, "buftype", { buf = bufnr })
      if not ok or vim.tbl_contains(config.ignore_buftypes, buftype) then
        return
      end

      local ft_ok, filetype =
        pcall(vim.api.nvim_get_option_value, "filetype", { buf = bufnr })
      if not ft_ok or vim.tbl_contains(config.ignore_filetypes, filetype) then
        return
      end

      if not is_closed_window_on_owner_tab(args, owner_tab_handle) then
        return
      end

      state.log_info("restore_pads_autocmd", "WinClosed event triggered")

      state.stop_timer(state.get_restore_timer())
      state.set_restore_timer(nil)

      local timer_id = vim.fn.timer_start(50, function()
        local prev_tab = vim.api.nvim_get_current_tabpage()
        local prev_win = vim.api.nvim_get_current_win()
        local switched = false
        if owner_tab_handle then
          if not state.is_tab_valid(owner_tab_handle) then
            return
          end
          if not pcall(vim.api.nvim_set_current_tabpage, owner_tab_handle) then
            return
          end
          switched = true
        end

        local timer_ok, timer_err = pcall(function()
          attempt_recovery(config, enable_callback)
        end)

        if switched and state.is_tab_valid(prev_tab) then
          pcall(vim.api.nvim_set_current_tabpage, prev_tab)
          if prev_win and vim.api.nvim_win_is_valid(prev_win) then
            pcall(vim.api.nvim_set_current_win, prev_win)
          end
        end

        if not timer_ok then
          state.log_error("restore_pads_autocmd", timer_err)
        end
      end)
      state.set_restore_timer(timer_id)
    end,
  })
end

function M.prune_tracker_callbacks()
  for tab, _ in pairs(tracker_callbacks) do
    if not state.is_tab_valid(tab) then
      delete_owner_callbacks(tab)
    end
  end
end

function M.prune_pad_groups()
  for tab, grp in pairs(pad_groups) do
    if not state.is_tab_valid(tab) then
      pcall(vim.api.nvim_clear_autocmds, { group = grp })
      pad_groups[tab] = nil
    end
  end
end

-- Neovim's tab-entry layout recalculation can shrink a winfixwidth pad in
-- a tab that was never touched while backgrounded. Detect and correct
-- that drift for the tab just entered; structural breaks (missing pads,
-- invalid main_win) are left to the WinClosed recovery path.
function M.repair_pad_widths()
  if not state.pad_state.enabled then
    return
  end
  if not window.are_pads_valid() then
    return
  end
  if
    not state.pad_state.main_win
    or not vim.api.nvim_win_is_valid(state.pad_state.main_win)
  then
    return
  end

  local snap = state.config_snapshot
  if not snap.leftpad or not snap.rightpad then
    return
  end

  local left_width = window.get_pad_width(state.pad_state.left_win)
  local right_width = window.get_pad_width(state.pad_state.right_win)
  if left_width == snap.leftpad and right_width == snap.rightpad then
    return
  end

  window.resize_pad(state.pad_state.left_win, snap.leftpad)
  window.resize_pad(state.pad_state.right_win, snap.rightpad)
end

-- Clears only the specified tab's pad group (not the tracker group).
-- When no tab is given, the current tab is used.
function M.clear_autocmds(tab)
  local grp = M.get_padgroup(tab)
  if grp then
    vim.api.nvim_clear_autocmds({ group = grp })
  end
  state.log_info("clear_autocmds", "Cleared pad lifecycle autocmds")
end

-- Validates whether the current buffer/window context is eligible for
-- centerpad tracking (not ignored filetype/buftype, not floating, not
-- a pad buffer).
local function is_valid_context(config)
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()

  if window.is_buffer_ignored(buf, config) then
    return false
  end

  if window.is_floating(win) then
    return false
  end

  local buf_ok, current_buf = pcall(vim.api.nvim_win_get_buf, win)
  if buf_ok and window.is_pad_buffer(current_buf) then
    return false
  end

  return true
end

-- Returns "resume", "suspend", or nil based on context validity and
-- current tracker/pad state.  Pure decision — no side effects.
local function decide_tracker_action(tracker, config)
  local valid = is_valid_context(config)
  if
    valid
    and tracker.suspended
    and tracker.config
    and not state.pad_state.enabled
    and not state.pads_exist()
  then
    return "resume"
  elseif
    not valid
    and not tracker.suspended
    and state.pad_state.enabled
    and state.pads_exist()
  then
    return "suspend"
  end
  return nil
end

-- Suspends or resumes pads based on the current context validity.
-- Guards on owner_tab before any mutation.
local function update_tracker_pads(
  tracker,
  config,
  owner_tab,
  suspend_callback,
  enable_callback
)
  local action = decide_tracker_action(tracker, config)
  if not action then
    return
  end

  if not validate_owner_tab(owner_tab) then
    return
  end

  if action == "resume" then
    state.log_info("buffer_tracker", "Context valid, resuming pads")
    tracker.suspended = false
    if enable_callback then
      enable_callback(tracker.config)
    end
  else
    state.log_info("buffer_tracker", "Context invalid, suspending pads")
    tracker.suspended = true
    if suspend_callback then
      suspend_callback()
    end
  end
end

function M.setup_buffer_tracker(config, suspend_callback, enable_callback)
  local owner_tab = vim.api.nvim_get_current_tabpage()

  -- Replace any prior owner callbacks so repeated setup/enable/resume
  -- never accumulates BufEnter/WinEnter registrations.
  delete_owner_callbacks(owner_tab)

  -- Cancel any pending owner debounce timer from a previous callback
  -- closure; the new closure will start its own timer if needed.
  state.stop_timer(state.tracker.debounce_timer)

  state.tracker.opted_in = true
  local snap = state.config_snapshot
  state.tracker.config = {
    leftpad = snap.leftpad,
    rightpad = snap.rightpad,
    ignore_filetypes = snap.ignore_filetypes,
    ignore_buftypes = snap.ignore_buftypes,
  }
  state.tracker.suspended = false
  state.tracker.debounce_timer = nil

  local function check_context()
    if not validate_owner_tab(owner_tab) then
      return
    end

    -- Operate on the captured owner's tracker store directly so a tab
    -- switch caused by another callback cannot redirect timer stops or
    -- timer assignments into a sibling tab.
    local tracker = state._tracker_store(owner_tab)
    if not tracker then
      return
    end

    state.stop_timer(tracker.debounce_timer)
    tracker.debounce_timer = nil

    tracker.debounce_timer = vim.fn.timer_start(50, function()
      -- The fired timer no longer owns a pending slot; clear it on the
      -- owner's store directly before any validation so a stale callback
      -- cannot write into a sibling's proxy.
      local fired_tracker = state._tracker_store(owner_tab)
      if fired_tracker then
        fired_tracker.debounce_timer = nil
      end

      if not validate_owner_tab(owner_tab) then
        return
      end

      local live_tracker = state._tracker_store(owner_tab)
      if not live_tracker or not live_tracker.opted_in then
        return
      end

      update_tracker_pads(
        live_tracker,
        config,
        owner_tab,
        suspend_callback,
        enable_callback
      )
    end)
  end

  local bufenter_id = vim.api.nvim_create_autocmd("BufEnter", {
    group = M.centerpad_tracker,
    callback = check_context,
  })

  local winenter_id = vim.api.nvim_create_autocmd("WinEnter", {
    group = M.centerpad_tracker,
    callback = check_context,
  })

  tracker_callbacks[owner_tab] = { bufenter_id, winenter_id }
end

-- Removes the specified tab's owned BufEnter/WinEnter callbacks and
-- stops its pending debounce timer. The shared centerpad_tracker and its
-- TabEnter bridge are intentionally preserved for sibling tabs.
function M.clear_tracker(owner_tab)
  owner_tab = owner_tab or vim.api.nvim_get_current_tabpage()

  -- Stop pending tracker debounce timer for the owner tab directly so a
  -- tab switch caused by pad deletion cannot redirect the stop into a
  -- sibling's timer.
  local tracker = state._tracker_store(owner_tab)
  if tracker and tracker.debounce_timer then
    pcall(vim.fn.timer_stop, tracker.debounce_timer)
    tracker.debounce_timer = nil
  end

  delete_owner_callbacks(owner_tab)

  if tracker then
    tracker.opted_in = false
    tracker.config = nil
    tracker.suspended = false
  end
  state.log_info("clear_tracker", "Cleared tracker state")
end

function M.cleanup(owner_tab)
  -- Guard: if the last window is a pad and buffer-deletion closes it,
  -- Neovim closes the tabpage and the current tab switches.  Subsequent
  -- state writes through the proxy would corrupt the sibling tab.
  local owner_ok, captured_owner_tab = state.get_current_tab()
  local owner = owner_tab or (owner_ok and captured_owner_tab or nil)

  -- Resolve the captured source window from owner metadata before
  -- destructive pad deletion can redirect the current tab or prune the
  -- owner store.  Restoration uses this captured identity rather than the
  -- mutable main_win so recovery never rewrites a replacement source.
  local source_opts = owner and state._source_options(owner) or nil
  local captured_source_win = source_opts and source_opts.win or nil

  -- Stop the owner's restore timer directly; never resolve through a
  -- post-switch current-tab proxy.
  state.stop_timer(state._restore_timer(owner))
  state._set_restore_timer(owner, nil)

  M.clear_autocmds(owner)
  local ps = state._get_pad_state(owner)
  window.delete_pads(owner, ps and ps.left_win, ps and ps.right_win)

  -- Gate every post-deletion effect on owner validity plus identity.
  local tab_alive = true
  if owner then
    local cur_ok, cur_tab = state.get_current_tab()
    tab_alive = cur_ok and cur_tab == owner and state.is_tab_valid(owner)
  end

  if tab_alive then
    if captured_source_win then
      window.restore_source_fillchars(captured_source_win)
    end
    enabled.set(false)
  end

  -- Always discard stale owner capture metadata after cleanup.
  if source_opts then
    source_opts.win = nil
    source_opts.fillchars = nil
  end

  state.log_info("cleanup", "Cleanup complete")
end

function M.full_reset()
  -- Capture the owner before any destructive operation can close its tab
  -- and cause subsequent teardown to resolve through a sibling proxy.
  local owner_ok, owner_tab = state.get_current_tab()
  local owner = owner_ok and owner_tab or nil

  -- Clear tracker state (callbacks, debounce timer, opt-in, config,
  -- suspension) for the owner *before* pad deletion can close the tab.
  if owner then
    M.clear_tracker(owner)
  end

  M.cleanup(owner)
end

return M
