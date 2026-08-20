# Shared Neovim project declarations. This file is loaded before protocol.mk;
# it contains no recipes or lifecycle targets.

# Repository and protocol roots.
repo_root      := ${CURDIR}
src            := ${repo_root}/src
stage          := ${repo_root}/stage
vendor         := ${repo_root}/vendor
nvim_src_dir   := ${src}/config/nvim
build_dir      := ${repo_root}/build
build_bin      := ${build_dir}/bin
m4_dir         := ${build_dir}/m4
scripts_dir    := ${build_dir}/scripts
vendor_dir     := ${vendor}
stage_dir      := ${stage}
stage_nvim_dir := ${stage}/config/nvim

# NVIM_CONFIG_DIR and NVIM_CACHE_DIR are application roots. Their parents are
# the XDG roots used by the protocol and by headless Neovim invocations.
ifneq ($(notdir ${NVIM_CONFIG_DIR}),nvim)
  $(error NVIM_CONFIG_DIR must end with /nvim (got: ${NVIM_CONFIG_DIR}))
endif
ifneq ($(notdir ${NVIM_CACHE_DIR}),nvim)
  $(error NVIM_CACHE_DIR must end with /nvim (got: ${NVIM_CACHE_DIR}))
endif

nvim_xdg_config := $(patsubst %/,%,$(dir ${NVIM_CONFIG_DIR}))
nvim_xdg_cache  := $(patsubst %/,%,$(dir ${NVIM_CACHE_DIR}))
config_root     := ${nvim_xdg_config}

# Hermetic runtime state.
nvim_cache_root     := ${NVIM_CACHE_DIR}
nvim_rocks_dir      := ${nvim_cache_root}/rocks
luarocks_config_dir := ${nvim_rocks_dir}/luarocks
luarocks_config     := ${luarocks_config_dir}/config.lua
nvim_treesitter_dir := ${nvim_cache_root}/treesitter

NVIM_ROCKS_DIR      := ${nvim_rocks_dir}
NVIM_TREESITTER_DIR := ${nvim_treesitter_dir}
LUAROCKS_CONFIG_DIR := ${luarocks_config_dir}
LUAROCKS_CONFIG     := ${luarocks_config}

luarocks_server := https://lux.lumen-labs.org/rocks-binaries/

# Hermetic Lua module paths used by seed.mk.
lua_share_dir      := ${nvim_rocks_dir}/share/lua/5.1
lua_lib_dir        := ${nvim_rocks_dir}/lib/lua/5.1
hermetic_lua_path  := ${lua_share_dir}/?.lua;${lua_share_dir}/?/init.lua
hermetic_lua_cpath := ${lua_lib_dir}/?.so;${lua_lib_dir}/?.dylib;${lua_lib_dir}/?.dll

# Protocol build declarations.

# Fennel is a private vendored build tool. Its sources are claimed from the
# ordinary source mapping because compilation changes both language and suffix.
FENNEL ?= ${vendor}/build/fennel/fennel
fnl_src = $(call rwildcard,${src}/config/nvim/lua/,*.fnl)
fnl_out = $(patsubst ${src}/config/nvim/lua/%.fnl,\
  ${stage}/config/nvim/lua/%.lua,${fnl_src})
claimed_sources = ${fnl_src}
claimed_outputs = ${fnl_out}
stage_tools += $(if $(strip ${fnl_src}),LUA FENNEL)

# Ordinary m4 templates use the protocol renderer and context. Only values
# actually present are exposed for optional formatter configuration.
M4FLAGS += -I ${m4_dir}
m4_vars += NVIM_ROCKS_DIR NVIM_CONFIG_DIR NVIM_TREESITTER_DIR
m4_vars += $(foreach v,PRETTIER STYLUA RUFF BLACK STYLER SQL_FORMATTER,\
  $(if $(strip ${$v}),$v))

# Synchronization provisions installed rocks and parser state. The protocol
# supplies M4 for ordinary templates and RSYNC for installation.
sync_tools += LUA NVIM LUAROCKS GIT TREE_SITTER C_COMPILER

show_vars := \
  NVIM_CONFIG_DIR NVIM_CACHE_DIR NVIM_ROCKS_DIR NVIM_TREESITTER_DIR \
  LUAROCKS_CONFIG_DIR LUAROCKS_CONFIG FENNEL \
  PRETTIER STYLUA RUFF BLACK STYLER SQL_FORMATTER
