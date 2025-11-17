#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
#
# stage.mk
#
# Build the stage image under ${stage_nvim_dir}:
#   - Copy top-level files (init.lua, rocks.toml)
#   - Transform *.lua.m4 → *.lua via m4
#   - Compile *.fnl → *.lua via fennel
#   - Copy runtime trees: after/, ftplugin/, colors/, plugin/
#
# This file defines only file targets and internal variables.
# The .PHONY "stage" target is defined in the top-level Makefile and should
# depend on ${stage_outputs}.
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#

#------------------------------------------------------------------------------#
# Public tool knobs (may be set by user / environment)
#------------------------------------------------------------------------------#

# m4 and fennel can be overridden from the environment if desired
M4        ?= $(shell command -v m4)
FENNEL    ?= $(shell command -v fennel)

# Optional include directory for m4 (e.g., build/m4)
M4_INCLUDE_DIR ?= ${CURDIR}/build/m4

#------------------------------------------------------------------------------#
# Internal paths (not meant to be overridden)
#------------------------------------------------------------------------------#

# Source Neovim config tree within the repo
nvim_src_dir   := ${CURDIR}/nvim

# Stage root and staged Neovim tree
stage_dir      := ${CURDIR}/stage
stage_nvim_dir := ${stage_dir}/nvim

#------------------------------------------------------------------------------#
# Source discovery
#------------------------------------------------------------------------------#

# Top-level files (always copied 1:1)
top_src := \
  ${nvim_src_dir}/init.lua \
  ${nvim_src_dir}/rocks.toml

top_out := $(patsubst ${nvim_src_dir}/%,${stage_nvim_dir}/%,${top_src})

# Single logical module tree: nvim/lua/**
# Three implementation forms:
#   - plain Lua:    foo.lua
#   - templated:    foo.lua.m4
#   - Fennel:       foo.fnl

# Recursive wildcard: $(call rwildcard,DIR,pattern)
# Example: $(call rwildcard,${nvim_src_dir}/lua/,*.lua)
rwildcard = $(wildcard $1$2) \
            $(foreach d,$(wildcard $1*/),
              $(call rwildcard,$d,$2))

# All *.lua under nvim/lua (including ones that are actually *.lua.m4)
lua_all_lua_src := $(call rwildcard,${nvim_src_dir}/lua/,*.lua)

# All *.lua.m4 under nvim/lua
lua_m4_src      := $(call rwildcard,${nvim_src_dir}/lua/,*.lua.m4)

# Plain Lua = all *.lua minus the .lua.m4 templates
lua_plain_src   := $(filter-out ${lua_m4_src},${lua_all_lua_src})

# All *.fnl under nvim/lua
fnl_src         := $(call rwildcard,${nvim_src_dir}/lua/,*.fnl)


# Outputs for each source form (all end up as *.lua under stage_nvim_dir/lua)
lua_plain_out := $(patsubst ${nvim_src_dir}/lua/%,${stage_nvim_dir}/lua/%,${lua_plain_src})
lua_m4_out    := $(patsubst ${nvim_src_dir}/lua/%.lua.m4,${stage_nvim_dir}/lua/%.lua,${lua_m4_src})
fnl_out       := $(patsubst ${nvim_src_dir}/lua/%.fnl,${stage_nvim_dir}/lua/%.lua,${fnl_src})

# Combined set of staged Lua outputs (used for duplicate detection & orchestration)
stage_lua_all := ${lua_plain_out} ${lua_m4_out} ${fnl_out}

# Runtime trees copied wholesale if present
after_src_dir    := ${nvim_src_dir}/after
ftplugin_src_dir := ${nvim_src_dir}/ftplugin
colors_src_dir   := ${nvim_src_dir}/colors
plugin_src_dir   := ${nvim_src_dir}/plugin

after_out_dir    := ${stage_nvim_dir}/after
ftplugin_out_dir := ${stage_nvim_dir}/ftplugin
colors_out_dir   := ${stage_nvim_dir}/colors
plugin_out_dir   := ${stage_nvim_dir}/plugin

# Runtime dirs that should exist in a complete stage image
stage_runtime_dirs := \
  ${after_out_dir} \
  ${ftplugin_out_dir} \
  ${colors_out_dir} \
  ${plugin_out_dir}

# All outputs that define a fully assembled stage image
stage_outputs := \
  ${top_out} \
  ${stage_lua_all} \
  ${stage_runtime_dirs}

#------------------------------------------------------------------------------#
# Duplicate target guard (module-path uniqueness)
#------------------------------------------------------------------------------#

# Assert that a list of targets contains no duplicates.
# Usage:
#   $(call assert-unique,LIST,ERROR_MESSAGE)
define assert-unique
  $(if $(filter-out $(words $(sort $(1))),$(words $(1))), \
    $(error $(2) (list: $(1))) \
  )
endef

# Fail at parse time if multiple sources map to the same staged Lua path
# (e.g., foo.lua, foo.lua.m4, and/or foo.fnl all producing the same module)
$(call assert-unique,${stage_lua_all},Duplicate staged Lua targets detected)

#------------------------------------------------------------------------------#
# Directory targets
#------------------------------------------------------------------------------#

${stage_dir}:
	mkdir -p "$@"

${stage_nvim_dir}: | ${stage_dir}
	mkdir -p "$@"


.PHONY: stage-runtime
stage-runtime: | ${stage_nvim_dir}
	@cd "${nvim_src_dir}" && \
	  ${RSYNC} -a --delete --ignore-missing-args \
	    after ftplugin colors plugin \
	    "${stage_nvim_dir}/"


stage-runtime: | ${stage_nvim_dir}
	@for d in after ftplugin colors plugin; do \
	  src="${nvim_src_dir}/$$d"; \
	  dst="${stage_nvim_dir}/$$d"; \
	  if [ -d "$$src" ]; then \
	    mkdir -p "$$dst"; \
	    ${RSYNC} -a --delete "$$src"/ "$$dst"/; \
	  fi; \
	done

#------------------------------------------------------------------------------#
# Top-level files (init.lua, rocks.toml)
#------------------------------------------------------------------------------#

${stage_nvim_dir}/init.lua: ${nvim_src_dir}/init.lua | ${stage_nvim_dir}
	mkdir -p "$(dir $@)"
	cp "$<" "$@"

${stage_nvim_dir}/rocks.toml: ${nvim_src_dir}/rocks.toml | ${stage_nvim_dir}
	mkdir -p "$(dir $@)"
	cp "$<" "$@"

#------------------------------------------------------------------------------#
# Lua modules: plain Lua, m4-templated Lua, and Fennel→Lua
#------------------------------------------------------------------------------#

# 1. Plain Lua copy
${stage_nvim_dir}/lua/%.lua: ${nvim_src_dir}/lua/%.lua | ${stage_nvim_dir}
	mkdir -p "$(dir $@)"
	cp "$<" "$@"

# 2. m4 templates → Lua
${stage_nvim_dir}/lua/%.lua: ${nvim_src_dir}/lua/%.lua.m4 | ${stage_nvim_dir}
	mkdir -p "$(dir $@)"
	"${M4}" -I "${M4_INCLUDE_DIR}" "$<" > "$@"

# 3. Fennel → Lua
${stage_nvim_dir}/lua/%.lua: ${nvim_src_dir}/lua/%.fnl | ${stage_nvim_dir}
	mkdir -p "$(dir $@)"
	"${FENNEL}" --compile "$<" > "$@"
