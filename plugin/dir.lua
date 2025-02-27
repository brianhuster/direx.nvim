if vim.g.loadedndirectory_plugin then
	return
end

vim.g.loaded_directory_plugin = true

local new_created_files = {}

local api = vim.api
local edit = vim.cmd.edit
local au = api.nvim_create_autocmd

api.nvim_create_augroup('FileExplorer', { clear = true })

au({ 'VimEnter', 'BufEnter' }, {
	group = 'FileExplorer',
	callback = function(args)
		if vim.fn.isdirectory(args.file) == 0 then return end
		local buf = api.nvim_get_current_buf()
		require 'direx'.open(buf, args.file)
	end
})

au({ 'BufFilePost', 'ShellCmdPost' }, {
	group = 'FileExplorer',
	nested = true,
	callback = function(args)
		if vim.bo.filetype == 'direx' then
			vim.cmd.edit()
		end
	end
})

vim.o.grepprg = 'rg --vimgrep --max-columns=100 '

vim.keymap.set('n', '<Plug>(direx-up)', function()
	vim.w.prev_bufname = api.nvim_buf_get_name(0)
	edit(vim.fs.dirname(vim.fs.normalize(api.nvim_buf_get_name(0))))
end, { desc = 'Open parent directory' })

if vim.fn.hasmapto('<Plug>(direx-up)') == 0 then
	vim.keymap.set('n', '-', '<Plug>(direx-up)', { desc = 'Open parent directory' })
end

local command = api.nvim_create_user_command

command('FindFile', function(cmd)
	require 'direx'.find_files(cmd.args, {})
end, { nargs = '+', desc = 'Find files/folders <arg> in directory and its subdirectories, then open quickfix window' })

command('LFindFile', function(cmd)
	require 'direx'.find_files(cmd.args, { wintype = 'location' })
end, { nargs = '+', desc = 'Find files/folders <arg> in directory and its subdirectories, then open location window' })

command('Grep', function(cmd)
	require 'direx'.grep(cmd.args, {})
end, { nargs = '+', desc = 'Grep <arg> in directory and its subdirectories, then open quickfix window' })

command('LGrep', function(cmd)
	require 'direx'.grep(cmd.args, { wintype = 'location' })
end, { nargs = '+', desc = 'Grep <arg> in directory and its subdirectories, then open location window' })

au('BufWritePre', {
	group = 'FileExplorer',
	callback = function(args)
		local lsp = require 'direx.lsp'
		if vim.fn.filereadable(args.file) == 0 then
			lsp.workspace.willCreateFiles({ args.match })
			new_created_files[args.match] = true
		else
			lsp.request('textDocument/willSave', {
				textDocument = vim.uri_from_fname(args.file),
				reason = 'manual'
			})
		end
	end
})

au('BufWritePost', {
	group = 'FileExplorer',
	callback = function(args)
		if new_created_files[args.match] then
			require 'direx.lsp'.workspace.didCreateFiles({ args.match })
		end
		new_created_files[args.match] = false
	end
})
