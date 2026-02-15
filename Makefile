#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
#
# Makefile
#
# Build, install, and sync Neovim configuration
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#

#------------------------------------------------------------------------------#
# Configure execution
#------------------------------------------------------------------------------#

SHELL := bash
.SHELLFLAGS := --noprofile --norc -euo pipefail -c

.DEFAULT_GOAL := help
.DELETE_ON_ERROR:

#------------------------------------------------------------------------------#
# Includes
#------------------------------------------------------------------------------#

# environment variables (user-facing knobs)
include environment.mk

# project-wide derived variables and structure
include project.mk

# build Lua modules in stage
include build.mk

# seed plugin managers (vendored submodules → stage)
include seed.mk

#------------------------------------------------------------------------------#
# Verify invariants (tools must exist)
#------------------------------------------------------------------------------#

toolset_vars := LUA NVIM RSYNC GIT AWK M4

missing_tools := \
  $(strip \
    $(foreach v,$(toolset_vars), \
      $(if $(strip $($v)),,$v) \
    ) \
  )

ifneq (${missing_tools},)
  $(error Missing required tools: ${missing_tools})
endif

#------------------------------------------------------------------------------#
# Human interface
#------------------------------------------------------------------------------#

.PHONY: help #> Show this help message
help:
	@${AWK} -f ${build_dir}/bin/generate-help.awk ${MAKEFILE_LIST}

.PHONY: show #> Show configuration variables
show:
	@printf '%s\n\n' "Environment:" "${env_summary}"
	@printf '%s\n\n' "Project:" "${project_summary}"
	@printf '%s\n' "Tools:"
	@printf '%s\n' "${toolset_summary}"

#------------------------------------------------------------------------------#
# Build & stage
#------------------------------------------------------------------------------#

# Build: stage code image (Lua, templates, Fennel)
#   config_env is order-only: its PHONY nature triggers re-evaluation every
#   run, but the cmp guard means downstream files only rebuild when the
#   content actually changes.
.PHONY: build #> Build stage/nvim code image (Lua, templates, Fennel)
build: ${stage_outputs} | ${config_env}

# Stage: assemble the complete staging directory (code + runtime dirs + seeds)
.PHONY: stage #> Construct the entire staging directory
stage: build runtime ${seed_targets}

#------------------------------------------------------------------------------#
# Install: sync stage → NVIM_CONFIG_DIR
#------------------------------------------------------------------------------#

.PHONY: install #> Install staged Neovim config into NVIM_CONFIG_DIR
install: stage
	@echo "Installing Neovim config to ${NVIM_CONFIG_DIR}"
	@mkdir -p "${NVIM_CONFIG_DIR}"
	@${RSYNC} --archive --delete \
	  "${stage_nvim_dir}/" \
	  "${NVIM_CONFIG_DIR}/"

#------------------------------------------------------------------------------#
# Sync: install + headless :Rocks sync
#
# This is the only step that requires network access.
# rocks_sync.lua:
#   - prepends NVIM_CONFIG_DIR to rtp/packpath (since we run with -u NONE)
#   - requires config.env (wires hermetic paths + vim.g.rocks_nvim)
#   - runs :packadd rocks.nvim + :Rocks sync
#
# The luarocks_config target is an install-time concern (writes to
# NVIM_CACHE_DIR, not stage/), so it lives here rather than in stage.
#------------------------------------------------------------------------------#

.PHONY: sync #> Build, install, and run headless Rocks sync
sync: install ${luarocks_config}
	@echo "Running Rocks sync on installed Neovim config..."
	@LUAROCKS_CONFIG="${luarocks_config}" \
	  NVIM_CONFIG_DIR="${NVIM_CONFIG_DIR}" \
	  ${NVIM} --headless -u NONE \
	    +"luafile ${scripts_dir}/rocks_sync.lua" \
	    +qa

#------------------------------------------------------------------------------#
# Test: smoke test using temporary config/cache directories
#
# Runs the FULL sync pipeline in temp dirs so that m4 templates are rendered
# with the temp paths (not the user's real paths).  If sync completes and
# Neovim starts, the project is working.
#
# NOTE: This clobbers stage/ with temp-path artifacts.  The next real
# `make sync` will cheaply re-stage with real paths.
#------------------------------------------------------------------------------#

.PHONY: test #> Smoke test: full sync into temporary directories
test:
	@tmp_cfg="$$(mktemp -d)"; \
	tmp_cache="$$(mktemp -d)"; \
	trap 'rm -rf "$$tmp_cfg" "$$tmp_cache"' EXIT; \
	echo "Smoke test using:"; \
	echo "  NVIM_CONFIG_DIR=$$tmp_cfg"; \
	echo "  NVIM_CACHE_DIR=$$tmp_cache"; \
	$(MAKE) sync \
	  NVIM_CONFIG_DIR="$$tmp_cfg" \
	  NVIM_CACHE_DIR="$$tmp_cache"

#------------------------------------------------------------------------------#
# Verify: check rendered artifacts for unexpanded m4 tokens
#------------------------------------------------------------------------------#

.PHONY: verify #> Verify no unexpanded NV_M4_ tokens remain in staged Lua
verify: build
	@echo "Checking for unexpanded m4 tokens in staged Lua files..."
	@if grep -rn 'NV_M4_[A-Z_]*' ${stage_nvim_dir}/lua/ 2>/dev/null \
	    | grep -v '^\s*--'; then \
	  echo "ERROR: Unexpanded m4 tokens found in staged output"; \
	  exit 1; \
	fi
	@echo "All clear."

#------------------------------------------------------------------------------#
# Clean / uninstall
#------------------------------------------------------------------------------#

.PHONY: clean #> Remove stage/
clean:
	@printf "\033[1;33mRemoving stage/…\033[0m\n"
	@rm -rf "${stage_dir}"
	@printf "\033[1;32mArtifacts removed.\033[0m\n"

.PHONY: clean-cache
clean-cache:
	@printf "\033[1;33mRemoving hermetic rocks cache…\033[0m\n"
	@rm -rf "${nvim_rocks_dir}" "${luarocks_config_dir}"
	@printf "\033[1;32mCache removed.\033[0m\n"

.PHONY: uninstall #> Remove installed config (FORCE=1 required) and stage
uninstall: clean
	@if [[ "${FORCE:-0}" == "1" ]]; then \
		printf "\033[1;33mFORCE=1: removing %s\033[0m\n" "${NVIM_CONFIG_DIR}"; \
		rm -rf "${NVIM_CONFIG_DIR}"; \
	else \
		printf "\033[1;34mConfig preserved. Use FORCE=1 to remove %s.\033[0m\n" \
			"${NVIM_CONFIG_DIR}"; \
	fi

.PHONY: uninstall-cache #> Remove installed config + hermetic cache
uninstall-cache: uninstall clean-cache

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
