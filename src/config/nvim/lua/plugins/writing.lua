-- ~/.config/nvim/lua/plugins/writing.lua
-- Plugins: zen-mode, render-markdown

-- Zen mode (distraction-free writing)
local ok_zen, zen = pcall(require, "zen-mode")
if ok_zen then
  zen.setup({
    window = {
      width = 80,
      backdrop = 0.93,
      options = {
        number         = false,
        relativenumber = false,
        signcolumn     = "no",
        cursorline     = false,
      },
    },
  })
end

-- Render-markdown (in-buffer rendering of headings, tables, code blocks)
-- opt=true: packadd + setup on first entry into a markdown buffer.
--
-- render-markdown's plugin file attaches eagerly on packadd and builds a
-- markdown treesitter parser immediately; if no parser can be created it throws
-- (E5113) on every markdown buffer.  So we gate on whether the parser actually
-- LOADS before loading the plugin.  This is a behavioral check, not a file or
-- name check: vim.treesitter.language.add() returns true even on a binary that
-- ships no usable parser, so only get_parser()+parse() is trustworthy.  A
-- correctly provisioned install (see `make sync`) always passes; a
-- broken one degrades to a warning instead of a wall of errors.
local function markdown_parser_loads()
  return pcall(function()
    local parser = vim.treesitter.get_parser(0, "markdown")
    assert(parser and parser:parse()[1]:root())
  end)
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  once = true,
  callback = function()
    if not markdown_parser_loads() then
      vim.notify(
        "render-markdown: markdown treesitter parser unavailable -- run `make sync`",
        vim.log.levels.WARN
      )
      return
    end
    vim.cmd("packadd render-markdown.nvim")
    local ok_rm, render_md = pcall(require, "render-markdown")
    if ok_rm then
      render_md.setup({
        file_types = { "markdown" },
        heading = { enabled = true },
      })
    end
  end,
})
