local M = {}

local api = vim.api

function M.bufmap(mode, lhs, rhs, opts)
	opts = opts or {}
	vim.keymap.set(mode, lhs, rhs, vim.tbl_extend('force', opts, { buffer = true }))
end

function M.get_grep_pattern(cmd)
	if cmd.args then return cmd.args end
	local pattern
	if cmd.range > 0 then
		local pos1, pos2 = api.nvim_buf_get_mark(0, '<'), vim.api.nvim_buf_get_mark(0, '>')
		pattern = api.nvim_buf_get_text(0, pos1[1] - 1, pos1[2], pos2[1] - 1, pos2[2], {})
		if type(pattern) == 'table' then
			pattern = table.concat(pattern, '\n')
		end
	else
		pattern = vim.fn.expand('<cword>')
	end
	if require('direx.config').grep.parse_args == 'shell' then
		pattern = vim.fn.shellescape(pattern)
	end
	return pattern
end

function M.feedkeys(key)
	api.nvim_feedkeys(vim.keycode(key), 'n', true)
end

---@param prg string
---@param arg string
---@return string[]
function M.parse_prg(prg, arg)
	return vim.tbl_map(function(v)
		return (v == '' or v == '$*') and arg or vim.fn.expandcmd(v)
	end, vim.split(prg, ' '))
end

return M
