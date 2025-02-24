vim.wo.conceallevel = 3
vim.wo.concealcursor = 'nv'
vim.bo.bufhidden = 'delete'
vim.bo.buftype = 'nowrite'
vim.bo.swapfile = false

vim.cmd.sort [[/^.*[/]/]]
vim.fn.search([[\V\C]] .. vim.fn.escape(vim.w.prev_bufname, '\\'), 'cw')

local api = vim.api
local ns_id = vim.api.nvim_create_namespace('Directory')
local bufnr = vim.api.nvim_get_current_buf()

local iconfunc = require('dir.config').iconfunc
if iconfunc then
	---@type string[]
	---@diagnostic disable-next-line: assign-type-mismatch
	local paths = vim.fn.getline(1, '$')
	for i, line in ipairs(paths) do
		local dict = iconfunc(line)
		vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, 0, {
			virt_text = { { dict.icon, dict.hl } },
			virt_text_pos = 'inline',
		})
	end
end

local map = vim.keymap.set

map('n', 'grn', function()
	require 'dir'.rename()
end, { desc = 'Rename path under cursor', buffer = true })


for _, key in ipairs { '<CR>', '<2-LeftMouse>' } do
	map('n', key, function()
		vim.cmd.edit(api.nvim_get_current_line())
	end, { desc = 'Open path under cursor', buffer = true })
end

map('n', 'K', function()
	require 'dir'.keywordexpr()
end, { desc = 'View file or folder info', buffer = true })

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

vim.b.undo_ftplugin = "setl conceallevel< concealcursor<"
