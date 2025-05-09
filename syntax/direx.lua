local ns_id = vim.api.nvim_create_namespace('DirexIcons')
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
