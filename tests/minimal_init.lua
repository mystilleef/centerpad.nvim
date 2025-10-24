-- Minimal init for testing with nlua
-- Add plugin to runtime path

local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h:h")
vim.opt.rtp:prepend(plugin_dir)

-- Disable swap and backup for tests
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.undofile = false

-- Create a reasonable window for tests
vim.o.lines = 50
vim.o.columns = 120
