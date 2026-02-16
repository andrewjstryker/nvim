-- ~/.config/nvim/init.lua

-- Leader keys early
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Wire hermetic env (adds rocks tree + LuaRocks paths)
require("config.env")

-- Minimal core
require("config.util")
require("config.options")
require("config.keymaps")
require("config.autocmds")

-- Plugin configurations (concern-based, loaded after rocks.nvim)
require("config.plugins")
