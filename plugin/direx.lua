if vim.g.loaded_direx then
	return
end

vim.g.loaded_direx = true

local new_created_files = {}

local api = vim.api
local edit = vim.cmd.edit
local au = api.nvim_create_autocmd

api.nvim_create_augroup('FileExplorer', { clear = true })

if require('direx.config').default then
	au({ 'VimEnter', 'BufEnter' }, {
		group = 'FileExplorer',
		callback = function(args)
			if vim.fn.isdirectory(args.file) == 0 then return end
			local buf = api.nvim_get_current_buf()
			require 'direx'.open(buf, args.file)
		end
	})
end

au({ 'BufFilePost', 'ShellCmdPost' }, {
	group = 'FileExplorer',
	nested = true,
	callback = function(args)
		if vim.bo.filetype == 'direx' then
			vim.cmd.edit()
		end
	end
})

local command = api.nvim_create_user_command

command('Direx', function(cmd)
	vim.w.prev_bufname = api.nvim_buf_get_name(0)
	local dir = cmd.args
	if dir == '' then
		if vim.bo.ft == 'direx' then
			return edit()
		end
		local bufname = api.nvim_buf_get_name(0)
		dir = #bufname > 0 and require('direx.fs').parent(bufname) or vim.fn.getcwd()
	end
	require 'direx'.open(nil, dir)
end, { nargs = '*' })

command('Find', function(cmd)
	require 'direx'.find(cmd.args, {})
end, { nargs = '+', desc = 'Find files/folders <arg> in directory and its subdirectories, then open quickfix window' })

command('Grep', function(cmd)
	local pattern = require 'direx.utils'.get_grep_pattern(cmd)
	require 'direx'.grep(pattern, {})
end, { nargs = '+', desc = 'Grep <arg> in directory and its subdirectories, then open quickfix window' })

vim.keymap.set('n', '<Plug>(direx-up)', function()
	local bufname = vim.api.nvim_buf_get_name(0)
	local dir = #bufname > 0 and require('direx.fs').parent(bufname) or vim.fn.getcwd()
	vim.cmd.Direx(dir)
end, { desc = 'Open parent directory' })

if vim.fn.hasmapto('<Plug>(direx-up)') == 0 then
	vim.keymap.set('n', '-', '<Plug>(direx-up)', { desc = 'Open parent directory' })
end

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

vim.api.nvim_create_autocmd('VimLeavePre', {
	callback = function()
		require 'direx'.killGrepProcess()
	end
})
