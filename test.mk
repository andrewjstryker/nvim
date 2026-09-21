#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
#
# test.mk
#
# Testing and verification -- a first-class concern.
#
# Responsibilities:
#   - Smoke-test a freshly built/synced config in throwaway directories, running
#     the headless checks under test/session/ (parsers, keymaps, Lua/Fennel).
#   - Verify rendered artifacts before install (no unexpanded m4 tokens; no
#     keymap collisions).
#
# Targets:
#   test-fast        -- build + install into temp, clean startup (no network,
#                       seconds).
#   check            -- verify, plus every check that runs offline against the
#                       already-synced cache.  Narrow with CHECKS=.
#   test             -- full sync into temp; every check (network).
#   verify           -- fail if staged Lua still contains unresolved M4_ tokens.
#
# Design:
#   This file holds no test logic, and no per-check targets.  It selects a
#   tier and hands the work to one driver under test/, the way
#   protocol/tests/staging.sh is driven -- a single implementation of
#   "throwaway XDG root, real build into it, headless Neovim against it".
#
#   The checks reuse the SAME code the runtime uses (e.g. config.keymap's
#   audit) rather than a second rulebook, and they run against the INSTALLED
#   image, never src/: the m4 render and the staging rules are part of what is
#   under test.  A sub-make re-stages with the temp config path, so the next
#   real `make install` re-stages.
#
# Assumptions:
#   - environment.mk has defined:
#       NVIM, TIMEOUT, NVIM_CONFIG_DIR, NVIM_CACHE_DIR
#   - project.mk has defined stage_nvim_dir.
#   - the top-level Makefile enforces the /nvim invariant on the dir variables
#     and provides the install/sync targets these invoke.
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#

#------------------------------------------------------------------------------#
# Tiers
#
# Three entry points, distinguished by PRECONDITION -- the one thing a caller
# cannot infer.  Which checks a tier runs is a list, not a target: adding a
# check must not add an entry point.
#
#   test-fast  needs nothing        build + install, does Neovim start?
#   check      needs `make sync`    + every check that works offline
#   test       needs the network    + a full sync and the install check
#
# `check` is the protocol's own extension point ("stage and run
# concern-defined checks"); this concern hooks verify and the offline
# behavioral checks into it rather than growing siblings beside it.
#
# All of it runs through one driver, test/checks.sh, which installs into a
# throwaway root and runs the named checks against that single install:
#
#   test/checks.sh         the driver (POSIX sh, like protocol/tests/staging.sh)
#   test/lua_runtime.sh    the lua_runtime check, which needs whole sessions
#   test/session/*.lua     assertions inside one running Neovim
#
# Each test/session/*.lua asserts BEHAVIOR and exits non-zero on failure.  The
# treesitter pair never looks at where a parser or a query file landed; see
# design.md §2.
#
#   ts_works    — does treesitter work for every language the build promises?
#   ts_install  — can this environment install a language it does not have?
#   keymaps     — do any config-owned keys collide?
#   lua_runtime — does the lazy Lua/Fennel resolve behave, first buffer on?
#
# Everything runs against temp directories, so the real ${NVIM_CONFIG_DIR} is
# never touched.  Stage is left holding temp-path artifacts; the next real
# `make install` cheaply re-stages.
#------------------------------------------------------------------------------#

# Tools reach the driver through the environment so host discovery stays in
# environment.mk and the tests never grow a second rulebook.
test_env = NVIM='${NVIM}' TIMEOUT='${TIMEOUT}' MAKE='$(MAKE)'

# ts_install is the only check that needs the network: it installs a language
# the canonical set deliberately lacks.  Everything else runs offline against
# an already-synced cache.
offline_checks = keymaps ts_works lua_runtime
online_checks  = ${offline_checks} ts_install

# Narrow either tier while iterating:  make check CHECKS=lua_runtime
CHECKS ?=

.PHONY: test-fast #> Quick smoke test: build + install + clean startup (no network)
test-fast:
	@${test_env} sh test/checks.sh

# Hooked into the protocol's `check`, below.  Ordered after verify so a
# parallel make cannot re-stage with temp paths while verify greps the stage.
.PHONY: test-installed
test-installed: verify
	@${test_env} sh test/checks.sh -c '${NVIM_CACHE_DIR}' \
	  $(if ${CHECKS},${CHECKS},${offline_checks})

check: test-installed

# One sync, one install, every check.
.PHONY: test #> Full check: install and sync into temp, then every check (network)
test:
	@tmp_root="$$(mktemp -d)"; \
	tmp_cache="$$tmp_root/cache/nvim"; \
	mkdir -p "$$tmp_cache"; \
	trap 'rm -rf "$$tmp_root"' EXIT; \
	${test_env} sh test/checks.sh -c "$$tmp_cache" -t 'install sync' \
	  $(if ${CHECKS},${CHECKS},${online_checks})

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
