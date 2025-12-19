# colorscheme-picker.nvim
A lightweight Neovim plugin for picking, applying, and persisting colorschemes, with optional global style overrides and transparency support.

Designed to stay out of the way and work with your existing setup.

___

### ✨ Features
- Interactive colorscheme picker
    - Supports fzf-lua or Telescope
- Persist last-used colorscheme across restarts
- Optional default colorscheme on startup
- Filter between user-installed and stock colorschemes
- Global style overrides
    - Disable bold, italic, and/or underline across all highlight groups
- Optional background transparency
- Optional highlight customization
    - Cursor line
    - Line numbers
- Configurable keymaps
- User commands for scripting and discoverability

___

### 📦 Installation
Using lazy.nvim
``` lua
{
	"danhat1020/colorscheme-picker.nvim",
	dependencies = {
		"ibhagwan/fzf-lua",
        -- or
        -- "nvim-telescope/telescope.nvim"
	},
	config = function()
		require("colorscheme-picker").setup()
	end,
}
```

You must install either fzf-lua or telescope.nvim.

___

### ⚙️ Setup
**Minimal setup**
``` lua
require("colorscheme-picker").setup()
```

**Full example**
``` lua
require("colorscheme-picker").setup({
	default_scheme = "default", -- or a specific colorscheme name
	picker = "fzf-lua",         -- "fzf-lua" or "telescope"
	include_stock = false,      -- include built-in colorschemes

	colors = {
		transparent = true,
		cursor_line = nil,
		line_number_current = nil,
		line_number = nil,
	},

	style = {
		bold = false,
		italic = true,
		underline = true,
	},

	keymaps = {
		pick = "<leader>cs",
		print = "<leader>cp",
	},
})
```

___

### ⌨️ Commands
The plugin provides the following user commands:

``` lua
:ColorschemePick
```
Open the colorscheme picker.

``` lua
:ColorschemePrint
```
Print the currently active colorscheme.

``` lua
:ColorschemeApply {name}
```
Apply a colorscheme by name (with completion).

___

### 🔑 API
These functions are considered public and stable:

`require("colorscheme-picker").setup(opts)`
`require("colorscheme-picker").pick()`
`require("colorscheme-picker").apply(name)`
`require("colorscheme-picker").print()`
`require("colorscheme-picker").get_schemes()`

Anything else is internal and may change.

___

### 🎨 Transparency
When enabled, the following highlight groups are cleared:

- `Normal`
- `NormalNC`
- `NormalFloat`
- `SignColumn`
- `StatusLine`
If `lualine.nvim` is installed, it will be reloaded automatically.

___

### 🧠 Persistence
The last-used colorscheme is stored in:
`stdpath("data")/colorscheme-picker.json`

Persistence is skipped if a fixed `default_scheme` is configured.

___

### 📋 Notes
- No live preview is performed in the picker (by design).
- Style overrides are applied after loading a colorscheme.
- Only non-stock colorschemes are shown by default.
