local api = vim.api
local ns_id = vim.api.nvim_create_namespace('Directory')
local buf = vim.api.nvim_get_current_buf()
---@module 'direx'
local dir = setmetatable({}, { __index = function(_, k) return require('direx')[k] end })
local bufmap = require('direx.utils').bufmap
local bufcmd = api.nvim_buf_create_user_command

-- Afjfe

vim.wo[0][0].conceallevel = 3
vim.wo[0][0].concealcursor = 'nvc'
vim.wo[0][0].wrap = false
vim.bo.bufhidden = 'delete'
vim.bo.buftype = 'nowrite'
vim.bo.swapfile = false

local function add_icons()
	vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
	local iconfunc = require('direx.config').iconfunc
	if iconfunc then
		---@type string[]
		---@diagnostic disable-next-line: assign-type-mismatch
		local paths = vim.fn.getline(1, '$')
		for i, line in ipairs(paths) do
			local dict = iconfunc(line)
			vim.api.nvim_buf_set_extmark(buf, ns_id, i - 1, 0, {
				virt_text = { { dict.icon, dict.hl } },
				virt_text_pos = 'inline',
			})
		end
	end
end

local function feedkeys(key)
	api.nvim_feedkeys(vim.keycode(key), 'n', true)
end

local function get_lines_from_range(args)
	return args.range > 0 and api.nvim_buf_get_lines(0, args.line1 - 1, args.line2, false) or nil
end


vim.cmd.sort [[/^.*[/]/]]
vim.fn.search([[\V\C]] .. vim.fn.escape(vim.w.prev_bufname, '\\'), 'cw')

add_icons()

bufmap('n', '<CR>', function() vim.cmd.edit(api.nvim_get_current_line()) end,
	{ desc = 'Open file or directory under cursor' })
bufmap('n', 'grn', function() dir.rename() end, { desc = 'Rename path under cursor' })
bufmap('n', 'K', function() dir.hover() end, { desc = 'View file or folder info' })
bufmap('n', 'P', function() dir.preview(api.nvim_get_current_line()) end, { desc = 'Preview file or directory' })
bufmap('n', 'g?', '<cmd>help direx-mappings<CR>')

bufmap('n', '!', function()
	feedkeys(':<C-U><Space>')
	local path = vim.fn.shellescape(api.nvim_get_current_line(), true)
	feedkeys(path .. '<C-b>!')
end, {})

bufmap('x', '!', function() feedkeys(':Shdo  {}<Left><Left><Left>') end)


bufcmd(buf, 'Shdo', function(args)
	local lines = get_lines_from_range(args)
	if not lines then return end
	require 'direx'.shdo(args.args, vim.fs.abspath(api.nvim_buf_get_name(0)), lines)
end, {
	range = true,
	nargs = '+',
	complete = 'shellcmd',
	desc = 'Execute shell command with optional range and arguments'
})

bufcmd(buf, 'Cut', function(args)
	local lines = get_lines_from_range(args) or { api.nvim_get_current_line() }
	dir.cut(lines)
end, {
	range = true,
	desc = 'Cut selected files and directories for later pasting'
})

bufcmd(buf, 'Copy', function(args)
	local lines = args.range > 0 and api.nvim_buf_get_lines(0, args.line1 - 1, args.line2, false) or
		{ api.nvim_get_current_line() }
	dir.copy(lines)
end, {
	range = true,
	desc = 'Copy selected files and directories for later pasting'
})

bufcmd(buf, 'Paste', function() dir.paste() end, { desc = 'Execute shell command with optional range and arguments' })

bufcmd(buf, 'Remove', function(args)
	local lines = get_lines_from_range(args) or { api.nvim_get_current_line() }
	dir.remove(lines, { confirm = args.bang == false })
end, { desc = 'Remove selected files and directories', range = true, bang = true })

bufcmd(buf, 'Trash', function(args)
	local lines = get_lines_from_range(args) or { api.nvim_get_current_line() }
	dir.trash(lines, { confirm = args.bang == false })
end, { range = true, bang = true, desc = 'Trash selected files and directories' })

bufcmd(buf, 'LFind', function(cmd)
	require 'direx'.find_files(cmd.args, { wintype = 'location', from_dir = api.nvim_buf_get_name(0) })
end, { nargs = '+', desc = 'Find files/folders <arg> in directory and its subdirectories, then open location window' })

bufcmd(buf, 'LGrep', function(cmd)
	local pattern = require 'direx.utils'.get_grep_pattern(cmd)
	require 'direx'.grep(pattern, { wintype = 'location', from_dir = api.nvim_buf_get_name(0) })
end, { nargs = '+', desc = 'Grep <arg> in directory and its subdirectories, then open location window' })

local augroup = vim.api.nvim_create_augroup('ft-directory', { clear = true })
vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedP', 'InsertLeave' }, {
	buffer = buf,
	group = augroup,
	callback = function()
		add_icons()
	end
})

vim.b.undo_ftplugin = table.concat({
	"setl conceallevel< concealcursor< bufhidden< buftype< swapfile< wrap<",
	"silent! nunmap <CR> ! K P grn g?",
	"silent! delcommand -buffer Shdo Cut Copy Paste Trash Remove LFind LGrep",
	"augroup ft-directory | au! | augroup END",
}, "\n")
