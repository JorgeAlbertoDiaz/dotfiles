-- Domain: git (fugitive, gitsigns).
--
-- Both survive from the original 45 as replacements rather than additions:
-- gitgutter is replaced by gitsigns, which lives here next to fugitive
-- because both are git domain plugins, not UI ones.

return {
  -- fugitive: kept, unchanged in spirit. There is no git client in Neovim.
  --
  -- The keymaps are the reference's, verbatim and in the same order.
  {
    "tpope/vim-fugitive",
    keys = {
      { "<leader>ga", "<cmd>Gwrite<cr>", desc = "Git: stage and commit (write)" },
      { "<leader>gc", "<cmd>Git commit --verbose<cr>", desc = "Git: commit" },
      { "<leader>gsh", "<cmd>Git push<cr>", desc = "Git: push" },
      { "<leader>gll", "<cmd>Git pull<cr>", desc = "Git: pull" },
      { "<leader>gs", "<cmd>Git<cr>", desc = "Git: status" },
      { "<leader>gb", "<cmd>Git blame<cr>", desc = "Git: blame" },
      { "<leader>gd", "<cmd>Gvdiffsplit<cr>", desc = "Git: diff against the index" },
      { "<leader>gr", "<cmd>GRemove<cr>", desc = "Git: remove hunks" },
    },
  },

  -- gitsigns: replacement for gitgutter. gitgutter falls back to a
  -- synchronous diff and freezes the UI when it cannot get an async one;
  -- gitsigns is async and native to the buffer's sign/extmark layer.
  --
  -- The reference showed git state two ways: the gitgutter sign column, and
  -- fugitive's statusline snippet. The sign column is what gitsigns
  -- reproduces; the statusline half moved to lualine's "branch" component
  -- (see lua/plugins/ui.lua).
  {
    "lewis6991/gitsigns.nvim",
    -- Attached on read/write rather than at startup: nothing to sign before a
    -- buffer is actually open.
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = { add = { text = "▎" } },
      signs_staged = { add = { text = "▎" } },
      signs_staged_enable = false,
      current_line_blame = false,
      current_line_blame_opts = { delay = 300, virt_text_pos = "eol" },
      current_line_blame_formatter = "<author>, <author_time:%R> - <summary>",
      signcolumn = true,
      numhl = false,
      linehl = false,
      word_diff = false,
      watch_gitdir = {
        follow_files = true,
      },
      attach_to_untracked = true,
      update_debounce = 200,
    },
    config = function(_, opts)
      require("gitsigns").setup(opts)
    end,
  },
}
