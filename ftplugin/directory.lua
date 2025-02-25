vim.wo[0][0].conceallevel = 3
vim.wo[0][0].concealcursor = 'nvc'
vim.wo[0][0].wrap = false
vim.bo.bufhidden = 'delete'
vim.bo.buftype = 'nowrite'
vim.bo.swapfile = false

vim.cmd.sort [[/^.*[/]/]]
vim.fn.search([[\V\C]] .. vim.fn.escape(vim.w.prev_bufname, '\\'), 'cw')

local api = vim.api
local ns_id = vim.api.nvim_create_namespace('Directory')
local buf = vim.api.nvim_get_current_buf()
local map = vim.keymap.set
local config = require('dir.config')

local function add_icons()
	vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
	local iconfunc = require('dir.config').iconfunc
	if iconfunc then
		---@type string[]
		---@diagnostic disable-next-line: assign-type-mismatch
		local paths = vim.fn.getline(1, '$')
		for i, line in ipairs(paths) do
			local dict = iconfunc(line)
			vim.api.nvim_buf_set_extmark(buf, ns_id, i - 1, 0, {
				virt_text = { { dict.icon, dict.hl } },
				virt_text_pos = 'inline',
			})
		end
	end
end

add_icons()

for _, key in ipairs { '<CR>', '<2-LeftMouse>' } do
	map('n', key, function()
		vim.cmd.edit(api.nvim_get_current_line())
	end, { buffer = true })
end

map('n', config.keymaps.rename, function()
	require 'dir'.rename()
end, { desc = 'Rename path under cursor', buffer = buf })


map('n', config.keymaps.hover, function()
	require 'dir'.hover()
end, { desc = 'View file or folder info', buffer = buf })

map({ 'n', 'x' }, config.keymaps.remove, function()
	require 'dir'.remove()
end, { desc = 'Remove files/folders under cursor or selected in visual mode', buffer = true })

map('n', '!', function()
	local function feedkeys(key)
		api.nvim_feedkeys(vim.keycode(key), 'n', true)
	end

	feedkeys(':<C-U><Space>')
	local path = vim.fn.shellescape(api.nvim_get_current_line(), true)
	feedkeys(path .. '<C-b>!')
end, {})

if config.keymaps.preview then
	map('n', config.keymaps.preview, function()
		require 'dir'.preview(api.nvim_get_current_line())
	end, { desc = 'Preview file or directory', buffer = true })
end

if config.keymaps.copy then
	map({ 'x' }, config.keymaps.copy, function()
		require 'dir'.copy()
	end, { desc = 'Copy path under cursor or selected in visual mode', buffer = true })
	map('n', config.keymaps.copy .. config.keymaps.copy:sub(-1), function()
		require 'dir'.copy({ vim.api.nvim_get_current_line() })
	end, { desc = 'Copy path under cursor and append to clipboard', buffer = true })
end

if config.keymaps.move then
	map({ 'x' }, config.keymaps.move, function()
		require 'dir'.move()
	end, { desc = 'Move paths', buffer = true })
	map('n', config.keymaps.move .. config.keymaps.move:sub(-1), function()
		require 'dir'.move({ vim.api.nvim_get_current_line() })
	end, { desc = 'Move path under cursor', buffer = true })
end

if config.keymaps.paste then
	map('n', config.keymaps.paste, function()
		require 'dir'.paste()
	end, { desc = 'Paste paths', buffer = true })
end

if config.keymaps.argadd then
	map({ 'n', 'x' }, config.keymaps.argadd, function()
		require 'dir'.argadd()
	end, { desc = 'Add paths to argument list', buffer = true })
end

if config.keymaps.argdelete then
	map({ 'n', 'x' }, config.keymaps.argdelete, function()
		require 'dir'.argdelete()
	end, { desc = 'Delete paths from argument list', buffer = true })
end

api.nvim_create_user_command('Shdo', function(args)
	local lines = args.range > 0 and api.nvim_buf_get_lines(0, args.line1 - 1, args.line2, false) or nil
	require 'dir'.shdo(args.args, vim.fs.abspath(api.nvim_buf_get_name(0)), lines)
end, {
	range = true,
	nargs = '?',
	complete = 'shellcmd',
	desc = 'Execute shell command with optional range and arguments'
})

local augroup = vim.api.nvim_create_augroup('ft-directory', { clear = true })

vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedP', 'InsertLeave' }, {
	buffer = buf,
	group = augroup,
	callback = function()
		add_icons()
	end
})

vim.cmd [[
func! s:undo_ft_directory()
	setl conceallevel< concealcursor< bufhidden< buftype< swapfile< wrap<
	silent! nunmap grn K <Del> <CR> <2-LeftMouse> !
	silent! xunmap <Del>
	augroup ft-directory | au! | augroup END
endf
let b:undo_ftplugin = 'call ' . expand('<SID>') . 'undo_ft_directory()'
]]
