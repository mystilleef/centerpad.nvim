-- Enabled-state synchronization for centerpad
-- Manages internal state and public globals with a legacy bridge.

local state = require("centerpad.state")

local M = {}

local warned_legacy = false

-- Return the internal enabled state.
function M.get()
  return state.pad_state.enabled
end

-- Set internal state and both public globals.
-- centerpad_enabled is the primary global; center_buf_enabled is the
-- deprecated one-release bridge.
function M.set(enabled)
  state.pad_state.enabled = enabled
  vim.g.centerpad_enabled = enabled
  vim.g.center_buf_enabled = enabled
end

-- Read public globals, warning once if only the legacy global is set.
-- Mirrors a legacy-only value to the new global without changing internal
-- state. Returns the effective new-global value and the legacy value.
function M.read_globals()
  local new = vim.g.centerpad_enabled
  local legacy = vim.g.center_buf_enabled

  if new == nil and legacy ~= nil then
    if not warned_legacy then
      warned_legacy = true
      vim.notify(
        "centerpad: vim.g.center_buf_enabled is deprecated; use vim.g.centerpad_enabled",
        vim.log.levels.WARN
      )
    end
    vim.g.centerpad_enabled = legacy
    new = legacy
  end

  return new, legacy
end

-- Reset the legacy warning flag. For tests only.
function M._reset_warning()
  warned_legacy = false
end

return M
