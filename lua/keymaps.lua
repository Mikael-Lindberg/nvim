-- define common options
local opts = {
    noremap = true,
    silent = true,
}

-- Window navigation
vim.keymap.set('n', '<C-h>', '<C-w>h', opts)
vim.keymap.set('n', '<C-j>', '<C-w>j', opts)
vim.keymap.set('n', '<C-k>', '<C-w>k', opts)
vim.keymap.set('n', '<C-l>', '<C-w>l', opts)

-- Running Cargo
vim.api.nvim_set_keymap('n', '<C-b>', ':!cargo run <CR>', 
    { noremap = true, silent = true }
)
