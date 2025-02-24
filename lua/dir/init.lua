local M = {}
local api = vim.api
local ws = require('dir.lsp').workspace

---@type { type: 'copy'|'move', paths: string[] }
local pending_operations = {}

---@return string[]
local function get_visual_lines()
	local line_start = api.nvim_buf_get_mark(0, "<")[1]
	local line_end = api.nvim_buf_get_mark(0, ">")[1]

	if line_start > line_end then
		line_start, line_end = line_end, line_start
	end

	--- Nvim API indexing is zero-based, end-exclusive
	local lines = api.nvim_buf_get_lines(0, line_start - 1, line_end, false)

	return lines
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
	vim.bo[bufnr].filetype = 'directory'
end

function M.rename()
	local oldname = api.nvim_get_current_line()
	local newname = vim.fn.input('Rename to ', oldname, 'file')
	if oldname == newname or #newname == 0 then
		return
	end
	ws.willRenameFiles { { oldname, newname } }
	local success, err, errname = vim.uv.fs_rename(oldname, newname)
	if not success then
		vim.notify(err .. ' ' .. errname, vim.log.levels.ERROR)
		return
	end
	ws.didRenameFiles { { oldname, newname } }
	vim.cmd.edit()
end

--- Use for `K` mapping
function M.keywordexpr()
	local fs = require 'dir.fs'
	local path = api.nvim_get_current_line()
	local stat = vim.uv.fs_stat(path)
	if not stat then
		return
	end
	local mode = fs.inspect_mode(stat.mode)
	local size = fs.inspect_bytes(stat.size)
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

function M.remove()
	---@type string[]
	local paths = {}
	local mode = api.nvim_get_mode().mode
	if mode == 'n' then
		paths = { api.nvim_get_current_line() }
	else
		paths = get_visual_lines()
	end
	local confirm = vim.fn.confirm(
		'Are you sure you want to delete these files?\n' .. table.concat(paths, '\n'),
		'&Yes\n&No',
		2)
	if confirm ~= 1 then
		return
	end

	local will_delete_files = vim.tbl_map(function(v)
		return { v }
	end, paths)
	ws.willDeleteFiles(will_delete_files)
	local did_delete_files = {}
	for _, path in ipairs(paths) do
		local success = vim.fn.delete(path, 'rf') == 0
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

	items = items or vim.fn.argv()
	for _, item in ipairs(items) do
		local line = fmt:gsub('{([^}]*)}', function(mod)
			return vim.fn.fnamemodify(item, mod:sub(2, -2))
		end)
		vim.fn.append(vim.fn.line('$'), line)
	end
	vim.cmd.filetype 'detect'
end

return M
