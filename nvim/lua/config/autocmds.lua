-- ~/.config/nvim/lua/config/autocmds.lua
local aug = vim.api.nvim_create_augroup("CoreAutocmds", { clear = true })

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

-- Prose-friendly settings for Markdown and text files
vim.api.nvim_create_autocmd("FileType", {
  group = aug,
  pattern = { "markdown", "text", "pandoc" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
    vim.opt_local.spelllang = "en_us"
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
