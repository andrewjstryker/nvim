local function check()
  local languages = {
    { "python", "py", 4 }, { "r", "R", 2 }, { "sh", "sh", 2 },
    { "lua", "lua", 2 }, { "fennel", "fnl", 2 },
  }
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  vim.fn.writefile({ "root = true" }, dir .. "/.editorconfig")
  local function open(lang, prefix)
    local path = dir .. "/" .. prefix .. "." .. lang[2]
    vim.fn.writefile({ "" }, path)
    vim.cmd.edit(path)
    assert(vim.bo.filetype == lang[1], "filetype detection: " .. path)
  end
  for _, lang in ipairs(languages) do
    open(lang, "default")
    assert(vim.bo.expandtab, lang[1] .. " should use spaces")
    assert(vim.bo.shiftwidth == lang[3], lang[1] .. " indentation width: " .. vim.bo.shiftwidth)
    assert(vim.bo.softtabstop == -1 or vim.bo.softtabstop == lang[3], lang[1] .. " Tab width")
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("i<Tab>x<Esc>", true, false, true), "xt", false)
    assert(vim.api.nvim_get_current_line() == string.rep(" ", lang[3]) .. "x", lang[1] .. " Tab insertion")
    vim.bo.modified = false
  end
  vim.fn.writefile({ "root = true", "[*]", "indent_style = tab", "indent_size = 3",
    "tab_width = 3", "max_line_length = 66" }, dir .. "/.editorconfig")
  for _, lang in ipairs(languages) do
    open(lang, "project")
    assert(not vim.bo.expandtab, lang[1] .. " project tabs ignored")
    assert(vim.bo.shiftwidth == 3 and vim.bo.tabstop == 3, lang[1] .. " project indentation ignored")
    assert(vim.bo.textwidth == 66, lang[1] .. " project width ignored")
  end
  vim.fn.writefile({ "root = true", "[*]", "max_line_length = off" }, dir .. "/.editorconfig")
  open(languages[1], "unlimited")
  assert(vim.bo.textwidth == 0, "EditorConfig width opt-out ignored")
  vim.fn.delete(dir, "rf")
end
local ok, err = xpcall(check, debug.traceback)
if not ok then io.stderr:write(err .. "\n"); os.exit(1) end
io.stdout:write("LANGUAGE DEFAULTS OK: indentation, Tab insertion and project overrides\n")
os.exit(0)
