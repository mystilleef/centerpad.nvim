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
  local enabled = require("centerpad.enabled")

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

    -- fillchars are window-local; no global save needed

    -- Check for pending timers
    if state.get_restore_timer() then
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

  -- Read globals (warns once on legacy-only usage) and report consistency
  local new_global, legacy_global = enabled.read_globals()

  if new_global == state.pad_state.enabled then
    vim.health.ok("Global flag 'centerpad_enabled' is consistent with state")
  else
    vim.health.warn(
      "Global flag mismatch: vim.g.centerpad_enabled="
        .. tostring(new_global)
        .. " but state.enabled="
        .. tostring(state.pad_state.enabled),
      { "Run :Centerpad to resynchronize state" }
    )
  end

  -- Legacy bridge status
  if legacy_global ~= nil then
    if legacy_global == state.pad_state.enabled then
      vim.health.info(
        "Legacy global 'center_buf_enabled' matches state (deprecated)"
      )
    else
      vim.health.warn(
        "Legacy global mismatch: vim.g.center_buf_enabled="
          .. tostring(legacy_global)
          .. " but state.enabled="
          .. tostring(state.pad_state.enabled),
        {
          "Use vim.g.centerpad_enabled instead; center_buf_enabled will be removed",
        }
      )
    end
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
