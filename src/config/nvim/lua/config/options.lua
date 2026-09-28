-- ~/.config/nvim/lua/config/options.lua
-- Inherit Neovim and vim-sensible defaults; keep only deliberate overrides.

-- Disable netrw (file explorer) — Neovim 0.12 loads it as an optional pack
-- plugin, which fails under our hermetic packpath.  Use Telescope instead.
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_netrw = 1

-- Files & history
vim.opt.exrc = true             -- trusted project-local .nvim.lua configuration
vim.opt.undofile = true
vim.opt.backup = true
local backup_dir = vim.fn.stdpath("state") .. "/backup"
vim.fn.mkdir(backup_dir, "p")
vim.opt.backupdir = backup_dir

-- Text formatting
vim.opt.textwidth = 80
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.softtabstop = -1         -- follow shiftwidth for Tab and Backspace
vim.opt.linebreak = true          -- wrap at word boundaries (takes effect when wrap is on)
vim.opt.wrap = false
vim.opt.formatoptions = "cqrj1"   -- added r: auto-insert comment leader on Enter

-- Search
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Dictionary (optional)
if vim.fn.filereadable("/usr/share/dict/words") == 1 then
  vim.opt.dictionary:append("/usr/share/dict/words")
end

-- Colorscheme is set in plugins/ui.lua (after pack paths are resolved)
