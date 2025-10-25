-- ============================================================================
-- STATUSLINE - Custom status line with useful information
-- ============================================================================
--
-- Shows:
-- 1. Current mode (NORMAL, INSERT, VISUAL, etc.)
-- 2. File path (relative to project root)
-- 3. Modified indicator [+]
-- 4. Read-only indicator [RO]
-- 5. File type
-- 6. File encoding
-- 7. Line:Column / Total Lines
-- 8. Percentage through file
-- ============================================================================

local M = {}

-- Mode names and colors
local modes = {
  ["n"] = { name = "NORMAL", hl = "StatusLineNormal" },
  ["no"] = { name = "N-PENDING", hl = "StatusLineNormal" },
  ["v"] = { name = "VISUAL", hl = "StatusLineVisual" },
  ["V"] = { name = "V-LINE", hl = "StatusLineVisual" },
  [""] = { name = "V-BLOCK", hl = "StatusLineVisual" },
  ["s"] = { name = "SELECT", hl = "StatusLineVisual" },
  ["S"] = { name = "S-LINE", hl = "StatusLineVisual" },
  [""] = { name = "S-BLOCK", hl = "StatusLineVisual" },
  ["i"] = { name = "INSERT", hl = "StatusLineInsert" },
  ["ic"] = { name = "INSERT", hl = "StatusLineInsert" },
  ["R"] = { name = "REPLACE", hl = "StatusLineReplace" },
  ["Rv"] = { name = "V-REPLACE", hl = "StatusLineReplace" },
  ["c"] = { name = "COMMAND", hl = "StatusLineCommand" },
  ["cv"] = { name = "VIM-EX", hl = "StatusLineCommand" },
  ["ce"] = { name = "EX", hl = "StatusLineCommand" },
  ["r"] = { name = "PROMPT", hl = "StatusLineCommand" },
  ["rm"] = { name = "MORE", hl = "StatusLineCommand" },
  ["r?"] = { name = "CONFIRM", hl = "StatusLineCommand" },
  ["!"] = { name = "SHELL", hl = "StatusLineCommand" },
  ["t"] = { name = "TERMINAL", hl = "StatusLineTerminal" },
}

-- Get current mode
local function get_mode()
  local mode_code = vim.api.nvim_get_mode().mode
  local mode = modes[mode_code] or { name = "UNKNOWN", hl = "StatusLine" }
  return string.format("%%#%s# %s %%*", mode.hl, mode.name)
end

-- Get file path (relative to cwd)
local function get_filepath()
  local filepath = vim.fn.expand("%:.")
  if filepath == "" then
    return "[No Name]"
  end

  -- Shorten long paths
  if #filepath > 40 then
    filepath = "..." .. filepath:sub(-37)
  end

  return filepath
end

-- Get modified indicator
local function get_modified()
  if vim.bo.modified then
    return " [+]"
  end
  return ""
end

-- Get readonly indicator
local function get_readonly()
  if vim.bo.readonly then
    return " [RO]"
  end
  return ""
end

-- Get file type
local function get_filetype()
  local ft = vim.bo.filetype
  if ft == "" then
    return "no ft"
  end
  return ft
end

-- Get file encoding
local function get_encoding()
  local enc = vim.bo.fileencoding
  if enc == "" then
    enc = vim.o.encoding
  end
  return enc
end

-- Get line/col info
local function get_position()
  local line = vim.fn.line(".")
  local col = vim.fn.col(".")
  local total = vim.fn.line("$")
  return string.format("%d:%d/%d", line, col, total)
end

-- Get percentage through file
local function get_percentage()
  local line = vim.fn.line(".")
  local total = vim.fn.line("$")
  local percent = math.floor((line / total) * 100)
  return string.format("%d%%", percent)
end

-- Get git branch (if in git repo)
local function get_git_branch()
  local branch = vim.fn.system("git branch --show-current 2>/dev/null | tr -d '\n'")
  if vim.v.shell_error == 0 and branch ~= "" then
    return "  " .. branch
  end
  return ""
end

-- Build the statusline
local function build_statusline()
  local parts = {
    get_mode(),                    -- Mode (colored)
    " ",
    get_git_branch(),              -- Git branch
    " ",
    get_filepath(),                -- File path
    get_modified(),                -- [+] if modified
    get_readonly(),                -- [RO] if readonly
    "%=",                          -- Right align from here
    get_filetype(),                -- File type
    " | ",
    get_encoding(),                -- Encoding
    " | ",
    get_position(),                -- Line:Col/Total
    " | ",
    get_percentage(),              -- Percentage
    " ",
  }

  return table.concat(parts)
end

-- Setup colors
local function setup_colors()
  -- Define highlight groups for different modes
  vim.api.nvim_set_hl(0, "StatusLineNormal", { fg = "#1e1e2e", bg = "#89b4fa", bold = true })
  vim.api.nvim_set_hl(0, "StatusLineInsert", { fg = "#1e1e2e", bg = "#a6e3a1", bold = true })
  vim.api.nvim_set_hl(0, "StatusLineVisual", { fg = "#1e1e2e", bg = "#f9e2af", bold = true })
  vim.api.nvim_set_hl(0, "StatusLineReplace", { fg = "#1e1e2e", bg = "#f38ba8", bold = true })
  vim.api.nvim_set_hl(0, "StatusLineCommand", { fg = "#1e1e2e", bg = "#cba6f7", bold = true })
  vim.api.nvim_set_hl(0, "StatusLineTerminal", { fg = "#1e1e2e", bg = "#94e2d5", bold = true })
end

-- Setup function
function M.setup()
  -- Setup colors
  setup_colors()

  -- Set the statusline
  vim.opt.statusline = "%!v:lua.require'plugins.statusline'.build()"

  -- Always show statusline
  vim.opt.laststatus = 2

  -- Refresh colors on colorscheme change
  vim.api.nvim_create_autocmd("ColorScheme", {
    callback = function()
      setup_colors()
    end,
  })
end

-- Expose build function for statusline evaluation
M.build = build_statusline

return M
