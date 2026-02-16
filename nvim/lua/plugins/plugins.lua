-- ~/.config/nvim/lua/config/plugins.lua
--
-- Concern-based plugin configuration loader.
-- Each module groups related plugins by workflow, not by plugin name.
-- Uses safe_require so a missing/broken plugin config doesn't block startup.

local safe = require("config.util").safe_require

safe("plugins.editing")
safe("plugins.git")
safe("plugins.ui")
safe("plugins.completion")
safe("plugins.lsp")
safe("plugins.navigation")
safe("plugins.writing")
safe("plugins.sql")
