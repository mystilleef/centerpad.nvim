local state = require("centerpad.state")

local M = {}

local warned_legacy = false

function M.get()
  return state.pad_state.enabled
end

-- centerpad_enabled is primary; center_buf_enabled is the
-- deprecated one-release bridge.
function M.set(enabled)
  state.pad_state.enabled = enabled
  vim.g.centerpad_enabled = enabled
  vim.g.center_buf_enabled = enabled
end

-- Warns once on legacy-only usage, mirrors legacy value to new global
-- without changing internal state.
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

function M._reset_warning()
  warned_legacy = false
end

return M
