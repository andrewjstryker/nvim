-- ~/.config/nvim/lua/config/keymaps.lua
local map = vim.keymap.set

-- Quick save / quit
map("n", "<leader>w", "<cmd>write<cr>", { noremap = true, silent = true })
map("n", "<leader>q", "<cmd>quit<cr>",  { noremap = true, silent = true })

-- Better window nav
map("n", "<C-h>", "<C-w>h", { noremap = true, silent = true, desc = "Move left" })
map("n", "<C-j>", "<C-w>j", { noremap = true, silent = true, desc = "Move down" })
map("n", "<C-k>", "<C-w>k", { noremap = true, silent = true, desc = "Move up" })
map("n", "<C-l>", "<C-w>l", { noremap = true, silent = true, desc = "Move right" })

-- Terminal mode window navigation
map("t", "<C-h>", [[<C-\><C-n><C-w>h]], { silent = true, desc = "Move left from terminal" })
map("t", "<C-j>", [[<C-\><C-n><C-w>j]], { silent = true, desc = "Move down from terminal" })
map("t", "<C-k>", [[<C-\><C-n><C-w>k]], { silent = true, desc = "Move up from terminal" })
map("t", "<C-l>", [[<C-\><C-n><C-w>l]], { silent = true, desc = "Move right from terminal" })
