-- ~/.config/nvim/lua/plugins/treesitter.lua
-- Plugin: nvim-treesitter

local ok, ts_configs = pcall(require, "nvim-treesitter.configs")
if not ok then return end

-- Pin parser installs to the hermetic treesitter dir (already on rtp via
-- env.lua).  Without this, :TSInstall writes to stdpath("data")/site/parser/
-- which is not on the hermetic rtp, so parsers never persist across sessions.
local env = require("config.env")

ts_configs.setup({
  parser_install_dir = env.treesitter_dir,
  highlight = { enable = true },
  indent    = { enable = true },
})
