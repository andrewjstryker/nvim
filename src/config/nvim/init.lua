-- ~/.config/nvim/init.lua

-- Leader keys early
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

---------------------------------------------------------------------------
-- VS Code (vscode-neovim) gate
--
-- The hermetic env (config.env) replaces rtp/packpath, which strips the
-- vscode.internal module the extension requires.  When running inside
-- VS Code, load a curated subset via config.vscode instead.
---------------------------------------------------------------------------
if vim.g.vscode then
  require("config.vscode")
  return
end

-- Wire hermetic env (adds rocks tree + LuaRocks paths)
require("config.env")

-- Minimal core
require("config.util")
require("config.options")
require("config.keymaps")
require("config.autocmds")

-- Plugin configurations (concern-based, loaded after rocks.nvim)
require("config.plugins")
