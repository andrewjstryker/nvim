-- ~/.config/nvim/lua/config/keymaps.lua
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Quick save / quit
map("n", "<leader>w", "<cmd>write<cr>", opts)
map("n", "<leader>q", "<cmd>quit<cr>",  opts)

-- Better window nav
map("n", "<C-h>", "<C-w>h", opts)
map("n", "<C-j>", "<C-w>j", opts)
map("n", "<C-k>", "<C-w>k", opts)
map("n", "<C-l>", "<C-w>l", opts)

-- Terminal mode window navigation
vim.keymap.set(
  "t", "<C-h>", [[<C-\><C-n><C-w>h]],
  { silent = true, desc = "Move left from terminal" }
)
vim.keymap.set(
  "t", "<C-j>", [[<C-\><C-n><C-w>j]],
  { silent = true, desc = "Move down from terminal" }
)
vim.keymap.set(
  "t", "<C-k>", [[<C-\><C-n><C-w>k]],
  { silent = true, desc = "Move up from terminal" }
)
vim.keymap.set(
  "t", "<C-l>", [[<C-\><C-n><C-w>l]],
  { silent = true, desc = "Move right from terminal" }
)

