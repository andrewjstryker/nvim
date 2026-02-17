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
-- Requires the markdown and markdown_inline treesitter parsers.
-- Run :TSInstall markdown markdown_inline if you see parser errors.
local has_parser = pcall(vim.treesitter.language.inspect, "markdown")
if has_parser then
  local ok_rm, render_md = pcall(require, "render-markdown")
  if ok_rm then
    render_md.setup({
      file_types = { "markdown" },
      heading = {
        enabled = true,
      },
    })
  end
end
