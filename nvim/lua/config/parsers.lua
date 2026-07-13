-- ~/.config/nvim/lua/config/parsers.lua
--
-- The canonical treesitter parser list.  ONE source of truth, consumed by:
--   * lua/plugins/treesitter.lua   -- ensure_installed (runtime auto_install)
--   * build/scripts/install_parsers.lua -- `make build-parsers` provisioning
--   * test/ts_shipped.lua          -- bundled-parser expectation (baseline slice)
--
-- Split into two groups so callers can ask for the load-bearing baseline (what
-- a standard Neovim install bundles) separately from the extras we add for
-- fenced-code and diagram support.
--
--   * baseline -- markdown rendering + the vimdoc parser help.lua asserts.
--   * fenced   -- languages we commonly embed in fenced code blocks, plus
--                 mermaid (syntax highlighting for ```mermaid blocks; actual
--                 diagram rendering is a separate, terminal-dependent concern).
--
-- Membership is deliberately behavioral-agnostic: whether a parser is already
-- provided by the Neovim binary or must be compiled into the hermetic
-- treesitter dir is decided at install time by can-it-load, not by this list.

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
