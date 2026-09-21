#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
#
# test/lua_runtime.sh
#
# The `lua_runtime` check: drive the lazy Lua/Fennel setup across whole Neovim
# sessions.  Sourced by test/checks.sh, which owns the throwaway root and the
# install; this file adds one function:
#
#   lua_runtime_scenarios <root> <cache>
#
# Everything here is a property NO single session can observe, which is why it
# is a driver and not just another test/session/ script:
#
#   * which Lua the configuration finds on PATH, and what it reports
#   * whether it probed the interpreter AT ALL (a project-local target must
#     make the probe unnecessary, not merely override its result)
#   * a trusted project-local .nvim.lua, which Neovim reads only at startup
#   * a Fennel file on the command line, so the resolve happens DURING startup
#     rather than from a later :setfiletype
#
# The per-session assertions live in test/session/lua_runtime.lua -- one static
# file for every scenario, parameterized through the environment.  Generating
# Lua source per scenario is how the ordering bug this check exists for stayed
# green: the generated assertions quietly skipped the first buffer.
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#

# lua_runtime_find_pack <cache> -- fail unless the Fennel syntax package is
# installed.  It is what the highlighting scenarios are about; without it they
# would pass by asserting nothing.  Say so plainly rather than failing later on
# a missing syntax file.
lua_runtime_find_pack() {
	_cache=$1
	for _kind in opt start; do
		_pack="${_cache}/rocks/share/nvim/site/pack/rocks/${_kind}/fennel"
		if [ -d "${_pack}" ]; then
			[ -f "${_pack}/syntax/fennel.vim" ] \
				|| fail "Fennel package has no syntax/fennel.vim: ${_pack}"
			return 0
		fi
	done
	fail "No Fennel syntax package under ${_cache}; run \`make sync\` first."
}

#------------------------------------------------------------------------------#
# Scenarios
#
#   name     a label, and the scenario's working directory
#   banner   what the fake `lua -v` on PATH reports
#   stream   which stream it reports on: out or err (LuaJIT uses stderr)
#   exrc     runtime.version a trusted project-local .nvim.lua sets, or -
#   mode     set  -- the session script opens the first buffer itself
#            open -- a Fennel file is on the command line, resolved at startup
#   first    filetype of that first buffer
#   version  expected vim.g.fennel_lua_version
#   jit      expected vim.g.fennel_use_luajit
#
# Do not align the columns: the fields are split on | and padding becomes part
# of the value.
#------------------------------------------------------------------------------#

lua_runtime_scenarios() {
	_root=$1
	_cache=$2
	# shellcheck disable=SC2154 # `here` is set by checks.sh, which sources us
	_assertions="${here}/session/lua_runtime.lua"
	_failures=0

	lua_runtime_find_pack "${_cache}"

	while IFS='|' read -r name banner stream exrc mode first version jit; do
		case ${name} in '' | '#'*) continue ;; esac

		work="${_root}/work/${name}"
		mkdir -p "${work}/bin"

		# A fake interpreter: it records that it was called, then answers.
		# LuaJIT reports its version on stderr, so the stream is part of
		# the scenario -- reading only stdout is a real way to get wrong.
		redirect=
		[ "${stream}" != err ] || redirect=' >&2'
		cat > "${work}/bin/lua" <<FAKE
#!/bin/sh
printf 'probe\n' >> "\$PROBE_LOG"
printf '%s\n' "${banner}"${redirect}
FAKE
		chmod u+x "${work}/bin/lua"

		if [ "${jit}" -eq 1 ]; then
			target=LuaJIT
		else
			target="Lua ${version}"
		fi

		startup_file=
		[ "${mode}" != open ] || {
			startup_file="${work}/example.fnl"
			printf '(local value 1)\nvalue\n' > "${startup_file}"
		}

		if [ "${exrc}" != - ]; then
			{
				printf 'vim.lsp.config("lua_ls", { settings = { Lua = {\n'
				printf '  runtime = { version = "%s" },\n' "${exrc}"
				printf '  diagnostics = { globals = { "vim" } },\n} } })\n'
			} > "${work}/.nvim.lua"
			want_probes=0
		else
			want_probes=1
		fi

		printf '\n--- scenario: %s ---\n' "${name}"

		# One subshell per scenario: the fake PATH, the scenario's home
		# and its LUA_TEST_* settings live and die with it, so nothing
		# leaks into the next scenario or into a later check.
		if (
			cd "${work}" || exit 1
			HOME=${_root}
			PATH="${work}/bin:${PATH}"
			PROBE_LOG="${work}/probes"
			LUA_TEST_MODE=${mode}
			LUA_TEST_FIRST=${first}
			LUA_TEST_VERSION=${version}
			LUA_TEST_TARGET=${target}
			LUA_TEST_JIT=${jit}
			export HOME PATH PROBE_LOG LUA_TEST_MODE LUA_TEST_FIRST \
				LUA_TEST_VERSION LUA_TEST_TARGET LUA_TEST_JIT

			# Trust it the way a user would, in a session of its own:
			# --clean loads no configuration, so it cannot probe the
			# interpreter and spoil the count below.
			if [ -f .nvim.lua ]; then
				test_nvim "${_root}" --clean \
					-c 'lua assert(vim.secure.trust({ action = "allow", path = ".nvim.lua" }))' \
					-c qa \
					|| fail "could not trust .nvim.lua for scenario ${name}"
			fi

			# startup_file is deliberately unquoted: empty must expand
			# to no argument at all, which is the difference between
			# the two modes.
			# shellcheck disable=SC2086
			test_session "${_root}" "${_assertions}" ${startup_file}
		); then
			probes=0
			[ ! -f "${work}/probes" ] \
				|| probes=$(wc -l < "${work}/probes" | tr -d ' ')
			if [ "${probes}" -ne "${want_probes}" ]; then
				printf 'Check FAILED: %s probed lua -v %s time(s), want %s\n' \
					"${name}" "${probes}" "${want_probes}" >&2
				_failures=$((_failures + 1))
			fi
		else
			_failures=$((_failures + 1))
		fi
	done <<'SCENARIOS'
system|Lua 5.5.1|out|-|set|fennel|5.5|0
stderr|Lua 5.4.8|err|-|set|lua|5.4|0
luajit|LuaJIT 2.1.0|out|-|set|fennel|5.1|1
project|Lua 5.5.1|out|LuaJIT|set|lua|5.1|1
startup|Lua 5.5.1|out|LuaJIT|open|fennel|5.1|1
SCENARIOS

	[ "${_failures}" -eq 0 ] || return 1
	printf '\nAll Lua/Fennel runtime scenarios passed.\n'
}
