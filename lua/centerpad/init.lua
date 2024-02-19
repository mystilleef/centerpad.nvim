local M = {
  config = {
    leftpad = 20,
    rightpad = 20,
    enable_by_default = false,
  },
}

local function resolve(config)
  M.config = vim.tbl_deep_extend("force", M.config, config or {})
end

function M.enable()
  require("centerpad.centerpad").enable(M.config)
end

function M.disable()
  require("centerpad.centerpad").disable()
end

function M.toggle()
  require("centerpad.centerpad").toggle(M.config)
end

function M.run(opts)
  require("centerpad.centerpad").run_command(M.config, opts)
end

function M.setup(config)
  resolve(config)
  if M.enable_by_default then
    M.enable()
  end
end

return M
