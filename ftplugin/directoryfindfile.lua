local map = require('direx.utils').bufmap

map('n', 'P', function()
	require 'direx'.preview(vim.api.nvim_get_current_line():sub(1, -4))
end, { desc = 'Preview file or directory', buffer = true })
