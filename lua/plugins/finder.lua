-- ============================================================================
-- PROJECT FINDER - Fuzzy file and content search (like Telescope but lighter)
-- ============================================================================
--
-- Features:
-- 1. Find files by name (respects .gitignore)
-- 2. Find files by content (grep search)
-- 3. Project-aware (finds git root automatically)
-- 4. Fast fuzzy matching
-- 5. No external dependencies (uses built-in vim.ui.select)
--
-- Usage:
--   <leader>ff  - Find files by name
--   <leader>fg  - Find in file contents (grep)
--   <leader>fb  - Find in open buffers
--   <leader>fr  - Find recent files
-- ============================================================================

local M = {}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Find the git root directory (or fallback to cwd)
local function get_project_root()
  local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
  if vim.v.shell_error == 0 then
    return git_root
  end
  return vim.fn.getcwd()
end

-- Files to exclude from search (add your own!)
local EXCLUDED_PATTERNS = {
  "%.svg$",
  "%.png$",
  "%.jpg$",
  "%.jpeg$",
  "%.gif$",
  "%.ico$",
  "%.webp$",
  "%-lock%.json$",
  "package%-lock%.json$",
  "yarn%.lock$",
  "pnpm%-lock%.yaml$",
  "%.lock$",
  "%.min%.js$",
  "%.min%.css$",
  "dist/",
  "build/",
  "%.map$",
}

-- Check if file should be excluded
local function should_exclude(filepath)
  for _, pattern in ipairs(EXCLUDED_PATTERNS) do
    if filepath:match(pattern) then
      return true
    end
  end
  return false
end

-- Get all files in project (respecting .gitignore)
local function get_project_files()
  local root = get_project_root()
  local cmd

  -- Try git ls-files first (fastest and respects .gitignore)
  local is_git = vim.fn.isdirectory(root .. "/.git") == 1
  if is_git then
    cmd = "git ls-files"
  else
    -- Fallback to find (exclude common directories)
    cmd = "find . -type f -not -path '*/\\.git/*' -not -path '*/node_modules/*' -not -path '*/__pycache__/*' -not -path '*/\\.venv/*' -not -path '*/venv/*'"
  end

  local all_files = vim.fn.systemlist("cd " .. vim.fn.shellescape(root) .. " && " .. cmd)

  -- Filter out excluded files
  local files = {}
  for _, file in ipairs(all_files) do
    if not should_exclude(file) then
      table.insert(files, file)
    end
  end

  return files, root
end

-- Fuzzy match scoring (simple but effective)
local function fuzzy_match(str, pattern)
  if pattern == "" then
    return true, 0
  end

  str = str:lower()
  pattern = pattern:lower()

  -- Convert spaces to path separators for path-aware matching
  -- "src app" becomes "src/app" or "src.*app"
  local path_pattern = pattern:gsub("%s+", "/")

  -- Exact match gets highest score
  if str:find(pattern, 1, true) then
    return true, 2000
  end

  -- Path-aware exact match (e.g., "src app" matches "src/app/file.js")
  if path_pattern ~= pattern and str:find(path_pattern, 1, true) then
    return true, 1800
  end

  -- Fuzzy match: all chars must appear in order
  local score = 0
  local str_idx = 1
  local consecutive = 0
  local last_sep_bonus = false

  for i = 1, #pattern do
    local char = pattern:sub(i, i)

    -- Skip spaces in pattern (already handled by path matching)
    if char == " " then
      goto continue
    end

    local found = str:find(char, str_idx, true)

    if not found then
      return false, 0
    end

    -- Award points for matches
    score = score + 1

    -- Bonus for consecutive matches
    if found == str_idx then
      consecutive = consecutive + 1
      score = score + consecutive * 5
    else
      consecutive = 0
    end

    -- Big bonus for matching after path separator or at start
    local prev_char = str:sub(found - 1, found - 1)
    if prev_char == "/" or prev_char == "" then
      score = score + 20
      last_sep_bonus = true
    elseif last_sep_bonus then
      -- Continue bonus for chars right after separator
      score = score + 10
      last_sep_bonus = false
    else
      last_sep_bonus = false
    end

    -- Bonus for matching at word boundaries (camelCase, snake_case)
    if prev_char:match("[%l%d]") and char:match("[%u]") then
      score = score + 15
    end
    if prev_char == "_" or prev_char == "-" then
      score = score + 15
    end

    str_idx = found + 1

    ::continue::
  end

  return true, score
end

-- Filter and sort items by fuzzy match
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

  -- Sort by score (descending)
  table.sort(matched, function(a, b)
    return a.score > b.score
  end)

  -- Extract just the items
  local result = {}
  for _, m in ipairs(matched) do
    table.insert(result, m.item)
  end

  return result
end

-- ============================================================================
-- INTERACTIVE PICKER
-- ============================================================================

local picker_state = {
  items = {},
  filtered_items = {},
  selected_idx = 1,
  query = "",
  buf = nil,
  win = nil,
  prompt_buf = nil,
  prompt_win = nil,
  on_select = nil,
  root = nil,
}

-- Create floating window
local function create_picker_window()
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create results buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "projectfinder")

  -- Create results window
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height - 3,
    row = row + 3,
    col = col,
    style = "minimal",
    border = "rounded",
  })

  -- Create prompt buffer
  local prompt_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(prompt_buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(prompt_buf, "buftype", "prompt")

  -- Create prompt window
  local prompt_win = vim.api.nvim_open_win(prompt_buf, true, {
    relative = "editor",
    width = width,
    height = 1,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  })

  vim.fn.prompt_setprompt(prompt_buf, "🔍 ")

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

  -- Highlight selected line
  vim.api.nvim_buf_clear_namespace(picker_state.buf, -1, 0, -1)
  if picker_state.selected_idx <= #picker_state.filtered_items then
    vim.api.nvim_buf_add_highlight(
      picker_state.buf,
      -1,
      "PmenuSel",
      picker_state.selected_idx - 1,
      0,
      -1
    )
  end
end

-- Handle query changes
local function on_query_change()
  local query = vim.api.nvim_buf_get_lines(picker_state.prompt_buf, 0, 1, false)[1]
  query = query:gsub("^🔍 ", "") -- Remove prompt

  picker_state.query = query

  -- If query looks like a function name (CamelCase or snake_case with 3+ chars)
  -- dynamically search for functions and add them to results
  if #query >= 3 and (query:match("^[A-Z]") or query:match("_")) then
    -- Schedule async function search
    vim.schedule(function()
      if picker_state.query ~= query then return end -- Query changed, abort

      local root = picker_state.root or vim.fn.getcwd()
      local has_rg = vim.fn.executable("rg") == 1

      -- Quick function search patterns
      local search_pattern = query
      local cmd
      if has_rg then
        cmd = string.format(
          "rg --line-number --no-heading --color=never -i 'function.*%s|%s.*function|def.*%s|%s.*\\(|func.*%s' 2>/dev/null | head -n 15",
          search_pattern, search_pattern, search_pattern, search_pattern, search_pattern
        )
      else
        cmd = string.format(
          "grep -rn -iE 'function.*%s|%s.*function|def.*%s|%s.*\\(|func.*%s' --exclude-dir=.git --exclude-dir=node_modules . 2>/dev/null | head -n 15",
          search_pattern, search_pattern, search_pattern, search_pattern, search_pattern
        )
      end

      local func_results = vim.fn.systemlist("cd " .. vim.fn.shellescape(root) .. " && " .. cmd)

      -- Add function results to the items list (mark them with [fn] prefix for visibility)
      local original_item_count = #picker_state.items
      for _, result in ipairs(func_results) do
        if not should_exclude(result) then
          -- Format: filename:line:content
          table.insert(picker_state.items, "[fn] " .. result)
        end
      end

      -- Only re-filter if we added new items and query hasn't changed
      if #picker_state.items > original_item_count and picker_state.query == query then
        picker_state.filtered_items = fuzzy_filter(picker_state.items, query)
        picker_state.selected_idx = math.min(picker_state.selected_idx, #picker_state.filtered_items)
        update_results()
      end
    end)
  end

  picker_state.filtered_items = fuzzy_filter(picker_state.items, query)
  picker_state.selected_idx = 1

  update_results()
end

-- Close the picker
local function close_picker()
  if picker_state.win and vim.api.nvim_win_is_valid(picker_state.win) then
    vim.api.nvim_win_close(picker_state.win, true)
  end
  if picker_state.prompt_win and vim.api.nvim_win_is_valid(picker_state.prompt_win) then
    vim.api.nvim_win_close(picker_state.prompt_win, true)
  end
  picker_state = {
    items = {},
    filtered_items = {},
    selected_idx = 1,
    query = "",
    buf = nil,
    win = nil,
    prompt_buf = nil,
    prompt_win = nil,
    on_select = nil,
    root = nil,
  }
end

-- Select current item
local function select_current()
  if #picker_state.filtered_items == 0 then
    return
  end

  local selected = picker_state.filtered_items[picker_state.selected_idx]
  local callback = picker_state.on_select

  close_picker()

  if callback then
    callback(selected)
  end
end

-- Move selection up/down
local function move_selection(direction)
  local new_idx = picker_state.selected_idx + direction
  if new_idx >= 1 and new_idx <= #picker_state.filtered_items then
    picker_state.selected_idx = new_idx
    update_results()

    -- Scroll the window to keep selection visible
    if picker_state.win and vim.api.nvim_win_is_valid(picker_state.win) then
      vim.api.nvim_win_set_cursor(picker_state.win, { picker_state.selected_idx, 0 })
    end
  end
end

-- Setup keymaps for picker
local function setup_picker_keymaps()
  local opts = { noremap = true, silent = true, buffer = picker_state.prompt_buf }

  -- Close picker
  vim.keymap.set("i", "<Esc>", close_picker, opts)
  vim.keymap.set("i", "<C-c>", close_picker, opts)

  -- Select item
  vim.keymap.set("i", "<CR>", select_current, opts)

  -- Navigate
  vim.keymap.set("i", "<C-n>", function() move_selection(1) end, opts)
  vim.keymap.set("i", "<C-p>", function() move_selection(-1) end, opts)
  vim.keymap.set("i", "<Down>", function() move_selection(1) end, opts)
  vim.keymap.set("i", "<Up>", function() move_selection(-1) end, opts)
  vim.keymap.set("i", "<C-j>", function() move_selection(1) end, opts)
  vim.keymap.set("i", "<C-k>", function() move_selection(-1) end, opts)

  -- Update on every keystroke
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = picker_state.prompt_buf,
    callback = on_query_change,
  })
end

-- Open the picker
local function open_picker(items, on_select, root)
  picker_state.items = items
  picker_state.filtered_items = items
  picker_state.selected_idx = 1
  picker_state.query = ""
  picker_state.on_select = on_select
  picker_state.root = root or vim.fn.getcwd()

  picker_state.buf, picker_state.win, picker_state.prompt_buf, picker_state.prompt_win =
    create_picker_window()

  setup_picker_keymaps()
  update_results()

  -- Enter insert mode in prompt
  vim.cmd("startinsert")
end

-- ============================================================================
-- PUBLIC FUNCTIONS
-- ============================================================================

-- Find files by name (also searches function definitions!)
function M.find_files()
  local files, root = get_project_files()

  if #files == 0 then
    vim.notify("No files found in project", vim.log.levels.WARN)
    return
  end

  open_picker(files, function(selected)
    -- Check if this is a function result (marked with [fn] prefix)
    if selected:match("^%[fn%]") then
      -- Remove the [fn] prefix
      selected = selected:gsub("^%[fn%]%s*", "")

      -- Parse: filename:line:content
      local filepath, line_num = selected:match("^([^:]+):(%d+)")

      if filepath and line_num then
        local full_path = root .. "/" .. filepath
        vim.cmd("edit " .. vim.fn.fnameescape(full_path))
        vim.api.nvim_win_set_cursor(0, { tonumber(line_num), 0 })
        vim.cmd("normal! zz")
      end
    else
      -- It's a regular file
      local full_path = root .. "/" .. selected
      vim.cmd("edit " .. vim.fn.fnameescape(full_path))
    end
  end, root)
end

-- Grep search in file contents
function M.grep_search()
  local root = get_project_root()

  -- Close picker and get the query
  close_picker()

  vim.ui.input({ prompt = "Grep for: " }, function(query)
    if not query or query == "" then
      return
    end

    -- Use ripgrep if available, fallback to grep
    local has_rg = vim.fn.executable("rg") == 1
    local cmd

    if has_rg then
      cmd = string.format(
        "rg --line-number --no-heading --color=never --smart-case '%s' 2>/dev/null",
        query:gsub("'", "'\\''")
      )
    else
      cmd = string.format(
        "grep -rn --exclude-dir=.git --exclude-dir=node_modules '%s' .",
        query:gsub("'", "'\\''")
      )
    end

    local results = vim.fn.systemlist("cd " .. vim.fn.shellescape(root) .. " && " .. cmd)

    if #results == 0 then
      vim.notify("No matches found for: " .. query, vim.log.levels.WARN)
      return
    end

    -- Limit results to prevent slowdown
    if #results > 1000 then
      results = vim.list_slice(results, 1, 1000)
      vim.notify("Showing first 1000 results", vim.log.levels.INFO)
    end

    open_picker(results, function(selected)
      -- Parse the grep result: filename:line:content
      local filepath, line_num = selected:match("^([^:]+):(%d+)")

      if filepath and line_num then
        local full_path = root .. "/" .. filepath
        vim.cmd("edit " .. vim.fn.fnameescape(full_path))
        vim.api.nvim_win_set_cursor(0, { tonumber(line_num), 0 })
        vim.cmd("normal! zz") -- Center the line
      end
    end, root)
  end)
end

-- Find in open buffers
function M.find_buffers()
  local buffers = {}

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_option(buf, "buflisted") then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" then
        -- Show relative path if possible
        local relative = vim.fn.fnamemodify(name, ":.")
        table.insert(buffers, relative)
      end
    end
  end

  if #buffers == 0 then
    vim.notify("No buffers open", vim.log.levels.WARN)
    return
  end

  open_picker(buffers, function(selected)
    vim.cmd("buffer " .. vim.fn.fnameescape(selected))
  end)
end

-- Find recent files
function M.find_recent()
  local recent = vim.v.oldfiles
  local files = {}

  -- Filter to only existing files and make relative
  for _, file in ipairs(recent) do
    if vim.fn.filereadable(file) == 1 then
      local relative = vim.fn.fnamemodify(file, ":.")
      table.insert(files, relative)

      -- Limit to 100 most recent
      if #files >= 100 then
        break
      end
    end
  end

  if #files == 0 then
    vim.notify("No recent files found", vim.log.levels.WARN)
    return
  end

  open_picker(files, function(selected)
    vim.cmd("edit " .. vim.fn.fnameescape(selected))
  end)
end

-- Search for function definitions
function M.find_functions()
  local root = get_project_root()

  vim.ui.input({ prompt = "Function name: " }, function(query)
    if not query or query == "" then
      return
    end

    -- Pattern to match function definitions in various languages
    local patterns = {
      -- JavaScript/TypeScript: function name(), const name = function(), name: function()
      "function%s+" .. query,
      query .. "%s*[:=]%s*function",
      query .. "%s*[:=]%s*%(",
      -- Python: def name(
      "def%s+" .. query .. "%s*%(",
      -- Go: func name(
      "func%s+" .. query .. "%s*%(",
      -- Rust: fn name(
      "fn%s+" .. query .. "%s*%(",
      -- C/C++/Java: type name(
      "%s+" .. query .. "%s*%(",
      -- Class methods
      query .. "%s*%([^)]*%)%s*{",
    }

    -- Build grep command
    local has_rg = vim.fn.executable("rg") == 1
    local results = {}

    for _, pattern in ipairs(patterns) do
      local cmd
      if has_rg then
        cmd = string.format(
          "rg --line-number --no-heading --color=never -e '%s' 2>/dev/null",
          pattern:gsub("'", "'\\''")
        )
      else
        cmd = string.format(
          "grep -rn -E '%s' --exclude-dir=.git --exclude-dir=node_modules . 2>/dev/null",
          pattern:gsub("'", "'\\''")
        )
      end

      local pattern_results = vim.fn.systemlist("cd " .. vim.fn.shellescape(root) .. " && " .. cmd)
      for _, result in ipairs(pattern_results) do
        -- Avoid duplicates
        if not vim.tbl_contains(results, result) then
          table.insert(results, result)
        end
      end
    end

    if #results == 0 then
      vim.notify("No functions found matching: " .. query, vim.log.levels.WARN)
      return
    end

    -- Limit results
    if #results > 500 then
      results = vim.list_slice(results, 1, 500)
      vim.notify("Showing first 500 function definitions", vim.log.levels.INFO)
    end

    open_picker(results, function(selected)
      -- Parse the grep result: filename:line:content
      local filepath, line_num = selected:match("^([^:]+):(%d+)")

      if filepath and line_num then
        local full_path = root .. "/" .. filepath
        vim.cmd("edit " .. vim.fn.fnameescape(full_path))
        vim.api.nvim_win_set_cursor(0, { tonumber(line_num), 0 })
        vim.cmd("normal! zz") -- Center the line
      end
    end, root)
  end)
end

-- ============================================================================
-- SETUP
-- ============================================================================

function M.setup()
  -- Create user commands
  vim.api.nvim_create_user_command("FindFiles", M.find_files, {})
  vim.api.nvim_create_user_command("GrepSearch", M.grep_search, {})
  vim.api.nvim_create_user_command("FindBuffers", M.find_buffers, {})
  vim.api.nvim_create_user_command("FindRecent", M.find_recent, {})
  vim.api.nvim_create_user_command("FindFunctions", M.find_functions, {})

  -- Set up keybindings
  vim.keymap.set("n", "<leader>ff", M.find_files, { desc = "Find files" })
  vim.keymap.set("n", "<leader>fg", M.grep_search, { desc = "Grep search" })
  vim.keymap.set("n", "<leader>fb", M.find_buffers, { desc = "Find buffers" })
  vim.keymap.set("n", "<leader>fr", M.find_recent, { desc = "Find recent" })
  vim.keymap.set("n", "<leader>fn", M.find_functions, { desc = "Find functions" })

  -- Optional: Add a keymap similar to Harpoon's quick access
  -- This lets you mark files with <leader>m and jump back with <leader>h
  vim.keymap.set("n", "<leader>fh", function()
    -- Show both recent and marked files
    M.find_recent()
  end, { desc = "Harpoon-style quick files" })
end

return M
