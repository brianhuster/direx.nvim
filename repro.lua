local tempfile = vim.fn.tempname()
vim.print(vim.uv.fs_stat(tempfile))
