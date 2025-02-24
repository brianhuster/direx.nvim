if vim.g.loaded_directory_plugin then
	return
end

vim.g.loaded_directory_plugin = true

local saved_files = {}

local edit = vim.cmd.edit
local au = vim.api.nvim_create_autocmd

vim.api.nvim_create_augroup('FileExplorer', {
	clear = true
})

au({ 'VimEnter', 'BufEnter' }, {
	group = 'FileExplorer',
	callback = function(args)
		if vim.fn.isdirectory(args.file) == 0 then return end
		local buf = vim.api.nvim_get_current_buf()
		require 'dir'.open(buf, args.file)
	end
})

au({ 'BufFilePost', 'ShellCmdPost' }, {
	group = 'FileExplorer',
	nested = true,
	callback = function(args)
		if vim.bo.filetype == 'directory' then
			vim.cmd.edit()
		end
	end
})

vim.keymap.set('n', '-', function()
	vim.w.prev_bufname = vim.api.nvim_buf_get_name(0)
	edit(vim.fs.dirname(vim.fs.normalize(vim.api.nvim_buf_get_name(0))))
end, { desc = 'Open parent directory' })

au('FileWritePre', {
	group = 'FileExplorer',
	callback = function(args)
		local lsp = require 'dir.lsp'
		if vim.fn.filereadable(args.file) == 0 then
			lsp.workspace.willCreateFiles({ args.match })
			saved_files[args.match] = 0
		else
			lsp.request('textDocument/willSave', {
				textDocument = vim.uri_from_fname(args.file),
				reason = 'manual'
			})
		end
	end
})

au('FileWritePost', {
	group = 'FileExplorer',
	callback = function(args)
		if saved_files[args.match] == 0 then
			require 'dir.lsp'.workspace.didCreateFiles({ args.match })
		end
		saved_files[args.match] = saved_files[args.match] + 1
	end
})
