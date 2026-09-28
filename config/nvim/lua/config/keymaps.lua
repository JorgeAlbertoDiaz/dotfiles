-- T6: the global keymaps, in one place.
--
-- Why a dedicated file at all, when most mappings are still declared next to
-- the plugin that provides them (telescope owns <leader>e, neo-tree owns F2/F3,
-- mini.comment owns gc)? Because everything below is either native to Neovim or
-- belongs to no plugin: the moment a mapping is a plugin's business, it goes in
-- that plugin's spec and NOT here. That is the rule this file exists to state.
--
-- Source of truth for intent: docs/referencia/nvim-vim-bootstrap-init.vim,
-- sections "Mappings". Every mapping below is either a direct translation of a
-- reference mapping or a documented decision; the reasoning is inline.

---Map a table of normal-mode keys in one call.
---@param tbl table<string, string|function>
---@param opts table|nil
local function map(tbl, opts)
  for lhs, rhs in pairs(tbl) do
    vim.keymap.set("n", lhs, rhs, opts)
  end
end

-- Windows. The reference used ':<C-u>split<CR>' and ':<C-u>vsplit<CR>'; the
-- <C-w>s / <C-w>v equivalents are the same motion without the round trip
-- through a command line, and they keep the count and registers working.
-- <leader>h and <leader>v are free: the leader-prefixed keys already in use are
-- telescope's b/e, fzf-lua's y, fugitive's g*, neo-tree's F2/F3 and lazy.nvim's
-- own (none, in 11.x).
map({
  ["<C-j>"] = "<C-w>j",
  ["<C-k>"] = "<C-w>k",
  ["<C-h>"] = "<C-w>h",
  ["<C-l>"] = "<C-w>l",
  ["<leader>h"] = "<C-w>s",
  ["<leader>v"] = "<C-w>v",
})

-- Buffers. z/q and x/w are the reference's own pairs, and the aliases are kept
-- because muscle memory does not read the reference.
--
-- <leader>c and <leader>w do not collide with fugitive's <leader>gc: with
-- mapleader = "," those are ",c" and ",w", not ",gc" and ",wc".
map({
  ["<leader>z"] = "<cmd>bp<cr>",
  ["<leader>q"] = "<cmd>bp<cr>",
  ["<leader>x"] = "<cmd>bn<cr>",
  ["<leader>w"] = "<cmd>bn<cr>",
  ["<leader>c"] = "<cmd>bd<cr>",
})

-- Tabs. Normal mode only, so <Tab> in insert mode still inserts a tab. <Tab> and
-- <S-Tab> move between tabs (the reference's gt / gT); <S-t> opens a new tab.
map({
  ["<Tab>"] = "gt",
  ["<S-Tab>"] = "gT",
  ["<S-t>"] = "<cmd>tabnew<cr>",
})

-- The reference's 'lcd %:p:h': the working directory follows the file.
map({ ["<leader>."] = "<cmd>lcd %:p:h<cr>" })

-- Whole-file reindent. Guarded: without a real indent provider (indentexpr,
-- cindent, lisp or equalprg) '=' would fall back to 'autoindent' and just copy
-- the previous line, which is what breaks prose filetypes, so it refuses and says
-- why. With tree-sitter indentation enabled (lua/plugins/lang.lua) this is the
-- normal case. Native >>/<< and the visual </> cover the block cases.
map({
  ["<leader>="] = function()
    if vim.bo.indentexpr == "" and not vim.bo.cindent and not vim.bo.lisp and vim.bo.equalprg == "" then
      vim.notify(
        ("Sin indentador para '%s'; no se reindenta"):format(vim.bo.filetype),
        vim.log.levels.WARN
      )
      return
    end
    vim.cmd("keepjumps normal! gg=G")
  end,
}, { desc = "Reindent the whole file", silent = true })

-- Search. The zzv / zzzv variants are the reference's, and they are the reason
-- 'hlsearch' is worth having: without them the match is scrolled off screen.
map({
  ["n"] = "nzzzv",
  ["N"] = "Nzzzv",
  -- <leader>/ clears the highlight. <leader><space> moved to telescope's
  -- project-wide search (lua/plugins/search.lua).
  ["<leader>/"] = "<cmd>noh<cr>",
})

-- <leader>sh: the reference's terminal key, kept with the exact spelling.
-- There is no <leader>s mapping, so this cannot shadow one.
map({ ["<leader>sh"] = "<cmd>terminal<cr>" })

-- F4. CONFIRMED -- replacement for Tagbar (outline of the file), confirmed by
-- the user on 2026-09-28.
--
-- The reference bound F4 to TagbarToggle. Tagbar is discarded, and its
-- replacement should show the same thing: the outline of the file. The native
-- equivalent is vim.lsp.buf.document_symbol(), which is a floating outline
-- rather than a sidebar.
--
-- It is mapped globally rather than from the LSP on_attach (in
-- lua/config/lsp.lua) because F4 should do something in a file with no server
-- attached -- and the honest thing to do there is say so, not stay silent.
--
-- The plan's tagbar replacement line named vim.lsp.buf.references() instead.
-- That is document symbols' cousin, not its twin; <leader>gr is fugitive's
-- GRemove, so a global <leader> reference mapping was never possible, and `gr`
-- (buffer-local, LSP on_attach) already covers references. The user confirmed
-- document_symbol over references on 2026-09-28.
map({
  ["<F4>"] = function()
    if #vim.lsp.get_clients({ bufnr = 0 }) == 0 then
      vim.notify("F4: no language server attached to this buffer", vim.log.levels.WARN)
      return
    end
    vim.lsp.buf.document_symbol()
  end,
}, { desc = "LSP: document symbols (F4, needs a server)", silent = true })

-- Editing with the current file's path already filled in.
--
-- The reference's intent was `<leader>e` -> :e <C-R>=expand("%:p:h") . "/" and
-- `<leader>te` -> tabedit with the same. <leader>te is free and mapped as the
-- reference had it. <leader>e is NOT: telescope owns it for find_files, which
-- the reference also wanted (it was the second, winning binding in the original
-- file, the way FZF was). Two functions cannot share one key, so the
-- shifted <leader>E carries the path-prefilled edit and <leader>e stays with
-- telescope. This is a deliberate deviation, not an oversight.
map({
  ["<leader>E"] = function()
    vim.cmd("edit " .. vim.fn.expand("%:p:h") .. "/")
  end,
  ["<leader>te"] = function()
    vim.cmd("tabedit " .. vim.fn.expand("%:p:h") .. "/")
  end,
}, { desc = "Edit with the current file's directory", silent = true })

-- Visual mode. The reference's pairs, unchanged: the trailing `gv` reselects so
-- a second press keeps moving the same selection.
vim.keymap.set("v", "<", "<gv", { silent = true, desc = "Visual: move selection left" })
vim.keymap.set("v", ">", ">gv", { silent = true, desc = "Visual: move selection right" })

-- Visual block line movement, from the reference. `:m '>+1` / `:m '<-2` and the
-- `gv=gv` are verbatim.
vim.keymap.set("x", "J", ":m '>+1<cr>gv=gv", { silent = true, desc = "Visual block: move down" })
vim.keymap.set("x", "K", ":m '<-2<cr>gv=gv", { silent = true, desc = "Visual block: move up" })

-- Command line: complete a path from the current file's directory, the
-- reference's <C-P> mapping.
vim.keymap.set("c", "<C-p>", '<C-r>=expand("%:p:h") . "/"<cr>', {
  silent = true,
  desc = "Command line: complete from the current file's directory",
})

-- Clipboard. All three are the reference's, and all three are guarded for the
-- same reason config/options.lua guards 'unnamedplus': there is no +clipboard
-- provider in every Neovim build, and the `"+` register is an error without one.
--
-- With 'clipboard' = unnamed,unnamedplus these are partly redundant -- `yy` and
-- `dd` already reach the system clipboard. They are kept anyway because the
-- reference had them, and because <leader>p ("+gP) is not redundant at all:
-- it pastes without first clobbering the unnamed register.
if vim.fn.has("unnamedplus") == 1 then
  map({
    ["Y"] = '"+y<cr>',
    ["X"] = '"+x<cr>',
    ["<leader>p"] = '"+gP<cr>',
  }, { silent = true, desc = "Clipboard" })
end

-- NOT HERE, and this is the point of the file:
--
--   gc / gcc      mini.comment installs its own expression mappings, verified
--                 against MiniComment.setup()'s defaults. A `keys` table would
--                 drop the operatorfunc indirection that makes 10gc_ work.
--   <leader>b/e   telescope.nvim, in lua/plugins/search.lua
--   <leader><space>  telescope.nvim, in lua/plugins/search.lua (repo-wide grep)
--   <C-p>         telescope.nvim, in lua/plugins/search.lua
--   <leader>y     fzf-lua, in lua/plugins/search.lua
--   <leader>:     fzf-lua, in lua/plugins/search.lua (command history)
--   <leader>g*    fugitive, in lua/plugins/git.lua
--   F2 / F3       neo-tree, in lua/plugins/ui.lua
--   gd / gr / K   the LSP, from the on_attach in lua/config/lsp.lua
--
-- NOT MAPPED, and deliberately:
--
--   cnoreabbrev W/Q/E...  the reference's command-line abbreviations. They are
--                         easy to trigger by accident inside a `:s///` argument
--                         or a path, and nothing in T6 asked for them.
--   :FixWhitespace        a surviving reference command, but it is a command and
--                         not a keymap. T6 is the keymap task; adding it here
--                         would be the wrong home for it.
