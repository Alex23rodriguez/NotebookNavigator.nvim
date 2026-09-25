local utils = {}

-- Cache of resolved cell markers per buffer, used when the user configures
-- a list of candidate markers for a filetype. The cache stores the first
-- marker found in the buffer (top-to-bottom scan, leftmost wins on ties),
-- keyed by (bufnr, list_key) so config changes also invalidate.
local resolved_cache = {}

-- Compute a stable key for a list of candidate markers so we can detect
-- config changes between calls.
local function list_key(candidates)
  return table.concat(candidates, "\0")
end

-- Scan the buffer top-to-bottom and return the first candidate marker that
-- appears as a line prefix. Falls back to candidates[1] when none is found.
local function scan_buffer(bufnr, candidates)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for _, line in ipairs(lines) do
    for _, candidate in ipairs(candidates) do
      if line:sub(1, #candidate) == candidate then
        return candidate
      end
    end
  end
  return candidates[1]
end

utils.get_cell_marker = function(bufnr, cell_markers)
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  local ft = vim.bo[bufnr].filetype

  -- if ft == nil or ft == "" then
    -- print "[NotebookNavigator] utils.lua: Empty filetype"
  -- end

  local user_opt_cell_marker = cell_markers[ft]
  if type(user_opt_cell_marker) == "table" then
    local key = list_key(user_opt_cell_marker)
    local entry = resolved_cache[bufnr]
    if entry and entry.list_key == key then
      return entry.marker
    end

    local resolved = scan_buffer(bufnr, user_opt_cell_marker)
    resolved_cache[bufnr] = { marker = resolved, list_key = key }
    return resolved
  elseif user_opt_cell_marker then
    return user_opt_cell_marker
  end

  -- use double percent markers as default for cell markers
  -- DOCS https://jupytext.readthedocs.io/en/latest/formats-scripts.html#the-percent-format
  if not vim.bo.commentstring then
    error("There's no cell marker and no commentstring defined for filetype " .. ft)
  end
  local cstring = string.gsub(vim.bo.commentstring, "^%%", "%%%%")
  local double_percent_cell_marker = cstring:format "%%"
  return double_percent_cell_marker
end

-- Invalidate the resolved-marker cache for a buffer. Called from autocmds
-- on BufReadPost, BufNewFile, BufWritePost and BufWipeout so edits that
-- change which marker is "first" are picked up at file boundaries rather
-- than on every keystroke.
utils.invalidate_resolved_cache = function(bufnr)
  resolved_cache[bufnr] = nil
end

local find_supported_repls = function()
  local supported_repls = {
    { name = "iron", module = "iron" },
    { name = "toggleterm", module = "toggleterm" },
    { name = "molten", module = "molten.health" },
  }

  local available_repls = {}
  for _, repl in pairs(supported_repls) do
    if pcall(require, repl.module) then
      available_repls[#available_repls + 1] = repl.name
    end
  end

  return available_repls
end

utils.available_repls = find_supported_repls()

utils.has_value = function(tab, val)
  for _, value in ipairs(tab) do
    if value == val then
      return true
    end
  end

  return false
end

return utils
