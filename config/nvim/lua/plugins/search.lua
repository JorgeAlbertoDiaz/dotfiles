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

-- :Rg / :Ag: the reference exposed the grep binaries as commands. Here they open
-- telescope's fuzzy grep (live_grep with no term, grep_string with one), which is
-- the same rg search behind a picker. pcall keeps the commands alive even if
-- telescope is not installed.
local function grep_command(term)
  local ok, builtin = pcall(require, "telescope.builtin")
  if not ok then
    vim.notify("telescope.nvim no está instalado", vim.log.levels.WARN)
    return
  end
  if term == nil or term == "" then
    builtin.live_grep()
  else
    builtin.grep_string({ search = term })
  end
end

vim.api.nvim_create_user_command("Rg", function(o)
  grep_command(o.args)
end, { nargs = "?", desc = "Buscar en el proyecto con ripgrep (telescope)" })
vim.api.nvim_create_user_command("Ag", function(o)
  grep_command(o.args)
end, { nargs = "?", desc = "Alias de :Rg" })

-- Shared by <leader>e and <C-p>: the reference's
-- `rg --files --hidden --follow --glob '!.git/*'`.
local function find_files()
  require("telescope.builtin").find_files({
    -- hidden + no_ignore: list every file, including dotfiles and anything
    -- ignored by .gitignore (untracked/ignored). The heavy directories below are
    -- still filtered so node_modules cannot flood the picker.
    hidden = true,
    no_ignore = true,
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
      { "<leader>e", find_files, desc = "Find files (all, hidden included)" },
      -- <C-p>: the reference's fuzzy-finder key, in normal mode. Command-line
      -- <C-p> stays as path completion (config/keymaps.lua); different mode.
      { "<C-p>", find_files, desc = "Find files (all, fuzzy)" },
      -- <leader><space>: repo-wide text search. rg is substring-based (not a word
      -- match) and --ignore-case makes it case-insensitive, i.e. "contains".
      {
        "<leader><space>",
        function()
          require("telescope.builtin").live_grep({
            additional_args = function()
              return { "--ignore-case" }
            end,
          })
        end,
        desc = "Search in project (substring, ignore case)",
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
      -- The draft's fuzzy command history. <C-h> was not usable: normal-mode <C-h>
      -- is window-left and command-line <C-h> is Backspace, so this uses the
      -- non-conflicting <leader>:.
      { "<leader>:", "<cmd>FzfLua command_history<cr>", desc = "Command history (fuzzy)" },
    },
    -- :FzfLua stays available for everything the reference reached through
    -- `:Fzf` and its friends.
    cmd = "FzfLua",
  },
}
