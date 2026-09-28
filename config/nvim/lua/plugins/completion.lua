-- Domain: completion (engine, snippet engine, server manager).
--
-- nvim-cmp is the engine, LuaSnip is what turns a `snippet` completion field
-- into text, and the sources below are separate plugins again -- see the note
-- on the source block for why that changed.

return {
  -- nvim-cmp: replacement for asyncomplete.vim + asyncomplete-lsp.vim, both
  -- abandoned since 2021.
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    -- The builtin sources were removed from nvim-cmp and live in their own
    -- repositories now. VERIFIED 2026-09-28: the current `sources` option is
    -- empty by default and `cmp.source` no longer carries `nvim_lsp`, `buffer`,
    -- `path` or `luasnip`. Naming them in `sources` without these would throw
    -- at startup.
    dependencies = {
      "L3MON4D3/LuaSnip",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "saadparwaiz1/cmp_luasnip",
    },
    opts = function()
      local cmp = require("cmp")

      -- LuaSnip may not be loaded yet even when cmp is: both are dependencies of
      -- this spec, and lazy resolves them in the order it feels like. Anything
      -- that asks "is there a jumpable snippet?" has to tolerate that, or the
      -- first <Tab> in a fresh session throws.
      local function has_jumpable_snippet()
        local luasnip = package.loaded["luasnip"]
        return luasnip ~= nil and luasnip.expandable ~= nil and luasnip.expandable()
      end

      return {
        -- Required by cmp: it is the engine that turns a completion item's
        -- `snippet` field into text. Guarded, because the module only exists
        -- once LuaSnip has actually been loaded.
        snippet = {
          expand = function(args)
            local luasnip = package.loaded["luasnip"]
            if not luasnip then
              return cmp.snippet.expand(args)
            end
            if luasnip.expandable and luasnip.expandable() then
              return luasnip.lsp_expand(args.body)
            end
            return cmp.snippet.expand(args)
          end,
        },
        -- <Tab> / <C-b> are the reference's snippet triggers. Here they walk
        -- the completion menu and fall through to their normal action when no
        -- menu is open, which is the behaviour vim-bootstrap's UltiSnips
        -- mapping had.
        --
        -- cmp.mapping.preset.insert() covers <Down>, <Up>, <C-n>, <C-p>, <C-y>
        -- and <C-e> on its own (verified in the current preset source), so those
        -- are not repeated. <Tab> and <S-Tab> are not part of that preset and
        -- have to be added here; the insert preset's own <Tab> is
        -- menu-only, so this is the mapping that also has to fall through to
        -- the real <Tab> when no menu is open.
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif has_jumpable_snippet() then
              require("luasnip").expand_or_jumpable()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif has_jumpable_snippet() then
              require("luasnip").jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        -- The active language set is not consulted here, and that is on
        -- purpose: these four sources are filetype-agnostic. Which LANGUAGES
        -- are active is lua/config/langs.lua's job, and the servers it wires
        -- are what produce LSP completions in the first place. So there is
        -- nothing per-language left for this file to say.
        sources = {
          { name = "nvim_lsp", priority = 1000 },
          { name = "luasnip", priority = 750 },
          { name = "path", priority = 250 },
          { name = "buffer", priority = 50 },
        },
        experimental = { ghost_text = false },
      }
    end,
    config = function(_, opts)
      local cmp = require("cmp")
      cmp.setup(opts)

      -- Tells the servers this client can handle snippets, resolve requests and
      -- documentation markup, instead of the bare defaults. Without it a server
      -- sends plain text and cmp cannot show documentation on demand.
      --
      -- KNOWN LIMITATION, accepted: this runs on InsertEnter, so the very first
      -- file opened in a session was handshaked before cmp was on the
      -- runtimepath and its first completion arrives without snippet support.
      -- The alternative is loading cmp (and five more plugins) at startup on
      -- every session to fix the first file of each one, which is a worse trade
      -- than a slightly worse first completion.
      pcall(function()
        cmp.set_capabilities({ completion = require("cmp_nvim_lsp").default_capabilities() })
      end)
    end,
  },

  -- LuaSnip: replacement for UltiSnips, which is DEAD in this environment
  -- (verified: UltiSnips.vim finishes immediately when has('python3') == 0,
  -- and the Python 3 provider no longer exists in Neovim 0.12.5). No system
  -- package brings it back.
  {
    "L3MON4D3/LuaSnip",
    -- InsertEnter is enough: a snippet cannot be expanded outside insert
    -- mode, and this also keeps cmp's dependency resolvable on first use.
    event = "InsertEnter",
    -- jsregexp only matters for the JavaScript regex snippets; the
    -- dependency's own Makefile installs it.
    build = "make install_jsregexp",
    config = function()
      -- setup lives ON the config module: require("luasnip.config").setup().
      -- Writing require("luasnip.config.setup({})") treats setup({}) as part of
      -- the module path and fails with "module 'luasnip.config.setup({})' not
      -- found" -- which only shows up on the first InsertEnter, never on
      -- startup, because this spec is lazy.
      require("luasnip.config").setup({})
    end,
  },

  -- luasnip-snippets: replacement for vim-snippets.
  --
  -- NOTE on the URL. The obvious `L3MON4D3/luasnip-snippets` returns 404
  -- (verified against the GitHub API). `mireq/luasnip-snippets` is the live
  -- conversion of honza/vim-snippets -- which is exactly the plugin the
  -- reference had -- and its generated per-filetype files are committed, so
  -- no build step is needed.
  {
    "mireq/luasnip-snippets",
    dependencies = { "L3MON4D3/LuaSnip" },
    event = "InsertEnter",
    config = function(plugin)
      -- The collection is a direct conversion of honza/vim-snippets, and it
      -- still interpolates five globals that vim-snippets defined for its
      -- users. 73 references across the tree, and the loader hard-errors on
      -- the first one it hits: "E121: Undefined variable: g:snips_author".
      --
      -- They are read from git rather than hardcoded, so they follow the
      -- identity the user already configured instead of adding a second place
      -- to maintain it. vim.fn.system keeps this off the shell: no job, no
      -- shell, and an unset key returns "" instead of a nil that would trip
      -- the same E121.
      local function git(key)
        local ok, value = pcall(vim.fn.system, { "git", "config", "--get", key })
        if not ok or vim.v.shell_error ~= 0 then
          return ""
        end
        return (value:gsub("%s+$", ""))
      end

      local name, email = git("user.name"), git("user.email")
      vim.g.snips_author = name
      vim.g.snips_author_email = email
      vim.g.snips_email = email
      vim.g.snips_company = git("user.company")
      vim.g.snips_github = git("github.user")

      -- Its snippets live in <plugin>/lua/luasnip_snippets/, which is NOT the
      -- directory LuaSnip's from_lua loader looks for by default: with no
      -- `paths` the loader resolves the runtimepath entry "luasnippets", no
      -- underscore (verified in LuaSnip/lua/luasnip/loaders/from_lua.lua, which
      -- calls resolve_root_paths(o.paths, "luasnippets")). So the path is
      -- explicit.
      --
      -- The first argument is the plugin table, not opts: lazy calls
      -- `plugin.config(plugin, opts)` (lazy.nvim/lua/lazy/core/loader.lua:380),
      -- and `dir` hangs off the plugin. Reading it off `opts` gives nil.
      require("luasnip.loaders.from_lua").lazy_load({
        paths = { plugin.dir .. "/lua/luasnip_snippets" },
      })
    end,
  },

  -- mason.nvim: installs the language servers and the tools they need.
  --
  -- This spec only declares the plugin and keeps :Mason reachable by hand. The
  -- list of packages comes from the language table, and the installation loop
  -- itself is in lua/config/lsp.lua -- next to the vim.lsp.config calls that
  -- consume the binaries, because mason installing a server and Neovim starting
  -- it are two halves of one decision and belong in one file.
  {
    "williamboman/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUninstall", "MasonLog", "MasonUpdate" },
    build = ":MasonUpdate",
    -- Mason redraws its own UI by querying the colorscheme's highlight
    -- groups, so the UI has to be rebuilt whenever the colorscheme changes.
    --
    -- `MasonUpdate` is the colorscheme command here, not the registry updater:
    -- they are different commands with an unfortunate name collision. The
    -- registry is updated by the `build` step above, at install time.
    init = function()
      vim.api.nvim_create_autocmd("ColorScheme", {
        callback = function()
          vim.cmd("MasonUpdate")
        end,
        desc = "Re-apply Mason highlights after a colorscheme change",
      })
    end,
    opts = {},
    config = function(_, opts)
      require("mason").setup(opts)
    end,
  },
}
