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

# treesitter parser provisioning
include treesitter.mk

# testing and verification (smoke tests, keymap check, m4-token verify)
include test.mk

#------------------------------------------------------------------------------#
# Verify invariants
#------------------------------------------------------------------------------#

# NVIM_CONFIG_DIR must end with /nvim.  The build uses $(dir ...) to derive
# XDG_CONFIG_HOME (stripping the trailing component), which only produces
# the correct XDG base directory when the final component is "nvim".
ifneq ($(notdir ${NVIM_CONFIG_DIR}),nvim)
  $(error NVIM_CONFIG_DIR must end with /nvim (got: ${NVIM_CONFIG_DIR}))
endif
ifneq ($(notdir ${NVIM_CACHE_DIR}),nvim)
  $(error NVIM_CACHE_DIR must end with /nvim (got: ${NVIM_CACHE_DIR}))
endif

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
#   config_env is a normal prerequisite: its PHONY recipe runs every time,
#   but the cmp guard only updates the file when content changes, so
#   downstream targets rebuild only when the environment actually changed.
.PHONY: build #> Build stage/nvim code image (Lua, templates, Fennel)
build: check-tools ${stage_outputs} ${config_env} verify

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
#   3. rocks-bootstrap  — install toml-edit (for rocks.toml parsing)
#   4. rocks-sync       — parse rocks.toml with host Lua + toml-edit, then:
#                           * install native rocks via luarocks CLI
#                           * git-clone plugins into the pack directory
#
# rocks.toml is the single authority for package versions.
# All steps are idempotent.  Steps 3-4 require network access.
#
# Step 5 (build-parsers) provisions the canonical treesitter parser set into
# the hermetic parser dir, so a working install never depends on the Neovim
# binary happening to bundle them.  It is behavioral: parsers that already load
# (bundled or previously installed) are left untouched, so hosts whose Neovim
# ships them do no work and need no network.
#
# The smoke tests below check both paths, with deliberately different severity:
#   * ts_shipped  — missing *bundled* parsers is expected content the install
#                   failed to provide: a loud WARNING, never a build failure.
#   * ts_install  — a broken *install capability* makes every missing parser
#                   unrecoverable: a hard ERROR that fails the build.
#------------------------------------------------------------------------------#

.PHONY: sync #> Build, install, and sync all plugins from rocks.toml
sync: check-tools install rocks-sync build-parsers

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
