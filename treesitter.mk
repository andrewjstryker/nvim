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
#   build/scripts/install_parsers.lua.  That script loops the canonical set
#   (lua/config/parsers.lua) and, per parser, skips any that already load and
#   compiles the rest into ${nvim_treesitter_dir} via nvim-treesitter's
#   installer -- the same code path the runtime uses for auto_install /
#   :TSInstall.
#
#   The skip is behavioral: whether a parser is provided by the Neovim binary,
#   found on $VIMRUNTIME, or previously installed is decided by can-it-load,
#   not by inspecting files or language names.  On a host whose Neovim bundles
#   the parsers this is a no-op, needing neither network nor a compiler.
#
#   Severity mirrors ts_install: a parser that is genuinely missing and fails
#   to install is a hard error (a broken install capability is unrecoverable).
#
# Assumptions:
#   - environment.mk has defined:
#       NVIM, NVIM_CONFIG_DIR
#   - project.mk has defined:
#       nvim_treesitter_dir, scripts_dir
#   - The config is installed and nvim-treesitter cloned; the target declares
#     install and rocks-sync as prerequisites so it also runs standalone.
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#

#------------------------------------------------------------------------------#
# Provision the canonical parser set
#
# Idempotent: parsers that already load are skipped, so re-runs only compile
# what is still missing.
#------------------------------------------------------------------------------#

.PHONY: build-parsers #> Compile any missing treesitter parsers into the hermetic dir
build-parsers: check-tools install rocks-sync
	@echo "Provisioning treesitter parsers into ${nvim_treesitter_dir}..."
	@${NVIM} --headless \
	  -u "${NVIM_CONFIG_DIR}/init.lua" \
	  -c "luafile ${scripts_dir}/install_parsers.lua" \
	  -c "qa"

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
