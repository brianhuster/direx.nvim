local M = {}

local api = vim.api

function M.bufmap(mode, lhs, rhs, opts)
	opts = opts or {}
	vim.keymap.set(mode, lhs, rhs, vim.tbl_extend('force', opts, { buffer = true }))
end

function M.add_icons()
	local ns_id = vim.api.nvim_create_namespace('Direx')
	vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)
	local iconfunc = require('direx.config').iconfunc
	if iconfunc then
		---@type string[]
		---@diagnostic disable-next-line: assign-type-mismatch
		local paths = vim.fn.getline(1, '$')
		for i, line in ipairs(paths) do
			local dict = iconfunc(line)
			vim.api.nvim_buf_set_extmark(0, ns_id, i - 1, 0, {
				virt_text = { { dict.icon, dict.hl } },
				virt_text_pos = 'inline',
			})
		end
	end
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
		return (v == '' or v == '$*') and arg or M.expandcmd(v)
	end, vim.split(prg, ' '))
end

---@param cmd string
---@return string
function M.expandcmd(cmd)
	vim.cmd(
		([[ silent! let g:_direx_expanded_cmd = expandcmd(escape("%s", '"')) ]])
		:format(cmd))
	return vim.g._direx_expanded_cmd
end

return M
