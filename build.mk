# Neovim-specific stage rules and validation. Ordinary copies and m4 rendering
# belong to protocol.mk; this concern supplies only extra dependencies and the
# claimed Fennel compiler rule.

m4_static_src := $(call rwildcard,${m4_dir}/,*.m4)
lua_plain_src := $(call rwildcard,${nvim_src_dir}/lua/,*.lua)
lua_m4_src    := $(call rwildcard,${nvim_src_dir}/lua/,*.lua.m4)

lua_plain_out := $(patsubst ${nvim_src_dir}/lua/%,\
  ${stage_nvim_dir}/lua/%,${lua_plain_src})
lua_m4_out := $(patsubst ${nvim_src_dir}/lua/%.lua.m4,\
  ${stage_nvim_dir}/lua/%.lua,${lua_m4_src})
stage_lua_all := ${lua_plain_out} ${lua_m4_out} ${fnl_out}

# Static Neovim macros are ordinary file inputs to every Lua template. Rules
# without recipes augment the protocol's ordinary m4 pattern rule.
${lua_m4_out}: ${m4_static_src}

# A Lua module may have exactly one implementation form.
define assert-unique
  $(if $(filter-out $(words $(sort ${1})),$(words ${1})),\
    $(error ${2} (list: ${1})))
endef
$(call assert-unique,${stage_lua_all},Duplicate staged Lua targets detected)

# Fennel is the sole claimed transformation. The compiler is pinned under
# vendor/build and therefore remains a private build input, never a manifest.
${stage_nvim_dir}/lua/%.lua: ${nvim_src_dir}/lua/%.fnl ${FENNEL}
	mkdir -p '$(@D)'
	'${LUA}' '${FENNEL}' --compile '$<' > '$@'
	chmod --reference='$<' '$@'
