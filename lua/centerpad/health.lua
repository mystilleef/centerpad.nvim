-- Health check module for centerpad
-- Provides diagnostic information via :checkhealth

local M = {}

function M.check()
  vim.health.start("centerpad.nvim")

  -- Check Neovim version
  if vim.fn.has("nvim-0.9") == 1 then
    vim.health.ok("Neovim version >= 0.9")
  else
    vim.health.error("Requires Neovim >= 0.9", {
      "Please upgrade to Neovim 0.9 or later",
    })
  end

  -- Check if modules can be loaded
  local modules = { "state", "window", "autocmds", "centerpad" }
  local all_loaded = true

  for _, mod_name in ipairs(modules) do
    local ok, err = pcall(require, "centerpad." .. mod_name)
    if ok then
      vim.health.ok("Module 'centerpad." .. mod_name .. "' loaded successfully")
    else
      vim.health.error(
        "Failed to load module 'centerpad." .. mod_name .. "'",
        { tostring(err) }
      )
      all_loaded = false
    end
  end

  if not all_loaded then
    return
  end

  -- Get centerpad state
  local centerpad = require("centerpad.centerpad")
  local state = require("centerpad.state")

  -- Check if centerpad is enabled
  if state.pad_state.enabled then
    vim.health.info("Centerpad is currently enabled")

    -- Validate state
    local valid, issues = centerpad.validate_state()
    if valid then
      vim.health.ok("Pad state is valid")
    else
      vim.health.warn("Pad state validation issues detected:", issues)
    end

    -- Check if pads actually exist
    if state.pads_exist() then
      vim.health.ok("Pad windows are valid and exist")
    else
      vim.health.error(
        "Enabled flag is set but pad windows don't exist",
        { "Try running :Centerpad to toggle off and on again" }
      )
    end

    -- Check main window
    if
      state.pad_state.main_win
      and vim.api.nvim_win_is_valid(state.pad_state.main_win)
    then
      vim.health.ok("Main window is valid")
    else
      vim.health.warn(
        "Main window is not valid",
        { "Focus redirection may not work correctly" }
      )
    end

    -- Check saved settings
    if state.saved_settings.fillchars then
      vim.health.info(
        "Original fillchars saved: " .. state.saved_settings.fillchars
      )
    end

    if state.saved_settings.lazyredraw ~= nil then
      vim.health.info(
        "Original lazyredraw saved: "
          .. tostring(state.saved_settings.lazyredraw)
      )
    end

    -- Check for pending timers
    if state.restore_timer then
      vim.health.info("Restore timer is pending (debouncing in progress)")
    end
  else
    vim.health.info("Centerpad is currently disabled")

    -- Check for orphaned state
    if state.pads_exist() then
      vim.health.warn(
        "Disabled but pad windows still exist",
        { "Try running :Centerpad to clean up" }
      )
    end
  end

  -- Check global flag consistency
  if vim.g.center_buf_enabled == state.pad_state.enabled then
    vim.health.ok("Global flag is consistent with state")
  else
    vim.health.warn(
      "Global flag mismatch: vim.g.center_buf_enabled="
        .. tostring(vim.g.center_buf_enabled)
        .. " but state.enabled="
        .. tostring(state.pad_state.enabled)
    )
  end

  -- Debug mode status
  if state.debug then
    vim.health.info("Debug mode is enabled")
  else
    vim.health.info(
      "Debug mode is disabled (enable with :lua require('centerpad').set_debug(true))"
    )
  end
end

return M
