local api = vim.api
vim.cmd [[syn match Directory ".*\/$"]]
vim.cmd(([[syn match Conceal "^\V\C%s" conceal]])
	:format(api.nvim_eval [[expand('%')->escape(' "\')]]))

local ns_id = api.nvim_create_namespace 'DirexIcons'
api.nvim_buf_clear_namespace(0, ns_id, 0, -1)
local iconfunc = require 'direx.config'.iconfunc
if iconfunc then
	---@type string[]
	---@diagnostic disable-next-line: assign-type-mismatch
	local paths = vim.fn.getline(1, '$')
	for i, line in ipairs(paths) do
		local dict = iconfunc(line)
		api.nvim_buf_set_extmark(0, ns_id, i - 1, 0, {
			virt_text = { { dict.icon, dict.hl } },
			virt_text_pos = 'inline',
			invalidate = true
		})
	end
end
