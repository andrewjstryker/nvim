-- ~/.config/nvim/lua/plugins/completion.lua
-- Plugins: nvim-cmp, cmp-nvim-lsp, cmp-buffer, cmp-path, copilot.lua

-- Copilot (setup first so cmp can reference it)
local ok_copilot, copilot = pcall(require, "copilot")
if ok_copilot then
  copilot.setup({
    server     = { type = "binary" }, -- use standalone copilot-language-server; no host Node.js
    suggestion = { enabled = false },  -- disable inline ghost text; use cmp instead
    panel      = { enabled = false },
  })
end

-- nvim-cmp
local ok_cmp, cmp = pcall(require, "cmp")
if not ok_cmp then return end

cmp.setup({
  -- No snippet engine configured — expand LSP snippets with basic insert.
  -- Add luasnip or snippy later if you want snippet support.
  snippet = {
    expand = function(args)
      vim.snippet.expand(args.body)    -- Neovim 0.10+ built-in snippets
    end,
  },

  mapping = cmp.mapping.preset.insert({
    ["<C-n>"]     = cmp.mapping.select_next_item(),
    ["<C-p>"]     = cmp.mapping.select_prev_item(),
    ["<C-b>"]     = cmp.mapping.scroll_docs(-4),
    ["<C-f>"]     = cmp.mapping.scroll_docs(4),
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<C-e>"]     = cmp.mapping.abort(),
    ["<CR>"]      = cmp.mapping.confirm({ select = false }),  -- only confirm explicit selection
  }),

  sources = cmp.config.sources({
    { name = "nvim_lsp" },
    { name = "path" },
  }, {
    { name = "buffer", keyword_length = 3 },
  }),
})
