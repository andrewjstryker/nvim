-- ~/.config/nvim/lua/config/vscode.lua
--
-- Curated configuration for Neovim running inside VS Code (vscode-neovim).
--
-- VS Code owns the UI, completion, LSP, diagnostics, treesitter, and file
-- navigation.  We keep: options, editing motions, and — critically — Fugitive.
--
-- This module loads config.vscode_env (the build-time rendered counterpart
-- to config.env) which APPENDS the hermetic rocks tree to Neovim's default
-- rtp/packpath rather than replacing them.  This preserves vscode.internal
-- while making hermetic plugins available.

---------------------------------------------------------------------------
-- 1) Wire hermetic paths (append mode — keeps VS Code's paths intact)
---------------------------------------------------------------------------
require("config.vscode_env")

---------------------------------------------------------------------------
-- 2) Core options (safe subset — no UI settings that conflict with VS Code)
---------------------------------------------------------------------------
require("config.options")

---------------------------------------------------------------------------
-- 3) Keymaps: pure-Neovim motions + Fugitive + VS Code action delegates
---------------------------------------------------------------------------
local vscode = require("vscode")
local map = vim.keymap.set

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { silent = true, desc = "Clear search highlight" })

-- Fugitive (the primary reason for this file)
map("n", "<leader>gs", "<cmd>Git<cr>",      { desc = "Git status" })
map("n", "<leader>gb", "<cmd>Git blame<cr>", { desc = "Git blame" })
map("n", "<leader>gd", "<cmd>Git diff<cr>",  { desc = "Git diff" })
map("n", "<leader>gl", "<cmd>Git log<cr>",   { desc = "Git log" })

-- Delegate find/search to VS Code's native pickers
map("n", "<leader>ff", function() vscode.action("workbench.action.quickOpen") end,
  { desc = "Find files (VS Code)" })
map("n", "<leader>fg", function() vscode.action("workbench.action.findInFiles") end,
  { desc = "Search in files (VS Code)" })

-- Save / quit via VS Code
map("n", "<leader>w", function() vscode.action("workbench.action.files.save") end,
  { desc = "Save" })
map("n", "<leader>q", function() vscode.action("workbench.action.closeActiveEditor") end,
  { desc = "Close editor" })

-- Format via VS Code (rather than conform)
map("n", "<leader>cf", function() vscode.action("editor.action.formatDocument") end,
  { desc = "Format buffer (VS Code)" })

---------------------------------------------------------------------------
-- 4) Editing plugins that work without a UI (loaded from hermetic packpath)
---------------------------------------------------------------------------

-- nvim-surround
local ok_surround, surround = pcall(require, "nvim-surround")
if ok_surround then surround.setup() end

-- Comment.nvim
local ok_comment, comment = pcall(require, "Comment")
if ok_comment then comment.setup() end

-- Leap motions
local ok_leap, leap = pcall(require, "leap")
if ok_leap then
  map({"n", "x", "o"}, "s",  function() leap.leap({}) end,
    { desc = "Leap forward" })
  map({"n", "x", "o"}, "S",  function() leap.leap({ backward = true }) end,
    { desc = "Leap backward" })
end
