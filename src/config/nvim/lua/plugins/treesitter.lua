-- ~/.config/nvim/lua/plugins/treesitter.lua
-- Plugin: nvim-treesitter (the `main` branch -- the v1.0 rewrite)
--
-- Branch choice is load-bearing.  The old `master` branch is locked at Neovim
-- <= 0.11: under 0.12 its query directives still index `match[capture_id]` as a
-- single node, but Neovim now passes a LIST of nodes per capture id, so every
-- markdown injection dies with "attempt to call method 'range' (a nil value)".
-- `main` targets Neovim 0.12+ and is the only branch that works here.
--
-- `main` is a different plugin, not a version bump.  There is no
-- `nvim-treesitter.configs`, no `ensure_installed`, no `auto_install`, and no
-- `:TSInstallSync`.  It provides a parser installer, the queries for those
-- parsers, and an indent expression.  Highlighting, folding, and injections are
-- Neovim's own, enabled per buffer -- which is what this file does.
--
-- Ownership follows the project's probing policy (design.md §2/§4): the parser
-- set is a BUILD-TIME INVARIANT, so runtime assumes it holds.
--
--   * config.parsers is the canonical set.  `make sync` provisions it via
--     sync, which fails if any parser cannot be installed.
--   * Adding a language is a build-time act: add it to config.parsers and
--     re-run `make sync`.  There is deliberately no install-on-use path --
--     `master`'s auto_install was the runtime half of a build-time concern, and
--     under `main` it would mean hand-rolled probing (is the CLI on PATH? is
--     the language in the registry? did the compile succeed?) to repair a
--     provisioning step that already ran.
--   * The tree-sitter CLI that `main` shells out to is likewise a build-time
--     prerequisite, discovered as TREE_SITTER in environment.mk and enforced by
--     `make sync`.  Runtime does not re-check it.

local ts = require("nvim-treesitter")
local env = require("config.env")

-- Parsers AND queries install here.  Under `main` the queries for a language
-- ship with the language -- they are linked into <install_dir>/queries/<lang>/
-- at install time rather than carried on the plugin's own runtimepath.
--
-- setup() prepends install_dir to the runtimepath, and it is the SOLE owner of
-- that entry: env.lua deliberately leaves the treesitter dir out of the
-- hermetic rtp it builds.  Listing it in both places puts it on the rtp twice,
-- and Neovim reads every query file under a duplicated entry twice and
-- concatenates the results.
--
-- The dir has to exist BEFORE setup() puts it on the runtimepath.  Neovim
-- resolves the runtimepath once at startup and drops entries that are not there
-- yet, so on a freshly cleaned tree the install dir would stay invisible for the
-- whole session: parsers install successfully and then fail to load, which is
-- exactly what `make clean-parsers && make sync` does in one process.
vim.fn.mkdir(env.treesitter_dir .. "/parser", "p")

ts.setup({ install_dir = env.treesitter_dir })

---------------------------------------------------------------------------
-- Enable highlighting and indentation
--
-- `main` ships neither: highlighting is Neovim's (vim.treesitter.start) and
-- indentation is this plugin's indentexpr.  Both are enabled for exactly the
-- filetypes served by the canonical parser set -- no wider, so a filetype
-- without a provisioned parser keeps its regex syntax instead of erroring, and
-- no narrower, so every language the build promises is actually lit up.
--
-- The language -> filetype mapping comes from Neovim's own registry (a parser
-- can serve several filetypes: bash -> sh, vimdoc -> help, ...), so the
-- pattern list stays correct without a second table to maintain here.
---------------------------------------------------------------------------
local ft_lang = {}
for _, lang in ipairs(require("config.parsers").all()) do
  for _, ft in ipairs(vim.treesitter.language.get_filetypes(lang)) do
    ft_lang[ft] = lang
  end
end

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("TreesitterAttach", { clear = true }),
  pattern = vim.tbl_keys(ft_lang),
  callback = function(args)
    vim.treesitter.start(args.buf, ft_lang[args.match])
    vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end,
})
