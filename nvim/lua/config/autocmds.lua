-- ~/.config/nvim/lua/config/autocmds.lua
local aug = vim.api.nvim_create_augroup("CoreAutocmds", { clear = true })

---------------------------------------------------------------------------
-- Treesitter parser auto-install prompt
--
-- Neovim 0.12 ftplugins call vim.treesitter.start() for many languages.
-- When the parser is missing, this throws an error.  We wrap the function
-- to catch the failure and offer to install the missing parser on the spot.
--
-- Parsers that have already been declined (this session) are not re-prompted.
---------------------------------------------------------------------------
do
  local declined = {}
  local original_ts_start = vim.treesitter.start

  vim.treesitter.start = function(bufnr, lang, ...)
    -- Resolve language from buffer filetype if not provided
    lang = lang or vim.bo[bufnr or 0].filetype
    if declined[lang] then return end

    local ok, err = pcall(original_ts_start, bufnr, lang, ...)
    if ok then return end

    -- Only intercept parser-missing errors; re-raise anything else
    if type(err) == "string" and (err:match("Parser could not be created") or err:match("No parser for language")) then
      vim.schedule(function()
        local answer = vim.fn.confirm(
          string.format("Treesitter parser for '%s' is not installed. Install it?", lang),
          "&Yes\n&No", 2)
        if answer == 1 then
          local install_ok, install_err = pcall(vim.cmd, "TSInstall " .. lang)
          if not install_ok then
            vim.notify("TSInstall failed: " .. tostring(install_err), vim.log.levels.WARN)
          end
        else
          declined[lang] = true
        end
      end)
    else
      error(err, 2)
    end
  end
end

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

-- render-markdown.nvim: load only when the treesitter markdown parser exists.
-- Without the parser the plugin errors on attach; keeping it opt avoids that.
vim.api.nvim_create_autocmd("FileType", {
  group = aug,
  pattern = { "markdown" },
  once = true,
  callback = function()
    if pcall(vim.treesitter.language.inspect, "markdown") then
      vim.cmd("packadd render-markdown.nvim")
      local ok, render_md = pcall(require, "render-markdown")
      if ok then
        render_md.setup({
          file_types = { "markdown" },
          heading = { enabled = true },
        })
      end
    end
  end,
})
