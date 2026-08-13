-- ~/.config/nvim/lua/config/keymaps.lua
-- Uses the collision-aware wrapper so silent overrides of config-owned keys
-- surface (see config.keymap).
local map = require("config.keymap").set

-- Quick save / quit
map("n", "<leader>w", "<cmd>write<cr>", { noremap = true, silent = true, desc = "Save" })
map("n", "<leader>q", "<cmd>quit<cr>",  { noremap = true, silent = true, desc = "Quit" })

-- Better window navigation.  override=true: <C-l> deliberately replaces
-- Neovim's default redraw mapping (navigation.lua later re-owns all four for
-- tmux); the acknowledgement keeps the audit quiet about the intended swap.
map("n", "<C-h>", "<C-w>h", { noremap = true, silent = true, desc = "Move left",  override = true })
map("n", "<C-j>", "<C-w>j", { noremap = true, silent = true, desc = "Move down",  override = true })
map("n", "<C-k>", "<C-w>k", { noremap = true, silent = true, desc = "Move up",    override = true })
map("n", "<C-l>", "<C-w>l", { noremap = true, silent = true, desc = "Move right", override = true })

-- Terminal mode window navigation
map("t", "<C-h>", [[<C-\><C-n><C-w>h]], { silent = true, desc = "Move left from terminal" })
map("t", "<C-j>", [[<C-\><C-n><C-w>j]], { silent = true, desc = "Move down from terminal" })
map("t", "<C-k>", [[<C-\><C-n><C-w>k]], { silent = true, desc = "Move up from terminal" })
map("t", "<C-l>", [[<C-\><C-n><C-w>l]], { silent = true, desc = "Move right from terminal" })

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { silent = true, desc = "Clear search highlight" })

-- Oil (file browser: edit the filesystem as a buffer)
map("n", "-", "<cmd>Oil<cr>", { desc = "Open parent directory (oil)" })

-- Telescope
map("n", "<leader>ff", "<cmd>Telescope find_files<cr>",  { desc = "Find files" })
map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>",   { desc = "Live grep" })
map("n", "<leader>fb", "<cmd>Telescope buffers<cr>",     { desc = "Buffers" })
map("n", "<leader>fh", "<cmd>Telescope help_tags<cr>",   { desc = "Help tags" })
map("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>",    { desc = "Recent files" })

-- Trouble (diagnostics)
map("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>",              { desc = "Diagnostics" })
map("n", "<leader>xd", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", { desc = "Buffer diagnostics" })
map("n", "<leader>xq", "<cmd>Trouble quickfix toggle<cr>",                 { desc = "Quickfix" })

-- Git (fugitive)
-- `gs` opens the fugitive status buffer from the file you are editing, matching
-- Vim muscle memory (stage/unstage chunks with s/u/=/visual-s once inside).
-- This deliberately claims `gs`; leap's leap-from-windows was moved off it (see
-- plugins/editing.lua) so there is no silent collision.
map("n", "gs", "<cmd>Git<cr>",                { desc = "Git status" })
map("n", "<leader>gs", "<cmd>Git<cr>",        { desc = "Git status" })
map("n", "<leader>gb", "<cmd>Git blame<cr>",  { desc = "Git blame" })
map("n", "<leader>gd", "<cmd>Git diff<cr>",   { desc = "Git diff" })
map("n", "<leader>gl", "<cmd>Git log<cr>",    { desc = "Git log" })

-- Zen mode (writing focus)
map("n", "<leader>z", "<cmd>ZenMode<cr>", { desc = "Zen mode" })

-- Dadbod SQL
map("n", "<leader>db", "<cmd>DBUIToggle<cr>", { desc = "Toggle DB UI" })

-- Conform (format)
map("n", "<leader>cf", function()
  require("conform").format({ async = true, lsp_fallback = true })
end, { desc = "Format buffer" })
