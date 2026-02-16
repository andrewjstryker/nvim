-- ~/.config/nvim/lua/plugins/sql.lua
-- Plugins: vim-dadbod, vim-dadbod-ui, vim-dadbod-completion

-- dadbod-ui settings (vim globals, set before the plugin loads)
vim.g.db_ui_use_nerd_fonts = 0                -- safe without nerd fonts
vim.g.db_ui_show_database_icon = 0
vim.g.db_ui_auto_execute_table_helpers = 1    -- run helpers on select

-- Wire dadbod-completion into nvim-cmp for sql/mysql/plsql buffers
local ok_cmp, cmp = pcall(require, "cmp")
if ok_cmp then
  cmp.setup.filetype({ "sql", "mysql", "plsql" }, {
    sources = cmp.config.sources({
      { name = "vim-dadbod-completion" },
      { name = "buffer" },
    }),
  })
end
