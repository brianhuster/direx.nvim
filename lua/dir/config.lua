local M = {}

---@class DirConfigOpts
---@field iconfunc? function

---@type function?
M.iconfunc = nil

---@class DirConfigKeymaps
---@field editfile string?
---@field mkdir string?
---@field rename string?
---@field remove string?
---@field copy string?
---@field move string?
---@field paste string?
---@field preview string?
---@field hover string?
---@field argadd string?
---@field argdelete string?

---@type DirConfigKeymaps
M.keymaps = {
	rename = 'grn',
	hover = 'K',
	remove = '<Del>',
}

---@param opts {
---iconfunc: function?,
---keymaps: table?,
---set: nil }
M.set = function(opts)
	assert(opts.set == nil)
	package.loaded['dir.config'] = vim.tbl_deep_extend('force', package.loaded['dir.config'], opts)
end

return M
