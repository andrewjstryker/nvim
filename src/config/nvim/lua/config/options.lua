-- ~/.config/nvim/lua/config/options.lua

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
vim.opt.swapfile = true
vim.opt.shada = "'100,<100,s10,h"

-- Text formatting
vim.opt.textwidth = 78
vim.opt.linebreak = true          -- wrap at word boundaries (takes effect when wrap is on)
vim.opt.wrap = false
vim.opt.formatoptions = "cqrj1"   -- added r: auto-insert comment leader on Enter

-- Search
vim.opt.hlsearch = true
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Tags
vim.opt.tags = "tags,../tags"

-- Dictionary (optional)
if vim.fn.filereadable("/usr/share/dict/words") == 1 then
  vim.opt.dictionary:append("/usr/share/dict/words")
end

-- Colorscheme is set in plugins/ui.lua (after pack paths are resolved)
