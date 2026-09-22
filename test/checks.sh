#!/bin/sh
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
#
# test/checks.sh
#
# The one test driver.  Install the configuration into a throwaway root, prove
# Neovim starts cleanly under it, then run the requested checks against that
# single install.
#
# Usage: checks.sh [-c CACHE_DIR] [-t 'TARGETS'] [CHECK...]
#
#   CHECK         A check to run.  Most are the name of a test/session/
#                 script (keymaps, ts_works, ts_install), asserted inside one
#                 Neovim under the fresh install.  Two need a session of their
#                 own and have a driver beside this one: `lua_runtime`
#                 (test/lua_runtime.sh) and `vscode` (test/vscode.sh).  With
#                 no CHECK, only the clean-startup check runs.
#   -t 'TARGETS'  Lifecycle targets to run into the temp root, in order.
#                 Default 'install'; 'install sync' provisions plugins and
#                 parsers too (network).
#   -c CACHE_DIR  Use CACHE_DIR as NVIM_CACHE_DIR instead of one inside the
#                 temp root.  With the default targets that means an
#                 already-synced tree: fast and offline, needs a prior
#                 `make sync`.
#
# An unknown CHECK is an error.  A driver that silently runs nothing is the
# failure mode this harness exists to rule out.
#
# The real ${NVIM_CONFIG_DIR} is never touched.  Stage is left holding
# temp-path artifacts, so the next real `make install` cheaply re-stages.
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#

set -eu

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# repo_root and the tools in the environment are lib.sh's inputs; it checks them.
# shellcheck disable=SC2034 # used by lib.sh, not here
repo_root=$(CDPATH='' cd -- "${here}/.." && pwd)
# shellcheck source=test/lib.sh
. "${here}/lib.sh"
# shellcheck source=test/lua_runtime.sh
. "${here}/lua_runtime.sh"
# shellcheck source=test/vscode.sh
. "${here}/vscode.sh"

lib_check_tools

usage="usage: checks.sh [-c CACHE_DIR] [-t 'TARGETS'] [CHECK...]"
cache=
targets=install
while getopts c:t: option; do
	case ${option} in
	c) cache=${OPTARG} ;;
	t) targets=${OPTARG} ;;
	*) fail "${usage}" ;;
	esac
done
shift $((OPTIND - 1))

# Reject typos before building anything: an hour into a sync is a poor moment
# to learn that `lua_runtme` matched no check and quietly did nothing.
for check in "$@"; do
	case ${check} in
	lua_runtime) ;;
	*)
		[ -f "${here}/session/${check}.lua" ] \
			|| fail "unknown check: ${check}"
		;;
	esac
done

root=$(test_root_create)
trap 'rm -rf "${root}"' EXIT HUP INT TERM
cfg="${root}/config/nvim"
[ -n "${cache}" ] || cache="${root}/cache/nvim"

printf 'Checks using:\n'
printf '  NVIM_CONFIG_DIR=%s\n' "${cfg}"
printf '  NVIM_CACHE_DIR=%s\n' "${cache}"
printf '  targets=%s\n' "${targets}"
printf '  checks=%s\n' "$([ $# -gt 0 ] && echo "$*" || echo '(startup only)')"

# shellcheck disable=SC2086 # targets is a deliberate word list
test_build_into "${cfg}" "${cache}" ${targets}

#------------------------------------------------------------------------------#
# Clean startup
#
# Two independent failures to catch: Neovim exiting non-zero, and Neovim
# reporting an error while still exiting zero -- which is what a broken
# autocommand or a bad plugin config usually does.
#------------------------------------------------------------------------------#

printf '\nVerifying Neovim starts cleanly...\n'
smoke_err="${root}/smoke.err"
test_nvim "${root}" \
	-c "lua assert(package.loaded['config.env'], 'config.env not loaded')" \
	-c qa 2>"${smoke_err}" \
	|| { sed 's/^/    /' "${smoke_err}" >&2
	     fail 'Startup FAILED — Neovim exited non-zero'; }

if grep -q '^Error\|^E[0-9]' "${smoke_err}"; then
	printf 'Startup FAILED — Neovim produced errors:\n' >&2
	sed 's/^/    /' "${smoke_err}" >&2
	exit 1
fi
printf 'Startup OK.\n'

#------------------------------------------------------------------------------#
# The requested checks
#------------------------------------------------------------------------------#

failures=0
for check in "$@"; do
	printf '\n=== %s ===\n' "${check}"
	case ${check} in
	lua_runtime)
		lua_runtime_scenarios "${root}" "${cache}" || failures=$((failures + 1))
		;;
	vscode)
		vscode_check "${root}" || failures=$((failures + 1))
		;;
	*)
		test_session "${root}" "${here}/session/${check}.lua" \
			|| failures=$((failures + 1))
		;;
	esac
done

printf '\n'
[ "${failures}" -eq 0 ] || fail "${failures} check(s) failed"
[ $# -eq 0 ] || printf 'All checks passed.\n'
