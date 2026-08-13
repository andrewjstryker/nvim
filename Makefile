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
.SILENT:

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
.PHONY: show #> Show resolved variables and declared paths
#
# Printed with $(info) rather than a shell heredoc.  The heredoc that used to be
# here could not work: make hands each recipe line to its own shell, so `cat
# <<'SHOW_EOF'` read to end-of-file and the next line was executed as a command
# ("Environment:: command not found").  $(info) prints a multi-line variable
# verbatim and needs no shell at all -- which is also why the recipe body is a
# bare colon.
# $(info) strips leading whitespace from its argument, so the indent comes from
# a variable holding two spaces.
empty :=
sp    := ${empty} ${empty}

show:
	$(info Environment:)
	$(info ${env_summary})
	$(info )
	$(info Project:)
	$(info ${project_summary})
	$(info )
	$(info Tools:)
	$(info ${toolset_summary})
	$(info )
	$(info Declared paths:)
	$(info ${sp}${sp}tree  0700   ${NVIM_CONFIG_DIR}/)
	$(info )
	$(info Written but NOT declared -- state, never reclaimed by uninstall:)
	$(info ${sp}${sp}${NVIM_ROCKS_DIR}/          hermetic luarocks tree)
	$(info ${sp}${sp}${nvim_treesitter_dir}/     compiled treesitter parsers)
	@:

#------------------------------------------------------------------------------#
# Build & stage
#------------------------------------------------------------------------------#

# Assemble is the internal dependency graph.  Public build removes the previous
# generated tree first, making stage reflect deleted sources and disappearing
# optional outputs without a separate manifest.
.PHONY: assemble
assemble: check-tools ${stage_outputs} ${config_env} runtime verify

.PHONY: build #> Rebuild the complete stage image
build:
	@rm -rf "${stage_dir}"
	@${MAKE} --no-print-directory assemble

.PHONY: stage #> Construct the entire staging directory
stage: build

#------------------------------------------------------------------------------#
# Install: sync stage → NVIM_CONFIG_DIR
#------------------------------------------------------------------------------#

# DESTDIR is the staged-root prefix required by the protocol: it relocates
# where we write without changing what we write.  Empty for a real install.
DESTDIR ?=

install_dir := ${DESTDIR}${NVIM_CONFIG_DIR}

#------------------------------------------------------------------------------#
# DRY_RUN
#
# A MODE, not a set of targets: `make install DRY_RUN=1` runs the same recipe as
# `make install`, so the report cannot drift from the action.  Deliberately NOT
# assigned here -- a plain assignment would override the environment and
# silently disarm it.  Any non-empty value is true.
#
# Every target that writes outside this working tree honours it: install,
# uninstall, uninstall-cache, and the two provisioning steps sync runs.  A
# modifier with exceptions is worse than no modifier, because the exception is
# always found the expensive way.
#
# clean and clean-cache are the boundary.  clean only removes stage/, inside the
# working tree, so a dry run may still do it; clean-cache reaches into
# NVIM_CACHE_DIR and does not.
#------------------------------------------------------------------------------#

$(if ${DRY_RUN},$(info === DRY RUN: nothing will be written ===))

# --archive --delete is the claim that this directory is entirely ours, which
# for $XDG_CONFIG_HOME/nvim it is: Neovim's own state lives in the cache and
# data trees, never here.  --chmod makes the installed modes explicit rather
# than whatever umask the build host happened to have.
rsync_install = --archive --checksum --delete --no-times --omit-dir-times \
  --chmod=D0700,F0600

ifeq (${DRY_RUN},)
  rsync_install += --itemize-changes
else
  rsync_install += --dry-run --itemize-changes
endif

.PHONY: install #> Install staged payload into NVIM_CONFIG_DIR (DRY_RUN=1 to report)
install: stage
ifeq (${DRY_RUN},)
	@mkdir -p "${install_dir}"
	@${RSYNC} ${rsync_install} "${stage_nvim_dir}/" "${install_dir}/"
else
	@# rsync cannot report into a directory that does not exist, and a dry run
	@# may not create one, so that single case is reported by hand.
	@if [ -d "${install_dir}" ]; then \
	  ${RSYNC} ${rsync_install} "${stage_nvim_dir}/" "${install_dir}/"; \
	else \
	  printf 'would create tree %s/ from %s/\n' \
	    "${install_dir}" "${stage_nvim_dir}"; \
	fi
endif

# ../SPEC.md no longer lists these -- a dry run is the DRY_RUN mode. They remain
# compatibility delegators for direct callers: one recipe per action, no second
# implementation to drift.
.PHONY: install-dry-run #> Report what install would change
install-dry-run:
	@${MAKE} --no-print-directory install DRY_RUN=1

.PHONY: preview #> Stage, then report files install would create or overwrite
preview:
	@${MAKE} --no-print-directory install DRY_RUN=1

#------------------------------------------------------------------------------#
# Sync: provision all plugins from rocks.toml
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

.PHONY: sync #> Sync plugins and parsers with installed configuration
ifeq (${DRY_RUN},)
sync: check-tools
	$(if ${DESTDIR},$(error sync cannot be staged: plugins and parsers \
	  are live state outside DESTDIR))
	@${MAKE} --no-print-directory rocks-sync provision-parsers
else
# rocks-sync clones and compiles into the hermetic tree, and build-parsers
# compiles treesitter grammars into it.  Both write outside this working tree
# and neither has a dry run of its own, so a dry run says what it would do and
# stops -- rather than "reporting" by doing it.
sync: check-tools
	$(if ${DESTDIR},$(error sync cannot be staged: plugins and parsers \
	  are live state outside DESTDIR))
	@printf 'would sync rocks into %s/\n'    "${NVIM_ROCKS_DIR}"
	@printf 'would build parsers into %s/\n' "${nvim_treesitter_dir}"
endif

.PHONY: check #> Build and validate the Neovim staged declaration
check: stage

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
	$(if ${DRY_RUN}, \
	  @printf 'would remove %s/ and %s/\n' \
	    "${nvim_rocks_dir}" "${luarocks_config_dir}", \
	  @printf "\033[1;33mRemoving hermetic rocks cache…\033[0m\n"; \
	  rm -rf "${nvim_rocks_dir}" "${luarocks_config_dir}"; \
	  printf "\033[1;32mCache removed.\033[0m\n")

# The protocol forbids gating uninstall behind a confirmation flag: its scope
# is bounded by declaration instead.  This removes the owned config tree and
# nothing else — the hermetic rocks tree, treesitter parsers, and every other
# cache stay put, because they are expensive to rebuild and are not
# configuration.  Use uninstall-cache to take those too.
.PHONY: uninstall #> Remove installed payload (DRY_RUN=1 to report only)
uninstall:
	@if [ -d "${install_dir}" ]; then \
	  $(if ${DRY_RUN}, \
	    printf 'would remove %s/\n' "${install_dir}", \
	    rm -rf "${install_dir}" && printf 'removed %s/\n' "${install_dir}"); \
	else \
	  printf 'not installed  %s/\n' "${install_dir}"; \
	fi
	@printf 'left in place  %s/ (cache: rocks, parsers)\n' "${NVIM_CACHE_DIR}"

.PHONY: uninstall-dry-run #> Report what uninstall would remove
uninstall-dry-run:
	@${MAKE} --no-print-directory uninstall DRY_RUN=1

.PHONY: uninstall-cache #> Remove installed config + hermetic cache
uninstall-cache: uninstall clean-cache

# Apply is sequential even under make -j.
.PHONY: apply #> Install, then synchronize
apply:
	@${MAKE} --no-print-directory install
	$(if ${DESTDIR},@printf 'sync skipped for staged apply\n',\
	  @${MAKE} --no-print-directory sync)

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
