#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
#
# test/vscode.sh
#
# The `vscode` check: run the VS Code entry point of the installed
# configuration.  Sourced by test/checks.sh, which owns the throwaway root and
# the install; this file adds one function:
#
#   vscode_check <root>
#
# A session cannot arrange its own entry point, which is why this is a driver:
#
#   * `vim.g.vscode` has to be set before init.lua runs, since that is the
#     gate config.vscode hangs on
#   * `config.vscode` hard-requires the extension's own `vscode` Lua module,
#     which exists only inside VS Code, so it must be stubbed before the
#     require happens
#   * the contract under test is that the EXTENSION's runtimepath entries
#     survive, so an entry has to be on the rtp before the config touches it
#
# Only the extension's Lua module is stubbed -- the same bargain the
# lua_runtime check strikes with vim.lsp.enable.  Everything else is the real
# installed configuration taking its real VS Code branch.
#
# The per-session assertions live in test/session/vscode.lua.
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#

vscode_check() {
	_root=$1
	_cfg="${_root}/config/nvim"
	_shim="${_root}/vscode-shim.lua"

	# Stands in for a runtimepath entry the extension owns (vscode.internal
	# and friends).  It only has to be a path the configuration must not
	# discard, so an empty directory is the honest fixture.
	_sentinel="${_root}/extension-runtime"
	mkdir -p "${_sentinel}"

	# -u names this file, so Neovim skips its own init lookup; the shim sets
	# the gate, stubs the extension module, plants the sentinel, and only
	# then hands over to the installed init.lua.  Neovim's filetype and
	# syntax defaults stay on, as they are inside VS Code -- which matters,
	# because an ftplugin is what fails when this check fails.
	cat > "${_shim}" <<SHIM
vim.g.vscode = true

-- Any field is a no-op function: config.vscode only calls vscode.action(),
-- and only from inside keymap callbacks that this check never presses.
package.preload["vscode"] = function()
  return setmetatable({}, { __index = function() return function() end end })
end

vim.opt.runtimepath:prepend("${_sentinel}")
vim.g.vscode_test_sentinel = "${_sentinel}"

dofile("${_cfg}/init.lua")
SHIM

	# shellcheck disable=SC2154 # `here` is set by checks.sh, which sources us
	test_session "${_root}" "${here}/session/vscode.lua" -u "${_shim}"
}
