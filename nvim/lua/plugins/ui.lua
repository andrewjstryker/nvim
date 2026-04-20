-- ~/.config/nvim/lua/plugins/ui.lua
-- Plugins: which-key, lualine, nvim-web-devicons, solarized.nvim

-- Truecolor + UI niceties
vim.opt.cursorline = true
vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.signcolumn = "yes"

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

-- Colorscheme: vim-solarized8 (lifepillar/vim-solarized8)
-- Works with the terminal's own Solarized palette
vim.g.solarized_use16 = 1
vim.opt.termguicolors = false
vim.opt.background = "dark"
local ok_cs = pcall(vim.cmd.colorscheme, "solarized8")
if not ok_cs then pcall(vim.cmd.colorscheme, "default") end

-- lualine: statusline
-- Custom 16-color solarized theme (ANSI indices match terminal palette)
local sol16 = (function()
  -- Solarized dark ANSI mapping
  local base03  = 8   -- brblack  (bg)
  local base02  = 0   -- black    (bg highlights)
  local base01  = 10  -- brgreen  (comments / secondary)
  local base0   = 12  -- brblue   (body text)
  local base1   = 14  -- brcyan   (emphasis)
  local green   = 2
  local blue    = 4
  local red     = 1
  local magenta = 5
  local yellow  = 3
  local mode = function(accent)
    return {
      a = { fg = base03, bg = accent, gui = "bold" },
      b = { fg = base1,  bg = base02 },
      c = { fg = base01, bg = base03 },
    }
  end
  return {
    normal   = mode(blue),
    insert   = mode(green),
    visual   = mode(magenta),
    replace  = mode(red),
    command  = mode(yellow),
    inactive = {
      a = { fg = base01, bg = base02 },
      b = { fg = base01, bg = base02 },
      c = { fg = base01, bg = base03 },
    },
  }
end)()

local ok2, lualine = pcall(require, "lualine")
if ok2 then
  lualine.setup({
    options = {
      theme = sol16,
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
