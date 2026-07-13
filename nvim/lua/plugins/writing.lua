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
-- opt=true: packadd + setup on first entry into a markdown buffer.  The
-- markdown treesitter parser it depends on is guaranteed by Neovim's bundled
-- parsers (verified by the treesitter tests), so we load it directly rather
-- than guarding on parser availability.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  once = true,
  callback = function()
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
