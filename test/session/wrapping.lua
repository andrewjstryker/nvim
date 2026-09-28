local function check()
  local sentence = ("words for wrapping "):rep(12):sub(1, -2)
  local function buffer(ft, lines)
    vim.cmd.enew({ bang = true })
    vim.bo.filetype = ft
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines or { "" })
    assert(vim.bo.textwidth == 80, ft .. " width")
    assert(not vim.bo.formatoptions:find("a", 1, true), ft .. " continuous formatting")
  end
  local function type_text(text)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("A" .. text .. "<Esc>", true, false, true), "xt", false)
  end
  local function lines() return vim.api.nvim_buf_get_lines(0, 0, -1, false) end
  local function wrapped()
    assert(#lines() > 1, "expected wrapping: " .. vim.bo.filetype)
    for _, line in ipairs(lines()) do assert(#line <= 80, "line exceeds width: " .. line) end
  end
  for _, ft in ipairs({ "text", "markdown", "pandoc", "tex", "plaintex" }) do
    buffer(ft)
    assert(vim.wo.wrap and vim.wo.spell, ft .. " prose display defaults")
    type_text(sentence)
    wrapped()
  end
  -- Changing filetype must undo prose display settings in the same window.
  vim.bo.filetype = "lua"
  assert(not vim.wo.wrap and not vim.wo.spell, "prose display leaked into code")
  assert(not vim.bo.formatoptions:find("t", 1, true), "prose wrapping leaked into code")
  buffer("lua")
  type_text("-- " .. sentence)
  wrapped()
  for _, line in ipairs(lines()) do assert(line:match("^%-%-"), "comment leader lost") end
  buffer("lua")
  type_text('local value = "' .. sentence .. '"')
  assert(#lines() == 1, "code wrapped while typing")
  vim.cmd.enew({ bang = true })
  vim.bo.filetype = "ps1"
  assert(vim.bo.textwidth == 0, "filetype's explicit width was overwritten")
  type_text("# " .. sentence)
  assert(#lines() == 1, "filetype's wrapping opt-out was ignored")
  buffer("lua", { "if true then" })
  type_text("<CR>local value = 1")
  assert(lines()[2]:match("^%s+local"), "code indentation missing")

  local function protected(ft, before, after)
    buffer(ft, before)
    vim.api.nvim_win_set_cursor(0, { #before, 0 })
    type_text(sentence)
    assert(#lines() == #before, "protected typing wrapped: " .. ft)
    local original = lines()
    for _, line in ipairs(after) do original[#original + 1] = line end
    original[#original + 1] = ""
    original[#original + 1] = sentence
    vim.api.nvim_buf_set_lines(0, 0, -1, false, original)
    vim.cmd("normal! gggqG")
    local result = lines()
    for i = 1, #before + #after do
      assert(result[i] == original[i], "gq changed protected line: " .. tostring(result[i]))
    end
    assert(#result > #original, "gq failed to reflow prose after protected region")
  end
  protected("markdown", { "```lua", "" }, { "```" })
  protected("markdown", { "~~~", "" }, { "~~~" })
  protected("markdown", { "> ```", "> " }, { "> ```" })
  protected("markdown", { "| heading |", "| --- |", "| " }, {})
  protected("tex", { "\\begin{verbatim}", "" }, { "\\end{verbatim}" })
  protected("tex", { "\\begin{align*}", "" }, { "\\end{align*}" })
  protected("tex", { "\\[", "" }, { "\\]" })
  protected("plaintex", { "$$", "" }, { "$$" })

  -- Real file reads exercise EditorConfig ordering; real writes exercise the
  -- default no-format/no-trim policy and the buffer-local Conform opt-in.
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local plain = dir .. "/untouched.txt"
  vim.fn.writefile({ "keep trailing spaces   " }, plain)
  vim.cmd.edit(plain)
  vim.cmd.write()
  assert(vim.fn.readfile(plain)[1] == "keep trailing spaces   ", "default save trimmed whitespace")
  vim.fn.writefile({ "root = true", "[*]", "max_line_length = 64",
    "trim_trailing_whitespace = false" }, dir .. "/.editorconfig")
  local file = dir .. "/sample.md"
  vim.fn.writefile({ "hard break  ", "untouched   " }, file)
  vim.cmd.edit(file)
  assert(vim.bo.textwidth == 64, "EditorConfig width lost")
  vim.cmd.write()
  assert(vim.deep_equal(vim.fn.readfile(file), { "hard break  ", "untouched   " }), "save changed whitespace")
  local conform = require("conform")
  if conform.formatters.prettier then
    local args = conform.formatters.prettier.prepend_args(nil, { buf = 0 })
    assert(vim.deep_equal(args, { "--prose-wrap", "preserve",
      "--embedded-language-formatting", "off", "--config-precedence", "prefer-file" }),
      "Markdown Prettier defaults lost")
  end
  local old_format, calls = conform.format, 0
  conform.format = function() calls = calls + 1 end
  vim.cmd.write()
  assert(calls == 0, "save formatted without opt-in")
  vim.b.format_on_save = true
  vim.cmd.write()
  assert(calls == 1, "save opt-in ignored")
  conform.format = old_format
  vim.b.format_on_save = nil
  vim.fn.writefile({ "root = true", "[*]", "trim_trailing_whitespace = true" }, dir .. "/.editorconfig")
  vim.cmd.edit()
  vim.cmd.write()
  assert(vim.deep_equal(vim.fn.readfile(file), { "hard break", "untouched" }), "explicit trimming ignored")
  vim.fn.delete(dir, "rf")
end
local ok, err = xpcall(check, debug.traceback)
if not ok then io.stderr:write(err .. "\n"); os.exit(1) end
io.stdout:write("WRAPPING OK: typing, protected regions, gq, EditorConfig and saving\n")
os.exit(0)
