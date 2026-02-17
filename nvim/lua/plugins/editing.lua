-- ~/.config/nvim/lua/plugins/editing.lua
-- Plugins: leap, nvim-surround, Comment, nvim-autopairs, nvim-lastplace

local ok, leap = pcall(require, "leap")
if ok then
  -- Explicit mappings rather than create_default_mappings(), which may not
  -- exist in all forks (e.g. Codeberg andyg/leap.nvim).
  vim.keymap.set({"n", "x", "o"}, "s",  function() leap.leap({}) end,
    { desc = "Leap forward" })
  vim.keymap.set({"n", "x", "o"}, "S",  function() leap.leap({ backward = true }) end,
    { desc = "Leap backward" })
  local has_user, leap_user = pcall(require, "leap.user")
  if has_user and leap_user.get_focusable_windows then
    vim.keymap.set({"n", "x", "o"}, "gs", function()
      leap.leap({ target_windows = leap_user.get_focusable_windows() })
    end, { desc = "Leap from windows" })
  end
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
