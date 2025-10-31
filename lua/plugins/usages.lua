-- ============================================================================
-- USAGES FINDER - Find all usages of a function/variable in your project
-- ============================================================================
--
-- Features:
-- 1. Press <leader>fu on a function name to see all its usages
-- 2. Uses the same picker UI as file finder
-- 3. Respects .gitignore
-- 4. Fuzzy search through usages
-- 5. Jump to any usage instantly
--
-- Usage:
--   <leader>fu  - Find usages of word under cursor
--   <leader>fU  - Find usages (prompt for name)
--
-- Works with:
--   - Functions
--   - Variables
--   - Classes
--   - Anything really!
-- ============================================================================

local M = {}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local DEFAULT_IGNORES = {
  "node_modules/",
  "vendor/",
  "%.min%.js$",
  "%.min%.css$",
  "dist/",
  "build/",
  "%.lock$",
  "package%-lock%.json$",
}

-- Find the git root directory (or fallback to cwd)
local function get_project_root()
  local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
  if vim.v.shell_error == 0 then
    return git_root
  end
  return vim.fn.getcwd()
end

-- Read custom ignore patterns from .nvimignore
local function read_nvimignore(root)
  local ignore_file = root .. "/.nvimignore"
  local patterns = {}

  if vim.fn.filereadable(ignore_file) == 1 then
    local lines = vim.fn.readfile(ignore_file)
    for _, line in ipairs(lines) do
      line = line:match("^%s*(.-)%s*$")
      if line ~= "" and not line:match("^#") then
        table.insert(patterns, line)
      end
    end
  end

  return patterns
end

-- ============================================================================
-- USAGE SEARCH
-- ============================================================================

-- Search for all usages of a symbol in the project
local function search_usages(symbol)
  local root = get_project_root()

  vim.notify("Searching for usages of '" .. symbol .. "'...", vim.log.levels.INFO)

  -- Use ripgrep if available, fallback to grep
  local has_rg = vim.fn.executable("rg") == 1
  local cmd

  if has_rg then
    -- Use word boundary search for better accuracy
    cmd = string.format(
      "rg --line-number --no-heading --color=never --word-regexp '%s' 2>/dev/null",
      symbol:gsub("'", "'\\''")
    )
  else
    cmd = string.format(
      "grep -rn -w --exclude-dir=.git --exclude-dir=node_modules '%s' . 2>/dev/null",
      symbol:gsub("'", "'\\''")
    )
  end

  local results = vim.fn.systemlist("cd " .. vim.fn.shellescape(root) .. " && " .. cmd)

  if vim.v.shell_error ~= 0 or #results == 0 then
    return {}, root
  end

  -- Parse results into structured data
  local usages = {}
  for _, result in ipairs(results) do
    -- Parse: filename:line:content
    local filepath, line_num, content = result:match("^([^:]+):(%d+):(.+)$")

    if filepath and line_num and content then
      -- Clean up content
      content = content:match("^%s*(.-)%s*$")

      table.insert(usages, {
        file = filepath,
        line = tonumber(line_num),
        content = content,
      })
    end
  end

  -- Limit results to prevent slowdown
  if #usages > 500 then
    usages = vim.list_slice(usages, 1, 500)
    vim.notify("Showing first 500 usages (found more)", vim.log.levels.INFO)
  end

  return usages, root
end

-- ============================================================================
-- PICKER UI (same as finder and todos)
-- ============================================================================

local picker_state = {
  items = {},
  usages = {},
  filtered_items = {},
  selected_idx = 1,
  query = "",
  buf = nil,
  win = nil,
  prompt_buf = nil,
  prompt_win = nil,
  root = nil,
  symbol = "",
}

-- Format usage for display
local function format_usage(usage)
  return string.format(
    "%s:%d - %s",
    usage.file,
    usage.line,
    usage.content
  )
end

-- Fuzzy match scoring
local function fuzzy_match(str, pattern)
  if pattern == "" then
    return true, 0
  end

  str = str:lower()
  pattern = pattern:lower()

  if str:find(pattern, 1, true) then
    return true, 2000
  end

  local score = 0
  local str_idx = 1
  local consecutive = 0

  for i = 1, #pattern do
    local char = pattern:sub(i, i)

    if char == " " then
      goto continue
    end

    local found = str:find(char, str_idx, true)

    if not found then
      return false, 0
    end

    score = score + 1

    if found == str_idx then
      consecutive = consecutive + 1
      score = score + consecutive * 5
    else
      consecutive = 0
    end

    str_idx = found + 1

    ::continue::
  end

  return true, score
end

-- Filter usages by fuzzy match
local function fuzzy_filter(items, pattern)
  if pattern == "" then
    return items
  end

  local matched = {}
  for _, item in ipairs(items) do
    local matches, score = fuzzy_match(item, pattern)
    if matches then
      table.insert(matched, { item = item, score = score })
    end
  end

  table.sort(matched, function(a, b)
    return a.score > b.score
  end)

  local result = {}
  for _, m in ipairs(matched) do
    table.insert(result, m.item)
  end

  return result
end

-- Create floating window
local function create_picker_window()
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "usagefinder")

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height - 3,
    row = row + 3,
    col = col,
    style = "minimal",
    border = "rounded",
  })

  local prompt_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(prompt_buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(prompt_buf, "buftype", "prompt")

  local prompt_win = vim.api.nvim_open_win(prompt_buf, true, {
    relative = "editor",
    width = width,
    height = 1,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  })

  -- Show what we're searching for in the prompt
  vim.fn.prompt_setprompt(prompt_buf, "🔍 [" .. picker_state.symbol .. "] ")

  return buf, win, prompt_buf, prompt_win
end

-- Update the results display
local function update_results()
  if not picker_state.buf or not vim.api.nvim_buf_is_valid(picker_state.buf) then
    return
  end

  local lines = {}
  for i, item in ipairs(picker_state.filtered_items) do
    local prefix = i == picker_state.selected_idx and "▶ " or "  "
    table.insert(lines, prefix .. item)
  end

  if #lines == 0 then
    lines = { "  No matches found" }
  end

  vim.api.nvim_buf_set_option(picker_state.buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(picker_state.buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(picker_state.buf, "modifiable", false)

  if picker_state.win and vim.api.nvim_win_is_valid(picker_state.win) then
    vim.api.nvim_win_set_cursor(picker_state.win, { picker_state.selected_idx, 0 })
  end
end

-- Close the picker
local function close_picker()
  if picker_state.win and vim.api.nvim_win_is_valid(picker_state.win) then
    vim.api.nvim_win_close(picker_state.win, true)
  end
  if picker_state.prompt_win and vim.api.nvim_win_is_valid(picker_state.prompt_win) then
    vim.api.nvim_win_close(picker_state.prompt_win, true)
  end
end

-- Select the current item
local function select_item()
  if #picker_state.filtered_items == 0 then
    close_picker()
    return
  end

  local selected = picker_state.filtered_items[picker_state.selected_idx]
  close_picker()

  -- Find the corresponding usage
  for _, usage in ipairs(picker_state.usages) do
    if format_usage(usage) == selected then
      local full_path = picker_state.root .. "/" .. usage.file
      vim.cmd("edit " .. vim.fn.fnameescape(full_path))
      vim.api.nvim_win_set_cursor(0, { usage.line, 0 })
      vim.cmd("normal! zz")

      -- Briefly highlight the line
      vim.cmd("normal! V")
      vim.defer_fn(function()
        if vim.api.nvim_get_mode().mode == "V" then
          vim.cmd("normal! \27") -- ESC
        end
      end, 300)

      return
    end
  end
end

-- Move selection
local function move_selection(delta)
  if #picker_state.filtered_items == 0 then
    return
  end

  picker_state.selected_idx = picker_state.selected_idx + delta

  if picker_state.selected_idx < 1 then
    picker_state.selected_idx = #picker_state.filtered_items
  elseif picker_state.selected_idx > #picker_state.filtered_items then
    picker_state.selected_idx = 1
  end

  update_results()
end

-- Update query and filter
local function on_query_change()
  if not picker_state.prompt_buf or not vim.api.nvim_buf_is_valid(picker_state.prompt_buf) then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(picker_state.prompt_buf, 0, -1, false)
  local query = lines[1] or ""
  -- Remove the prompt prefix
  query = query:gsub("^🔍 %[.-%] ", "")

  picker_state.query = query
  picker_state.filtered_items = fuzzy_filter(picker_state.items, query)
  picker_state.selected_idx = 1

  update_results()
end

-- Setup keymaps for picker
local function setup_picker_keymaps()
  local opts = { buffer = picker_state.prompt_buf, noremap = true, silent = true }

  vim.keymap.set("i", "<CR>", select_item, opts)
  vim.keymap.set("i", "<Esc>", close_picker, opts)
  vim.keymap.set("i", "<C-c>", close_picker, opts)
  vim.keymap.set("i", "<Down>", function() move_selection(1) end, opts)
  vim.keymap.set("i", "<Up>", function() move_selection(-1) end, opts)
  vim.keymap.set("i", "<C-j>", function() move_selection(1) end, opts)
  vim.keymap.set("i", "<C-k>", function() move_selection(-1) end, opts)

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = picker_state.prompt_buf,
    callback = on_query_change,
  })
end

-- Open the picker with usages
local function open_usage_picker(usages, root, symbol)
  if #usages == 0 then
    vim.notify("No usages found for '" .. symbol .. "'", vim.log.levels.WARN)
    return
  end

  local items = {}
  for _, usage in ipairs(usages) do
    table.insert(items, format_usage(usage))
  end

  picker_state.items = items
  picker_state.usages = usages
  picker_state.filtered_items = items
  picker_state.selected_idx = 1
  picker_state.query = ""
  picker_state.root = root
  picker_state.symbol = symbol

  picker_state.buf, picker_state.win, picker_state.prompt_buf, picker_state.prompt_win =
    create_picker_window()

  setup_picker_keymaps()
  update_results()

  vim.cmd("startinsert")

  vim.notify(
    string.format("Found %d usages of '%s'", #usages, symbol),
    vim.log.levels.INFO
  )
end

-- ============================================================================
-- PUBLIC FUNCTIONS
-- ============================================================================

-- Find usages of word under cursor
function M.find_usages_under_cursor()
  -- Get word under cursor
  local word = vim.fn.expand("<cword>")

  if word == "" then
    vim.notify("No word under cursor", vim.log.levels.WARN)
    return
  end

  local usages, root = search_usages(word)
  open_usage_picker(usages, root, word)
end

-- Find usages with prompt
function M.find_usages_prompt()
  vim.ui.input({ prompt = "Find usages of: " }, function(symbol)
    if not symbol or symbol == "" then
      return
    end

    local usages, root = search_usages(symbol)
    open_usage_picker(usages, root, symbol)
  end)
end

-- ============================================================================
-- SETUP
-- ============================================================================

function M.setup()
  -- Create user commands
  vim.api.nvim_create_user_command("FindUsages", M.find_usages_under_cursor, { desc = "Find usages of word under cursor" })
  vim.api.nvim_create_user_command("FindUsagesPrompt", M.find_usages_prompt, { desc = "Find usages (with prompt)" })

  -- Set up keybindings
  vim.keymap.set("n", "<leader>fu", M.find_usages_under_cursor, { desc = "Find usages" })
  vim.keymap.set("n", "<leader>fU", M.find_usages_prompt, { desc = "Find usages (prompt)" })
end

return M
