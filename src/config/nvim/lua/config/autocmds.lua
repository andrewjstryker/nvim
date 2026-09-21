-- ~/.config/nvim/lua/config/autocmds.lua
--
-- Core, editor-wide autocommands only.  This file is a dispatcher: it wires
-- events to small callbacks and delegates anything non-trivial elsewhere.
--
--   * Per-filetype buffer settings  -> after/ftplugin/<ft>.lua
--   * Plugin configuration/loading  -> lua/plugins/<concern>.lua
--   * Treesitter parsers            -> owned by Neovim (bundled) and
--                                      nvim-treesitter (extras); see
--                                      lua/plugins/treesitter.lua
--
-- Keep this file free of clever, defensive, or plugin-specific logic.
local aug = vim.api.nvim_create_augroup("CoreAutocmds", { clear = true })

-- Resolve the session's Lua target before syntax loads. First file wins.
vim.api.nvim_create_autocmd("FileType", {
  group = aug,
  pattern = { "lua", "fennel" },
  once = true,
  callback = function()
    require("plugins.lua")
  end,
})

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  group = aug,
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 120 })
  end,
})

-- Trim trailing whitespace on save (skip diff buffers and gpg files)
vim.api.nvim_create_autocmd("BufWritePre", {
  group = aug,
  callback = function()
    if vim.bo.filetype == "diff" or vim.bo.filetype == "gpg" then return end
    local pos = vim.api.nvim_win_get_cursor(0)
    vim.cmd([[silent! %s/\s\+$//e]])
    pcall(vim.api.nvim_win_set_cursor, 0, pos)
  end,
})

---------------------------------------------------------------------------
-- Lazy-load opt=true plugins on matching filetypes
---------------------------------------------------------------------------
local ft_plugins = {
  { pattern = { "r", "rmd", "rnoweb", "rhelp" }, plugin = "Nvim-R" },
  { pattern = { "csv", "tsv" },                   plugin = "csv.vim" },
  { pattern = { "ledger", "journal" },             plugin = "vim-ledger" },
  { pattern = { "dockerfile" },                    plugin = "dockerfile.vim" },
  { pattern = { "pandoc" },                        plugin = "vim-pandoc-syntax" },
}

for _, ft in ipairs(ft_plugins) do
  vim.api.nvim_create_autocmd("FileType", {
    group = aug,
    pattern = ft.pattern,
    once = true,
    callback = function()
      vim.cmd("packadd " .. ft.plugin)
    end,
  })
end
