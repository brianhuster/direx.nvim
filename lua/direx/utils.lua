local M = {}

function M.bufmap(mode, lhs, rhs, opts)
	opts = opts or {}
	vim.keymap.set(mode, lhs, rhs, vim.tbl_extend('force', opts, { buffer = true }))
end

return M
