local lsp = {}

function lsp.request(method, params)
	local clients = vim.lsp.get_clients()
	if #clients == 0 then
		return
	end
	for _, client in ipairs(clients) do
		if client:supports_method(method) then
			pcall(client.request, method, params, function(err, result)
				if result and result.changes then
					vim.lsp.util.apply_workspace_edit(result, 'utf-8')
				end
			end)
		end
	end
end

lsp.workspace = setmetatable({}, {
	---@param method 'willRenameFiles'|'didRenameFiles'|'willDeleteFiles'|'didDeleteFiles'|'willCreateFiles'|'didCreateFiles'
	__index = function(_, method)
		---@param list string[][] If rename then { old_name, new_name } else { name }
		return function(list)
			local uri = vim.uri_from_fname
			local files = {}
			for _, v in ipairs(list) do
				local param = v[2] and { oldUri = uri(v[1]), newUri = uri(v[2]) } or { uri = uri(v[1]) }
				table.insert(files, param)
			end
			lsp.request('workspace/' .. method, { files = files })
		end
	end,
})

return lsp
