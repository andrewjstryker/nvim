#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
#
# Makefile
#
# Build, install, and synchronize the Neovim configuration.  The reusable
# lifecycle lives in protocol/; this file contains only Neovim-specific work.
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#

# Keep the protocol at a repository-local boundary.  It is copied here for
# now and can become a submodule at the same path without changing this file.
src      := ${CURDIR}/src
stage    := ${CURDIR}/stage
vendor   := ${CURDIR}/vendor
FENNEL   ?= ${vendor}/build/fennel/fennel

# Fennel is a concern-owned transformation: claim its sources from the
# protocol's ordinary identity transform and publish the generated Lua paths.
fnl_src = $(call rwildcard,${src}/config/nvim/lua/,*.fnl)
fnl_out = $(patsubst ${src}/config/nvim/lua/%.fnl,\
  ${stage}/config/nvim/lua/%.lua,${fnl_src})
claimed_sources = ${fnl_src}
claimed_outputs = ${fnl_out}

PROTOCOL_MK ?= protocol/protocol.mk
include ${PROTOCOL_MK}

# The smoke-test recipes use bash's EXIT trap.  The protocol recipes are
# portable sh and run unchanged under this stricter shell.
SHELL := bash
.SHELLFLAGS := --noprofile --norc -euo pipefail -c

# User-facing environment knobs and Neovim's build graph.
include environment.mk
include project.mk
include build.mk
include seed.mk
include treesitter.mk
include test.mk

# NVIM_CONFIG_DIR and NVIM_CACHE_DIR are application roots.  Their parents are
# the XDG roots used by the protocol's config namespace.
ifneq ($(notdir ${NVIM_CONFIG_DIR}),nvim)
  $(error NVIM_CONFIG_DIR must end with /nvim (got: ${NVIM_CONFIG_DIR}))
endif
ifneq ($(notdir ${NVIM_CACHE_DIR}),nvim)
  $(error NVIM_CACHE_DIR must end with /nvim (got: ${NVIM_CACHE_DIR}))
endif

config_root = ${nvim_xdg_config}

# Preserve the existing build contract: staging requires the complete local
# toolchain, while synchronization requires the tools which provision runtime
# state. The protocol supplies M4 for templates and RSYNC for installation.
stage_tools += LUA NVIM LUAROCKS GIT AWK
sync_tools  += LUA NVIM LUAROCKS GIT AWK

show_vars := \
  NVIM_CONFIG_DIR NVIM_CACHE_DIR NVIM_ROCKS_DIR nvim_treesitter_dir \
  LUAROCKS_CONFIG_DIR LUAROCKS_CONFIG FENNEL TREE_SITTER C_COMPILER \
  PRETTIER STYLUA RUFF BLACK STYLER SQL_FORMATTER

.PHONY: verify
verify: stage

# Extend the shared check surface with Neovim's rendered-output validation.
.PHONY: check
check: verify

# Compatibility name for Neovim's historical build surface. The protocol's
# incremental stage target now owns the complete staged image.
.PHONY: build #> Build the complete stage image
build: stage

# Provision plugins and parsers after installation. A direct sync assumes that
# install has already run; the collection driver provides the ordered apply
# operation.
.PHONY: sync #> Synchronize plugins and parsers with installed configuration
ifeq (${DRY_RUN},)
sync: provision-parsers
else
sync:
	printf 'would sync rocks into %s/\n' '${NVIM_ROCKS_DIR}'
	printf 'would build parsers into %s/\n' '${nvim_treesitter_dir}'
endif

# Compatibility names retained for direct callers; the protocol's DRY_RUN
# mode remains the single implementation of each operation.
.PHONY: install-dry-run #> Report what install would change
install-dry-run: DRY_RUN = 1
install-dry-run: install

.PHONY: uninstall-dry-run #> Report what uninstall would remove
uninstall-dry-run: DRY_RUN = 1
uninstall-dry-run: uninstall

# Cache is runtime state and intentionally outside the protocol manifest.
.PHONY: clean-cache #> Remove the hermetic rocks cache
clean-cache:
	$(if ${DRY_RUN}, \
	  printf 'would remove %s/ and %s/\n' \
	    '${nvim_rocks_dir}' '${luarocks_config_dir}', \
	  printf '\033[1;33mRemoving hermetic rocks cache…\033[0m\n'; \
	  rm -rf '${nvim_rocks_dir}' '${luarocks_config_dir}'; \
	  printf '\033[1;32mCache removed.\033[0m\n')

.PHONY: uninstall-cache #> Remove installed config and hermetic cache
uninstall-cache: uninstall clean-cache

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
