-- ~/.config/nvim/lua/config/autocmds.lua
local aug = vim.api.nvim_create_augroup("CoreAutocmds", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
  group = aug,
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 120 })
  end,
})

