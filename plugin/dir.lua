if vim.g.loaded_directory_plugin then
	return
end

vim.g.loaded_directory_plugin = true

local saved_files = {}

local api = vim.api
local edit = vim.cmd.edit
local au = api.nvim_create_autocmd
local config = require 'dir.config'

api.nvim_create_augroup('FileExplorer', {
	clear = true
})

au({ 'VimEnter', 'BufEnter' }, {
	group = 'FileExplorer',
	callback = function(args)
		if vim.fn.isdirectory(args.file) == 0 then return end
		local buf = api.nvim_get_current_buf()
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
	vim.w.prev_bufname = api.nvim_buf_get_name(0)
	edit(vim.fs.dirname(vim.fs.normalize(api.nvim_buf_get_name(0))))
end, { desc = 'Open parent directory' })

vim.api.nvim_create_user_command('Find', function(args)
	local files = vim.fn.glob((vim.bo[api.nvim_win_get_buf(0)].ft == 'directory' and '%**/' or './**/') .. args.args,
		false, true)
	if #files == 0 then
		vim.notify('No files found', vim.log.levels.WARN)
		return
	end
	local dir = vim.bo.ft == 'directory' and api.nvim_buf_get_name(0) or vim.uv.cwd()
	vim.fn.setloclist(0, {}, 'r', {
		lines = vim.fn.glob((vim.bo.ft == 'directory' and '%**/' or './**/') .. args.args, false, true),
		efm = '%f',
		title = 'Find ' .. args.args .. ' from ' .. dir
	})
	vim.cmd.lopen()
end, { nargs = '+', desc = 'Find file <arg> in directory and its subdirectories' })

au('FileWritePre', {
	group = 'FileExplorer',
	callback = function(args)
		error(vim.inspect(args))
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
		error(vim.inspect(args))
		if saved_files[args.match] == 0 then
			require 'dir.lsp'.workspace.didCreateFiles({ args.match })
		end
		saved_files[args.match] = saved_files[args.match] + 1
	end
})
