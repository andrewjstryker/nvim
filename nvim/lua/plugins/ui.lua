-- ~/.config/nvim/lua/plugins/ui.lua
-- Plugins: which-key, lualine, nvim-web-devicons, solarized.nvim

-- which-key: shows pending keybind popup
local ok, wk = pcall(require, "which-key")
if ok then
  wk.setup({
    delay = 300,
  })

  -- Register group labels so the popup is navigable
  wk.add({
    { "<leader>f", group = "Find" },
    { "<leader>g", group = "Git" },
    { "<leader>h", group = "Hunk" },
    { "<leader>x", group = "Diagnostics" },
  })
end

-- devicons: used by lualine, telescope, trouble
pcall(require, "nvim-web-devicons")

-- Colorscheme (solarized.nvim)
vim.opt.background = "dark"       -- change to "light" for light palette
local ok_cs = pcall(vim.cmd.colorscheme, "solarized")
if not ok_cs then pcall(vim.cmd.colorscheme, "default") end

-- lualine: statusline
local ok2, lualine = pcall(require, "lualine")
if ok2 then
  lualine.setup({
    options = {
      theme = "solarized",          -- bundled with solarized.nvim
      section_separators = "",       -- clean look without patched fonts
      component_separators = "|",
    },
    sections = {
      lualine_a = { "mode" },
      lualine_b = { "branch", "diff" },
      lualine_c = { "filename" },
      lualine_x = { "diagnostics", "filetype" },
      lualine_y = { "progress" },
      lualine_z = { "location" },
    },
  })
end
