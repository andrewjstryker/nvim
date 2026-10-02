-- ~/.config/nvim/lua/plugins/completion.lua
-- Plugins: nvim-cmp, cmp-nvim-lsp, cmp-buffer, cmp-path, copilot.lua, copilot-cmp

-- Copilot (setup first so cmp can reference it)
local ok_copilot, copilot = pcall(require, "copilot")
local copilot_ready = false
if ok_copilot then
  local server = require("config.env").copilot_server
  if vim.fn.executable(server) == 0 then
    vim.notify("Copilot server is missing; run make sync to provision it", vim.log.levels.WARN)
  else
    copilot.setup({
      -- Provisioned by make sync; never download a server during editor startup.
      server = {
        type = "binary",
        custom_server_filepath = server,
      },
      suggestion = { enabled = false },  -- disable inline ghost text; use cmp instead
      panel      = { enabled = false },
    })
    copilot_ready = true
  end
end

-- nvim-cmp
local ok_cmp, cmp = pcall(require, "cmp")
if not ok_cmp then return end

local ok_copilot_cmp, copilot_cmp = pcall(require, "copilot_cmp")
if copilot_ready and ok_copilot_cmp then copilot_cmp.setup() end

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
    { name = "copilot" },
    { name = "nvim_lsp" },
    { name = "path" },
  }, {
    { name = "buffer", keyword_length = 3 },
  }),
})
