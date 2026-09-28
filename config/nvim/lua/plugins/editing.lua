-- Domain: editing (commenting, auto-pairs).

return {
  -- mini.comment: replacement for commentary.
  --
  -- VERIFIED, and it is the reason this is not a plain `keys` spec: mini.comment
  -- installs its own mappings, and they are expression mappings that set
  -- 'operatorfunc' to get dot-repeatability and counts (10gc_ toggles ten
  -- lines). A hand-rolled `keys = { { "gc", ... } }` would silently drop that
  -- behaviour. So the plugin is loaded before the user can press the keys and
  -- left in charge of its own bindings.
  --
  -- The reference's gc / gcc come straight from MiniComment.setup()'s defaults
  -- (comment = "gc", comment_line = "gcc", textobject = "gc"), which is why
  -- they are not repeated here.
  {
    "echasnovski/mini.comment",
    -- VeryLazy rather than startup: the mapping has to exist when the key is
    -- pressed, but nothing about commenting is needed during the first redraw.
    event = "VeryLazy",
    opts = {
      options = {
        -- Trust the buffer's 'commentstring' (ftplugin or tree-sitter) rather
        -- than mini.comment's own guess.
        custom_commentstring = function()
          return vim.bo.commentstring
        end,
      },
    },
    config = function(_, opts)
      require("mini.comment").setup(opts)
    end,
  },

  -- nvim-autopairs: replacement for delimitMate. No native equivalent exists,
  -- and this one is maintained and faster.
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {
      -- The pickers in this config are their own insert mode: pairing
      -- brackets there breaks the prompts.
      disable_filetype = {
        "TelescopePrompt",
        "spectre_panel",
        "snacks_picker_input",
      },
      -- A treesitter parser for the buffer makes the checker accurate instead
      -- of heuristic, and the parsers for every active language are installed
      -- by lua/plugins/lang.lua, so this dependency is gone.
      check_ts = true,
      enable_abbr = false,
      enable_check_bracket_line = true,
      enable_afterquote = true,
      map_cr = true,
      map_bs = true,
    },
    config = function(_, opts)
      require("nvim-autopairs").setup(opts)
    end,
  },
}
