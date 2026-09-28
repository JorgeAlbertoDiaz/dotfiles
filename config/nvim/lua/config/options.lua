-- Base options, translated to the Lua option API from the directives that
-- survive the 45 -> 16 verdict in odd/tasks/nvim-nativo.md.
--
-- Source of truth for intent: docs/referencia/nvim-vim-bootstrap-init.vim,
-- sections "Base setup" and "Visual Settings". Nothing here comes from a
-- discarded plugin: the replacements own their configuration in lua/plugins/.
--
-- Two deliberate deviations from the reference, both verified on 0.12.5:
--
--   * 'title' is only enabled for a real GUI. The reference set it
--     unconditionally, which in a terminal editor hijacks the shell's own
--     window title. 'titleold' and 'titlestring' are kept as-is; they are
--     only consulted while 'title' is on.
--   * The reference set `syntax on`. Neovim enables syntax from its filetype
--     autocommands instead -- `:set syntax?` reports an empty value at
--     startup, yet `&syntax` is already "go" in an opened .go buffer -- so
--     there is nothing to set.

local opt = vim.opt

-- Encoding.
--
-- 'fileencoding' is a global-local option: assigning it through vim.opt sets
-- the value on the current buffer and marks it modified, so a fresh unnamed
-- buffer would refuse to close with E37. opt_global sets the default for new
-- buffers instead, which is what a vimrc-level `set` did.
vim.opt.encoding = "utf-8"
vim.opt_global.fileencoding = "utf-8"
vim.opt.fileencodings = "utf-8"

-- Editing
opt.backspace = { "indent", "eol", "start" }
opt.tabstop = 4
opt.softtabstop = 0
opt.shiftwidth = 4
opt.expandtab = true

-- Leader. init.lua sets this too, and earlier: the plugin specs are written
-- against it, so it has to be resolved before lazy.nvim reads them.
vim.g.mapleader = ","

opt.hidden = true

-- Search
opt.hlsearch = true
opt.incsearch = true
opt.ignorecase = true
opt.smartcase = true

-- Files
opt.fileformats = { "unix", "dos", "mac" }
opt.autoread = true

-- Shell, matching the reference's `if exists('$SHELL')` fallback.
local shell = vim.env.SHELL
opt.shell = (shell ~= nil and shell ~= "") and shell or "/bin/sh"

-- Display
opt.ruler = true
opt.number = true
opt.background = "dark"
opt.wildmenu = true
opt.laststatus = 2

-- Mouse
opt.mouse = "a"
opt.mousemodel = "popup"

-- Terminal capability and bells.
--
-- 't_Co', 't_vb' and friends are terminal code options: Neovim 0.12 refuses
-- them through the Lua API ("Unknown option 't_Co'"), so they go through
-- ':set' like the reference did.
vim.cmd("set t_Co=256")
opt.errorbells = false
opt.visualbell = true
vim.cmd("set t_vb=")

-- GUI-only options. Setting 'guifont' from a terminal session is a no-op at
-- best and a warning at worst, so both are gated on an actual GUI.
if vim.fn.has("gui_running") == 1 then
  opt.guifont = "Monospace 10"
  opt.title = true
end
opt.titleold = "Terminal"
opt.titlestring = "%F"

-- Modelines
opt.modeline = true
opt.modelines = 10

-- Indent guide, replacing the discarded indentLine.
--
-- VERIFIED on 0.12.5: `set fillchars+=vert:┆` is accepted, while the
-- equivalent `set listchars+=vert:┆` fails with E474. The guide therefore
-- lives in 'fillchars', never in 'listchars'. 'fillchars' is empty by default
-- in this version, so appending loses no default.
opt.fillchars:append("vert:┆")

-- Clipboard. 'unnamedplus' only exists where the +clipboard provider does;
-- asking for it unconditionally breaks the option on builds without one.
if vim.fn.has("unnamedplus") == 1 then
  opt.clipboard = { "unnamed", "unnamedplus" }
end

-- Command-line completion. The patterns come from the reference's fzf block,
-- which is where the original file kept them.
opt.wildmode = { "list:longest", "list:full" }
opt.wildignore = {
  "*/tmp/*",
  "*.so",
  "*.swp",
  "*.zip",
  "*.pyc",
  "*.db",
  "*.sqlite",
  "*.o",
  "*.obj",
  "*.rbc",
  "__pycache__",
  ".git",
  -- The reference's fzf default command pruned these three by path; keeping
  -- them out of 'wildignore' carries the same intent to every wildcard
  -- completion, not just to a fuzzy finder.
  "*node_modules*",
  "*target*",
  "*dist*",
}
