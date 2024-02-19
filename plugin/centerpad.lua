vim.api.nvim_create_user_command("Centerpad", function(opts)
  require("centerpad").run(opts)
end, { nargs = "*" })
