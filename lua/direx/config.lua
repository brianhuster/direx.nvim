local M = {}

---@class DirConfigOpts
---@field iconfunc? function
---@field default? boolean
---@field grep? { parse_args: 'shell'|false, timeout: number }
---@field set nil

M.grep = { parse_args = 'shell' }
M.default = true

---@param opts DirConfigOpts
M.set = function(opts)
	assert(opts.set == nil)
	package.loaded['direx.config'] = vim.tbl_deep_extend('force', package.loaded['direx.config'], opts)
end

return M
