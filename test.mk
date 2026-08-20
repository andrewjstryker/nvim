#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
#
# test.mk
#
# Testing and verification -- a first-class concern.
#
# Responsibilities:
#   - Smoke-test a freshly built/synced config in throwaway directories, running
#     the headless checks under test/ (parsers, keymaps).
#   - Verify rendered artifacts before install (no unexpanded m4 tokens; no
#     keymap collisions).
#
# Targets:
#   test-fast     -- build + install into temp; warns on missing bundled parsers
#                    (no network, seconds).
#   test          -- full sync into temp; runs every test/ check (network).
#   check-keymaps -- load the full config headless and fail on keymap collisions
#                    BEFORE install (fast: temp config dir, real synced cache).
#   verify        -- fail if staged Lua still contains unresolved M4_ tokens.
#
# Design:
#   Everything runs against a TEMP config dir so the real ${NVIM_CONFIG_DIR} is
#   never touched.  The headless checks (test/*.lua) each exit non-zero on
#   failure and reuse the SAME code the runtime uses (e.g. config.keymap's audit)
#   rather than a second rulebook.  Like the smoke tests, a sub-make re-stages
#   with the temp config path, so the next real `make install` re-stages.
#
# Assumptions:
#   - environment.mk has defined:
#       NVIM, NVIM_CONFIG_DIR, NVIM_CACHE_DIR
#   - project.mk has defined stage_nvim_dir.
#   - the top-level Makefile enforces the /nvim invariant on the dir variables
#     and provides the install/sync targets these invoke.
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#

#------------------------------------------------------------------------------#
# Smoke tests
#
# Two tiers:
#   test-fast  — build + install + verify (no network, seconds)
#   test       — full sync + smoke (network required, ~1 min)
#
# The treesitter checks in the `test` tier assert BEHAVIOR, never layout:
#   ts_works    — does treesitter work for every language the build promises?
#   ts_install  — can this environment install a language it does not have?
# Neither looks at where a parser or query file landed; see design.md §2.
#
# Both use temp directories so the user's real config is never touched.
# Stage is left containing temp-path artifacts; the next real `make install`
# will cheaply re-stage with real paths.
#------------------------------------------------------------------------------#

# Shared helper: set up temp dirs, run one or more ordered make targets, then
# smoke-test Neovim. Each sub-Make is a deliberate, shallow build evaluation
# with the temporary installation context.
# Usage: $(call run_smoke,<ordered-make-targets>[,<test scripts>])
#
# The optional second argument is a space-separated list of Lua test scripts
# (see test/) run headless under the freshly installed config; each must exit
# non-zero on failure. Used to check parsers and keymaps after sync.
#
# The temp directory structure ($tmp/config/nvim, $tmp/cache/nvim) satisfies
# the /nvim invariant enforced in the top-level Makefile, so $(dir ...) produces
# correct XDG base directories.
define run_smoke
	@tmp_root="$$(mktemp -d)"; \
	tmp_cfg="$$tmp_root/config/nvim"; \
	tmp_cache="$$tmp_root/cache/nvim"; \
	mkdir -p "$$tmp_cfg" "$$tmp_cache" "$$tmp_root/state" "$$tmp_root/data"; \
	trap 'rm -rf "$$tmp_root"' EXIT; \
	echo "Smoke test using:"; \
	echo "  NVIM_CONFIG_DIR=$$tmp_cfg"; \
	echo "  NVIM_CACHE_DIR=$$tmp_cache"; \
	for target in $(1); do \
	  $(MAKE) "$$target" \
	    NVIM_CONFIG_DIR="$$tmp_cfg" \
	    NVIM_CACHE_DIR="$$tmp_cache"; \
	done; \
	echo "Verifying Neovim starts cleanly..."; \
	smoke_err="$$tmp_root/smoke_stderr.log"; \
	XDG_CONFIG_HOME="$$tmp_root/config" \
	  XDG_CACHE_HOME="$$tmp_root/cache" \
	  XDG_STATE_HOME="$$tmp_root/state" \
	  XDG_DATA_HOME="$$tmp_root/data" \
	  ${NVIM} --headless \
	    -u "$$tmp_cfg/init.lua" \
	    +"lua assert(package.loaded['config.env'], 'config.env not loaded')" \
	    +qa 2>"$$smoke_err"; \
	if grep -q "^Error\|^E[0-9]" "$$smoke_err"; then \
	  echo "Smoke test FAILED — Neovim produced errors:"; \
	  cat "$$smoke_err"; \
	  exit 1; \
	fi; \
	echo "Smoke test passed."; \
	scripts="$(2)"; \
	for tscript in $$scripts; do \
	  echo "Post-sync check: $$tscript"; \
	  XDG_CONFIG_HOME="$$tmp_root/config" \
	    XDG_CACHE_HOME="$$tmp_root/cache" \
	    XDG_STATE_HOME="$$tmp_root/state" \
	    XDG_DATA_HOME="$$tmp_root/data" \
	    ${NVIM} --headless \
	      -u "$$tmp_cfg/init.lua" \
	      -c "luafile $$tscript" \
	      -c "qa" \
	    || { echo "Check FAILED: $$tscript"; exit 1; }; \
	done
endef

# test-fast deliberately runs no post-sync checks. It installs the config
# but never provisions plugins or parsers, so the only honest thing to assert at
# that point is the one it does assert: Neovim starts cleanly.  Checking
# treesitter here would only ever report the absence of a step this tier skips.
.PHONY: test-fast #> Quick smoke test: build + install + clean startup (no network)
test-fast:
	$(call run_smoke,install)

.PHONY: test #> Full smoke test: install and sync, then check runtime behavior (network)
test:
	$(call run_smoke,install sync,$(abspath test/ts_works.lua) $(abspath test/ts_install.lua) $(abspath test/keymaps.lua))

#------------------------------------------------------------------------------#
# Pre-install keymap collision check
#
# Load the full config headless and run the keymap audit (config.keymap) via
# test/keymaps.lua -- the SAME audit the runtime runs at VimEnter, so there is
# no second rulebook to drift.  The staged config installs into a TEMP config
# dir (the real ${NVIM_CONFIG_DIR} is never touched) while plugins load from the
# already-synced ${NVIM_CACHE_DIR}: fast, no network.
#
# Requires a prior `make sync` so plugin maps are present; without it only
# config-level maps are checked.
#------------------------------------------------------------------------------#

.PHONY: check-keymaps #> Detect keymap collisions before install (needs synced plugins)
check-keymaps: check-stage-tools check-install-tools
	@echo "Checking for keymap collisions..."
	@tmp_root="$$(mktemp -d)"; \
	tmp_cfg="$$tmp_root/config/nvim"; \
	trap 'rm -rf "$$tmp_root"' EXIT; \
	mkdir -p "$$tmp_cfg" "$$tmp_root/cache" "$$tmp_root/state"; \
	$(MAKE) --no-print-directory install \
	  NVIM_CONFIG_DIR="$$tmp_cfg" NVIM_CACHE_DIR="${NVIM_CACHE_DIR}" >/dev/null; \
	XDG_CONFIG_HOME="$$tmp_root/config" \
	  XDG_CACHE_HOME="$$tmp_root/cache" \
	  XDG_STATE_HOME="$$tmp_root/state" \
	  XDG_DATA_HOME="$$tmp_root/data" \
	  ${NVIM} --headless \
	    -u "$$tmp_cfg/init.lua" \
	    -c "luafile $(abspath test/keymaps.lua)" \
	    -c "qa"

#------------------------------------------------------------------------------#
# Verify: check rendered artifacts for unexpanded m4 tokens
#------------------------------------------------------------------------------#

.PHONY: verify #> Verify no unexpanded M4_ tokens remain in staged Lua
verify: stage
	@if grep -rn 'M4_[A-Z_]*' ${stage_nvim_dir}/lua/ 2>/dev/null \
	    | grep -v '^\s*--'; then \
	  echo "ERROR: Unexpanded m4 tokens found in staged output"; \
	  exit 1; \
	fi

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
