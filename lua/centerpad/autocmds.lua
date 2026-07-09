-- Autocmd management module for centerpad
-- Handles all autocmd setup, cleanup, and callbacks

local state = require("centerpad.state")
local window = require("centerpad.window")
local enabled = require("centerpad.enabled")

local M = {}

-- Autocmd group for centerpad
M.padgroup = vim.api.nvim_create_augroup("padgroup", { clear = true })

-- Returns true for a normal, non-floating, non-pad window
local function is_source_window(win)
  if not vim.api.nvim_win_is_valid(win) then
    return false
  end

  local cfg_ok, cfg = pcall(vim.api.nvim_win_get_config, win)
  if not cfg_ok then
    return false
  end
  if cfg.relative and cfg.relative ~= "" then
    return false
  end

  local buf_ok, buf = pcall(vim.api.nvim_win_get_buf, win)
  if not buf_ok then
    return false
  end

  return not window.is_pad_buffer(buf)
end

-- Update main_win to the current source window
local function refresh_main_win()
  local cur = vim.api.nvim_get_current_win()
  if not is_source_window(cur) then
    return false
  end
  state.pad_state.main_win = cur
  return true
end

-- Run cleanup and schedule a full re-enable for recovery
local function recover_pads(config, enable_callback)
  state.log_info("restore_pads_autocmd", "Pad state unsafe, recovering")
  M.cleanup()
  vim.schedule(function()
    enable_callback(config)
  end)
end

-- Prevent focus on pad buffers by redirecting to main window
function M.setup_prevent_focus_autocmd(buffer, _pad_side)
  vim.api.nvim_create_autocmd("BufEnter", {
    buffer = buffer,
    group = M.padgroup,
    callback = function()
      -- Try to focus main window if it's valid. When the main window is
      -- invalid (e.g. it was just closed), avoid wincmd fallbacks that can
      -- bounce between pads; the WinClosed recovery autocmd will rebuild
      -- the layout.
      if
        state.pad_state.main_win
        and vim.api.nvim_win_is_valid(state.pad_state.main_win)
      then
        pcall(vim.api.nvim_set_current_win, state.pad_state.main_win)
      end
    end,
  })
end

-- Setup autocmd to restore pads when windows are closed
function M.setup_restore_pads_autocmd(config, enable_callback)
  vim.api.nvim_create_autocmd({ "WinClosed" }, {
    group = M.padgroup,
    callback = function(args)
      local bufnr = args.buf
      if not state.pad_state.enabled then
        return
      end

      -- Detect manual/external pad closes before applying buftype filters,
      -- because pad buffers themselves have ignored buftypes such as nofile.
      if window.is_pad_buffer(bufnr) then
        -- A pad buffer closed outside of our own cleanup path (cleanup
        -- clears autocmds first). Treat this as an unsafe state and
        -- recover rather than leaving stale tracked window IDs.
        state.log_info("restore_pads_autocmd", "Pad buffer closed, recovering")
        recover_pads(config, enable_callback)
        return
      end

      -- Filter out as many buftypes and filetypes as possible
      -- This autocmd is called frequently, so performance matters
      local ok, buftype =
        pcall(vim.api.nvim_get_option_value, "buftype", { buf = bufnr })
      if not ok or vim.tbl_contains(config.ignore_buftypes, buftype) then
        -- By default, ignore any buffer that's not a writable file
        return
      end

      local ft_ok, filetype =
        pcall(vim.api.nvim_get_option_value, "filetype", { buf = bufnr })
      if not ft_ok or vim.tbl_contains(config.ignore_filetypes, filetype) then
        -- Ignore buffers that are not source code
        return
      end

      state.log_info("restore_pads_autocmd", "WinClosed event triggered")

      -- Debounce: cancel previous timer if it exists
      if state.restore_timer then
        pcall(vim.fn.timer_stop, state.restore_timer)
        state.restore_timer = nil
      end

      -- Debounced restoration after 50ms to avoid excessive re-rendering
      state.restore_timer = vim.fn.timer_start(50, function()
        state.restore_timer = nil

        if not state.pad_state.enabled then
          return
        end

        -- Refresh main_win from the current source window before trusting
        -- stale tracked state. If the current window is not a valid,
        -- non-floating, non-pad source, fall back to recovery.
        if not refresh_main_win() then
          recover_pads(config, enable_callback)
          return
        end

        if not window.are_pads_valid() then
          recover_pads(config, enable_callback)
          return
        end

        local left_width = window.get_pad_width(state.pad_state.left_win)
        local right_width = window.get_pad_width(state.pad_state.right_win)
        if
          not left_width
          or not right_width
          or left_width ~= config.leftpad
          or right_width ~= config.rightpad
        then
          recover_pads(config, enable_callback)
          return
        end

        state.log_info(
          "restore_pads_autocmd",
          "Pads stable after WinClosed, skipping rebuild"
        )
      end)
    end,
  })
end

-- Clear all autocmds
function M.clear_autocmds()
  vim.api.nvim_clear_autocmds({ group = M.padgroup })
  state.log_info("clear_autocmds", "Cleared all autocmds")
end

-- Full cleanup: clear autocmds, stop timers, delete pads, restore settings
function M.cleanup()
  -- Cancel any pending restore timer
  if state.restore_timer then
    pcall(vim.fn.timer_stop, state.restore_timer)
    state.restore_timer = nil
  end

  M.clear_autocmds()
  window.delete_pads()
  window.restore_global_settings()

  enabled.set(false)

  state.log_info("cleanup", "Cleanup complete")
end

return M
