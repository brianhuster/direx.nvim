local M = {}

local uv = vim.uv
local fs = vim.fs

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
	return success
end

---@param oldpath string
---@param newpath string
---@return boolean?
function M.copylink(oldpath, newpath)
	local target = uv.fs_readlink(oldpath)
	if target then
		if vim.b.dirvish_sudo then
			M.sudo_exec({ 'cp', oldpath, newpath })
			return vim.v.shell_error == 0
		end
		local success, errname, errmsg = uv.fs_symlink(target, newpath)
		return success
	end
end

function M.copy(oldpath, newdir)
	local stat = vim.uv.fs_lstat(oldpath)
	local type = stat and stat.type
	local joinpath, basename = vim.fs.joinpath, vim.fs.basename
	local newpath = joinpath(newdir, basename(oldpath:sub(-1) == '/' and oldpath:sub(1, -2) or oldpath))
	if type == 'directory' then
		require('dir.fs').copydir(oldpath, newpath)
	elseif type == 'file' then
		require('dir.fs').copyfile(oldpath, newpath)
	elseif type == 'link' then
		require('dir.fs').copyfile(oldpath, newpath)
	end
end

---@param oldname string
---@param newname string
function M.rename(oldname, newname)
	local success, err, errname = vim.uv.fs_rename(oldname, newname)
	if not success then
		success = M.copy(oldname, vim.fs.dirname(newname:sub(-1) == '/' and newname:sub(1, -2) or newname))
		if success then
			M.remove(oldname)
		else
			vim.notify("Copy not successful. Old path will be kept")
		end
	end
end

---@param path string
---@return boolean
function M.remove(path)
	local success = false
	if vim.fn.isdirectory(path) == 1 then
		success = vim.fn.delete(path, 'rf') == 0
	else
		success = vim.fn.delete(path) == 0
	end
	return success
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

return M
