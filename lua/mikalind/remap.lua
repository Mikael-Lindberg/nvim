vim.g.mapleader = " "
vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)

vim.keymap.set("n", "<F5>", ":! build.bat <CR>")

vim.keymap.set("n", "<C-b>", ":! build.bat run <CR>")
