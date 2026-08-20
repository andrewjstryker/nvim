-- ~/.config/nvim/lua/config/parsers.lua
--
-- The canonical treesitter parser list.  ONE source of truth, consumed by:
--   * build/scripts/install_parsers.lua -- `make sync` provisioning
--   * lua/plugins/treesitter.lua   -- which filetypes get treesitter enabled
--   * test/ts_works.lua            -- every entry must actually highlight
--
-- This list is a synchronization contract. `make sync` installs every
-- entry (parser + queries) and fails the build if any cannot be installed; the
-- runtime then assumes they are there.  Adding a language means editing this
-- file and re-running `make sync` -- there is no install-on-use path.
--
-- Split into two groups to record WHY each language is in the set:
--
--   * baseline -- markdown rendering + the vimdoc parser help.lua asserts.
--   * fenced   -- languages we commonly embed in fenced code blocks, plus
--                 mermaid (syntax highlighting for ```mermaid blocks; actual
--                 diagram rendering is a separate, terminal-dependent concern).
--
-- The groups carry no operational difference: every entry is provisioned and
-- verified identically, and all() is what callers use.  In particular, whether
-- a language is ALSO bundled with the Neovim binary is irrelevant -- the build
-- installs it either way, because under nvim-treesitter's `main` branch a
-- language's queries are installed with it, and those queries are what
-- highlighting actually needs.

local M = {}

M.baseline = {
  "markdown",
  "markdown_inline",
  "vimdoc",
  "lua",
  "vim",
  "query",
  "c",
}

M.fenced = {
  "python",
  "bash",
  "json",
  "yaml",
  "toml",
  "sql",
  "r",
  "mermaid",
}

-- The full provisioning set (baseline + fenced), de-duplicated and order-stable.
function M.all()
  local seen, out = {}, {}
  for _, group in ipairs({ M.baseline, M.fenced }) do
    for _, lang in ipairs(group) do
      if not seen[lang] then
        seen[lang] = true
        out[#out + 1] = lang
      end
    end
  end
  return out
end

return M
