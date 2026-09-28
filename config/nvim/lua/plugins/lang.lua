-- Domain: lang (per-language tooling).
--
-- The language SET is not declared in this file. It lives in
-- lua/config/langs.lua, one line per language, and everything here is derived
-- from it: which tree-sitter parsers to install, which linters to wire to which
-- filetypes, and which formatters to run on save. That is the whole point of
-- the table -- a language is added in one place or not at all.
--
-- Source of truth for intent: docs/referencia/nvim-vim-bootstrap-init.vim and
-- odd/tasks/nvim-nativo.md.

local langs = require("config.langs")

return {
  -- nvim-treesitter: replacement for the syntax-highlighting half of every
  -- discarded plugin, and the reason filetype plugins stopped being the way
  -- highlighting happens.
  --
  -- THE BRANCH IS THE PART THAT MATTERS. The plan's risk section says the main
  -- branch "is archived" -- that was true of what it used to point at, and it
  -- is no longer true. Re-verified 2026-09-28 against the repository itself:
  --
  --   * nvim-treesitter/nvim-treesitter is NOT archived. Last commit 2026-09-27.
  --     The default branch is `main`.
  --   * `main` is a rewrite: it is built on Neovim's own parser ABI and targets
  --     0.12, and it DROPPED the `ensure_installed` option the plan names.
  --   * `master` is frozen, kept only for the old API.
  --
  -- So this pins `main` and adapts the plan's instruction to the API that
  -- actually exists: `require('nvim-treesitter').install({ ... }):wait(ms)`.
  -- VERIFIED against main @ 728e031, lua/nvim-treesitter/{init,config,install}.lua
  -- and README.md: install() is a no-op for parsers that are already there, so
  -- calling it unconditionally costs a directory listing, not a download.
  --
  -- lazy = false is not a preference. main states it does not support lazy
  -- loading, and the FileType autocmd below runs before anything is installed
  -- otherwise.
  --
  -- No `build` step, and that is deliberate. `:TSUpdate` is the advice the OLD
  -- nvim-treesitter gave next to `ensure_installed`; on main it resolves to
  -- install.update() with no arguments, which means "re-download every parser I
  -- can currently see installed" (verified in
  -- lua/nvim-treesitter/install.lua: M.update turns an empty list into 'all'
  -- and then filters by `missing`). As a build step that runs before this
  -- plugin's own config has ever installed a parser, it is either a no-op or a
  -- full re-download, depending on whether the parser directory survived. The
  -- config below installs exactly the parsers the language table asks for, and
  -- skips the work entirely when they are already there.
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    config = function()
      local ts = require("nvim-treesitter")
      local wanted = langs.parsers()
      local installed = ts.get_installed("parsers")

      local missing = vim.tbl_filter(function(parser)
        return not vim.tbl_contains(installed, parser)
      end, wanted)

      if #missing > 0 then
        -- Synchronous on purpose, and only when something is actually missing.
        -- A fresh clone has nothing installed, and a FileType that fires before
        -- its parser exists gets no highlighting at all until the next reload;
        -- blocking here is cheaper than that. Every start after the first one
        -- skips this entirely.
        local ok, err = pcall(function()
          ts.install(missing):wait(300000)
        end)
        if not ok then
          vim.notify(
            ("nvim-treesitter: could not install %s: %s"):format(table.concat(missing, ", "), err),
            vim.log.levels.ERROR
          )
        end
      end

      -- Highlighting only. The `indentexpr` and `foldexpr` that main also
      -- offers are deliberately NOT enabled: config/autocmds.lua carries the
      -- reference's per-language indentation (python's tabstop=8 with a
      -- shiftwidth=4 and cinwords, html's ts=2, javascript's ts=4), and that is
      -- a surviving UX decision, not an oversight. A tree-sitter indentexpr
      -- would silently override all of it.
      --
      -- pcall because vim.treesitter.start() raises when the parser is missing,
      -- and "missing" is exactly the state this file exists to fix -- it should
      -- never be a reason to break the editor. The failure is reported once
      -- rather than once per buffer, so a genuinely absent parser does not turn
      -- into a notification storm while navigating a directory.
      local reported_failure = false
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("lang_treesitter", { clear = true }),
        desc = "Start tree-sitter highlighting for the declared languages",
        callback = function(args)
          if not vim.tbl_contains(langs.filetypes(), vim.bo[args.buf].filetype) then
            return
          end
          local ok, err = pcall(vim.treesitter.start, args.buf)
          if not ok and not reported_failure then
            reported_failure = true
            vim.notify(
              ("nvim-treesitter: %s"):format(err),
              vim.log.levels.WARN
            )
          end
        end,
      })
    end,
  },

  -- nvim-lint: replacement for ALE, which the 45 -> 16 verdict discards.
  --
  -- linters_by_ft is DERIVED from the language table, so a language's linter
  -- is declared next to its language and nowhere else. Only two of the eight
  -- languages have one: the plan's minimum (python, via ruff) and lua, which is
  -- the language this config is written in. The other five are one table line
  -- away and are listed as deliberate omissions in lua/config/langs.lua.
  --
  -- There is no `setup()` and no `opts`: nvim-lint is configured by assigning
  -- the fields on the module, and `require("lint").setup` does not exist (it
  -- was verified against lua/lint.lua on the current commit, which exports
  -- linters_by_ft, linters, try_lint, lint, get_namespace, get_running and
  -- _resolve_linter_by_ft, and nothing else). A `linters_by_ft` value may be a
  -- bare string: M.linters is a metatable that resolves
  -- `lint.linters.<name>` on access, so no explicit require is needed.
  {
    "mfussenegger/nvim-lint",
    lazy = false,
    config = function()
      require("lint").linters_by_ft = langs.linters_by_ft()

      -- VERIFIED against nvim-lint's README: try_lint() with no argument runs
      -- exactly the linters configured for the current filetype. BufWritePost
      -- is the documented trigger, and the linters that need a saved file
      -- would misreport on every keystroke otherwise.
      vim.api.nvim_create_autocmd("BufWritePost", {
        group = vim.api.nvim_create_augroup("lang_lint", { clear = true }),
        desc = "Run the configured linters after writing a buffer",
        callback = function()
          require("lint").try_lint()
        end,
      })
    end,
  },

  -- conform.nvim: replacement for vim-php-cs-fixer and requirements.txt.vim,
  -- and the format-on-save half of the same table.
  {
    "stevearc/conform.nvim",
    lazy = false,
    config = function()
      local conform = require("conform")
      local stylua = require("conform.formatters.stylua")

      conform.setup({
        formatters_by_ft = langs.formatters_by_ft(),
        -- The plan's intent for the servers is "formatting via LSP where the
        -- server can, tool otherwise". Conform asks for the tool first and only
        -- falls back to the server, which is the right order: a formatter's
        -- output is reproducible and a server's depends on its version.
        format_on_save = {
          lsp_format = "fallback",
          timeout_ms = 1000,
        },
        -- Only a formatter that cannot run should be a visible failure. Every
        -- other language in the table has a formatter, so "no formatters
        -- available" means the mason install has not finished yet.
        notify_no_formatters = true,
        formatters = {
          stylua = vim.tbl_deep_extend("force", stylua, {
            -- stylua's defaults are tabs and a width of 4. This repository is
            -- two-space indented, and format-on-save would otherwise rewrite
            -- every Lua file in it. Conform has NO generic options-to-flags
            -- conversion -- a formatter's `options` field is read by that
            -- formatter's own code and is ignored by the runner -- so these
            -- have to go in as real CLI arguments, which is what
            -- conform.util.extend_args is for (documented in the util module).
            args = require("conform.util").extend_args(stylua.args, {
              "--indent-type",
              "Spaces",
              "--indent-width",
              "2",
              "--column-width",
              "100",
            }),
          }),
        },
      })
    end,
  },

  -- emmet-vim: kept from the original 45. There is no native equivalent and
  -- it earns its keep on markup.
  --
  -- The reference's filetypes were broader -- javascript, svelte, vue among them
  -- -- and vue is not one of the active languages, so markup is both the
  -- minimum that makes the plugin useful and the whole of what is claimed here.
  {
    "mattn/emmet-vim",
    ft = { "html", "css" },
  },
}
