#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
#
# treesitter.mk
#
# Responsibilities:
#   - Provision the canonical treesitter parser set into the hermetic parser
#     dir (${nvim_treesitter_dir}), so a working install never depends on the
#     Neovim binary happening to bundle the parsers it needs.
#
# Design:
#   build-parsers runs headless under the installed config and executes
#   build/scripts/install_parsers.lua.  That script hands the canonical set
#   (lua/config/parsers.lua) to nvim-treesitter's installer, which compiles and
#   installs both the parsers and their queries into ${nvim_treesitter_dir}.
#
#   Idempotency belongs to the installer, not to us: nvim-treesitter records the
#   grammar revision it installed per language and skips anything already at
#   that revision, so re-runs only compile what changed.  We do NOT pre-filter
#   with a can-it-load check -- under the `main` branch a language's queries are
#   installed alongside it, so a parser that loads says nothing about whether
#   its queries are present.
#
#   This target is what ESTABLISHES the parser invariant; the runtime assumes it
#   holds and does no install-on-use (see lua/plugins/treesitter.lua).  So the
#   severity here is a hard error: a parser that cannot be installed fails the
#   build, matching ts_install.
#
#   The headless Neovim runs with XDG_CONFIG_HOME/XDG_CACHE_HOME exported from
#   the install locations.  Without them `-u ${NVIM_CONFIG_DIR}/init.lua` still
#   picks up the user's real ~/.config/nvim through the default runtimepath, so
#   a build targeting a temp tree would provision the real one instead and then
#   verify it -- reporting success while leaving the temp tree empty.
#
# Assumptions:
#   - environment.mk has defined:
#       NVIM, NVIM_CONFIG_DIR, TREE_SITTER
#   - project.mk has defined:
#       nvim_treesitter_dir, scripts_dir, nvim_xdg_config, nvim_xdg_cache
#   - The config is installed and nvim-treesitter cloned. provision-parsers is
#     the lifecycle primitive; build-parsers adds those prerequisites so it
#     remains useful as a standalone command.
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#

#------------------------------------------------------------------------------#
# tree-sitter CLI guard
#
# Scoped to this file rather than added to the global toolset: build, install,
# and test-fast are unaffected by a missing CLI, and only parser compilation
# needs it.  environment.mk resolves TREE_SITTER to empty when the binary is
# absent OR older than ${TREE_SITTER_MIN_VERSION}.
#------------------------------------------------------------------------------#

.PHONY: check-treesitter-cli
check-treesitter-cli:
ifeq ($(strip ${TREE_SITTER}),)
	$(error tree-sitter CLI >= ${TREE_SITTER_MIN_VERSION} not found on PATH. \
	  nvim-treesitter compiles parsers with `tree-sitter build`. \
	  Install it with `cargo install tree-sitter-cli` (not npm), \
	  or set TREE_SITTER=/path/to/tree-sitter)
endif

#------------------------------------------------------------------------------#
# Provision the canonical parser set
#
# Idempotent: nvim-treesitter skips languages already at the recorded revision,
# so re-runs only compile what changed.
#------------------------------------------------------------------------------#

.PHONY: provision-parsers
provision-parsers: check-tools check-treesitter-cli
	@echo "Provisioning treesitter parsers into ${nvim_treesitter_dir}..."
	@XDG_CONFIG_HOME="${nvim_xdg_config}" \
	  XDG_CACHE_HOME="${nvim_xdg_cache}" \
	  ${NVIM} --headless \
	    -u "${NVIM_CONFIG_DIR}/init.lua" \
	    -c "luafile ${scripts_dir}/install_parsers.lua" \
	    -c "qa"

.PHONY: build-parsers #> Install prerequisites and compile the canonical parser set
build-parsers: install rocks-sync provision-parsers

#------------------------------------------------------------------------------#
# Discard the hermetic parser tree
#
# The remedy build-parsers points at when its verification fails.  Needed
# because nvim-treesitter's installer treats a .so already sitting in the
# install dir as proof the language is fully installed and skips it -- queries
# and all.  A parser tree written by a different layout (notably the pre-`main`
# one, which had no queries dir) can therefore never be repaired in place: the
# only way forward is to remove it and reprovision.
#
# Safe to run at any time.  ${nvim_treesitter_dir} is entirely build-owned and
# holds nothing but compiled output; the next build-parsers rebuilds it.
#------------------------------------------------------------------------------#

.PHONY: clean-parsers #> Remove the hermetic treesitter tree (parsers + queries)
clean-parsers:
	@printf "\033[1;33mRemoving %s…\033[0m\n" "${nvim_treesitter_dir}"
	@rm -rf "${nvim_treesitter_dir}"
	@printf "\033[1;32mParser tree removed. Run \`make build-parsers\` to reprovision.\033[0m\n"

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
