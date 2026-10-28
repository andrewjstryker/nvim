-- Mail keeps its conventional 72 columns: Neovim's mail ftplugin only sets
-- that when textwidth is 0, and options.lua sets 80.
vim.bo.textwidth = 72

-- A composed message opens below its headers, on the line that ends them.
-- Mail clients write the headers first; other mail files keep the cursor.
local first = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] or ""
if first:match("^[%w-]+:") then
  for row, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    if line == "" then
      vim.api.nvim_win_set_cursor(0, { row, 0 })
      break
    end
  end
end
