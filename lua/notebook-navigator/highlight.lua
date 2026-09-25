local highlight = {}

-- Build a Vim regex that matches any of the user-configured markers for the
-- buffer's filetype as a line prefix. When the user configures a list of
-- candidates, all of them are OR'd together so every listed marker is
-- highlighted, regardless of which one is dominant in the buffer.
local function build_pattern_regex(buf_id, cell_markers)
  local ft = vim.bo[buf_id].filetype
  local user_opt = cell_markers[ft]

  local function escape_marker(m)
    return (string.gsub(m, "%%", "%%%%"))
  end

  if type(user_opt) == "table" then
    local parts = {}
    for _, m in ipairs(user_opt) do
      table.insert(parts, escape_marker(m))
    end
    return "^(" .. table.concat(parts, "|") .. ")"
  elseif user_opt then
    return "^" .. escape_marker(user_opt)
  end

  if not vim.bo[buf_id].commentstring then
    return nil
  end
  local cstring = string.gsub(vim.bo[buf_id].commentstring, "^%%", "%%%%")
  local default_marker = cstring:format "%%"
  return "^" .. escape_marker(default_marker)
end

highlight.minihipatterns_spec = function(cell_markers, hl_group)
  local notebook_cells = {
    pattern = function(buf_id)
      return build_pattern_regex(buf_id, cell_markers)
    end,
    group = "",
    extmark_opts = {
      virt_text = {
        {
          "───────────────────────────────────────────────────────────────",
          hl_group,
        },
      },
      line_hl_group = hl_group,
      hl_eol = true,
    },
  }
  return notebook_cells
end

highlight.setup_autocmd_syntax_highlights = function(cell_markers, hl_group)
  vim.api.nvim_create_augroup("NotebookNavigator", { clear = true })

  -- Create autocmd for every language
  for ft, marker in pairs(cell_markers) do
    local pattern
    if type(marker) == "table" then
      local parts = {}
      for _, m in ipairs(marker) do
        table.insert(parts, (string.gsub(m, "%%", "%%%%")))
      end
      pattern = table.concat(parts, "|")
    else
      pattern = (string.gsub(marker, "%%", "%%%%"))
    end
    local syntax_rule = [[ /^\s*(]] .. pattern .. [[).*$/]]
    local syntax_cmd = "syntax match CodeCell" .. syntax_rule
    vim.api.nvim_create_autocmd("FileType", {
      pattern = ft,
      group = "NotebookNavigator",
      command = syntax_cmd,
    })
  end
  vim.api.nvim_set_hl(0, "CodeCell", { link = hl_group })
  vim.api.nvim_exec_autocmds("FileType", { group = "NotebookNavigator" })
end

return highlight
