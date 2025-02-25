vim.wo.conceallevel = 3
vim.wo.concealcursor = 'nv'
vim.bo.bufhidden = 'delete'
vim.bo.buftype = 'nowrite'
vim.bo.swapfile = false

vim.cmd.sort [[/^.*[/]/]]
vim.fn.search([[\V\C]] .. vim.fn.escape(vim.w.prev_bufname, '\\'), 'cw')

local api = vim.api
local ns_id = vim.api.nvim_create_namespace('Directory')
local buf = vim.api.nvim_get_current_buf()
local map = vim.keymap.set

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

map('n', 'grn', function()
	require 'dir'.rename()
end, { desc = 'Rename path under cursor', buffer = buf })


for _, key in ipairs { '<CR>', '<2-LeftMouse>' } do
	map('n', key, function()
		vim.cmd.edit(api.nvim_get_current_line())
	end, { desc = 'Open path under cursor', buffer = buf })
end

map('n', 'K', function()
	require 'dir'.keywordexpr()
end, { desc = 'View file or folder info', buffer = buf })

map({ 'n', 'x' }, '<Del>', function()
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

map('n', 'P', function() require 'dir'.preview(api.nvim_get_current_line()) end,
	{ buffer = buf, desc = 'Preview file or directory' })

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
	setl conceallevel< concealcursor< bufhidden< buftype< swapfile<
	silent! nunmap grn K <Del> <CR> <2-LeftMouse> !
	silent! xunmap <Del>
	augroup ft-directory
		au!
	augroup END
endf
let b:undo_ftplugin = 'call ' . expand('<SID>') . 'undo_ft_directory()'
]]
