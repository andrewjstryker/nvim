-- ~/.config/nvim/lua/plugins/lsp.lua
-- Plugin: nvim-lspconfig (config provider)
--
-- Neovim 0.12 native LSP: nvim-lspconfig provides default configs via its
-- lsp/ directory on the runtimepath.  We customize with vim.lsp.config()
-- and activate with vim.lsp.enable().  No require('lspconfig') needed.

---------------------------------------------------------------------------
-- Shared config for all servers
---------------------------------------------------------------------------

-- Advertise cmp-nvim-lsp capabilities to all servers
local capabilities = vim.lsp.protocol.make_client_capabilities()
local ok_cmp_lsp, cmp_lsp = pcall(require, "cmp_nvim_lsp")
if ok_cmp_lsp then
  capabilities = cmp_lsp.default_capabilities(capabilities)
end

vim.lsp.config("*", {
  capabilities = capabilities,
  root_markers = { ".git" },
})

-- Buffer-local LSP keymaps (set once when any server attaches)
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("LspKeymaps", { clear = true }),
  callback = function(ev)
    local map = vim.keymap.set
    local opts = function(desc)
      return { buffer = ev.buf, desc = desc }
    end

    map("n", "gd",         vim.lsp.buf.definition,      opts("Go to definition"))
    map("n", "gD",         vim.lsp.buf.declaration,      opts("Go to declaration"))
    map("n", "gr",         vim.lsp.buf.references,       opts("References"))
    map("n", "gi",         vim.lsp.buf.implementation,   opts("Implementation"))
    map("n", "K",          vim.lsp.buf.hover,            opts("Hover docs"))
    map("n", "<leader>rn", vim.lsp.buf.rename,           opts("Rename symbol"))
    map("n", "<leader>ca", vim.lsp.buf.code_action,      opts("Code action"))
    map("n", "[d",         vim.diagnostic.goto_prev,     opts("Prev diagnostic"))
    map("n", "]d",         vim.diagnostic.goto_next,     opts("Next diagnostic"))
  end,
})

---------------------------------------------------------------------------
-- Per-server overrides
--
-- nvim-lspconfig provides sensible defaults for each server (cmd,
-- filetypes, root_markers) via its lsp/ directory.  We only need to
-- override where our setup differs from those defaults.
---------------------------------------------------------------------------

-- Python: install with `pip install pyright ruff`
-- (ruff_lsp is deprecated; ruff has a native LSP server now)
vim.lsp.config("ruff", {
  -- ruff handles formatting and linting; disable hover to let pyright own it
  on_attach = function(client, _)
    client.server_capabilities.hoverProvider = false
  end,
})

-- Enable all servers (nvim-lspconfig supplies cmd, filetypes, root_markers)
-- Each server auto-starts only when its filetypes are opened.
vim.lsp.enable({
  "pyright",
  "ruff",
  "r_language_server",
  "sqlls",
  "marksman",
})
