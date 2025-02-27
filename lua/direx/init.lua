local M = {}
local api = vim.api
local ws = require 'direx.lsp'.workspace
---@module 'direx.fs'
local dirfs = setmetatable({}, { __index = function(_, k) return require('direx.fs')[k] end })

---@type { type: 'copy'|'move', paths: string[] }
M.pending_operations = {}

---@param target string
local function moveCursorTo(target)
	vim.fn.search('\\V' .. vim.fn.escape(target, '\\') .. '\\$')
end

---@param dir string
---@param bufnr number
function M.open(bufnr, dir)
	vim.validate('path', dir, 'string')
	dir = vim.fs.abspath(dir)
	if dir:sub(-1) ~= '/' then
		dir = dir .. '/'
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
function M.hover()
	local path = api.nvim_get_current_line()
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
---@param opts { wintype: 'quickfix'|'location'? }
function M.find_files(pattern, opts)
	local default_opts = {
		wintype = 'quickfix',
	}
	local in_direx_win = vim.bo[api.nvim_win_get_buf(0)].ft == 'direx'
	opts = vim.tbl_deep_extend('force', default_opts, opts)
	local files = vim.fn.glob((in_direx_win and '%**/' or './**/') .. pattern,
		false, true)
	if #files == 0 then
		vim.notify('No files found', vim.log.levels.WARN)
		return
	end
	local dir = in_direx_win and api.nvim_buf_get_name(0) or vim.uv.cwd()
	---@param wintype 'location'|'quickfix'
	---@param ... any see :h setqflist()
	---@return boolean
	local setlist = function(wintype, ...)
		return (wintype == 'location' and vim.fn.setloclist(0, ...) or vim.fn.setqflist(...)) == 0
	end
	setlist(opts.wintype, {}, 'r', {
		lines = files, efm = '%f', title = 'Find ' .. pattern .. ' from ' .. dir
	})
	vim.cmd(opts.wintype == 'location' and 'lopen' or 'copen')
	vim.bo.ft = 'direxfindfile'
end

---@param pattern string
---@param opts { wintype: 'quickfix'|'location'? }
function M.grep(pattern, opts)
	local grepcmd = vim.split(vim.o.grepprg, ' ')
	local win = vim.api.nvim_get_current_win()
	local in_direx_win = vim.bo[api.nvim_win_get_buf(win)].ft == 'direx'
	local cwd = in_direx_win and api.nvim_buf_get_name(0) or vim.uv.cwd()
	local default_opts = {
		wintype = 'quickfix',
	}
	opts = vim.tbl_deep_extend('force', default_opts, opts)
	if #grepcmd == 0 then
		vim.notify('No grepprg set', vim.log.levels.ERROR)
		return
	end

	grepcmd = vim.tbl_map(function(v)
		if v == '' or v == '%s' then
			return pattern
		elseif v == '%' or v == '#' then
			return vim.fn.expand(v)
		end
		return v
	end, grepcmd)
	vim.cmd(opts.wintype == 'quickfix' and 'copen' or 'lopen')
	local function setlist(list)
		local dict = {
			lines = list,
			title = "Grep " .. pattern .. " from " .. cwd,
			efm = vim.o.grepformat,
		}
		return opts.wintype == 'location' and vim.fn.setloclist(win, {}, 'r', dict) or vim.fn.setqflist({}, 'r', dict)
	end
	local grep_result = '' ---@type string
	vim.system(grepcmd, {
		text = true,
		cwd = cwd,
		stdout = vim.schedule_wrap(function(_, data)
			if not data then return end
			grep_result = grep_result .. data
			setlist(vim.split(grep_result, '\n'))
		end)
	}, function(data)
		print(data.stderr or '')
	end)
end

return M
