# Centerpad

If you have a large or widescreen monitor, this plugin
allows you to center your `Neovim` main buffer by adding
paddings to the left and right of it. The paddings are empty
buffers that can neither be modified nor focused.

## Centerpad in action

[!See in action](https://github.com/mystilleef/centerpad.nvim/assets/273399/6dd4f3fd-5053-4afa-b6ba-851688398385)

## Installing for Lazy

```lua
-- lazy package manager
{
  ...
  {
    "mystilleef/centerpad.nvim",
    main = "centerpad",
    opts = { enable_by_default = false, leftpad = 25, rightpad = 25 },
  },
  ...
}

-- if you have lazy loading enabled then use this instead
{
  ...
  {
    "mystilleef/centerpad.nvim",
    main = "centerpad",
    event = "UIEnter", -- lazy load on event (optional)
    cmd = "Centerpad", -- lazy load on command (optional)
    opts = { enable_by_default = false, leftpad = 25, rightpad = 25 },
  },
  ...
}
```

The `leftpad` and `rightpad` options will adjust the
paddings on the left and right side of the main buffer,
respectively.

## Usage

- `:Centerpad` - Toggle centering on/off
- `:Centerpad 20` - Set left and right padding to 20
- `:Centerpad 10 20` - Set left padding to 10, right to 20

## Configuration

By default, `Centerpad` will set the left and right padding
to 25 columns each. You can override these values in your
`Lazy` configuration as shown above.

### Setting keybinding using Lua

```lua
-- use <leader>z to toggle Centerpad
vim.api.nvim_set_keymap(
  "n",
  "<leader>z",
  "<cmd>Centerpad<cr>",
  { silent = true, noremap = true }
)
```

### Setting keybinding using Vimscript

```vim
" use <leader>z to toggle Centerpad
nnoremap <silent><leader>z <cmd>Centerpad<cr>
```

## Difference from the forked version

- written completely in `Lua`
- designed with `Lazy` compatibility in mind
- paddings can't be modified
- paddings can't be focused

## Credits

[smithbm2316](https://github.com/smithbm2316/centerpad.nvim)
