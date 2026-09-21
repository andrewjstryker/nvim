#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
#
# test/lib.sh
#
# Shared plumbing for the headless Neovim test drivers.  Sourced, never
# executed: every function assumes the caller has set -eu.
#
# One responsibility: hand a driver a throwaway XDG root with the configuration
# really installed into it, and a way to run Neovim there.  Everything a test
# asserts belongs in the driver or in a test/session/ script, never here.
#
# Callers supply the tools through the environment so host discovery stays in
# environment.mk and never leaks a second rulebook into the tests:
#
#   NVIM     -- Neovim binary                (required)
#   MAKE     -- make binary                  (defaults to make)
#   TIMEOUT  -- timeout(1) binary            (required)
#
# A driver sets one variable of its own before sourcing this file:
#
#   repo_root  -- the repository to build from (required)
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#

: "${MAKE:=make}"

# Seconds any one headless Neovim may run.  A test that hangs -- an autocommand
# that re-enters itself, a language server that never answers -- has to become a
# failure, not a wedged build.  The ceiling is generous because ts_install
# legitimately spends up to five minutes fetching and compiling a grammar.
: "${NVIM_TIMEOUT:=600}"

fail() {
	printf '%s\n' "$*" >&2
	exit 1
}

lib_check_tools() {
	[ -n "${NVIM:-}" ] || fail 'NVIM is not set (host discovery failed?)'
	[ -x "${NVIM}" ] || [ "${NVIM}" = nvim ] || fail "NVIM is not executable: ${NVIM}"
	[ -n "${TIMEOUT:-}" ] || fail 'TIMEOUT is not set (is timeout(1) installed?)'
	[ -n "${repo_root:-}" ] || fail 'repo_root is not set by the driver'
	[ -f "${repo_root}/Makefile" ] || fail "not a repository root: ${repo_root}"
}

#------------------------------------------------------------------------------#
# Throwaway roots
#
# The layout satisfies the /nvim invariant the top-level Makefile enforces, so
# $(dir ...) yields correct XDG base directories on the sub-make.  The real
# ${NVIM_CONFIG_DIR} is never touched.
#------------------------------------------------------------------------------#

# test_root_create -- echo a fresh throwaway XDG root.  The CALLER owns cleanup;
# set the trap before anything can fail, as protocol/tests/staging.sh does.
test_root_create() {
	_root=$(mktemp -d)
	mkdir -p \
		"${_root}/config/nvim" \
		"${_root}/cache/nvim" \
		"${_root}/state" \
		"${_root}/data"
	printf '%s\n' "${_root}"
}

# test_build_into <config-dir> <cache-dir> <make target>...
#
# Run the real lifecycle targets into the throwaway root, in the given order.
# Tests run against the built and installed image, never against src/: the m4
# render and the staging rules are part of what they are testing.
test_build_into() {
	_cfg=$1
	_cache=$2
	shift 2
	for _target in "$@"; do
		# shellcheck disable=SC2154 # set by the driver; lib_check_tools verifies it
		"${MAKE}" --no-print-directory -C "${repo_root}" "${_target}" \
			NVIM_CONFIG_DIR="${_cfg}" \
			NVIM_CACHE_DIR="${_cache}" \
			|| fail "make ${_target} failed"
	done
}

#------------------------------------------------------------------------------#
# Running Neovim
#------------------------------------------------------------------------------#

# test_nvim <root> <nvim argument>...
#
# Headless Neovim under the throwaway root's XDG directories.  Exported
# variables set by the caller (PATH, HOME, a scenario's own settings) are
# inherited, so a driver shapes the environment before calling.
test_nvim() {
	_root=$1
	shift
	XDG_CONFIG_HOME="${_root}/config" \
	XDG_CACHE_HOME="${_root}/cache" \
	XDG_STATE_HOME="${_root}/state" \
	XDG_DATA_HOME="${_root}/data" \
		"${TIMEOUT}" "${NVIM_TIMEOUT}" "${NVIM}" \
			--headless -n -i NONE "$@"
}

# test_session <root> <script.lua> [nvim argument]...
#
# Run one test/session/ assertion script under the installed configuration.
#
# THE SCRIPT OWNS THE EXIT.  Note the absence of a trailing `-c qa`: a session
# script ends in os.exit(0) or os.exit(1), so Neovim's status is the script's
# verdict.  Appending `-c qa` would quit for it -- and then a script that died
# before reaching its own os.exit, on a typo or an error outside its pcall,
# would exit 0 and be reported as a pass.  That is not hypothetical: it is how
# this check first "passed" while asserting nothing at all.
#
# A script that never exits at all (a Lua syntax error, a hang) leaves Neovim
# running and NVIM_TIMEOUT kills it.  Slow, but a failure rather than a lie.
test_session() {
	_root=$1
	_script=$2
	shift 2
	_err="${_root}/session.err"

	# No -u: XDG_CONFIG_HOME already points Neovim at the installed config,
	# and naming the init file explicitly SUPPRESSES exrc -- which silently
	# turned the project-local .nvim.lua scenarios into duplicates of the
	# plain ones.  Let Neovim find its own configuration.
	printf 'Session check: %s\n' "${_script##*/}"
	if test_nvim "${_root}" "$@" -c "luafile ${_script}" 2>"${_err}"
	then
		return 0
	fi
	printf 'Check FAILED: %s\n' "${_script}" >&2
	sed 's/^/    /' "${_err}" >&2
	return 1
}
