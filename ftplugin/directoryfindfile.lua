local map = require('direx.utils').bufmap
local keymaps = require('direx.config').keymaps

if keymaps.preview then
	map('n', keymaps.preview, function()
		require 'direx'.preview(vim.api.nvim_get_current_line():sub(1, -4))
	end, { desc = 'Preview file or directory', buffer = true })
end
