-- ~/.config/nvim/lua/plugins/editing.lua
-- Plugins: leap, nvim-surround, Comment, nvim-autopairs, nvim-lastplace

local ok, leap = pcall(require, "leap")
if ok then
  leap.add_default_mappings()
end

local ok2, surround = pcall(require, "nvim-surround")
if ok2 then
  surround.setup()
end

local ok3, comment = pcall(require, "Comment")
if ok3 then
  comment.setup()
end

local ok4, autopairs = pcall(require, "nvim-autopairs")
if ok4 then
  autopairs.setup({
    check_ts = true,          -- use treesitter to check for pair context
    disable_filetype = { "TelescopePrompt", "vim" },
  })
end

local ok5, lastplace = pcall(require, "nvim-lastplace")
if ok5 then
  lastplace.setup({
    lastplace_ignore_buftype = { "quickfix", "nofile", "help" },
    lastplace_ignore_filetype = { "gitcommit", "gitrebase" },
  })
end
