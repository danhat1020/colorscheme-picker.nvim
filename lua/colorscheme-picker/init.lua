local M = {}

local function safe_required(mod)
	local ok, lib = pcall(require, mod)
	return ok and lib or nil
end

local persistence = require("colorscheme-picker.persistence")
local util = require("colorscheme-picker.util")

M.config = {
	default_scheme = "default", -- can declare default or reload last used scheme
	picker = "fzf-lua", -- "fzf-lua" or "telescope"
	include_stock = false, -- include all neovim colorschemes or only installed ones
	colors = {
		transparent = false, -- set background transparent
		cursor_line = nil, -- set cursorline color
		line_number_current = nil, -- set current line number color
		line_number = nil, -- set other line numbers color
	},
	style = {
		bold = true, -- universal bold
		italic = true, -- universal italic
		underline = true, -- universal underline
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

M._preview = {
	original = nil,
	active = false,
}

function M.setup(opts)
	if M.state.did_setup then
		return
	end
	M.state.did_setup = true

	opts = opts or {}

	M.config = vim.tbl_deep_extend("force", M.config, opts)

	if M.config.default_scheme and M.config.default_scheme ~= "default" then
		M.state.current = M.config.default_scheme
	else
		M.state.current = persistence.load()
	end

	-- validation
	if not vim.tbl_contains({ "fzf-lua", "telescope" }, M.config.picker) then
		vim.notify("[colorscheme-picker] Invalid picker: " .. tostring(M.config.picker), vim.log.levels.ERROR)
		return
	end

	vim.api.nvim_create_autocmd("VimEnter", {
		once = true,
		callback = function()
			M.apply(M.state.current)
			M.apply_keymaps()
		end,
	})

	vim.api.nvim_create_user_command("ColorschemePick", function()
		require("colorscheme-picker").pick()
	end, {})
	vim.api.nvim_create_user_command("ColorschemePrint", function()
		require("colorscheme-picker").print()
	end, {})
	vim.api.nvim_create_user_command("ColorschemeApply", function(opts)
		require("colorscheme-picker").apply(opts.args)
	end, {
		nargs = 1,
		complete = function()
			return require("colorscheme-picker").get_schemes()
		end,
	})
end

function M.begin_preview()
	if not M._preview.active then
		M._preview.original = M.state.current
		M._preview.active = true
	end
end

function M.preview(name)
	if not name or name == "" then
		return
	end
	M.begin_preview()
	M.apply(name)
end

function M.end_preview(confirm)
	if not M._preview.active then
		return
	end

	if not confirm and M._preview.original then
		M.apply(M._preview.original)
	end

	M._preview.original = nil
	M._preview.active = false
end

function M.get_schemes()
	if M.config.include_stock then
		return util.get_all_schemes()
	else
		return util.get_user_schemes()
	end
end

function M._pick_fzf()
	require("fzf-lua").fzf_exec(M.get_schemes(), {
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

function M.pick()
	M.get_schemes()
	if M.config.picker == "fzf-lua" then
		if safe_required("fzf-lua") then
			M._pick_fzf()
		else
			vim.notify("[colorscheme-picker] fzf-lua not found", vim.log.levels.ERROR)
			return
		end
	else
		if safe_required("telescope") then
			M._pick_telescope()
		else
			vim.notify("[colorscheme-picker] telescope not found", vim.log.levels.ERROR)
			return
		end
	end
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
		persistence.save(name)
	end

	M.apply_font_styles()
	if M.config.colors.transparent then
		M.apply_transparency()
	end
	if M.config.colors.cursor_line ~= nil then
		vim.api.nvim_set_hl(0, "CursorLine", { bg = M.config.colors.cursor_line })
	end
	if M.config.colors.line_number_current ~= nil then
		vim.api.nvim_set_hl(0, "CursorLineNr", { fg = M.config.colors.line_number_current })
	end
	if M.config.colors.line_number ~= nil then
		vim.api.nvim_set_hl(0, "LineNr", { fg = M.config.colors.line_number })
	end
end

function M.print()
	print("Colorscheme: " .. M.state.current)
end

function M.apply_transparency()
	local clear = { bg = "none" }
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
	local disable_bold = M.config.style.bold == false
	local disable_italic = M.config.style.italic == false
	local disable_underline = M.config.style.underline == false

	for _, group in ipairs(vim.fn.getcompletion("", "highlight")) do
		local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group })
		if ok and hl then
			local new = {}

			if disable_bold and hl.bold then
				new.bold = false
			end
			if disable_italic and hl.italic then
				new.italic = false
			end
			if disable_underline and hl.underline then
				new.underline = false
			end

			if next(new) ~= nil then
				vim.api.nvim_set_hl(0, group, new)
			end
		end
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
