-- ============================================================================
-- TODO TRACKER - Find and manage TODO comments in your project
-- ============================================================================
--
-- Features:
-- 1. Uses the custom finder UI (same as file finder)
-- 2. Fuzzy search through TODO comments
-- 3. Search by keyword (TODO, FIXME) or content (object pooling)
-- 4. Respects .gitignore (uses git ls-files)
-- 5. Custom ignore patterns via .nvimignore file
-- 6. Highlights TODO comments in code
--
-- Usage:
--   <leader>ft  - Find all TODOs in project
--   <leader>fT  - Find TODOs in current file
--
-- Search examples:
--   "todo"           -> Shows only TODO items
--   "fixme"          -> Shows only FIXME items
--   "object pooling" -> Shows TODOs containing "object pooling"
--   "pooling"        -> Shows TODOs containing "pooling"
-- ============================================================================

local M = {}

-- ============================================================================
-- CONFIGURABLE TODO TYPES
-- ============================================================================

-- Add or remove TODO types here
local TODO_TYPES = {
  { keyword = "TODO", color = "#f38ba8" },
  { keyword = "FIXME", color = "#fab387" },
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Default ignore patterns (in addition to .gitignore and .nvimignore)
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

-- Check if file should be excluded
local function should_exclude(filepath, custom_patterns)
  for _, pattern in ipairs(DEFAULT_IGNORES) do
    if filepath:match(pattern) then
      return true
    end
  end

  for _, pattern in ipairs(custom_patterns) do
    local lua_pattern = pattern:gsub("%*", ".*"):gsub("?", ".")
    if filepath:match(lua_pattern) then
      return true
    end
  end

  return false
end

-- Get all files in project (respecting .gitignore)
local function get_project_files(root)
  local cmd
  local is_git = vim.fn.isdirectory(root .. "/.git") == 1

  if is_git then
    cmd = "git ls-files"
  else
    cmd = "find . -type f -not -path '*/\\.git/*' -not -path '*/node_modules/*' -not -path '*/__pycache__/*'"
  end

  local all_files = vim.fn.systemlist("cd " .. vim.fn.shellescape(root) .. " && " .. cmd)
  local custom_patterns = read_nvimignore(root)

  local files = {}
  for _, file in ipairs(all_files) do
    if not should_exclude(file, custom_patterns) then
      table.insert(files, file)
    end
  end

  return files
end

-- Parse TODO comments from a file
local function parse_todos_from_file(filepath, root)
  local full_path = root .. "/" .. filepath

  if vim.fn.filereadable(full_path) == 0 then
    return {}
  end

  local todos = {}
  local lines = vim.fn.readfile(full_path)

  -- Build patterns from TODO_TYPES
  for _, todo_type in ipairs(TODO_TYPES) do
    local keyword = todo_type.keyword
    local pattern = keyword .. ":?%s*(.+)$"

    for line_num, line in ipairs(lines) do
      local todo_text = line:match(pattern)

      if todo_text then
        todo_text = todo_text:match("^%s*(.-)%s*$")
        todo_text = todo_text:gsub("%s*%*/$", ""):gsub("%s*%-%->%s*$", "")

        table.insert(todos, {
          file = filepath,
          line = line_num,
          keyword = keyword,
          text = todo_text,
          full_line = line,
        })
      end
    end
  end

  return todos
end

-- ============================================================================
-- TODO COLLECTION
-- ============================================================================

-- Scan project for all TODOs
local function scan_todos()
  local root = get_project_root()
  local files = get_project_files(root)

  vim.notify("Scanning " .. #files .. " files for TODOs...", vim.log.levels.INFO)

  local all_todos = {}
  local file_count = 0

  for _, file in ipairs(files) do
    local todos = parse_todos_from_file(file, root)
    if #todos > 0 then
      file_count = file_count + 1
      for _, todo in ipairs(todos) do
        table.insert(all_todos, todo)
      end
    end
  end

  vim.notify(
    string.format("Found %d TODOs in %d files", #all_todos, file_count),
    vim.log.levels.INFO
  )

  return all_todos, root
end

-- ============================================================================
-- FINDER INTEGRATION (uses the custom picker from finder.lua)
-- ============================================================================

local picker_state = {
  items = {},
  todos = {},
  filtered_items = {},
  selected_idx = 1,
  query = "",
  buf = nil,
  win = nil,
  prompt_buf = nil,
  prompt_win = nil,
  root = nil,
}

-- Format TODO for display
local function format_todo(todo)
  return string.format(
    "[%s] %s:%d - %s",
    todo.keyword,
    todo.file,
    todo.line,
    todo.text
  )
end

-- Fuzzy match scoring
local function fuzzy_match(str, pattern)
  if pattern == "" then
    return true, 0
  end

  str = str:lower()
  pattern = pattern:lower()

  -- Exact match gets highest score
  if str:find(pattern, 1, true) then
    return true, 2000
  end

  -- Fuzzy match: all chars must appear in order
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

-- Filter TODOs by fuzzy match
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
  vim.api.nvim_buf_set_option(buf, "filetype", "todofinder")

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

  -- Scroll to selection
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

  -- Find the corresponding TODO
  for _, todo in ipairs(picker_state.todos) do
    if format_todo(todo) == selected then
      local full_path = picker_state.root .. "/" .. todo.file
      vim.cmd("edit " .. vim.fn.fnameescape(full_path))
      vim.api.nvim_win_set_cursor(0, { todo.line, 0 })
      vim.cmd("normal! zz")
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
  query = query:gsub("^🔍 ", "")

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

-- Open the picker with TODOs
local function open_todo_picker(todos, root)
  if #todos == 0 then
    vim.notify("No TODOs found in project", vim.log.levels.WARN)
    return
  end

  -- Format todos for display
  local items = {}
  for _, todo in ipairs(todos) do
    table.insert(items, format_todo(todo))
  end

  picker_state.items = items
  picker_state.todos = todos
  picker_state.filtered_items = items
  picker_state.selected_idx = 1
  picker_state.query = ""
  picker_state.root = root

  picker_state.buf, picker_state.win, picker_state.prompt_buf, picker_state.prompt_win =
    create_picker_window()

  setup_picker_keymaps()
  update_results()

  vim.cmd("startinsert")
end

-- ============================================================================
-- SYNTAX HIGHLIGHTING
-- ============================================================================

-- Setup TODO highlighting
local function setup_highlighting()
  local augroup = vim.api.nvim_create_augroup("TodoHighlight", { clear = true })

  -- Set highlight groups for each TODO type
  for _, todo_type in ipairs(TODO_TYPES) do
    local hl_name = todo_type.keyword .. "Keyword"
    vim.api.nvim_set_hl(0, hl_name, { fg = todo_type.color, bold = true })
  end

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "WinEnter" }, {
    group = augroup,
    callback = function()
      local ft = vim.bo.filetype
      if ft == "" or ft == "help" or ft == "man" then
        return
      end

      for _, todo_type in ipairs(TODO_TYPES) do
        local keyword = todo_type.keyword
        local hl_name = keyword .. "Keyword"
        vim.fn.matchadd(hl_name, "\\<" .. keyword .. ":")
      end
    end,
  })
end

-- ============================================================================
-- PUBLIC FUNCTIONS
-- ============================================================================

-- Show all TODOs in project
function M.show_todos()
  local todos, root = scan_todos()
  open_todo_picker(todos, root)
end

-- Show TODOs in current file only
function M.show_todos_current_file()
  local root = get_project_root()
  local filepath = vim.fn.expand("%:.")

  if filepath == "" then
    vim.notify("No file open", vim.log.levels.WARN)
    return
  end

  local todos = parse_todos_from_file(filepath, root)

  if #todos == 0 then
    vim.notify("No TODOs found in current file", vim.log.levels.INFO)
    return
  end

  open_todo_picker(todos, root)
end

-- Create a .nvimignore file
function M.create_nvimignore()
  local root = get_project_root()
  local ignore_file = root .. "/.nvimignore"

  if vim.fn.filereadable(ignore_file) == 1 then
    vim.notify(".nvimignore already exists", vim.log.levels.WARN)
    vim.cmd("edit " .. ignore_file)
    return
  end

  local default_content = [[# .nvimignore - Custom patterns to exclude from TODO search
# (In addition to .gitignore and built-in patterns)
#
# Examples:
# *.min.js              - Exclude minified JS
# vendor/               - Exclude vendor directory
# wp-content/plugins/*  - Exclude WordPress plugins

# Add your patterns below:
]]

  vim.fn.writefile(vim.split(default_content, "\n"), ignore_file)
  vim.notify("Created .nvimignore at project root", vim.log.levels.INFO)
  vim.cmd("edit " .. ignore_file)
end

-- ============================================================================
-- SETUP
-- ============================================================================

function M.setup()
  setup_highlighting()

  vim.api.nvim_create_user_command("Todos", M.show_todos, { desc = "Show all TODOs" })
  vim.api.nvim_create_user_command("TodosCurrent", M.show_todos_current_file, { desc = "Show TODOs in current file" })
  vim.api.nvim_create_user_command("TodosIgnore", M.create_nvimignore, { desc = "Create .nvimignore file" })

  vim.keymap.set("n", "<leader>ft", M.show_todos, { desc = "Find TODOs" })
  vim.keymap.set("n", "<leader>fT", M.show_todos_current_file, { desc = "Find TODOs (current file)" })
end

return M
