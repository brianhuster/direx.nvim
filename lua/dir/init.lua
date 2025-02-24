local M = {}
local api = vim.api
local fs = vim.fs
local ws = require('dir.lsp').workspace

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
	dir = fs.abspath(dir)
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
	local oldname = vim.fn.getline('.')
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
	---@param mode number
	---@return string
	local function mode_to_human_readable(mode)
		local bit = require('bit')
		local types = {
			[0xC000] = 's', -- socket
			[0xA000] = 'l', -- symbolic link
			[0x8000] = '-', -- regular file
			[0x6000] = 'b', -- block device
			[0x4000] = 'd', -- directory
			[0x2000] = 'c', -- character device
			[0x1000] = 'p', -- FIFO
		}
		local permissions = {
			[0] = '---',
			[1] = '--x',
			[2] = '-w-',
			[3] = '-wx',
			[4] = 'r--',
			[5] = 'r-x',
			[6] = 'rw-',
			[7] = 'rwx',
		}
		local file_type = types[bit.band(mode, 0xF000)] or '?'
		local owner_perms = permissions[bit.rshift(bit.band(mode, 0x01C0), 6)]
		local group_perms = permissions[bit.rshift(bit.band(mode, 0x0038), 3)]
		local other_perms = permissions[bit.band(mode, 0x0007)]
		return file_type .. owner_perms .. group_perms .. other_perms
	end

	local function bytes_to_human_readable(bytes)
		local units = { "B", "KB", "MB", "GB", "TB" }
		local scale = 1024
		local unit_index = 1
		while bytes >= scale and unit_index < #units do
			bytes = bytes / scale
			unit_index = unit_index + 1
		end
		return string.format("%.2f%s", bytes, units[unit_index])
	end

	local path = vim.fn.getline('.')
	local stat = vim.uv.fs_stat(path)
	if not stat then
		return
	end
	local mode = mode_to_human_readable(stat.mode)
	local size = bytes_to_human_readable(stat.size)
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
	-- get current mode
	---@type string[]
	local paths = {}
	local mode = api.nvim_get_mode().mode
	if mode == 'n' then
		paths = { vim.fn.getline('.') }
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

return M
