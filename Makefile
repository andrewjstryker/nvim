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

# luarocks config + core rocks bootstrap
include seed.mk

#------------------------------------------------------------------------------#
# Verify invariants (tools must exist)
#------------------------------------------------------------------------------#

toolset_vars := LUA NVIM LUAROCKS RSYNC GIT AWK M4

missing_tools := \
  $(strip \
    $(foreach v,$(toolset_vars), \
      $(if $(strip $($v)),,$v) \
    ) \
  )

# Guard target: any target that needs the full toolset depends on this.
# Targets like clean and help do NOT depend on it, so they work even when
# tools are missing.
.PHONY: check-tools
check-tools:
ifneq (${missing_tools},)
	$(error Missing required tools: ${missing_tools})
endif

#------------------------------------------------------------------------------#
# Human interface
#------------------------------------------------------------------------------#

.PHONY: help #> Show this help message
help:
	@${AWK} -f ${build_dir}/bin/generate-help.awk ${MAKEFILE_LIST}

# show: display resolved paths and variables.
#
# Uses a heredoc to avoid shell quoting issues with paths that contain
# special characters (the summary blocks may contain $(dir ...) expansions
# with trailing slashes, etc.).
.PHONY: show #> Show configuration variables
show:
	@cat <<'SHOW_EOF'
	Environment:
	${env_summary}

	Project:
	${project_summary}

	Tools:
	${toolset_summary}
	SHOW_EOF

#------------------------------------------------------------------------------#
# Build & stage
#------------------------------------------------------------------------------#

# Build: stage code image (Lua, templates, Fennel)
#   config_env is order-only: its PHONY nature triggers re-evaluation every
#   run, but the cmp guard means downstream files only rebuild when the
#   content actually changes.
.PHONY: build #> Build stage/nvim code image (Lua, templates, Fennel)
build: check-tools ${stage_outputs} | ${config_env}

# Stage: assemble the complete staging directory (code + runtime dirs)
.PHONY: stage #> Construct the entire staging directory
stage: build runtime

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
# Sync: install + sync all plugins from rocks.toml
#
# Pipeline:
#   1. stage + install  — copy config to NVIM_CONFIG_DIR
#   2. luarocks_config  — write hermetic luarocks config.lua
#   3. luarocks_wrapper — write wrapper script for rocks.nvim subprocess calls
#   4. rocks-bootstrap  — install toml-edit (for rocks.toml parsing)
#   5. rocks-sync       — parse rocks.toml with host Lua + toml-edit, then:
#                           * install native rocks via luarocks CLI
#                           * git-clone plugins into the pack directory
#
# rocks.toml is the single authority for package versions.
# All steps are idempotent.  Steps 4-5 require network access.
#
# This produces the same on-disk layout that rocks.nvim and rocks-git.nvim
# would create via interactive `:Rocks sync`.  At runtime, rocks.nvim and
# rocks-git.nvim manage updates and additions interactively as normal.
#------------------------------------------------------------------------------#

.PHONY: sync #> Build, install, and sync all plugins from rocks.toml
sync: check-tools install rocks-sync

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
