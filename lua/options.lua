vim.opt.clipboard = 'unnamedplus' -- use system clipboard

-- Tab
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

-- UI config
vim.opt.number = true
vim.opt.relativenumber = true
-- vim.opt.cursorline = true
-- vim.opt.splitbelow = true
-- vim.opt.splitright = true
vim.opt.showmode = false;

-- Searching
vim.opt.incsearch = true
vim.opt.hlsearch = false
vim.opt.ignorecase = true
vim.opt.smartcase = true 

-- Column
vim.opt.colorcolumn = '81'
vim.cmd([[
    highlight ColorColumn ctermbg=235 guibg=#1e1e1e
]])
