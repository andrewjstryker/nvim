-- Shared writing policy: comments, prose, display wrapping, spelling and gq.
-- External formatters belong to plugins/formatting.lua; writing UI plugins
-- belong to plugins/writing.lua. Filetype-specific exceptions use after/ftplugin/.
local M = {}
local markdown = { markdown = true, pandoc = true }
local tex = { tex = true, plaintex = true }
local prose = { text = true, markdown = true, pandoc = true,
  tex = true, plaintex = true }
local expression = "v:lua.require'config.writing'.format()"

function M.configure_buffer()
  if vim.bo.buftype ~= "" then return end
  local ft = vim.bo.filetype
  -- Width is inherited from options.lua, then owned by filetype/project
  -- settings. Do not reset it here or include it in this module's undo list.
  -- Preserve filetype-specific list handling, but remove exceptions that leave
  -- existing long lines unwrapped or continuously reformat whole paragraphs.
  vim.opt_local.formatoptions:remove({ "t", "a", "l", "v", "b" })
  vim.opt_local.formatoptions:append("cqrj1")
  if prose[ft] then
    vim.opt_local.formatoptions:append("t")
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
    vim.opt_local.spelllang = "en_us"
    vim.b.undo_ftplugin = (vim.b.undo_ftplugin or "")
      .. " | setlocal wrap< spell< spelllang<"
  end
  -- Own gq even when an LSP offers range formatting. Whole-file formatting
  -- remains available separately through <leader>cf.
  vim.bo.formatexpr = expression
  vim.b.undo_ftplugin = (vim.b.undo_ftplugin or "")
    .. " | setlocal formatoptions< formatexpr<"
end

local environments = {
  verbatim = true, Verbatim = true, BVerbatim = true, LVerbatim = true,
  lstlisting = true, minted = true, alltt = true,
  equation = true, align = true, alignat = true, flalign = true,
  gather = true, multline = true, displaymath = true, eqnarray = true,
}

local function tex_regions(lines)
  local protected, environment, display = {}, nil, nil
  for row, line in ipairs(lines) do
    protected[row] = environment ~= nil or display ~= nil
    local i = 1
    while i <= #line do
      local tail = line:sub(i)
      if environment then
        local closing = "\\end{" .. environment .. "}"
        local at = line:find(closing, i, true)
        if not at then break end
        environment, i = nil, at + #closing
      elseif tail:sub(1, 1) == "%" then
        break
      elseif tail:sub(1, 7) == "\\begin{" then
        local name = tail:match("^\\begin{([^}]+)}")
        if name and environments[name:gsub("%*$", "")] then
          environment, protected[row] = name, true
        end
        i = i + (name and #name + 8 or 1)
      elseif tail:sub(1, 2) == "\\[" then
        display, protected[row], i = "bracket", true, i + 2
      elseif tail:sub(1, 2) == "\\]" then
        display, protected[row], i = nil, true, i + 2
      elseif tail:sub(1, 2) == "$$" then
        if display == "dollar" then display = nil else display = "dollar" end
        protected[row], i = true, i + 2
      elseif tail:sub(1, 1) == "\\" then
        i = i + 2 -- escaped percent/dollar/backslash
      else
        i = i + 1
      end
    end
  end
  return protected
end

local function markdown_regions(lines)
  local protected = {}
  local ok, parser = pcall(vim.treesitter.get_parser, 0, "markdown")
  -- If provisioning is incomplete, preserve text rather than risk breaking it.
  if not ok or not parser then
    for row in ipairs(lines) do protected[row] = true end
    return protected
  end
  local function visit(node)
    local kind = node:type()
    if kind == "fenced_code_block" or kind == "indented_code_block" or kind == "pipe_table" then
      local first, _, last, col = node:range()
      for row = first + 1, last + (col > 0 and 1 or 0) do protected[row] = true end
    else
      for child in node:iter_children() do visit(child) end
    end
  end
  for _, tree in ipairs(parser:parse()) do visit(tree:root()) end
  for row, line in ipairs(lines) do
    -- Protect unfinished table rows before a delimiter row has been typed,
    -- and intentional Markdown hard breaks. This deliberately errs on the
    -- side of preserving lines containing pipes.
    if line:find("|", 1, true) or line:match("  $") or line:match("\\$") then
      protected[row] = true
    end
  end
  return protected
end

function M.format()
  local ft = vim.bo.filetype
  if not markdown[ft] and not tex[ft] then return 1 end
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local protected = markdown[ft] and markdown_regions(lines) or tex_regions(lines)
  local first, last = vim.v.lnum, math.min(#lines, vim.v.lnum + vim.v.count - 1)
  if vim.api.nvim_get_mode().mode:match("^[iR]") then
    for row = first, last do
      if protected[row] then return 0 end
    end
    return 1 -- native wrapping, including comments and list indentation
  end

  -- Reflow only contiguous unprotected ranges, working backwards so changes
  -- in line counts cannot move the ranges still waiting to be formatted.
  local ranges, start = {}, nil
  for row = first, last + 1 do
    if row <= last and not protected[row] then
      start = start or row
    elseif start then
      ranges[#ranges + 1], start = { start, row - 1 }, nil
    end
  end
  local view, fex, prg = vim.fn.winsaveview(), vim.bo.formatexpr, vim.bo.formatprg
  vim.bo.formatexpr, vim.bo.formatprg = "", ""
  local ok, err = pcall(function()
    for i = #ranges, 1, -1 do
      local range = ranges[i]
      vim.api.nvim_win_set_cursor(0, { range[1], 0 })
      vim.cmd("silent keepjumps normal! " .. (range[2] - range[1] + 1) .. "gqq")
    end
  end)
  vim.bo.formatexpr, vim.bo.formatprg = fex, prg
  vim.fn.winrestview(view)
  if not ok then error(err) end
  return 0
end

return M
