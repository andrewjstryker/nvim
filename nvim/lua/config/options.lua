-- ~/.config/nvim/lua/config/options.lua

-- Truecolor + UI niceties
vim.opt.termguicolors = true
vim.opt.cursorline = true
vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.signcolumn = "yes"

-- Files & history
vim.opt.undofile = true
vim.opt.backup = true
local backup_dir = vim.fn.stdpath("state") .. "/backup"
vim.fn.mkdir(backup_dir, "p")
vim.opt.backupdir = backup_dir
vim.opt.swapfile = true
vim.opt.shada = "'20,<50,s10,h"

-- Text formatting
vim.opt.textwidth = 78
vim.opt.linebreak = false
vim.opt.wrap = false
vim.opt.formatoptions = "cqbj1"

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

-- Colorscheme (graceful fallback)
local ok = pcall(vim.cmd.colorscheme, "solarized")
if not ok then pcall(vim.cmd.colorscheme, "default") end
