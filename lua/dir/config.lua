local M = {}

---@class DirConfigOpts
---@field iconfunc? function

---@type function?
M.iconfunc = nil

---@param opts {
---iconfunc: function?,
---set: nil }
M.set = function(opts)
	assert(opts.set == nil)
	package.loaded['dir.config'] = vim.tbl_deep_extend('force', package.loaded['dir.config'], opts)
end

return M
