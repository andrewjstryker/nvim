-- ~/.config/nvim/lua/plugins/git.lua
-- Plugins: gitsigns.nvim, vim-fugitive (fugitive needs no setup call)

local ok, gitsigns = pcall(require, "gitsigns")
if not ok then return end

gitsigns.setup({
  signs = {
    add          = { text = "+" },
    change       = { text = "~" },
    delete       = { text = "_" },
    topdelete    = { text = "‾" },
    changedelete = { text = "~" },
  },
  on_attach = function(bufnr)
    local gs = package.loaded.gitsigns
    local map = vim.keymap.set
    local opts = function(desc)
      return { buffer = bufnr, desc = desc }
    end

    -- Navigation between hunks
    map("n", "]h", gs.next_hunk, opts("Next hunk"))
    map("n", "[h", gs.prev_hunk, opts("Prev hunk"))

    -- Stage / reset
    map("n", "<leader>hs", gs.stage_hunk,      opts("Stage hunk"))
    map("n", "<leader>hr", gs.reset_hunk,      opts("Reset hunk"))
    map("n", "<leader>hu", gs.undo_stage_hunk, opts("Undo stage hunk"))
    map("n", "<leader>hp", gs.preview_hunk,    opts("Preview hunk"))

    -- Blame
    map("n", "<leader>hb", function() gs.blame_line({ full = true }) end, opts("Blame line"))
  end,
})
