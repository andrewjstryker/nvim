#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
#
# Makefile
#
# Build, install, and synchronize the Neovim configuration.  The reusable
# lifecycle lives in protocol/; this file contains only Neovim-specific work.
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#

# Resolve the project and its protocol declarations before loading the shared
# lifecycle. Concern implementations follow the protocol boundary.
include environment.mk
include project.mk

PROTOCOL_MK ?= protocol/protocol.mk
include ${PROTOCOL_MK}

include build.mk
include seed.mk
include treesitter.mk
include test.mk

check: verify

# Compatibility name for Neovim's historical build surface. The protocol's
# incremental stage target now owns the complete staged image.
.PHONY: build #> Build the complete stage image
build: stage

# Compatibility names retained for direct callers; the protocol's DRY_RUN
# mode remains the single implementation of each operation.
.PHONY: install-dry-run #> Report what install would change
install-dry-run: DRY_RUN = 1
install-dry-run: install

.PHONY: uninstall-dry-run #> Report what uninstall would remove
uninstall-dry-run: DRY_RUN = 1
uninstall-dry-run: uninstall

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
