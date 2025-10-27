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

-- Set all required options for a pad buffer/window
local function set_pad_options(window, buffer)
  -- Window options
  pcall(vim.api.nvim_set_option_value, "winfixwidth", true, { win = window })
  pcall(vim.api.nvim_set_option_value, "winfixbuf", true, { win = window })

  -- Disable ALL UI elements to ensure completely blank pads
  pcall(vim.api.nvim_set_option_value, "statusline", " ", { win = window })
  pcall(vim.api.nvim_set_option_value, "winbar", "", { win = window })
  pcall(vim.api.nvim_set_option_value, "signcolumn", "no", { win = window })
  pcall(vim.api.nvim_set_option_value, "number", false, { win = window })
  pcall(
    vim.api.nvim_set_option_value,
    "relativenumber",
    false,
    { win = window }
  )
  pcall(vim.api.nvim_set_option_value, "foldcolumn", "0", { win = window })
  pcall(vim.api.nvim_set_option_value, "cursorline", false, { win = window })
  pcall(vim.api.nvim_set_option_value, "cursorcolumn", false, { win = window })
  pcall(vim.api.nvim_set_option_value, "list", false, { win = window })
  pcall(vim.api.nvim_set_option_value, "spell", false, { win = window })
  pcall(vim.api.nvim_set_option_value, "colorcolumn", "", { win = window })
  pcall(vim.api.nvim_set_option_value, "wrap", false, { win = window })
  pcall(vim.api.nvim_set_option_value, "linebreak", false, { win = window })
  pcall(vim.api.nvim_set_option_value, "conceallevel", 0, { win = window })

  -- Buffer options
  pcall(
    vim.api.nvim_set_option_value,
    "filetype",
    "centerpad",
    { buf = buffer }
  )
  pcall(vim.api.nvim_set_option_value, "buftype", "nofile", { buf = buffer })
  pcall(vim.api.nvim_set_option_value, "bufhidden", "wipe", { buf = buffer })
  pcall(vim.api.nvim_set_option_value, "modifiable", false, { buf = buffer })
  pcall(vim.api.nvim_set_option_value, "readonly", true, { buf = buffer })
  pcall(vim.api.nvim_set_option_value, "buflisted", false, { buf = buffer })
  pcall(vim.api.nvim_set_option_value, "swapfile", false, { buf = buffer })
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

  set_pad_options(window, buffer)
  pcall(vim.api.nvim_win_set_width, window, size)

  -- Set fillchars to make pad completely blank
  local fillchars_str = table.concat({
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
  pcall(
    vim.api.nvim_set_option_value,
    "fillchars",
    fillchars_str,
    { win = window }
  )

  state.log_info("create_pad_window", "Created " .. position .. " pad")
  return window
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
  if state.saved_settings.fillchars then
    pcall(function()
      vim.o.fillchars = state.saved_settings.fillchars
    end)
    state.saved_settings.fillchars = nil
    state.log_info("restore_settings", "Restored fillchars")
  end

  -- Restore lazyredraw
  if state.saved_settings.lazyredraw ~= nil then
    pcall(
      vim.api.nvim_set_option_value,
      "lazyredraw",
      state.saved_settings.lazyredraw,
      {}
    )
    state.saved_settings.lazyredraw = nil
    state.log_info("restore_settings", "Restored lazyredraw")
  end
end

return M
