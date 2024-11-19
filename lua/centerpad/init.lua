local centerpad = require("centerpad.centerpad")

local M = {
  config = {
    leftpad = 25,
    rightpad = 25,
    enable_by_default = false,
    ignore_filetypes = { "help", "qf", "terminal" },
  },
}

local function resolve(config)
  M.config = vim.tbl_deep_extend("force", M.config, config or {})
end

function M.enable()
  centerpad.enable(M.config)
end

function M.disable()
  centerpad.disable()
end

function M.toggle()
  centerpad.toggle(M.config)
end

function M.run(opts)
  centerpad.run(M.config, opts)
end

function M.setup(config)
  resolve(config)
  M.enable()
end

return M
