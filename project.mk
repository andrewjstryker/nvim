#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
#
# project.mk
#
# Shared internal project structure.
#
# Responsibilities:
#   - Derive internal paths (repo root, nvim src, build, stage).
#   - Bridge user-facing knobs from environment.mk into the variables expected
#     by other *.mk files (e.g., NVIM_CONFIG, NVIM_ROCKS).
#   - Provide a summary block suitable for "make show".
#
# Assumptions:
#   - environment.mk has already been included and defines:
#       XDG_CONFIG_HOME, XDG_CACHE_HOME,
#       NVIM_CONFIG_DIR, NVIM_CACHE_DIR,
#       ROCKS_NVIM_REPO, ROCKS_NVIM_REF,
#       tool variables (NVIM, LUA, RSYNC, GIT, AWK, M4, ...)
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#

#------------------------------------------------------------------------------#
# Repository layout (internal, not meant to be overridden)
#------------------------------------------------------------------------------#

# Root of the repository (assumed to be where Make is invoked)
repo_root      := ${CURDIR}

# Neovim source tree within the repo
nvim_src_dir   := ${repo_root}/nvim

# Build assets (e.g., m4 macros, vendored tools)
build_dir      := ${repo_root}/build

# Stage root and staged Neovim tree (assembled image)
stage_dir      := ${repo_root}/stage
stage_nvim_dir := ${stage_dir}/nvim

#------------------------------------------------------------------------------#
# Hermetic rocks tree + config bridge
#------------------------------------------------------------------------------#

# NVIM_CONFIG_DIR and NVIM_CACHE_DIR come from environment.mk. They are the
# only user-facing directory knobs; everything else is derived from them.

# Derive the hermetic LuaRocks tree root from NVIM_CACHE_DIR.
# This matches the design doc's "NVIM_ROCKS" path in XDG cache.
nvim_rocks_dir ?= ${NVIM_CACHE_DIR}/rocks

#------------------------------------------------------------------------------#
# Project summary (for "make show" or similar)
#------------------------------------------------------------------------------#

define project_summary
  Repository root............ ${repo_root}

  # Source / build layout
  Neovim source.............. ${nvim_src_dir}
  Build dir.................. ${build_dir}
  Stage dir.................. ${stage_dir}
  Stage Neovim............... ${stage_nvim_dir}

  # Install / cache layout
  NVIM_CONFIG (install)...... ${NVIM_CONFIG}
  NVIM_CONFIG_DIR (input).... ${NVIM_CONFIG_DIR}
  NVIM_CACHE_DIR (input)..... ${NVIM_CACHE_DIR}

  # Seed plugin pins
  ROCKS_NVIM_REPO............ ${ROCKS_NVIM_REPO}
  ROCKS_NVIM_REF............. ${ROCKS_NVIM_REF}
  ROCKS_GIT_REPO............. ${ROCKS_GIT_REPO}
  ROCKS_GIT_REF.............. ${ROCKS_GIT_REF}
endef

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
