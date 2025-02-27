local M = {}

local uv = vim.uv
local fs = vim.fs

---@param path string
---@return string
function M.basename(path)
	return vim.fs.basename(path:sub(-1) == '/' and path:sub(1, -2) or path)
end

---@param filename string
---@return boolean
M.mkfile = function(filename)
	local dirname = vim.fs.dirname(filename)
	if vim.fn.isdirectory(dirname) == 0 then
		local has_parent = M.mkdir(dirname)
		if not has_parent then
			vim.notify(
				("Failed to create %s"):format(dirname),
				vim.log.levels.ERROR)
			return false
		end
	end
	return vim.fn.writefile({}, filename) == 0
end

---@param path string
---@return boolean
function M.mkdir(path)
	return vim.fn.mkdir(path, 'p') == 1
end

---@param file string
---@param newpath string
---@return boolean
function M.copyfile(file, newpath)
	local success, errname, errmsg = uv.fs_copyfile(file, newpath)
	if not success then
		vim.notify(string.format("%s: %s", errname, errmsg), vim.log.levels.ERROR)
	end
	return not not success
end

-- Copy dir recursively
---@param dir string
---@param newpath string
---@return boolean
function M.copydir(dir, newpath)
	local handle = uv.fs_scandir(dir)
	if not handle then
		return false
	end
	local success, errname, errmsg = uv.fs_mkdir(newpath, 493)
	if not success then
		vim.notify(string.format("%s: %s", errname, errmsg), vim.log.levels.ERROR)
		return false
	end

	success = true
	while true do
		local name, type = uv.fs_scandir_next(handle)
		if not name then
			break
		end
		local filepath = fs.joinpath(dir, name)
		if type == "directory" then
			success = M.copydir(filepath, fs.joinpath(newpath, name))
		elseif type == "file" then
			success = M.copyfile(filepath, fs.joinpath(newpath, name))
		elseif type == "link" then
			success = M.copylink(filepath, fs.joinpath(newpath, name))
		end
	end
	return not not success
end

---@param oldpath string
---@param newpath string
---@return boolean
function M.copylink(oldpath, newpath)
	local target = uv.fs_readlink(oldpath)
	if target then
		if vim.b.dirvish_sudo then
			M.sudo_exec({ 'cp', oldpath, newpath })
			return vim.v.shell_error == 0
		end
		local success, errname, errmsg = uv.fs_symlink(target, newpath)
		return not not success
	end
	return false
end

---@param oldpath string
---@param newpath string
---@return boolean
function M.copy(oldpath, newpath)
	---@diagnostic disable-next-line: param-type-mismatch
	local stat = vim.uv.fs_lstat(oldpath)
	local type = stat and stat.type
	if type == 'directory' then
		return M.copydir(oldpath, newpath)
	elseif type == 'file' then
		return M.copyfile(oldpath, newpath)
	elseif type == 'link' then
		return M.copylink(oldpath, newpath)
	end
	return false
end

---@param oldname string
---@param newname string
---@return boolean
function M.rename(oldname, newname)
	-- local success, err, errname = vim.uv.fs_rename(oldname, newname)
	-- if not success then
	-- 	success = M.copy(oldname, newname)
	-- 	if success then
	-- 		return M.remove(oldname)
	-- 	else
	-- 		vim.notify("Copy not successful. Old path will be kept")
	-- 	end
	-- end
	-- return false
	return vim.fn.rename(oldname, newname) == 0
end

---@param path string
---@return boolean
function M.remove(path)
	return vim.fn.isdirectory(path) == 1 and vim.fn.delete(path, 'rf') == 0 or vim.fn.delete(path, 'rf') == 0
end

---@param mode number
---@return string
function M.inspect_mode(mode)
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

---@param bytes number
---@return string
function M.inspect_bytes(bytes)
	local units = { "B", "KB", "MB", "GB", "TB" }
	local scale = 1024
	local unit_index = 1
	while bytes >= scale and unit_index < #units do
		bytes = bytes / scale
		unit_index = unit_index + 1
	end
	return string.format("%.2f%s", bytes, units[unit_index])
end

--- This function only works on OS and desktop environments that follow FreeDesktop.org standards
---@see https://specifications.freedesktop.org/trash-spec/latest/
---@param path string
function M.trash(path)
	if vim.fn.has('win32') == 1 or vim.fn.has('mac') then
		if vim.fn.executable('trash') then
			return vim.system({ 'trash', vim.fn.shellescape(path) }, { text = true }, function(obj)
				print(obj.stderr)
				print(obj.stdout)
			end)
		end
	end

	path = path:sub(-1) == '/' and path:sub(1, -2) or path
	local time = os.date('%Y-%m-%dT%H-%M-%S')
	local file_name = M.basename(path) .. '_' .. time
	local escaped = vim.uri_from_fname(path):sub(#'file://' + 1)
	local trash = os.getenv('HOME') .. '/.local/share/Trash'
	local trashfiles_dir = trash .. '/files'
	local trashinfo_dir = trash .. '/info'
	for _, v in ipairs { trashfiles_dir, trashinfo_dir } do
		if not vim.fn.isdirectory(v) then
			local success = vim.fn.mkdir(v, 'p')
			if not success then
				vim.notify(string.format("Failed to create %s", v), vim.log.levels.ERROR)
				return false
			end
		end
	end
	-- Create and write the trashinfo file
	local trashinfo_fname = trashinfo_dir .. '/' .. file_name .. '.trashinfo'
	local trashinfo_file = uv.fs_open(trashinfo_fname, 'w', 438)
	if not trashinfo_file then
		vim.notify(string.format("Failed to create %s", file_name), vim.log.levels.ERROR)
		return false
	end
	local trashinfo = ('[Trash Info]\nPath=%s\nDeletionDate=%s'):format(
		escaped,
		os.date('%Y-%m-%dT%H:%M:%S'))
	uv.fs_write(trashinfo_file, trashinfo, -1)
	uv.fs_close(trashinfo_file)

	-- Update directorysizes
	if vim.fn.isdirectory(path) == 1 then
		local dirsize = uv.fs_stat(path).size
		local mtime = vim.fn.getftime(trashinfo_fname)
		local tempfile = vim.fn.tempname()
		local dirsizes_fname = trash .. '/directorysizes'
		if vim.fn.filereadable(dirsizes_fname) == 1 then
			if vim.fn.filecopy(dirsizes_fname, tempfile) == 0 then
				vim.notify('Can\'t copy ' .. dirsizes_fname .. ' to ' .. tempfile)
				return false
			end
		end
		local dirsizes = vim.fn.readfile(tempfile)
		local has_path = false
		for i, v in ipairs(dirsizes) do
			if v:sub(- #escaped) == escaped then
				dirsizes[i] = dirsize .. ' ' .. mtime .. ' ' .. escaped
				has_path = true
				break
			end
		end
		if not has_path then
			table.insert(dirsizes, dirsize .. ' ' .. mtime .. ' ' .. escaped)
		end
		if vim.fn.writefile(dirsizes, tempfile) ~= 0 then
			vim.notify("Can't write to " .. tempfile)
			return false
		end
		if not uv.fs_copyfile(tempfile, dirsizes_fname) then
			vim.notify('Can\'t copy ' .. tempfile .. ' to ' .. dirsizes_fname)
			return false
		end
	end
	return M.rename(path, trashfiles_dir .. '/' .. file_name)
end

return M
