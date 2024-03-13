local v = vim.api

local marginpads_group =
  vim.api.nvim_create_augroup("augroup_marginpads", { clear = true })

local function set_buf_options()
  vim.cmd([[
    setlocal noswapfile hidden nobuflisted nocursorline nolist winfixwidth
    setlocal nomodified nomodifiable nonumber
    setlocal buftype=nofile bufhidden=hide filetype=centerpad
    setlocal foldcolumn=0 signcolumn=no
  ]])
  vim.opt_local.fillchars:append({
    vert = " ",
    vertleft = " ",
    vertright = " ",
    verthoriz = " ",
    horiz = " ",
    horizup = " ",
    horizdown = " ",
    eob = " ",
    foldopen = " ",
    foldclose = " ",
    fold = " ",
    lastline = " ",
  })
end

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

-- Example usage:
-- local my_unlisted_buffers = get_unlisted_buffers()
-- print(vim.inspect(my_unlisted_buffers))

local function set_current_window(window)
  if v.nvim_win_is_valid(window) then
    v.nvim_set_current_win(window)
  end
end

local function never_focus_autocmd(main_win, pad)
  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    buffer = pad,
    group = marginpads_group,
    callback = function()
      set_current_window(main_win)
    end,
  })
end

local function delete_margin_buffers()
  local windows = v.nvim_tabpage_list_wins(0)
  for _, win in ipairs(windows) do
    local bufnr = v.nvim_win_get_buf(win)
    local cur_name = v.nvim_buf_get_name(bufnr)
    if cur_name:match("leftpad") or cur_name:match("rightpad") then
      v.nvim_buf_delete(bufnr, { force = true })
    end
  end
end

local turn_off = function()
  v.nvim_clear_autocmds({ group = marginpads_group })
  -- Get reference to current_buffer
  local curr_buf = v.nvim_get_current_buf()
  local curr_bufname = v.nvim_buf_get_name(curr_buf)
  -- Make sure the currently focused buffer is not a scratch buffer
  if curr_bufname == "leftpad" or curr_bufname == "rightpad" then
    print("ERROR: margin buffers should not be in focus")
    return
  end
  delete_margin_buffers()
  -- keep track of the current state of the plugin
  vim.g.center_buf_enabled = false
end

local function turn_off_autocmd()
  vim.api.nvim_create_autocmd({ "BufLeave" }, {
    group = marginpads_group,
    callback = function()
      local buffer = v.nvim_get_current_buf()
      local turn_off_on_buffer_close = function()
        if vim.tbl_contains(get_unlisted_buffers(), buffer) then
          vim.schedule(turn_off)
        end
      end
      vim.defer_fn(turn_off_on_buffer_close, 50)
    end,
  })
end

local turn_on = function(config)
  v.nvim_clear_autocmds({ group = marginpads_group })
  -- Get reference to current_buffer
  local main_win = v.nvim_get_current_win()
  -- get the user's current options for split directions
  local useropts = {
    splitbelow = vim.o.splitbelow,
    splitright = vim.o.splitright,
  }
  -- create scratch window to the left
  vim.o.splitright = false
  vim.cmd(string.format("%svnew", config.leftpad))
  local leftpad = v.nvim_get_current_buf()
  v.nvim_buf_set_name(leftpad, "leftpad")
  set_buf_options()
  never_focus_autocmd(main_win, leftpad)
  set_current_window(main_win)
  -- create scratch window to the right
  vim.o.splitright = true
  vim.cmd(string.format("%svnew", config.rightpad))
  local rightpad = v.nvim_get_current_buf()
  v.nvim_buf_set_name(rightpad, "rightpad")
  set_buf_options()
  never_focus_autocmd(main_win, rightpad)
  set_current_window(main_win)
  turn_off_autocmd()
  -- set fillchars for main window
  vim.opt.fillchars:append({
    vert = " ",
    vertleft = " ",
    vertright = " ",
    verthoriz = " ",
    -- horiz = " ",
    -- horizup = " ",
    -- horizdown = " ",
  })
  -- keep track of the current state of the plugin
  vim.g.center_buf_enabled = true
  -- reset the user's split opts
  vim.o.splitbelow = useropts.splitbelow
  vim.o.splitright = useropts.splitright
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
