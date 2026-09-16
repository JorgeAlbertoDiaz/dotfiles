-- ~/.config/nvim/init.lua
-- Configuración mínima de Neovim.

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.mouse = "a"
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.swapfile = false

vim.g.mapleader = " "
vim.keymap.set("n", "<leader>w", ":w<CR>", { desc = "Guardar archivo" })
vim.keymap.set("n", "<leader>q", ":q<CR>", { desc = "Salir" })