-- Autocommands translated from the surviving rules of the reference
-- (docs/referencia/nvim-vim-bootstrap-init.vim, "Autocmd Rules" plus the
-- per-language indentation block).
--
-- Every rule uses nvim_create_autocmd, so the reference's `augroup X` /
-- `autocmd!` / `augroup END` triple collapses into the group name passed to
-- nvim_create_augroup -- which already clears the group on creation.
--
-- The reference's `augroup go` block mixed two different things: buffer-local
-- indentation and a pile of <Plug> mappings. The mappings moved to the nvim-go
-- spec in lua/plugins/lang.lua, because lazy.nvim has to know about them;
-- only the indentation stayed here.

-- Keeps the reference's group names so this file stays auditable against it.
local function group(name)
  return vim.api.nvim_create_augroup("vimrc-" .. name, { clear = true })
end

-- Keep syntax generation bounded when jumping into a long buffer: without
-- this, Vim only parses the screen-sized window and highlighting looks wrong
-- until the buffer is re-read.
vim.api.nvim_create_autocmd("BufEnter", {
  group = group("sync-fromstart"),
  callback = function()
    vim.cmd("syntax sync maxlines=200")
  end,
})

-- Restore the cursor to where it was when the buffer was last left.
vim.api.nvim_create_autocmd("BufReadPost", {
  group = group("remember-cursor-position"),
  callback = function()
    local line = vim.fn.line([['"]])
    if line > 1 and line <= vim.fn.line("$") then
      vim.cmd([[normal! g`"]])
    end
  end,
})

-- Plain text wraps at 79 columns.
--
-- The reference used a bare `set` inside a BufRead/BufNewFile autocommand,
-- which leaked the window-local override into the global options. setlocal is
-- the behaviour that was actually being asked for.
local function setup_wrapping()
  vim.opt_local.wrap = true
  vim.opt_local.wm = 2
  vim.opt_local.textwidth = 79
end

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  group = group("wrapping"),
  pattern = "*.txt",
  callback = setup_wrapping,
})

-- Makefiles are whitespace-sensitive, and CMake has no reliable filetype
-- detection from the extension.
vim.api.nvim_create_autocmd("FileType", {
  group = group("make-cmake"),
  pattern = "make",
  callback = function()
    vim.opt_local.expandtab = false
  end,
})

vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
  group = group("make-cmake"),
  pattern = "CMakeLists.txt",
  callback = function()
    vim.bo.filetype = "cmake"
  end,
})

-- Do not let the terminal's own scrolling fight with the surrounding window.
vim.api.nvim_create_autocmd("TermEnter", {
  group = group("terminal-scrolloff"),
  callback = function()
    vim.opt_local.scrolloff = 0
  end,
})

vim.api.nvim_create_autocmd("TermLeave", {
  group = group("terminal-scrolloff"),
  callback = function()
    vim.opt_local.scrolloff = 3
  end,
})

-- The bell is configured at startup, but a GUI started after that needs it
-- again.
local function enable_visualbell()
  vim.opt.visualbell = true
  vim.cmd("set t_vb=")
end

vim.api.nvim_create_autocmd("GUIEnter", {
  group = group("visualbell"),
  callback = enable_visualbell,
})

-- Close the completion preview window once a completion run ends, so it does
-- not sit on top of the buffer.
--
-- The reference guarded this with `v:version > 703 || ... patch598`, which is
-- dead weight on 0.12, and then with `&completeopt =~ 'preview'`. Neither
-- tests what the rule is actually for: whether the window we are returning
-- from is a preview popup. win_gettype is the direct way to ask that.
vim.api.nvim_create_autocmd("CompleteDone", {
  group = group("completion-preview-close"),
  callback = function()
    if vim.fn.win_gettype(vim.fn.winnr("#")) == "popup" then
      vim.cmd("pclose")
    end
  end,
})

-- Per-language indentation, verbatim from the reference. These filetypes are
-- the ones the reference already declared, so nothing new is being introduced
-- here; the language *set* is still an open decision (T5).
local indent_group = group("filetype-indent")

-- go: hard tabs, but 4-wide for the soft case so gofmt stays happy.
vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
  group = indent_group,
  pattern = "*.go",
  callback = function()
    vim.opt_local.expandtab = false
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.softtabstop = 4
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = indent_group,
  pattern = "html",
  callback = function()
    vim.opt_local.tabstop = 2
    vim.opt_local.shiftwidth = 2
    vim.opt_local.expandtab = true
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = indent_group,
  pattern = "javascript",
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.softtabstop = 4
    vim.opt_local.expandtab = true
  end,
})

-- The reference also set g:javascript_enable_domhtmlcss there. That was
-- syntax highlighting, and syntax now comes from treesitter (T5), so only the
-- indentation is kept.
vim.api.nvim_create_autocmd("FileType", {
  group = indent_group,
  pattern = "python",
  callback = function()
    vim.opt_local.expandtab = true
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 8
    vim.opt_local.colorcolumn = "79"
    -- croq: comments, trailing whitespace-only lines omitted, return removes
    --       indent, right-aligns the line, joins with a space
    vim.opt_local.formatoptions:append("croq")
    vim.opt_local.softtabstop = 4
    vim.opt_local.cinwords = "if,elif,else,for,while,try,except,finally,def,class,with"
  end,
})
