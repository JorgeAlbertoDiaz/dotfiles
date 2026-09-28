-- Domain: search (fuzzy finding).
--
-- The reference declared fzf twice -- once from ~/.fzf and once from
-- plugged/fzf.vim -- and because the first one set g:loaded_fzf_vim, the
-- second one finished early. The net result was that :Fzf did not exist at
-- all, only :Snippets. Two clean plugins replace the mess:
--
--   * telescope.nvim takes the picker keys (<leader>b, <leader>e).
--   * fzf-lua takes <leader>y, because it is the one-to-one replacement for
--     the reference's `:History:` command.

-- The reference guarded its ripgrep wiring on the binary being present. rg is
-- already installed (packages/dev-core.txt), and 'grepprg' has to be set
-- before any picker runs, so it is set here rather than inside a spec: this is
-- the search domain's own global, and a lazy spec would set it too late.
if vim.fn.executable("rg") == 1 then
  vim.opt.grepprg = "rg --vimgrep"
end

return {
  -- telescope.nvim: replacement for fzf.vim. vim.ui.select exists natively
  -- (verified in 0.12.5) and telescope's prompt is built on it, so the second
  -- fzf copy from the reference has nothing left to do.
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    keys = {
      -- :Buffers from the reference.
      { "<leader>b", "<cmd>Telescope buffers<cr>", desc = "Find in open buffers" },
      {
        "<leader>e",
        function()
          require("telescope.builtin").find_files({
            -- The reference's `rg --files --hidden --follow --glob '!.git/*'`.
            -- 'hidden' is the direct translation; telescope's `follow` only
            -- applies to the `find` fallback command, so --follow has no
            -- equivalent when fd/rg is used.
            hidden = true,
            file_ignore_patterns = {
              "%.git",
              "node_modules",
              "target",
              "dist",
              "__pycache__",
              "%.pyc",
              "%.rbc",
              "%.db",
              "%.sqlite",
              "%.o",
              "%.obj",
            },
          })
        end,
        desc = "Find files (hidden included)",
      },
    },
    config = function()
      require("telescope").setup({
        -- .gitignore is respected by default, which is the whole reason rg was
        -- worth keeping in the first place.
        respect_gitignore = true,
      })
    end,
  },

  -- fzf-lua: replacement for the fzf.vim copy, and the exact match for the
  -- reference's `nmap <leader>y :History:<cr>`.
  --
  -- VERIFIED: `:History:` was never a telescope builtin (telescope has
  -- `resume` and `oldfiles`, but no history picker). fzf-lua's own command
  -- dispatch has one, so that key keeps its original behaviour -- and going
  -- through :FzfLua also lazy-loads the plugin.
  {
    "ibhagwan/fzf-lua",
    keys = {
      { "<leader>y", "<cmd>FzfLua history<cr>", desc = "Search the fzf history" },
    },
    -- :FzfLua stays available for everything the reference reached through
    -- `:Fzf` and its friends.
    cmd = "FzfLua",
  },
}
