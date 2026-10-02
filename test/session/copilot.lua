local function check()
  local server = require("config.env").copilot_server
  assert(vim.fn.executable(server) == 1, "Copilot server was not provisioned by sync")
  assert(package.loaded["plugins.completion"], "Completion setup failed")
  local lsp = require("copilot.lsp")
  assert(lsp.config.type == "binary", "Copilot must use the standalone server")
  assert(lsp.config.custom_server_filepath == server, "Copilot ignored the provisioned server")
  assert(lsp.binary.initialized and not lsp.initialization_failed(), "Copilot server setup failed")
  local found = false
  for _, source in ipairs(require("cmp").get_config().sources) do
    if source.name == "copilot" then found = true end
  end
  assert(found, "Copilot is absent from the completion menu")
  assert(package.loaded["copilot_cmp"], "Copilot cmp integration was not loaded")

  -- Attach the real standalone server to an unnamed buffer without triggering
  -- other language servers. Initialization and source registration need no login.
  vim.bo.filetype = "text"
  require("copilot.client").buf_attach(true)
  assert(vim.wait(15000, function()
    return next(require("copilot_cmp").client_source_map) ~= nil
  end, 50), "Copilot failed to initialize and register its cmp source")
end
local ok, err = xpcall(check, debug.traceback)
for _, client in ipairs(vim.lsp.get_clients()) do client:stop(true) end
if not ok then io.stderr:write(err .. "\n"); os.exit(1) end
io.stdout:write("COPILOT OK: provisioned server, LSP initialization and cmp registration\n")
os.exit(0)
