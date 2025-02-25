local M = {}

---@class DirConfigOpts
---@field iconfunc? function
---@field set nil

---@param opts DirConfigOpts
M.set = function(opts)
	assert(opts.set == nil)
	package.loaded['direx.config'] = vim.tbl_deep_extend('force', package.loaded['direx.config'], opts)
end

return M
