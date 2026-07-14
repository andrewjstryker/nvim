-- ~/.config/nvim/lua/plugins/navigation.lua
-- Plugins: telescope, trouble, nvim-tmux-navigation, oil

-- Oil (edit the filesystem as a buffer).  Opens with `-` from any buffer
-- (vim.g.oil convention) to navigate to the parent directory.
local ok_oil, oil = pcall(require, "oil")
if ok_oil then
  oil.setup({
    default_file_explorer = true,
    view_options = { show_hidden = true },
  })
end

-- Telescope
local ok_tele, telescope = pcall(require, "telescope")
if ok_tele then
  telescope.setup({
    defaults = {
      layout_strategy = "horizontal",
      sorting_strategy = "ascending",
      layout_config = {
        prompt_position = "top",
      },
    },
  })
end

-- Trouble (diagnostics list / quickfix replacement)
local ok_trouble, trouble = pcall(require, "trouble")
if ok_trouble then
  trouble.setup()
end

-- Tmux-aware window navigation
-- Replaces <C-h/j/k/l> with tmux-aware versions when inside tmux.
local ok_tmux, tmux_nav = pcall(require, "nvim-tmux-navigation")
if ok_tmux then
  tmux_nav.setup({
    disable_when_zoomed = true,
  })

  -- Override the basic <C-h/j/k/l> maps from keymaps.lua with tmux-aware ones.
  -- Routed through the wrapper so this deliberate re-own is recorded (and stays
  -- silent) rather than looking like a foreign hijack (config.keymap).
  local map = require("config.keymap").set
  map("n", "<C-h>", tmux_nav.NvimTmuxNavigateLeft,  { desc = "Move left (tmux-aware)" })
  map("n", "<C-j>", tmux_nav.NvimTmuxNavigateDown,  { desc = "Move down (tmux-aware)" })
  map("n", "<C-k>", tmux_nav.NvimTmuxNavigateUp,    { desc = "Move up (tmux-aware)" })
  map("n", "<C-l>", tmux_nav.NvimTmuxNavigateRight, { desc = "Move right (tmux-aware)" })
end
