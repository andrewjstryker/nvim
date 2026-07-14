-- ~/.config/nvim/lua/plugins/editing.lua
-- Plugins: leap, nvim-surround, Comment, nvim-autopairs, nvim-lastplace

local ok, leap = pcall(require, "leap")
if ok then
  -- Route through the collision-aware wrapper so these global claims are
  -- tracked and any later plugin stealing them is surfaced (config.keymap).
  local map = require("config.keymap").set
  -- Explicit mappings rather than create_default_mappings(), which may not
  -- exist in all forks (e.g. Codeberg andyg/leap.nvim).
  map({"n", "x", "o"}, "s",  function() leap.leap({}) end,
    { desc = "Leap forward" })
  -- `S` omits visual (x) mode: nvim-surround owns visual S ("surround the
  -- selection").  Claiming it here only created a phantom map surround silently
  -- overwrote -- the keymap audit flagged exactly that.
  map({"n", "o"}, "S", function() leap.leap({ backward = true }) end,
    { desc = "Leap backward" })
  -- Leap-from-windows lives on <leader>s, NOT gs: gs is fugitive's git status
  -- (see config/keymaps.lua).  Relocated so nothing silently fights over gs.
  local has_user, leap_user = pcall(require, "leap.user")
  if has_user and leap_user.get_focusable_windows then
    map({"n", "x", "o"}, "<leader>s", function()
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
