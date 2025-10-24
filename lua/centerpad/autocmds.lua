-- Autocmd management module for centerpad
-- Handles all autocmd setup, cleanup, and callbacks

local state = require("centerpad.state")
local window = require("centerpad.window")

local M = {}

-- Autocmd group for centerpad
M.padgroup = vim.api.nvim_create_augroup("padgroup", { clear = true })

-- Prevent focus on pad buffers by redirecting to main window
function M.setup_prevent_focus_autocmd(buffer, pad_side)
  vim.api.nvim_create_autocmd("BufEnter", {
    buffer = buffer,
    group = M.padgroup,
    callback = function()
      -- Try to focus main window if it's valid
      if
        state.pad_state.main_win
        and vim.api.nvim_win_is_valid(state.pad_state.main_win)
      then
        pcall(vim.api.nvim_set_current_win, state.pad_state.main_win)
      else
        -- Fallback to window navigation commands
        if pad_side == "left" then
          pcall(vim.cmd, "wincmd l")
        elseif pad_side == "right" then
          pcall(vim.cmd, "wincmd h")
        else
          pcall(vim.cmd, "wincmd p")
        end
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

      -- Filter out as many buftypes and filetypes as possible
      -- This autocmd is called frequently, so performance matters
      local ok, buftype =
        pcall(vim.api.nvim_get_option_value, "buftype", { buf = bufnr })
      if not ok or vim.tbl_contains(config.ignore_buftypes, buftype) then
        -- By default, ignore any buffer that's not a writable file
        return
      end

      if window.is_pad_buffer(bufnr) then
        -- Ignore centerpad buffers
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

      -- Save lazyredraw state before modifying
      if state.saved_settings.lazyredraw == nil then
        state.saved_settings.lazyredraw = vim.o.lazyredraw
      end

      pcall(vim.api.nvim_set_option_value, "lazyredraw", true, {})

      -- Debounced restoration after 50ms to avoid excessive re-rendering
      state.restore_timer = vim.fn.timer_start(50, function()
        state.restore_timer = nil
        M.cleanup()
        vim.schedule(function()
          -- Call the enable callback to re-enable centerpad
          enable_callback(config)

          -- Restore lazyredraw to saved value
          if state.saved_settings.lazyredraw ~= nil then
            pcall(
              vim.api.nvim_set_option_value,
              "lazyredraw",
              state.saved_settings.lazyredraw,
              {}
            )
            state.saved_settings.lazyredraw = nil
          end
          pcall(vim.api.nvim_command, "redraw!")
        end)
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

  state.pad_state.enabled = false
  vim.g.center_buf_enabled = false

  state.log_info("cleanup", "Cleanup complete")
end

return M
