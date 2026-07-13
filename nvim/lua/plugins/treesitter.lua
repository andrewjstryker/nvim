-- ~/.config/nvim/lua/plugins/treesitter.lua
-- Plugin: nvim-treesitter

local ok, ts_configs = pcall(require, "nvim-treesitter.configs")
if not ok then return end

-- Pin parser installs to the hermetic treesitter dir (already on rtp via
-- env.lua).  Without this, :TSInstall writes to stdpath("data")/site/parser/
-- which is not on the hermetic rtp, so parsers never persist across sessions.
local env = require("config.env")

-- Parser ownership is split deliberately:
--   * Parsers bundled with Neovim (vimdoc, markdown, lua, vim, query, c, ...)
--     are provided by the nvim install itself, found via $VIMRUNTIME/parser
--     on the runtimepath.  No config action needed.
--   * Any *other* language is installed on first use by nvim-treesitter's own
--     auto_install, into the hermetic parser dir below.  This replaces the
--     hand-rolled get_parser wrapper we used to carry -- the plugin does this
--     natively, without patching core Neovim APIs.
--
-- Both cases are covered by headless tests (see the Makefile: test-fast
-- verifies a bundled parser loads; test verifies an extra parser installs).
ts_configs.setup({
  parser_install_dir = env.treesitter_dir,
  auto_install       = true,
  highlight = { enable = true },
  indent    = { enable = true },
})
