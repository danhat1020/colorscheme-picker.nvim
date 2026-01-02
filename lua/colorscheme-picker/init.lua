local M = {}

local function safe_required(mod)
	local ok, lib = pcall(require, mod)
	return ok and lib or nil
end

local util = require("colorscheme-picker.util")

M.config = {
	default_scheme = "default", -- can declare default or reload last used scheme
	picker = "default", -- "fzf-lua" or "telescope" or "native-find" or "default"
	include_stock = true, -- include all neovim colorschemes or only installed ones
	colors = {
		transparent = false, -- set background to universally transparent
		cursor_line = nil, -- set cursorline color
		line_number_current = nil, -- set current line number color
		line_number = nil, -- set other line numbers color
		comment = nil, -- set comment color
		mode_in_cmdbar = nil, -- set mode message color
		end_of_buffer = nil, -- set ~ color at end of file, set false to remove, or leave as default
		visual_mode = nil, -- set background color of visual mode selection
	},
	style = {
		bold = true, -- universal bold
		italic = true, -- universal italic
		undercurl = true, -- universal undercurl
	},
	keymaps = {
		pick = nil, -- open picker
		print = nil, -- print currently used colorscheme
	},
}

M.state = {
	current = nil,
	did_setup = false,
}

function M.setup(opts)
	if M.state.did_setup then
		return
	end
	M.state.did_setup = true

	vim.g.SCHEME = ""

	opts = opts or {}

	M.config = vim.tbl_deep_extend("force", M.config, opts)

	-- validation
	if not vim.tbl_contains({ "fzf-lua", "telescope", "native-find", "default" }, M.config.picker) then
		vim.notify("[colorscheme-picker] Invalid picker: " .. tostring(M.config.picker), vim.log.levels.ERROR)
		return
	end

	vim.api.nvim_create_autocmd("VimEnter", {
		once = true,
		nested = true,
		callback = function()
			local def = M.config.default_scheme
			if def and def ~= "default" then
				M.apply(def)
			else
				M.apply(vim.g.SCHEME)
			end
			M.apply_keymaps()
		end,
	})
	vim.api.nvim_create_autocmd("ColorScheme", {
		callback = function()
			M.apply(vim.g.SCHEME)
		end,
	})

	vim.api.nvim_create_user_command("ColorschemePick", function()
		require("colorscheme-picker").pick()
	end, {})
	vim.api.nvim_create_user_command("ColorschemePrint", function()
		require("colorscheme-picker").print()
	end, {})
	vim.api.nvim_create_user_command("ColorschemeApply", function(options)
		require("colorscheme-picker").apply(options.args)
	end, {
		nargs = 1,
		complete = function()
			return require("colorscheme-picker").get_schemes()
		end,
	})
end

function M.get_schemes()
	if M.config.include_stock then
		return util.get_all_schemes()
	else
		return util.get_user_schemes()
	end
end

function M._pick_ui()
	vim.ui.select(M.get_schemes(), {
		prompt = "Pick colorscheme: ",
	}, function(choice)
		M.apply(choice)
	end)
end

function M._pick_fzf()
	require("fzf-lua").fzf_exec(M.get_schemes(), {
		winopts = {
			width = 1.0,
		},
		prompt = "Pick colorscheme: ",
		actions = {
			["default"] = function(selected)
				M.apply(selected[1])
			end,
		},
	})
end

function M._pick_telescope()
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	pickers
		.new({}, {
			prompt_title = "Pick colorscheme:",
			finder = finders.new_table({
				results = M.get_schemes(),
			}),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(_, map)
				actions.select_default:replace(function(bufnr)
					local entry = action_state.get_selected_entry()
					actions.close(bufnr)
					M.apply(entry[1])
				end)
				return true
			end,
		})
		:find()
end

function M._pick_native()
	require("native-find").pick(M.get_schemes(), {
		prompt = "Pick colorscheme: ",
	})
end

function M.pick()
	if M.config.picker == "fzf-lua" then
		if safe_required("fzf-lua") then
			M._pick_fzf()
		else
			vim.notify("[colorscheme-picker] fzf-lua not found", vim.log.levels.ERROR)
			return
		end
	elseif M.config.picker == "telescope" then
		if safe_required("telescope") then
			M._pick_telescope()
		else
			vim.notify("[colorscheme-picker] telescope not found", vim.log.levels.ERROR)
			return
		end
	elseif M.config.picker == "native-find" then
		if safe_required("native-find") then
			M._pick_native()
		else
			vim.notify("[colorscheme-picker] native-find not found", vim.log.levels.ERROR)
			return
		end
	elseif M.config.picker == "default" then
		M._pick_ui()
	end
end

local function hl(group, opts)
	vim.api.nvim_set_hl(0, group, opts)
end

function M.apply(name)
	if not name or name == "" then
		return
	end

	local ok = pcall(vim.cmd.colorscheme, name)
	if not ok then
		vim.notify("[colorscheme-picker] Colorscheme not found: " .. name, vim.log.levels.WARN)
		return
	end

	M.state.current = name

	if not M.config.default_scheme or M.config.default_scheme == "default" then
		vim.g.SCHEME = name
	end

	if M.config.colors.transparent then
		M.apply_transparency()
	end
	M.apply_highlight_colors()
	M.apply_font_styles()
end

function M.apply_highlight_colors()
	if M.config.colors.cursor_line ~= nil then
		hl("CursorLine", { bg = M.config.colors.cursor_line })
	end
	if M.config.colors.line_number_current ~= nil then
		hl("CursorLineNr", { fg = M.config.colors.line_number_current })
	end
	if M.config.colors.line_number ~= nil then
		hl("LineNr", { fg = M.config.colors.line_number })
	end
	if M.config.colors.comment ~= nil then
		hl("@lsp.type.comment", { fg = M.config.colors.comment })
		hl("@comment", { fg = M.config.colors.comment })
		hl("Comment", { fg = M.config.colors.comment })
	end
	if M.config.colors.mode_in_cmdbar ~= nil then
		hl("ModeMsg", { fg = M.config.colors.mode_in_cmdbar })
	end
	if M.config.colors.end_of_buffer == false then
		vim.opt.fillchars:append({ eob = " " })
	elseif M.config.colors.end_of_buffer ~= nil then
		hl("EndOfBuffer", { fg = M.config.colors.end_of_buffer })
	end
	if M.config.colors.visual_mode ~= nil then
		hl("Visual", { bg = M.config.colors.visual_mode })
	end
	hl("StatusLineNC", { fg = "#808080", bg = "NONE" })
	hl("WinBar", { fg = "#808080", bg = "NONE" })
	hl("WinBarNC", { fg = "#505050", bg = "NONE" })
end

function M.print()
	print("Current colorscheme: " .. vim.g.SCHEME)
end

function M.apply_transparency()
	local clear = { bg = "NONE" }
	vim.api.nvim_set_hl(0, "Normal", clear)
	vim.api.nvim_set_hl(0, "NormalNC", clear)
	vim.api.nvim_set_hl(0, "NormalFloat", clear)
	vim.api.nvim_set_hl(0, "SignColumn", clear)
	vim.api.nvim_set_hl(0, "StatusLine", clear)
	local lualine = safe_required("lualine")
	if lualine then
		require("lualine").setup()
	end
end

function M.apply_font_styles()
	local bold = M.config.style.bold
	local italic = M.config.style.italic
	local undercurl = M.config.style.undercurl

	local groups = vim.fn.getcompletion("", "highlight")

	for _, group in ipairs(groups) do
		local ok, hi = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
		if not ok or not hi then
			goto continue
		end

		local new = vim.deepcopy(hi)

		if not bold then
			new.bold = false
		end
		if not italic then
			new.italic = false
		end

		local has_line = hi.underline or hi.undercurl

		if has_line then
			if undercurl then
				new.underline = false
				new.undercurl = true
			elseif not undercurl then
				new.underline = true
				new.undercurl = false
			end
		end

		vim.api.nvim_set_hl(0, group, new)

		::continue::
	end
end

function M.apply_keymaps()
	local km = M.config.keymaps
	local map = vim.keymap.set

	if km.pick then
		map("n", km.pick, function()
			require("colorscheme-picker").pick()
		end, { noremap = true, desc = "Pick colorscheme" })
	end

	if km.print then
		map("n", km.print, function()
			require("colorscheme-picker").print()
		end, { noremap = true, desc = "Print current colorscheme" })
	end
end

return M
