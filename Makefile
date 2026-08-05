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

# DESTDIR is the staged-root prefix required by the protocol: it relocates
# where we write without changing what we write.  Empty for a real install.
DESTDIR ?=

install_dir := ${DESTDIR}${NVIM_CONFIG_DIR}

.PHONY: install #> Install staged Neovim config into NVIM_CONFIG_DIR
install: stage
	@echo "Installing Neovim config to ${install_dir}"
	@mkdir -p "${install_dir}"
	@${RSYNC} --archive --delete \
	  "${stage_nvim_dir}/" \
	  "${install_dir}/"

.PHONY: install-dry-run #> Report what install would change
install-dry-run: stage
	@if [ -d "${install_dir}" ]; then \
	  ${RSYNC} --archive --delete --dry-run --itemize-changes \
	    "${stage_nvim_dir}/" \
	    "${install_dir}/"; \
	else \
	  printf 'would create tree %s/ from %s/\n' \
	    "${install_dir}" "${stage_nvim_dir}"; \
	fi

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
# binary happening to bundle them.  It ESTABLISHES that invariant and verifies
# it behaviorally — every canonical language must parse and highlight — so a
# language that cannot be provisioned fails the build rather than degrading
# silently at runtime.
#
# The smoke tests assert the two things a user depends on, both behaviorally:
#   * ts_works    — does treesitter work for every language the build promised?
#                   A hard ERROR: the canonical set is a build-time contract.
#   * ts_install  — can this environment install a language it does not have?
#                   A hard ERROR: without it, anything outside the canonical
#                   set is unreachable.
# Neither asserts on file layout — where a parser or query lives is a build-time
# substitution, authoritative by the probing policy, and invisible to the user.
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

# The protocol forbids gating uninstall behind a confirmation flag: its scope
# is bounded by declaration instead.  This removes the owned config tree and
# nothing else — the hermetic rocks tree, treesitter parsers, and every other
# cache stay put, because they are expensive to rebuild and are not
# configuration.  Use uninstall-cache to take those too.
.PHONY: uninstall #> Remove installed config and stage
uninstall: clean
	@if [ -d "${install_dir}" ]; then \
	  rm -rf "${install_dir}"; \
	  printf 'removed %s/\n' "${install_dir}"; \
	fi

.PHONY: uninstall-dry-run #> Report what uninstall would remove
uninstall-dry-run:
	@if [ -d "${install_dir}" ]; then \
	  printf 'would remove %s/\n' "${install_dir}"; \
	else \
	  printf 'not installed  %s/\n' "${install_dir}"; \
	fi
	@printf 'left in place  %s/ (cache)\n' "${NVIM_CACHE_DIR}"

.PHONY: uninstall-cache #> Remove installed config + hermetic cache
uninstall-cache: uninstall clean-cache

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
