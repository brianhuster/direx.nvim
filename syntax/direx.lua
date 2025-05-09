local api = vim.api
local ns_id = api.nvim_create_namespace('DirexSyn')
local paths = vim.fn.getline(1, '$')
local bufname = api.nvim_buf_get_name(0)
local bufname_len = #bufname

---@diagnostic disable-next-line: param-type-mismatch
for i, line in ipairs(paths) do
	if line:sub(1, bufname_len) == bufname then
		api.nvim_buf_set_extmark(0, ns_id, i - 1, 0, {
			end_col = bufname_len + 1,
			conceal = '',
		})
	end
end
