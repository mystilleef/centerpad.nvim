local scratch_buffer_fillchars = {
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

local marginpads_group =
  vim.api.nvim_create_augroup("augroup_marginpads", { clear = true })

function get_unlisted_buffers()
  local all_buffers = vim.api.nvim_list_bufs()
  local unlisted_buffers = {}
  for _, bufnum in ipairs(all_buffers) do
    if not vim.api.nvim_buf_is_loaded(bufnum) then
      table.insert(unlisted_buffers, bufnum)
    end
  end
  return unlisted_buffers
end

local function set_current_window(window)
  if vim.api.nvim_win_is_valid(window) then
    vim.api.nvim_set_current_win(window)
  end
end

local function delete_scratch_buffers()
  local windows = vim.api.nvim_tabpage_list_wins(0)
  for _, win in ipairs(windows) do
    local bufnr = vim.api.nvim_win_get_buf(win)
    local cur_name = vim.api.nvim_buf_get_name(bufnr)
    if cur_name:match("leftpad") or cur_name:match("rightpad") then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end
end

local turn_off = function()
  vim.api.nvim_clear_autocmds({ group = marginpads_group })
  delete_scratch_buffers()
  vim.opt.fillchars:append({ vert = "│" })
  vim.g.center_buf_enabled = false
end

local function turn_off_autocmd()
  vim.api.nvim_create_autocmd({ "BufLeave" }, {
    group = marginpads_group,
    callback = function()
      local buffer = vim.api.nvim_get_current_buf()
      local turn_off_on_buffer_close = function()
        if vim.tbl_contains(get_unlisted_buffers(), buffer) then
          vim.schedule(turn_off)
        end
      end
      vim.defer_fn(turn_off_on_buffer_close, 50)
    end,
  })
end

local function prevent_focus_autocmd(buffer)
  vim.api.nvim_create_autocmd("BufEnter", {
    buffer = buffer,
    group = marginpads_group,
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

local function set_scratch_options(window, buffer)
  vim.api.nvim_set_option_value("winfixwidth", true, { win = window })
  vim.api.nvim_set_option_value("filetype", "centerpad", { buf = buffer })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buffer })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buffer })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buffer })
  vim.api.nvim_set_option_value("readonly", true, { buf = buffer })
  vim.api.nvim_set_option_value("buflisted", false, { buf = buffer })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buffer })
end

local function create_split_window(buffer, position)
  return vim.api.nvim_open_win(buffer, false, {
    vertical = true,
    split = position,
    focusable = false,
    style = "minimal",
    noautocmd = true,
  })
end

local function create_scratch_buffer(name, position, size)
  local buffer = vim.api.nvim_create_buf(false, true)
  local window = create_split_window(buffer, position)
  vim.api.nvim_buf_set_name(buffer, name)
  set_scratch_options(window, buffer)
  vim.api.nvim_win_set_width(window, size)
  set_current_window(window)
  vim.opt_local.fillchars:append(scratch_buffer_fillchars)
  prevent_focus_autocmd(buffer)
end

local turn_on = function(config)
  local main_win = vim.api.nvim_get_current_win()
  vim.api.nvim_clear_autocmds({ group = marginpads_group })
  delete_scratch_buffers()
  create_scratch_buffer("leftpad", "left", config.leftpad)
  set_current_window(main_win)
  create_scratch_buffer("rightpad", "right", config.rightpad)
  set_current_window(main_win)
  turn_off_autocmd()
  vim.opt.fillchars:append({ vert = " " })
  vim.g.center_buf_enabled = true
end

local M = {}

function M.enable(config)
  M.disable()
  turn_on(config)
end

function M.disable()
  turn_off()
end

M.toggle = function(config)
  config = config or { leftpad = 25, rightpad = 25 }
  if vim.g.center_buf_enabled == true then
    M.disable()
  else
    M.enable(config)
  end
end

M.run = function(config, command_opts)
  local args = command_opts.fargs
  if #args == 1 then
    M.enable({ leftpad = tonumber(args[1]), rightpad = tonumber(args[1]) })
  elseif #args == 2 then
    M.enable({ leftpad = tonumber(args[1]), rightpad = tonumber(args[2]) })
  else
    M.toggle(config)
  end
end

return M
