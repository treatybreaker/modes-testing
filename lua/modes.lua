local utils = require('modes.utils')

local M = {}
local config = {}
local default_config = {
	colors = {},
	line_opacity = {
		copy = 0.15,
		delete = 0.15,
		insert = 0.15,
		visual = 0.15,
	},
	set_cursor = true,
	set_cursorline = true,
	set_number = true,
	ignore_filetypes = { 'NvimTree', 'TelescopePrompt' },
}
local colors = {}
local blended_colors = {}
local default_colors = {}
local operator_started = false

M.reset = function()
	M.highlight('default')
	operator_started = false
end

---Update highlights
---@param scene 'default'|'insert'|'visual'|'copy'|'delete'|
M.highlight = function(scene)
	if scene == 'default' then
		utils.set_hl('CursorLine', { bg = default_colors.cursor_line })
		if config.set_number then
			utils.set_hl('CursorLineNr', { bg = default_colors.cursor_line_nr })
		end
		utils.set_hl('ModeMsg', { fg = default_colors.mode_msg })
		utils.set_hl('Visual', { bg = default_colors.visual })
	end

	if scene == 'insert' then
		utils.set_hl('CursorLine', { bg = blended_colors.insert })
		if config.set_number then
			utils.set_hl('CursorLineNr', { bg = blended_colors.insert })
		end
		utils.set_hl('ModeMsg', { fg = colors.insert })
	end

	if scene == 'visual' then
		utils.set_hl('CursorLine', { bg = blended_colors.visual })
		if config.set_number then
			utils.set_hl('CursorLineNr', { bg = blended_colors.visual })
		end
		utils.set_hl('ModeMsg', { fg = colors.visual })
		utils.set_hl('Visual', { bg = blended_colors.visual })
	end

	if scene == 'copy' then
		utils.set_hl('CursorLine', { bg = blended_colors.copy })
		if config.set_number then
			utils.set_hl('CursorLineNr', { bg = blended_colors.copy })
		end
		utils.set_hl('ModesOperator', { link = 'ModesCopy' })
	end

	if scene == 'delete' then
		utils.set_hl('CursorLine', { bg = blended_colors.delete })
		if config.set_number then
			utils.set_hl('CursorLineNr', { bg = blended_colors.delete })
		end
		utils.set_hl('ModesOperator', { link = 'ModesDelete' })
	end
end

M.define = function()
	default_colors = {
		cursor_line = utils.get_bg('CursorLine', 'CursorLine'),
		cursor_line_nr = utils.get_bg('CursorLineNr', 'CursorLineNr'),
		mode_msg = utils.get_fg('ModeMsg', 'ModeMsg'),
		normal = utils.get_bg('Normal', 'Normal'),
		visual = utils.get_bg('Visual', 'Visual'),
	}
	colors = {
		copy = config.colors.copy or utils.get_bg('ModesCopy', '#f5c359'),
		delete = config.colors.delete or utils.get_bg('ModesDelete', '#c75c6a'),
		insert = config.colors.insert or utils.get_bg('ModesInsert', '#78ccc5'),
		visual = config.colors.visual or utils.get_bg('ModesVisual', '#9745be'),
	}
	blended_colors = {
		copy = utils.blend(
			colors.copy,
			default_colors.normal,
			config.line_opacity.copy
		),
		delete = utils.blend(
			colors.delete,
			default_colors.normal,
			config.line_opacity.delete
		),
		insert = utils.blend(
			colors.insert,
			default_colors.normal,
			config.line_opacity.insert
		),
		visual = utils.blend(
			colors.visual,
			default_colors.normal,
			config.line_opacity.visual
		),
	}

	---Create highlight groups
	vim.cmd('hi ModesCopy guibg=' .. colors.copy)
	vim.cmd('hi ModesDelete guibg=' .. colors.delete)
	vim.cmd('hi ModesInsert guibg=' .. colors.insert)
	vim.cmd('hi ModesVisual guibg=' .. colors.visual)
end

M.enable_managed_ui = function()
	if config.set_cursor then
		vim.opt.guicursor:append('v-sm:block-ModesVisual')
		vim.opt.guicursor:append('i-ci-ve:ver25-ModesInsert')
		vim.opt.guicursor:append('r-cr-o:hor20-ModesOperator')
	end

	if config.set_cursorline then
		vim.opt.cursorline = true
	end
end

M.disable_managed_ui = function()
	if config.set_cursor then
		vim.opt.guicursor:remove('v-sm:block-ModesVisual')
		vim.opt.guicursor:remove('i-ci-ve:ver25-ModesInsert')
		vim.opt.guicursor:remove('r-cr-o:hor20-ModesOperator')
	end

	if config.set_cursorline then
		vim.opt.cursorline = false
	end
end

M.setup = function(opts)
	opts = opts or default_config
	if opts.focus_only then
		print(
			'modes.nvim – `focus_only` has been removed and is now the default behaviour'
		)
	end

	config = vim.tbl_deep_extend('force', default_config, opts)

	if type(config.line_opacity) == 'number' then
		config.line_opacity = {
			copy = config.line_opacity,
			delete = config.line_opacity,
			insert = config.line_opacity,
			visual = config.line_opacity,
		}
	end

	M.define()
	vim.defer_fn(function()
		M.define()
	end, 15)

	vim.on_key(function(key)
		local ok, current_mode = pcall(vim.fn.mode)
		if not ok then
			M.reset()
		end

		if current_mode == 'i' then
			if key == utils.replace_termcodes('<esc>') then
				M.reset()
			end
		end

		if current_mode == 'n' then
			if key == utils.replace_termcodes('<esc>') then
				M.reset()
			end

			if key == 'y' then
				if operator_started then
					M.reset()
				else
					M.highlight('copy')
					operator_started = true
				end
			end

			if key == 'd' then
				if operator_started then
					M.reset()
				else
					M.highlight('delete')
					operator_started = true
				end
			end

			if
				(key:lower() == 'v' or key == utils.replace_termcodes('<c-v>'))
				and not operator_started
			then
				M.highlight('visual')
			end
		end

		if
			current_mode:lower() == 'v'
			or current_mode == utils.replace_termcodes('<c-v>')
		then
			if key == utils.replace_termcodes('<esc>') then
				M.reset()
			end
		end
	end)

	---Set highlights when colorscheme changes
	vim.api.nvim_create_autocmd('ColorScheme', {
		pattern = '*',
		callback = M.define,
	})

	---Set insert highlight
	vim.api.nvim_create_autocmd('InsertEnter', {
		pattern = '*',
		callback = function()
			M.highlight('insert')
		end,
	})

	---Reset highlights
	vim.api.nvim_create_autocmd(
		{ 'CmdlineLeave', 'InsertLeave', 'TextYankPost', 'WinLeave' },
		{
			pattern = '*',
			callback = M.reset,
		}
	)

	---Enable managed UI initially
	M.enable_managed_ui()

	---Enable managed UI for current window
	vim.api.nvim_create_autocmd('WinEnter', {
		pattern = '*',
		callback = M.enable_managed_ui,
	})

	---Disable managed UI for unfocused windows
	vim.api.nvim_create_autocmd('WinLeave', {
		pattern = '*',
		callback = M.disable_managed_ui,
	})

	---Disable managed UI for ignored filetypes
	vim.api.nvim_create_autocmd('FileType', {
		pattern = config.ignore_filetypes,
		callback = M.disable_managed_ui,
	})
end

return M
