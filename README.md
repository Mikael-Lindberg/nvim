# My Neovim Config

A lightweight, fast Neovim configuration with a custom fuzzy finder that combines file and function search in one interface.

## Features

### 🔍 Smart Unified Finder
- **One keybind for everything**: `<Space>ff`
- Search files by name with intelligent path matching
- Automatically searches for functions when you type CamelCase or snake_case
- Filters out junk files (SVGs, lock files, minified files)
- Git-aware (respects `.gitignore`)

### ⚡ Quality of Life Improvements
- Relative line numbers for fast motions
- `jk` or `kj` to exit insert mode
- Smart indentation per language
- Persistent undo history
- System clipboard integration
- Auto-trim trailing whitespace
- Cursor position memory across sessions

### 🎨 Sensible Defaults
- 80-character column guide
- Visible whitespace characters
- Fast window/buffer navigation
- Centered scrolling
- No swap files (persistent undo instead)

## Installation

```bash
# Backup your existing config
mv ~/.config/nvim ~/.config/nvim.backup

# Clone this repo
git clone <your-repo-url> ~/.config/nvim

# Open Neovim
nvim
```

That's it! No plugins to install, everything works out of the box.

## Usage

### The Universal Finder

Press **`<Space>ff`** and start typing:

**Finding Files:**
```
Type: Door
Result: Door.js, DoorManager.tsx, src/entities/Door.py

Type: src app
Result: src/app/layout.tsx, src/app/page.tsx (path-aware!)

Type: comp button
Result: src/components/Button.tsx (matches folder structure)
```

**Finding Functions:**
```
Type: ActivateDoor
Result:
  src/Door.js
  [fn] src/game.js:45: function ActivateDoor(id) {
  [fn] src/Door.tsx:20: const ActivateDoor = () => {
  [fn] src/api.py:89: def ActivateDoor(door_id):
```

Function results are marked with `[fn]` and show the exact line.

### Other Finders

| Key | Action |
|-----|--------|
| `<Space>fg` | Grep search (search text in all files) |
| `<Space>fb` | Find in open buffers |
| `<Space>fr` | Find recent files |

### Essential Keybindings

#### File Operations
| Key | Action |
|-----|--------|
| `<Space>w` | Save file |
| `<Space>q` | Quit |
| `<Space>ce` | Edit config |
| `<Space>cr` | Reload config |

#### Navigation
| Key | Action |
|-----|--------|
| `jk` or `kj` | Exit insert mode (much faster!) |
| `Ctrl+h/j/k/l` | Navigate between splits |
| `Shift+h/l` | Previous/next buffer |
| `Ctrl+d/u` | Half-page scroll (centered) |

#### Window Management
| Key | Action |
|-----|--------|
| `<Space>sv` | Split vertically |
| `<Space>sh` | Split horizontally |
| `<Space>sc` | Close current split |
| `Ctrl+arrows` | Resize splits |

#### Visual Mode
| Key | Action |
|-----|--------|
| `<` and `>` | Indent (stays in visual mode) |
| `J` and `K` | Move selected lines up/down |
| `p` | Paste without yanking replaced text |

#### Search
| Key | Action |
|-----|--------|
| `/` | Search |
| `n` / `N` | Next/previous match (centered) |
| `Esc` | Clear search highlighting |

## Customization

### Change Excluded Files

Edit `lua/plugins/finder.lua` and modify the `EXCLUDED_PATTERNS` array:

```lua
local EXCLUDED_PATTERNS = {
  "%.svg$",
  "%.png$",
  "package%-lock%.json$",
  "dist/",

  -- Add your own:
  "%.test%.js$",     -- Exclude test files
  "migrations/",     -- Exclude migrations
}
```

### Change Keybindings

Edit `init.lua` and modify the keymap section:

```lua
-- Change leader key (default: Space)
vim.g.mapleader = ","

-- Change any keybinding
vim.keymap.set("n", "<leader>w", ":w<CR>", opts)
```

### Language-Specific Settings

The config automatically sets proper indentation for:
- Python: 4 spaces
- JavaScript/TypeScript/JSON: 2 spaces
- HTML/CSS: 2 spaces
- YAML: 2 spaces

Add your own in the "LANGUAGE-SPECIFIC SETTINGS" section of `init.lua`.

## How It Works

### The Finder

The custom finder (`lua/plugins/finder.lua`) is a pure Lua implementation with:

1. **Fuzzy matching** - Type partial matches, find files instantly
2. **Smart path scoring** - `src app` prioritizes `src/app/` paths
3. **Dynamic function search** - Detects CamelCase queries and searches code
4. **Git integration** - Uses `git ls-files` for speed
5. **Zero dependencies** - No external plugins required

### Smart Path Matching

The finder converts spaces to path separators:
- `src app api` → matches `src/app/api/route.ts`
- Bonus points for path separator matches
- Bonus points for consecutive character matches

### Function Detection

When you type something that looks like a function name (CamelCase, snake_case, 3+ characters), the finder automatically searches for:
- JavaScript/TypeScript: `function name()`, `const name = ()`, etc.
- Python: `def name(`
- Go: `func name(`
- Rust: `fn name(`
- C/C++/Java: `type name(`

Results are prefixed with `[fn]` and show the exact line where the function is defined.

## File Structure

```
~/.config/nvim/
├── init.lua                    # Main config (settings, keybindings)
└── lua/
    └── plugins/
        └── finder.lua          # Custom fuzzy finder
```

## Requirements

- Neovim 0.8 or higher
- Git (optional, but recommended for better performance)
- `ripgrep` (optional, for faster grep search)

### Install ripgrep (optional)

```bash
# Ubuntu/Debian
sudo apt install ripgrep

# macOS
brew install ripgrep

# Arch
sudo pacman -S ripgrep
```

## Tips & Tricks

1. **Use the finder for everything** - It's faster than a file tree
2. **Type paths with spaces** - `src app components` is natural
3. **Function names work instantly** - Just start typing CamelCase
4. **Combine approaches**:
   - Know the file? `<Space>ff` + filename
   - Know the function? `<Space>ff` + function name
   - Know the text? `<Space>fg` + search term

5. **Learn vim motions**:
   - `ciw` - Change inner word
   - `dap` - Delete around paragraph
   - `vi{` - Visual select inside braces
   - `*` - Search for word under cursor

6. **Use marks for quick jumps**:
   - `ma` - Set mark 'a'
   - `'a` - Jump to mark 'a'

## Philosophy

This config prioritizes:
- **Speed** - Everything is instant, no plugin managers or lazy loading
- **Simplicity** - ~800 lines total, easy to understand and modify
- **Productivity** - Optimized for real coding workflows
- **No bloat** - Only what you actually need

## Troubleshooting

**Finder not working?**
- Make sure `lua/plugins/finder.lua` exists
- Try `:source $MYVIMRC` to reload

**Function search not finding anything?**
- Install `ripgrep` for better results
- Make sure your query is 3+ characters
- Try exact function names (case-sensitive)

**Files not excluded?**
- Check the patterns in `EXCLUDED_PATTERNS`
- Lua patterns use `%` instead of `\` for escaping

**Colors look weird?**
- Try different colorschemes: `:colorscheme habamax`
- Add to init.lua: `vim.cmd([[colorscheme slate]])`

## Contributing

Feel free to modify and adapt this config to your needs! If you add cool features, consider sharing them.

## License

Free to use, modify, and distribute. No attribution required.

---

**Made with ❤️ and Neovim**

Built to be fast, simple, and actually useful for daily coding.
