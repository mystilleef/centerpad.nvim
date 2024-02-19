# Centerpad

If you have a large or widescreen monitor, this plugin
allows you to center your `Neovim` buffer on your screen.

### Centerpad in action

https://github.com/mystilleef/centerpad.nvim/assets/273399/6dd4f3fd-5053-4afa-b6ba-851688398385

## Installing for Lazy

```lua
-- lazy package manager
{
  ...
  {
    "mystilleef/centerpad.nvim",
    main = "centerpad",
    opts = { enable_by_default = false, leftpad = 20, rightpad = 20 },
  },
  ...
}

-- if you have lazy loading enabled then use this instead
{
  ...
  {
    "mystilleef/centerpad.nvim",
    main = "centerpad",
    event = "UIEnter",
    cmd = "Centerpad",
    opts = { enable_by_default = false, leftpad = 20, rightpad = 20 },
  },
  ...
}
```

The `leftpad` and `rightpad` options will adjust the padding
for the scratch buffers on the left and right side of your
main buffer, respectively.

## Usage

- `:Centerpad` - Toggle centering on/off
- `:Centerpad 20` - Set left and right padding to 20
- `:Centerpad 10 20` - Set left padding to 10, right to 20

## Configuration

By default, `Centerpad` will set the left and right padding
to 20 columns each. You can override these values in your
`Lazy` configuration as shown above.

### Setting keybinding using Lua

```lua
-- using the command
vim.api.nvim_set_keymap(
  "n",
  "<leader>z",
  "<cmd>Centerpad<cr>",
  { silent = true, noremap = true }
)
```

### Setting keybinding using Vimscript

```vim
" using the command
nnoremap <silent><leader>z <cmd>Centerpad<cr>
```

## Difference from the forked version

- written completely in `Lua`
- designed with `Lazy` compatibility in mind
- margins can't be modified
- margins can't be focused

## Credits

[smithbm2316](https://github.com/smithbm2316/centerpad.nvim)
