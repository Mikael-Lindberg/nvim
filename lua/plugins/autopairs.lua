-- ============================================================================
-- AUTO-PAIRS - Automatic bracket and quote pairing
-- ============================================================================
--
-- Features:
-- 1. Auto-close brackets, quotes, etc.
-- 2. Smart deletion (delete pair when backspacing opening bracket)
-- 3. Skip closing bracket when typing it
-- 4. Works in insert mode only
--
-- Pairs:
--   ( → ()
--   { → {}
--   [ → []
--   " → ""
--   ' → ''
--   ` → ``
-- ============================================================================

local M = {}

-- Pairs to auto-complete
local autopair_map = {
  ["("] = ")",
  ["["] = "]",
  ["{"] = "}",
  ['"'] = '"',
  ["'"] = "'",
  ["`"] = "`",
}

-- Get the character before cursor
local function get_char_before_cursor()
  local col = vim.fn.col(".") - 1
  if col == 0 then
    return ""
  end
  local line = vim.fn.getline(".")
  return line:sub(col, col)
end

-- Get the character after cursor
local function get_char_after_cursor()
  local col = vim.fn.col(".")
  local line = vim.fn.getline(".")
  return line:sub(col, col)
end

-- Check if we're in a string or comment
local function in_string_or_comment()
  -- Get syntax group at cursor
  local synstack = vim.fn.synstack(vim.fn.line("."), vim.fn.col("."))
  if #synstack == 0 then
    return false
  end

  local synname = vim.fn.synIDattr(synstack[#synstack], "name"):lower()
  return synname:match("string") or synname:match("comment")
end

-- Auto-pair opening brackets
local function autopair(open_char)
  local close_char = autopair_map[open_char]

  -- Special handling for quotes - only auto-pair if not in string
  if open_char == '"' or open_char == "'" or open_char == "`" then
    local after = get_char_after_cursor()

    -- If next char is the same quote, just move over it
    if after == open_char then
      return "<Right>"
    end

    -- If we're already in a string, just insert the character
    if in_string_or_comment() then
      return open_char
    end
  end

  -- Insert the pair and move cursor between them
  return open_char .. close_char .. "<Left>"
end

-- Skip closing bracket if it's already there
local function skip_closing(close_char)
  local after = get_char_after_cursor()

  -- If the next character is the closing bracket, skip over it
  if after == close_char then
    return "<Right>"
  end

  -- Otherwise, just insert the character
  return close_char
end

-- Smart backspace - delete pair if both brackets are present
local function smart_backspace()
  local before = get_char_before_cursor()
  local after = get_char_after_cursor()

  -- Check if we're between a pair
  if autopair_map[before] and autopair_map[before] == after then
    return "<Del><BS>"
  end

  -- Normal backspace
  return "<BS>"
end

-- Smart CR (Enter) - add extra line and indent between brackets
local function smart_cr()
  local before = get_char_before_cursor()
  local after = get_char_after_cursor()

  -- If between brackets, add extra line with proper indent
  if (before == "(" and after == ")") or
     (before == "{" and after == "}") or
     (before == "[" and after == "]") then
    return "<CR><Esc>O"
  end

  -- Normal enter
  return "<CR>"
end

-- Setup function
function M.setup()
  local opts = { noremap = true, silent = true, expr = true }

  -- Auto-pair opening brackets
  for open_char, close_char in pairs(autopair_map) do
    vim.keymap.set("i", open_char, function()
      return autopair(open_char)
    end, opts)

    -- Skip closing brackets
    vim.keymap.set("i", close_char, function()
      return skip_closing(close_char)
    end, opts)
  end

  -- Smart backspace
  vim.keymap.set("i", "<BS>", smart_backspace, opts)

  -- Smart Enter
  vim.keymap.set("i", "<CR>", smart_cr, opts)

  -- Space between brackets adds spaces on both sides
  vim.keymap.set("i", "<Space>", function()
    local before = get_char_before_cursor()
    local after = get_char_after_cursor()

    if (before == "(" and after == ")") or
       (before == "{" and after == "}") or
       (before == "[" and after == "]") then
      return "<Space><Space><Left>"
    end

    return "<Space>"
  end, opts)
end

return M
