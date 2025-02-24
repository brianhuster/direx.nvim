vim.wo.conceallevel = 3
vim.wo.concealcursor = 'nv'
vim.bo.bufhidden = 'delete'
vim.bo.buftype = 'nowrite'
vim.bo.swapfile = false

vim.keymap.set('n', 'grn', function()
	require 'dir'.rename()
end, { desc = 'Rename path under cursor', buffer = true })

vim.keymap.set('n', '.', function()
	--
end, { desc = "Execute file under cursor", buffer = true })

vim.keymap.set('n', '<CR>', function()
	vim.cmd.edit(vim.fn.getline('.'))
end, { desc = 'Open path under cursor', buffer = true })

vim.keymap.set('n', 'K', function()
	require 'dir'.keywordexpr()
end, { desc = 'View file or folder info', buffer = true })

vim.keymap.set({ 'n', 'x' }, '<Del>', function()
	require 'dir'.remove()
end, { desc = 'Remove files/folders under cursor or selected in visual mode', buffer = true })

vim.b.undo_ftplugin = "setl conceallevel< concealcursor<"
