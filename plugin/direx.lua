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

au({ 'ShellCmdPost' }, {
	group = 'FileExplorer',
	nested = true,
	callback = function(_)
		if vim.bo.filetype == 'direx' then
			vim.cmd.Direx()
		end
	end
})

local command = api.nvim_create_user_command

---@return string
local function get_dir()
	if vim.bo.ft == 'direx' then
		return vim.api.nvim_buf_get_name(0)
	elseif vim.bo.ft == 'qf' and vim.b._direx then
		return vim.b._direx
	else
		return vim.fn.getcwd()
	end
end

command('Direx', function(cmd)
	vim.w._direx_prev_bufname = vim.fn.expand '%'
	local dir = cmd.args
	if dir == '' then
		if vim.bo.ft == 'direx' then
			return edit()
		end
		local bufname = api.nvim_buf_get_name(0)
		dir = #bufname > 0 and require('direx.fs').parent(bufname) or vim.fn.getcwd()
	end
	vim.cmd.edit(vim.fn.expandcmd(dir))
	require 'direx'.open(nil, dir)
end, { nargs = '*' })

command('DirexFind', function(cmd)
	require 'direx'.find(cmd.args, { dir = cmd.bang and get_dir() or nil })
end, { nargs = '+', bang = true,
	desc = 'Find files/folders <arg> in directory and its subdirectories, then open quickfix window' })

command('DirexLFind', function(cmd)
	require 'direx'.find(cmd.args, { wintype = 'location', dir = cmd.bang and get_dir() or nil })
end, { nargs = '+', bang = true, desc = 'Find files/folders <arg> in directory and its subdirectories, then open location window' })

command('DirexGrep', function(cmd)
	local pattern = require 'direx.utils'.get_grep_pattern(cmd)
	require 'direx'.grep(pattern, { dir = cmd.bang and get_dir() or nil })
end, { nargs = '+', bang = true, desc = 'Grep <arg> in directory and its subdirectories, then open quickfix window' })

command('DirexLGrep', function(cmd)
	local pattern = require 'direx.utils'.get_grep_pattern(cmd)
	require 'direx'.grep(pattern, { wintype = 'location', dir = cmd.bang and get_dir() or nil })
end, { nargs = '+', bang = true, desc = 'Grep <arg> in directory and its subdirectories, then open location window' })

command('DirexFzf', function(cmd)
	require 'direx'.fzf(cmd, { dir = cmd.bang and get_dir() or nil })
end, { nargs = '*', bang = true, desc = 'Fuzzy finder' })

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
			lsp.workspace.willCreateFiles {{ args.match }}
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
			require 'direx.lsp'.workspace.didCreateFiles {{ args.match }}
		end
		new_created_files[args.match] = false
	end
})

vim.api.nvim_create_autocmd('VimLeavePre', {
	callback = function()
		require 'direx'.killGrepProcess()
	end
})
