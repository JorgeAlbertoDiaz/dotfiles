-- Domain: ui (colorscheme, statusline, file tree).
--
-- Every replacement here was chosen by the 45 -> 16 verdict in
-- odd/tasks/nvim-nativo.md. The intent of the vim-bootstrap original lives in
-- docs/referencia/nvim-vim-bootstrap-init.vim; this file is where that intent
-- gets its modern implementation.

return {
  -- badwolf: the only colorscheme kept from the original 45. priority 1000
  -- makes it the first plugin on 'runtimepath' after the manager, so anything
  -- shipping its own highlights loads after it.
  --
  -- The reference's g:indentLine_* and g:airline_* settings are not
  -- translated here: the indent guide is native (see config/options.lua) and
  -- airline is replaced below.
  {
    "sjl/badwolf",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("badwolf")
    end,
  },

  -- lualine: replacement for airline + airline-themes.
  --
  -- Eager, because a statusline has to exist on the first redraw. The section
  -- layout mirrors what the reference's hand-written 'statusline' string
  -- carried: file, modified flag, readonly flag, file format, position.
  {
    "nvim-lualine/lualine.nvim",
    lazy = false,
    -- No `version = "*"`: lazy's docs warn that semver-aware pins tend to be
    -- stale and break the install. lazy-lock.json does the pinning.
    opts = function()
      -- gitsigns does not export a statusline helper any more; it publishes
      -- vim.b.gitsigns_status and fires `User GitSignsUpdate`. The component
      -- below is a plain function, which lualine calls on every redraw.
      local function gitsigns()
        return vim.b.gitsigns_status or ""
      end

      return {
        -- VERIFIED against the theme list shipped by lualine: there is no
        -- "badwolf" theme, so "auto" is the only correct value until one exists
        -- upstream. "auto" derives its palette from 'background', which
        -- config/options.lua pins to "dark".
        theme = "auto",
        options = {
          -- Sections live under options.sections, keyed by position AND name
          -- (lualine_a, lualine_b, ...). Putting them straight under options
          -- is silently ignored, which is why the layout below has to be
          -- nested one level deeper than it looks.
          sections = {
            lualine_a = { "mode" },
            lualine_b = {
              -- Replaces the reference's
              -- `set statusline+=%{fugitive#statusline()}`.
              "branch",
              gitsigns,
            },
            lualine_c = {
              "filename",
              path = 0,
              symbols = { modified = " [+]", readonly = " [RO]" },
            },
            lualine_x = { "encoding", "fileformat", "filetype" },
            lualine_y = { "progress" },
            lualine_z = { "location" },
          },
        },
      }
    end,
    config = function(_, opts)
      local lualine = require("lualine")
      lualine.setup(opts)

      -- gitsigns updates the buffer variable asynchronously, so a passive
      -- redraw would show a stale diff count. GitSignsUpdate is the event
      -- that says "the statusline you are drawing is now wrong".
      --
      -- This autocmd is registered here and NOT through lualine's
      -- options.refresh.events: lualine builds those as
      -- `:autocmd lualine <event> <pattern>`, and GitSignsUpdate is a `User`
      -- event pattern, not a real event, so it fails with E216.
      vim.api.nvim_create_autocmd("User", {
        pattern = "GitSignsUpdate",
        group = vim.api.nvim_create_augroup("lualine_gitsigns", { clear = true }),
        desc = "Redraw the statusline when the gitsigns status changes",
        callback = function()
          lualine.refresh()
        end,
      })
    end,
  },

  -- gitsigns lives in lua/plugins/git.lua, next to fugitive: it is a git
  -- domain plugin, not a UI one.

  -- neo-tree.nvim: replacement for nerdtree + nerdtree-tabs.
  --
  -- Loaded on its keymaps rather than on startup: a file tree is not something
  -- needed before it has been asked for.
  {
    "nvim-neo-tree/neo-tree.nvim",
    -- neo-tree requires these three. Without nui.nvim the module fails to load
    -- and :Neotree does not exist, which is why F2/F3 errored out. Declaring
    -- them here makes lazy install them as part of the same spec.
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    keys = {
      -- NERDTreeFind / NERDTreeToggle from the reference, same two keys.
      { "<F2>", "<cmd>Neotree reveal_force_cwd<cr>", desc = "Reveal the current file in the tree" },
      { "<F3>", "<cmd>Neotree toggle<cr>", desc = "Toggle the file tree" },
    },
    opts = {
      sources = { "filesystem", "buffers", "git_status" },
      default_source = "filesystem",
      close_if_last_window = true,
      enable_git_status = true,
      enable_diagnostics = true,
      -- NERDTreeWinSize=50, faithfully: window.width is in columns for the
      -- left/right positions. Position is "right" by request: the tree opens on
      -- the right edge.
      window = { position = "right", width = 50 },
      sort_case_insensitive = true,
      filesystem = {
        -- NERDTreeChDirMode=2: the tree always stays on the file being
        -- edited.
        follow_current_file = { enabled = true },
        -- NERDTreeIgnore from the reference, as Lua patterns. node_modules
        -- and friends are already in 'wildignore' (config/options.lua); this
        -- is the tree's own copy of the same intent.
        filtered_items = {
          hide_dotfiles = false,
          hide_by_name = { "node_modules", ".git", "__pycache__", ".venv" },
          hide_by_pattern = { "*.pyc", "*.rbc", "*.db", "*.sqlite", "*~" },
        },
      },
    },
    config = function(_, opts)
      require("neo-tree").setup(opts)
    end,
  },
}
