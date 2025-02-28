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

local function get_grep_pattern(cmd)
	if cmd.args then return cmd.args end
	local pattern
	if cmd.range > 0 then
		local pos1, pos2 = api.nvim_buf_get_mark(0, '<'), vim.api.nvim_buf_get_mark(0, '>')
		pattern = api.nvim_buf_get_text(0, pos1[1] - 1, pos1[2], pos2[1] - 1, pos2[2], {})
		if type(pattern) == 'table' then
			pattern = table.concat(pattern, '\n')
		end
	else
		pattern =  vim.fn.expand('<cword>')
	end
	if require('direx.config').grep.parse_args == 'shell' then
		pattern = vim.fn.shellescape(pattern)
	end
	return pattern
end

command('Grep', function(cmd)
	local pattern = get_grep_pattern(cmd)
	require 'direx'.grep(pattern, {})
end, { nargs = '+', desc = 'Grep <arg> in directory and its subdirectories, then open quickfix window' })

command('LGrep', function(cmd)
	local pattern = get_grep_pattern(cmd)
	require 'direx'.grep(pattern, { wintype = 'location' })
end, { nargs = '+', desc = 'Grep <arg> in directory and its subdirectories, then open location window' })

vim.api.nvim_create_autocmd('VimLeavePre', {
	callback = function()
		require 'direx'.killGrepProcess()
	end
})
