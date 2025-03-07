local M = {}
local api = vim.api
local ws = require 'direx.lsp'.workspace
---@module 'direx.fs'
local dirfs = setmetatable({}, { __index = function(_, k) return require('direx.fs')[k] end })

---@type { type: 'copy'|'move', paths: string[] }
M.pending_operations = {}

---@type vim.SystemObj?
M.grep_process = nil

---@param target string
local function moveCursorTo(target)
	vim.fn.search('\\V' .. vim.fn.escape(target, '\\') .. '\\$')
end

function M.killGrepProcess()
	if M.grep_process and not M.grep_process:is_closing() then
		M.grep_process:kill('SIGTERM')
	end
end

---@param dir string
---@param bufnr number?
function M.open(bufnr, dir)
	if vim.o.autochdir then
		vim.notify("Direx may not work properly with 'autochdir', please turn it off", vim.log.levels.WARN)
	end
	vim.validate('path', dir, 'string')
	dir = vim.fs.normalize(dir)
	if dir:sub(-1) ~= '/' then
		dir = dir .. '/'
	end

	if not bufnr then
		bufnr = vim.fn.bufnr(dir, true)
	end

	vim.api.nvim_buf_set_name(bufnr, dir)

	local paths = vim.fn.readdir(dir)
	paths = vim.tbl_map(function(p)
		p = dir .. p
		if vim.fn.isdirectory(p) == 1 then
			return p .. '/'
		end
		return p
	end, paths)
	api.nvim_buf_set_lines(bufnr, 0, -1, false, paths)
	vim.bo[bufnr].filetype = 'direx'
end

function M.rename()
	local oldname = api.nvim_get_current_line()
	local newname = vim.fn.input('New name: ', oldname, 'file')
	if oldname == newname or #newname == 0 then
		return
	end
	ws.willRenameFiles { { oldname, newname } }
	local success = dirfs.rename(oldname, newname)
	if not success then return end
	ws.didRenameFiles { { oldname, newname } }
	vim.cmd.edit()
end

--- Use for `K` mapping
--- @param path string?
function M.hover(path)
	if not path then
		path = api.nvim_get_current_line()
	end
	local stat = vim.uv.fs_stat(path)
	if not stat then
		return
	end
	local mode = dirfs.inspect_mode(stat.mode)
	local size = dirfs.inspect_bytes(stat.size)
	local type = stat.type
	local function date(sec)
		return os.date('%Y-%m-%d %H:%M:%S', sec)
	end
	vim.lsp.util.open_floating_preview({
		('%s %s %s'):format(type, size, mode),
		'Created: ' .. date(stat.birthtime.sec),
		'Accessed: ' .. date(stat.atime.sec),
		'Modified: ' .. date(stat.mtime.sec),
		'Changed: ' .. date(stat.ctime.sec),
	}, 'markdown')
end

---@param paths string[]
---@param opts { trash: boolean?, confirm: boolean? }?
function M.remove(paths, opts)
	opts = opts or {}
	if opts.confirm then
		local confirm = vim.fn.confirm(
			'Are you sure you want to ' ..
			(opts.trash and 'trash' or 'delete') .. ' these files?\n' .. table.concat(paths, '\n'),
			'&Yes\n&No',
			2)
		if confirm ~= 1 then
			return
		end
	end

	local will_delete_files = vim.tbl_map(function(v)
		return { v }
	end, paths)
	ws.willDeleteFiles(will_delete_files)
	local did_delete_files = {}
	for _, path in ipairs(paths) do
		local success = opts.trash and dirfs.trash(path) or dirfs.remove(path)
		if success then
			table.insert(did_delete_files, { path })
		end
	end
	ws.didDeleteFiles(did_delete_files)
	vim.cmd.edit()
end

---@param fmt string
---@param dir string
---@param items string[]
function M.shdo(fmt, dir, items)
	vim.cmd.new()
	vim.cmd.lcd({ args = { dir }, mods = { silent = true } })
	vim.fn.setline(1, '#!' .. vim.o.shell)
	vim.fn.setline(2, 'cd ' .. vim.fn.shellescape(vim.fn.getcwd()))

	for _, item in ipairs(items) do
		local line = fmt:gsub('{([^}]*)}', function(mod)
			return vim.fn.fnamemodify(item, mod:sub(2))
		end)
		vim.fn.append(vim.fn.line('$'), line)
	end
	vim.cmd.filetype 'detect'
end

---@param path string
function M.preview(path)
	if path:sub(-1) == '/' then
		local buf, _ = vim.lsp.util.open_floating_preview(
			{ ' ' }, 'direx',
			{ border = 'rounded', width = 50, height = 20 })
		vim.bo[buf].modifiable = true
		M.open(buf, path)
	else
		vim.lsp.util.open_floating_preview(vim.fn.readfile(path, '', 20),
			vim.filetype.match({ filename = path }) or 'text',
			{ border = 'rounded', max_width = 50, max_height = 20 })
	end
end

---@param paths string[] paths to prepare for copy. If in visual mode, leave empty
function M.copy(paths)
	M.pending_operations = {
		type = 'copy',
		paths = paths,
	}
	vim.notify('Copied ' .. #paths .. ' files')
end

---@param paths string[] paths to prepare for move. If in visual mode, leave empty
function M.cut(paths)
	M.pending_operations = {
		type = 'move',
		paths = paths,
	}
	vim.notify('Cut ' .. #paths .. ' files')
end

function M.paste()
	local newpath ---@type string?
	local oldpaths = M.pending_operations.paths
	local type = M.pending_operations.type
	local new_dir = api.nvim_buf_get_name(0)
	M.pending_operations.paths = {}
	if type == 'copy' then
		for _, target in ipairs(oldpaths) do
			newpath = vim.fs.joinpath(new_dir, dirfs.basename(target))
			local success = dirfs.copy(target, newpath)
			if not success then
				vim.notify(string.format("Failed to copy %s", target), vim.log.levels.ERROR)
				return
			end
		end
	elseif type == 'move' then
		for _, target in ipairs(oldpaths) do
			newpath = vim.fs.joinpath(new_dir, dirfs.basename(target))
			local success = dirfs.rename(target, newpath)
			if not success then
				vim.notify(string.format("Failed to move %s", target), vim.log.levels.ERROR)
				return
			end
		end
	end
	vim.cmd.edit()
	if newpath then
		moveCursorTo(newpath)
	end
end

---@param pattern string
---@param opts { wintype: 'quickfix'|'location'?, dir: string? }
function M.find(pattern, opts)
	local default_opts = {
		wintype = 'quickfix',
		dir = vim.fn.getcwd(),
	}
	opts = vim.tbl_deep_extend('force', default_opts, opts)
	local files = vim.fn.glob(vim.fs.joinpath(opts.dir, '**/') .. pattern,
		false, true)
	if #files == 0 then
		vim.notify('No files found', vim.log.levels.WARN)
		return
	end
	local dir = opts.dir or vim.fn.getcwd()
	if dir:sub(-1) ~= '/' then
		dir = dir .. '/'
	end
	---@param wintype 'location'|'quickfix'
	---@param ... any see :h setqflist()
	---@return boolean
	local setlist = function(wintype, ...)
		return (wintype == 'location' and vim.fn.setloclist(0, ...) or vim.fn.setqflist(...)) == 0
	end
	local getlist = function(wintype, ...)
		return wintype == 'location' and vim.fn.getloclist(0, ...) or vim.fn.getqflist(...)
	end
	setlist(opts.wintype, {}, 'r', {
		lines = files,
		efm = '%f',
		title = 'Find ' .. pattern .. ' from ' .. dir,
		quickfixtextfunc = function(info)
			local items = getlist(opts.wintype, { id = info.id, items = 1 }).items
			local l = {}
			for idx = info.start_idx, info.end_idx do
				local bufname = api.nvim_buf_get_name(items[idx].bufnr)
				table.insert(l, require('direx.fs').isdirectory(bufname) and bufname .. '/' or bufname)
			end
			return l
		end
	})
	vim.cmd(opts.wintype == 'location' and 'lopen' or 'copen')
	vim.b._direx = dir
	vim.cmd.runtime 'syntax/direxfind.vim'
	vim.cmd.runtime 'ftplugin/direx_find.lua'
end

---@param pattern string
---@param opts { wintype: 'quickfix'|'location'?, dir: string? }
function M.grep(pattern, opts)
	M.killGrepProcess()
	local grepprg, grepfm, shell, shellcmdflag = vim.o.grepprg, vim.o.grepformat, vim.o.shell, vim.o.shellcmdflag
	local win = vim.api.nvim_get_current_win()
	local cwd = opts.dir or vim.fn.getcwd()
	local default_opts = {
		wintype = 'quickfix',
	}
	opts = vim.tbl_deep_extend('force', default_opts, opts)

	if #grepprg == 0 or grepprg == 'internal' then
		vim.notify('No grepprg set', vim.log.levels.WARN)
		return
	end

	local function setlist(list, action)
		list = vim.tbl_filter(function(v) return v ~= '' end, list)
		local dict = {
			lines = list,
			title = "Grep " .. pattern .. " from " .. cwd,
			efm = grepfm,
			quickfixtextfunc = ""
		}
		return opts.wintype == 'location' and vim.fn.setloclist(win, {}, action, dict) or
			vim.fn.setqflist({}, action, dict)
	end

	setlist({}, 'r')

	local grepcmd = vim.tbl_map(function(v)
		return (v == '' or v == '$*') and pattern
			or ((v:sub(1, 1) == '%' or v:sub(1, 1) == '#' or v:sub(1, 1) == '<') and vim.fn.expand(v))
			or v
	end, vim.split(grepprg, ' '))
	if require('direx.config').grep.parse_args == 'shell' then
		grepcmd = { shell, shellcmdflag, table.concat(grepcmd, ' ') }
	end
	local grep_qflist_lines_num = 0
	local temporary = {
		lines = {},
		sync_with_qflist = false,
	}
	vim.cmd(opts.wintype == 'quickfix' and 'copen' or 'lopen')
	vim.b._direx = cwd
	local winheight = vim.api.nvim_win_get_height(0)

	api.nvim_create_autocmd('CursorMoved', {
		buffer = 0,
		callback = function(args)
			local lnum = vim.fn.getpos('.')[2]
			if lnum + winheight >= grep_qflist_lines_num then
				if not temporary.sync_with_qflist then
					local list = temporary.lines
					for i, v in ipairs(list) do
						if v ~= '' then
							list[i] = vim.fs.joinpath(cwd, v)
						end
					end
					setlist(list, 'a')
					temporary.sync_with_qflist = true
					temporary.text = ''
					grep_qflist_lines_num = vim.fn.line('$')
				end
			end
		end
	})


	M.grep_process = vim.system(grepcmd, {
		text = true,
		cwd = cwd,
		timeout = require('direx.config').grep.timeout,
		stdout = function(_, data)
			if not data or data == '' or data == '\n' then return end
			local datalist = vim.split(data, '\n')
			datalist = vim.tbl_map(function(v) return v:sub(1, 200) end, datalist)
			temporary.lines = vim.list_extend(temporary.lines, datalist)
			temporary.sync_with_qflist = false
			if grep_qflist_lines_num < 2 * winheight and not temporary.sync_with_qflist then
				vim.schedule(function()
					local list = temporary.lines
					for i, v in ipairs(list) do
						if v ~= '' then
							list[i] = vim.fs.joinpath(cwd, v)
						end
					end
					setlist(list, 'a')
					temporary.sync_with_qflist = true
					temporary.lines = {}
				end)
			end
		end
	}, function(data)
		print(data.stderr or '')
	end)
end

---@param cmd table Similar to the result of nvim_parse_cmd()
---@param opts { dir: string? }
function M.fzf(cmd, opts)
	local tempfile = vim.fn.tempname()
	local buf = vim.api.nvim_create_buf(false, false)
	vim.api.nvim_set_current_buf(buf)
	vim.fn.jobstart('fzf ' .. cmd.args .. ' > ' .. tempfile, {
		term = true,
		cwd = opts.dir,
		on_exit = function(_, code)
			if code == 0 then
				local fname = vim.fn.readfile(tempfile)[1]
				if vim.fn.isabsolutepath(fname) == 0 then
					fname = vim.fs.joinpath(opts.dir or '', fname)
				end
				vim.cmd.edit(fname)
				vim.api.nvim_buf_delete(buf, { force = true })
			end
		end
	})
	vim.cmd.startinsert()
	vim.keymap.set('t', '<Esc>', function()
		vim.fn.jobstop(vim.bo.channel)
		vim.api.nvim_buf_delete(buf, { force = true })
	end)
end

return M
