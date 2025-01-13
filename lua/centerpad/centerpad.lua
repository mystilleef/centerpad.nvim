local pad_buffer_fillchars = {
  horiz = " ",
  horizup = " ",
  horizdown = " ",
  vert = " ",
  vertleft = " ",
  vertright = " ",
  verthoriz = " ",
  fold = " ",
  foldopen = " ",
  foldclose = " ",
  foldsep = " ",
  diff = " ",
  eob = " ",
  lastline = " ",
}

local padgroup = vim.api.nvim_create_augroup("padgroup", { clear = true })

local function set_current_window(window)
  if vim.api.nvim_win_is_valid(window) then
    vim.api.nvim_set_current_win(window)
  end
end

local function delete_pads()
  local windows = vim.api.nvim_tabpage_list_wins(0)
  for _, win in ipairs(windows) do
    local bufnr = vim.api.nvim_win_get_buf(win)
    local cur_name = vim.api.nvim_buf_get_name(bufnr)
    if cur_name:match("leftpad") or cur_name:match("rightpad") then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end
end

local function remove_pads()
  vim.api.nvim_clear_autocmds({ group = padgroup })
  delete_pads()
  vim.opt.fillchars:append({ vert = "│" })
  vim.g.center_buf_enabled = false
end

local function prevent_focus_autocmd(buffer)
  vim.api.nvim_create_autocmd("BufEnter", {
    buffer = buffer,
    group = padgroup,
    callback = function(args)
      local buffer_name = vim.api.nvim_buf_get_name(args.buf)
      if buffer_name:match("leftpad") then
        vim.cmd("wincmd l")
      elseif buffer_name:match("rightpad") then
        vim.cmd("wincmd h")
      else
        vim.cmd("wincmd p")
      end
    end,
  })
end

local function set_pad_options(window, buffer)
  vim.api.nvim_set_option_value("winfixwidth", true, { win = window })
  vim.api.nvim_set_option_value("winfixbuf", true, { win = window })
  vim.api.nvim_set_option_value("filetype", "centerpad", { buf = buffer })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buffer })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buffer })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buffer })
  vim.api.nvim_set_option_value("readonly", true, { buf = buffer })
  vim.api.nvim_set_option_value("buflisted", false, { buf = buffer })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buffer })
end

local function create_split_for_pad(buffer, position)
  return vim.api.nvim_open_win(buffer, false, {
    split = position,
    focusable = false,
    style = "minimal",
    noautocmd = true,
  })
end

local function create_pad_window(name, position, size)
  local buffer = vim.api.nvim_create_buf(false, true)
  local window = create_split_for_pad(buffer, position)
  vim.api.nvim_buf_set_name(buffer, name)
  set_pad_options(window, buffer)
  vim.api.nvim_win_set_width(window, size)
  set_current_window(window)
  vim.opt_local.fillchars:append(pad_buffer_fillchars)
  prevent_focus_autocmd(buffer)
end

local M = {}

-- restart centerpad on :bdelete
local function restore_pads_autocmd(config)
  vim.api.nvim_create_autocmd({ "WinClosed" }, {
    group = padgroup,
    callback = function(args)
      local bufnr = args.buf
      local buftype = vim.api.nvim_buf_get_option(bufnr, "buftype")
      if not vim.g.center_buf_enabled then
        return
      end
      if vim.tbl_contains(config.ignore_buftypes, buftype) then
        return
      end
      local cur_name = vim.api.nvim_buf_get_name(bufnr)
      if cur_name:match("leftpad") or cur_name:match("rightpad") then
        return
      end
      local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")
      if vim.tbl_contains(config.ignore_filetypes, filetype) then
        return
      end
      vim.api.nvim_set_option("lazyredraw", true)
      remove_pads()
      vim.schedule(function()
        M.enable(config)
        vim.api.nvim_set_option("lazyredraw", false)
        vim.api.nvim_command("redraw!")
      end)
    end,
  })
end

local function add_pads(config)
  local main_win = vim.api.nvim_get_current_win()
  vim.api.nvim_clear_autocmds({ group = padgroup })
  delete_pads()
  create_pad_window("leftpad", "left", config.leftpad)
  set_current_window(main_win)
  create_pad_window("rightpad", "right", config.rightpad)
  set_current_window(main_win)
  restore_pads_autocmd(config)
  vim.opt.fillchars:append({ vert = " " })
  vim.g.center_buf_enabled = true
end

function M.should_enable(config)
  local filetype_ignored =
    vim.tbl_contains(config.ignore_filetypes, vim.bo.filetype)
  local buftype_ignored =
    vim.tbl_contains(config.ignore_buftypes, vim.bo.buftype)
  return not filetype_ignored or not buftype_ignored
end

function M.enable(config)
  if M.should_enable(config) then
    M.disable()
    add_pads(config)
  end
end

function M.disable()
  remove_pads()
end

function M.toggle(config)
  if vim.g.center_buf_enabled == true then
    M.disable()
  else
    M.enable(config or { leftpad = 25, rightpad = 25 })
  end
end

function M.run(config, command_opts)
  local args = command_opts.fargs
  if #args == 1 then
    config.leftpad = tonumber(args[1])
    config.rightpad = tonumber(args[1])
    M.enable(config)
  elseif #args == 2 then
    config.leftpad = tonumber(args[1])
    config.rightpad = tonumber(args[2])
    M.enable(config)
  else
    M.toggle(config)
  end
end

return M
