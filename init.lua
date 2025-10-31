-- ============================================================================
-- NEOVIM CONFIG - Quality of Life Settings (No Plugins Required)
-- ============================================================================

-- Set leader key early (used for custom keybindings)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- ============================================================================
-- APPEARANCE & UI
-- ============================================================================

-- Line numbers
vim.opt.number = true                -- Show absolute line number on current line
vim.opt.relativenumber = true        -- Show relative line numbers (great for motions)

-- Cursor line
vim.opt.cursorline = true            -- Highlight the current line

-- Show column at 80 characters (coding standard)
vim.opt.colorcolumn = "80"

-- Better colors
vim.opt.termguicolors = true         -- Enable 24-bit RGB colors
vim.cmd([[colorscheme habamax]])

-- Finder styling (add after colorscheme)
vim.api.nvim_set_hl(0, "FloatBorder", { fg = "#89b4fa", bg = "NONE" })
vim.api.nvim_set_hl(0, "NormalFloat", { bg = "#1e1e2e" })
vim.api.nvim_set_hl(0, "PmenuSel", { bg = "#45475a", fg = "#cdd6f4" })

-- Show invisible characters (helpful for debugging whitespace)
vim.opt.list = true
vim.opt.listchars = {
  tab = "→ ",
  trail = "·",
  extends = "→",
  precedes = "←",
  nbsp = "␣"
}

-- Always show signcolumn (prevents text shifting when signs appear)
vim.opt.signcolumn = "yes"

-- Better command-line completion
vim.opt.wildmode = "longest:full,full"
vim.opt.wildmenu = true

-- Show matching brackets
vim.opt.showmatch = true

-- Minimal number of screen lines to keep above/below cursor
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8

-- ============================================================================
-- EDITING BEHAVIOR
-- ============================================================================

-- Indentation
vim.opt.tabstop = 4                  -- Number of spaces a tab counts for
vim.opt.shiftwidth = 4               -- Number of spaces for auto-indent
vim.opt.expandtab = true             -- Use spaces instead of tabs
vim.opt.smartindent = true           -- Smart auto-indenting on new lines
vim.opt.autoindent = true            -- Copy indent from current line when starting new line

-- Wrapping
vim.opt.wrap = false                 -- Don't wrap lines (but you can toggle this)
vim.opt.linebreak = true             -- If wrap is on, break at word boundaries

-- Search
vim.opt.ignorecase = true            -- Ignore case in search
vim.opt.smartcase = true             -- Unless uppercase is used
vim.opt.incsearch = true             -- Show search matches as you type
vim.opt.hlsearch = true              -- Highlight all search matches

-- Split behavior
vim.opt.splitright = true            -- Vertical splits go to the right
vim.opt.splitbelow = true            -- Horizontal splits go below

-- Mouse support (yes, it's useful!)
vim.opt.mouse = "a"

-- Clipboard integration with system
vim.opt.clipboard = "unnamedplus"    -- Use system clipboard

-- Better completion experience
vim.opt.completeopt = "menu,menuone,noselect"

-- Persistent undo (undo even after closing file)
vim.opt.undofile = true
vim.opt.undolevels = 10000

-- Faster updates (better experience for autocompletion, git signs, etc)
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300

-- Don't show mode in command line (it's in statusline usually)
vim.opt.showmode = false

-- Enable folding (but start with everything unfolded)
vim.opt.foldmethod = "indent"
vim.opt.foldlevel = 99

-- Case-insensitive filename completion
vim.opt.fileignorecase = true
vim.opt.wildignorecase = true

-- ============================================================================
-- BACKUPS & FILES
-- ============================================================================

vim.opt.backup = false               -- Don't create backup files
vim.opt.writebackup = false          -- Don't backup before overwriting
vim.opt.swapfile = false             -- Don't use swap files (with undofile, not needed)

-- ============================================================================
-- KEYMAPS - Essential Productivity Boosters
-- ============================================================================

local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Better escape (jk or kj to exit insert mode - much faster than reaching for Esc)
keymap("i", "jk", "<Esc>", opts)
keymap("i", "kj", "<Esc>", opts)

-- Clear search highlighting with Esc in normal mode
keymap("n", "<Esc>", ":noh<CR>", opts)

-- Better window navigation (Ctrl+h/j/k/l to move between splits)
keymap("n", "<C-h>", "<C-w>h", opts)
keymap("n", "<C-j>", "<C-w>j", opts)
keymap("n", "<C-k>", "<C-w>k", opts)
keymap("n", "<C-l>", "<C-w>l", opts)

-- Resize windows with arrows
keymap("n", "<C-Up>", ":resize +2<CR>", opts)
keymap("n", "<C-Down>", ":resize -2<CR>", opts)
keymap("n", "<C-Left>", ":vertical resize -2<CR>", opts)
keymap("n", "<C-Right>", ":vertical resize +2<CR>", opts)

-- Buffer navigation
keymap("n", "<S-l>", ":bnext<CR>", opts)     -- Shift+L for next buffer
keymap("n", "<S-h>", ":bprevious<CR>", opts) -- Shift+H for previous buffer

-- Stay in indent mode (keep selection when indenting in visual mode)
keymap("v", "<", "<gv", opts)
keymap("v", ">", ">gv", opts)

-- Move text up and down in visual mode
keymap("v", "J", ":m '>+1<CR>gv=gv", opts)
keymap("v", "K", ":m '<-2<CR>gv=gv", opts)

-- Better paste (don't yank when pasting over selection)
keymap("v", "p", '"_dP', opts)

-- Keep cursor centered when scrolling or searching
keymap("n", "<C-d>", "<C-d>zz", opts)
keymap("n", "<C-u>", "<C-u>zz", opts)
keymap("n", "n", "nzzzv", opts)
keymap("n", "N", "Nzzzv", opts)

-- Quick save
keymap("n", "<leader>w", ":w<CR>", opts)

-- Quick quit
keymap("n", "<leader>q", ":q<CR>", opts)

-- Split windows easily
keymap("n", "<leader>sv", ":vsplit<CR>", opts)  -- Split vertically
keymap("n", "<leader>sh", ":split<CR>", opts)   -- Split horizontally
keymap("n", "<leader>sc", ":close<CR>", opts)   -- Close current split

-- Toggle line wrapping
keymap("n", "<leader>tw", ":set wrap!<CR>", opts)

-- Toggle relative line numbers
keymap("n", "<leader>tn", ":set relativenumber!<CR>", opts)

-- Quick access to config file
keymap("n", "<leader>ce", ":e $MYVIMRC<CR>", opts)
keymap("n", "<leader>cr", ":source $MYVIMRC<CR>", opts)

-- Select all
keymap("n", "<C-a>", "ggVG", opts)

-- Better line join (keep cursor in place)
keymap("n", "J", "mzJ`z", opts)

-- ============================================================================
-- AUTO COMMANDS - Automatic behaviors
-- ============================================================================

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Highlight on yank (briefly flash yanked text)
augroup("YankHighlight", { clear = true })
autocmd("TextYankPost", {
  group = "YankHighlight",
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
  end,
})

-- Remove trailing whitespace on save
augroup("TrimWhitespace", { clear = true })
autocmd("BufWritePre", {
  group = "TrimWhitespace",
  pattern = "*",
  command = [[%s/\s\+$//e]],
})

-- Restore cursor position when opening files
augroup("RestoreCursor", { clear = true })
autocmd("BufReadPost", {
  group = "RestoreCursor",
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Close certain filetypes with 'q'
augroup("QuickClose", { clear = true })
autocmd("FileType", {
  group = "QuickClose",
  pattern = { "help", "man", "qf", "lspinfo" },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", ":close<CR>", { buffer = event.buf, silent = true })
  end,
})

-- Auto-create directories when saving files
augroup("AutoCreateDir", { clear = true })
autocmd("BufWritePre", {
  group = "AutoCreateDir",
  callback = function(event)
    local file = vim.loop.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})

-- ============================================================================
-- LANGUAGE-SPECIFIC SETTINGS
-- ============================================================================

-- Python
augroup("PythonSettings", { clear = true })
autocmd("FileType", {
  group = "PythonSettings",
  pattern = "python",
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.expandtab = true
  end,
})

-- JavaScript/TypeScript/JSON
augroup("JSSettings", { clear = true })
autocmd("FileType", {
  group = "JSSettings",
  pattern = { "javascript", "typescript", "json", "jsonc", "jsx", "tsx" },
  callback = function()
    vim.opt_local.tabstop = 2
    vim.opt_local.shiftwidth = 2
    vim.opt_local.expandtab = true
  end,
})

-- HTML/CSS
augroup("WebSettings", { clear = true })
autocmd("FileType", {
  group = "WebSettings",
  pattern = { "html", "css", "scss", "sass" },
  callback = function()
    vim.opt_local.tabstop = 2
    vim.opt_local.shiftwidth = 2
    vim.opt_local.expandtab = true
  end,
})

-- YAML
augroup("YAMLSettings", { clear = true })
autocmd("FileType", {
  group = "YAMLSettings",
  pattern = "yaml",
  callback = function()
    vim.opt_local.tabstop = 2
    vim.opt_local.shiftwidth = 2
    vim.opt_local.expandtab = true
  end,
})

-- ============================================================================
-- HELPFUL COMMANDS
-- ============================================================================

-- Create a command to show the highlight group under cursor (useful for theming)
vim.api.nvim_create_user_command("HiTest", function()
  local result = vim.treesitter.get_captures_at_cursor(0)
  print(vim.inspect(result))
end, {})

-- ============================================================================
-- NOTES & TIPS
-- ============================================================================

--[[

KEY BINDINGS CHEAT SHEET:
=========================

LEADER KEY: <Space>

File Operations:
  <leader>w         - Save file
  <leader>q         - Quit
  <leader>ce        - Edit this config
  <leader>cr        - Reload config

Window Management:
  <C-h/j/k/l>       - Navigate between splits
  <C-arrows>        - Resize splits
  <leader>sv        - Split vertically
  <leader>sh        - Split horizontally
  <leader>sc        - Close split

Buffer Navigation:
  <S-h>             - Previous buffer
  <S-l>             - Next buffer

Insert Mode:
  jk or kj          - Exit insert mode (faster than Esc!)

Visual Mode:
  < and >           - Indent and stay in visual mode
  J and K           - Move selected lines up/down
  p                 - Paste without yanking replaced text

Normal Mode:
  <Esc>             - Clear search highlighting
  <C-d/u>           - Half-page scroll (centered)
  n/N               - Next/previous search (centered)
  J                 - Join lines (cursor stays in place)
  <C-a>             - Select all

Toggles:
  <leader>tw        - Toggle line wrap
  <leader>tn        - Toggle relative numbers

BUILT-IN NEOVIM FEATURES TO REMEMBER:
======================================

1. Text Objects:
   - ciw  - Change inner word
   - ci"  - Change inside quotes
   - ca{  - Change around braces
   - dap  - Delete around paragraph
   - yip  - Yank inside paragraph

2. Marks:
   - ma   - Set mark 'a'
   - 'a   - Jump to mark 'a'
   - ''   - Jump back to previous position

3. Macros:
   - qa   - Start recording macro in register 'a'
   - q    - Stop recording
   - @a   - Play macro 'a'
   - @@   - Replay last macro

4. Registers:
   - "ayy - Yank line into register 'a'
   - "ap  - Paste from register 'a'
   - :reg - Show all registers

5. Command Mode:
   - :!<cmd>        - Run shell command
   - :%s/old/new/g  - Replace all in file
   - :sort          - Sort selected lines
   - :term          - Open terminal

6. Visual Block Mode (Ctrl+V):
   - Great for column editing
   - I/A for insert at start/end of selection

--]]

-- Plugins I make
require("plugins.finder").setup()
require("plugins.statusline").setup()
require("plugins.autopairs").setup()
require("plugins.todos").setup()
require("plugins.usages").setup()
