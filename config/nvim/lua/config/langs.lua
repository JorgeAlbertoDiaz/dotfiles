-- T5: the single declarative source of truth for per-language support.
--
-- Source of truth for intent: docs/referencia/nvim-vim-bootstrap-init.vim and
-- odd/tasks/nvim-nativo.md. Every name below was verified against the installed
-- plugin's own source on 2026-09-28, never against a lockfile guess:
--
--   linters     lua/lint/linters/<name>.lua       in nvim-lint
--   formatters  lua/conform/formatters/<name>.lua in conform.nvim
--   parsers     lua/nvim-treesitter/parsers.lua   in nvim-treesitter (main)
--   cmd         the matching lsp/<name>.lua        in nvim-lspconfig
--   mason       the registry index                in mason-registry
--
-- AND every mason package below was installed, not merely named: the check
-- waited on the registry's own package:install:success event and then confirmed
-- is_installed() for each one. That is what caught luacheck.
--
-- HOW TO ADD A LANGUAGE: one line in `langs` below. Nothing in lua/plugins/*.lua
-- or in lua/config/lsp.lua names a language, a linter, a formatter or a parser
-- directly: the treesitter, nvim-lint, conform.nvim, vim.lsp and mason wiring
-- is all derived from this table through the helpers at the bottom.
--
-- Entry shape:
--   ft     filetypes this language claims. Explicit, not derived from the key,
--          because the react and JSX filetypes are separate filetype plugins
--          and each one needs its own parser/query/highlight.
--   lsp    name of the vim.lsp.config entry in lua/config/lsp.lua.
--   lint   nvim-lint linters. Empty means "no linter", never "unverified".
--   fmt    conform.nvim formatters.
--   ts     tree-sitter parser. Defaults to the table key, which is correct for
--          every entry below; set it only when the parser is named differently.

local langs = {
  html = {
    ft = { "html" },
    lsp = "html",
    lint = {},
    fmt = { "prettier" },
  },
  css = {
    ft = { "css" },
    lsp = "css",
    lint = {},
    fmt = { "prettier" },
  },
  javascript = {
    ft = { "javascript", "javascriptreact" },
    lsp = "ts_ls",
    lint = {},
    fmt = { "prettier" },
  },
  lua = {
    ft = { "lua" },
    lsp = "lua_ls",
    -- selene, not luacheck. luacheck is the obvious choice and it is NOT what
    -- ships: mason's `luacheck` package is `pkg:luarocks/luacheck@1.1.0`, and
    -- that install was observed here to never resolve -- over 10 minutes with
    -- no success and no failure event, `is_installed()` still false, and mason
    -- still reporting it as installing at exit. A linter that hangs forever on
    -- install is worse than no linter, and the cause is in the luarocks
    -- installer, not in anything T5 controls.
    --
    -- selene is the verified replacement: it is in nvim-lint's linters, and
    -- mason ships it as a plain GitHub binary (`pkg:github/Kampfkarren/selene`),
    -- the same install path stylua and ruff use -- both of which land in
    -- seconds. Restoring luacheck is one word, if the luarocks package is ever
    -- fixed upstream or luacheck is packaged for the distribution instead.
    lint = { "selene" },
    fmt = { "stylua" },
  },
  php = {
    ft = { "php" },
    lsp = "phpactor",
    lint = {},
    fmt = { "php_cs_fixer" },
  },
  python = {
    ft = { "python" },
    lsp = "pyright",
    -- The plan's minimum. ruff replaces flake8, pylint, isort and black in one
    -- tool, and its default rules need no setup.cfg or pyproject.toml to run.
    lint = { "ruff" },
    fmt = { "ruff_format" },
  },
  typescript = {
    ft = { "typescript", "typescriptreact" },
    lsp = "ts_ls",
    lint = {},
    fmt = { "prettier" },
  },
  svelte = {
    ft = { "svelte" },
    lsp = "svelte",
    lint = {},
    fmt = { "prettier" },
  },
  -- markdown: no LSP, linter or formatter. It is here for one reason: the
  -- tree-sitter parser, which gives '=' a real indent provider instead of
  -- 'autoindent' copying the previous line (what mangled .md files).
  markdown = {
    ft = { "markdown" },
    lint = {},
    fmt = {},
  },
}

-- Languages the reference declared and this config deliberately does not.
--
-- Each is excluded on purpose, not overlooked, and each becomes one line above
-- if it is ever wanted. The table stays the only place a language is named.
--
--   go     -- the plan drops it with Go itself (T7 owns the toolchain), and
--             nvim-go was the plugin providing the workflow. Adding it back
--             needs gopls + golangci-lint + gofumpt, not just a table line.
--             { ft = { "go", "gomod" }, lsp = "gopls", lint = { "golangci-lint" },
--               fmt = { "gofumpt" } }
--   vue    -- dropped for the same reason as go: no active Vue project, and
--             vtsls has no ecosystem status. Needs a `vue` parser too.
--             { ft = { "vue" }, lsp = "vtsls", lint = {}, fmt = { "prettier" } }
--   rust   -- the plan leaves rust-analyzer undecided (rustup vs the
--             distribution package) and it is not packaged in Tumbleweed.
--             { ft = { "rust" }, lsp = "rust_analyzer", lint = { "clippy" },
--               fmt = { "rustfmt" } }

-- The mason package that provides each tool named above.
--
-- Only the names that differ from the mason package name are listed; anything
-- absent resolves to itself. The right-hand column is the registry's own
-- package name, verified against the registry index, and the right-hand side
-- of `lsp` is the binary mason actually puts on PATH.
local packages = {
  -- vim.lsp.config name -> mason package
  lsp = {
    html = { "html-lsp" },
    css = { "css-lsp" },
    ts_ls = { "typescript-language-server" },
    lua_ls = { "lua-language-server" },
    pyright = { "pyright" },
    phpactor = { "phpactor" },
    svelte = { "svelte-language-server" },
  },
  -- nvim-lint / conform tool name -> mason package
  tools = {
    -- ruff's `format` subcommand is the formatter; the package is shared.
    ruff_format = { "ruff" },
    -- conform spells this formatter with an underscore, mason with a hyphen.
    php_cs_fixer = { "php-cs-fixer" },
  },
}

---Resolve an LSP server name to the mason package that installs it.
---@param server string
---@return string
local function lsp_package(server)
  return (packages.lsp[server] or { server })[1]
end

---Resolve a linter or formatter name to the mason package that installs it.
---@param tool string
---@return string
local function tool_package(tool)
  return (packages.tools[tool] or { tool })[1]
end

---Deduplicate and sort, so that the mason notification lists the same packages
---in the same order on every start.
---
---Written in plain Lua rather than as `vim.fn.sort(vim.fn.uniq(list))` on
---purpose: vim.fn.uniq blanks the entries it drops, which leaves holes in the
---returned list, and it was verified to come back with prettier listed four times
---here rather than once. table.sort plus a seen-set has no such failure mode.
---@param list string[]
---@return string[]
local function sorted_unique(list)
  local seen = {}
  local out = {}
  for _, value in ipairs(list) do
    if not seen[value] then
      seen[value] = true
      out[#out + 1] = value
    end
  end
  table.sort(out)
  return out
end

local M = {}

---The raw table, for readers and for anything that wants to iterate it.
M.langs = langs

---Every filetypes any language claims.
---@return string[]
function M.filetypes()
  local out = {}
  for _, entry in pairs(langs) do
    vim.list_extend(out, entry.ft)
  end
  return sorted_unique(out)
end

---Every tree-sitter parser the language set needs.
---@return string[]
function M.parsers()
  local out = {}
  for name, entry in pairs(langs) do
    out[#out + 1] = entry.ts or name
  end
  return sorted_unique(out)
end

---Filetypes grouped by the LSP server that serves them.
---
---Derived rather than written down: javascript and typescript both point at
---ts_ls, so ts_ls ends up owning four filetypes from two table lines.
---@return table<string, string[]>
function M.server_filetypes()
  local out = {}
  for _, entry in pairs(langs) do
    -- A language may declare no LSP (markdown): it still needs a parser and the
    -- per-filetype wiring, just not a server.
    if entry.lsp then
      out[entry.lsp] = out[entry.lsp] or {}
      vim.list_extend(out[entry.lsp], entry.ft)
    end
  end
  for name, fts in pairs(out) do
    out[name] = sorted_unique(fts)
  end
  return out
end

---Filetypes grouped by nvim-lint linter, ready for linters_by_ft.
---@return table<string, string[]>
function M.linters_by_ft()
  local out = {}
  for _, entry in pairs(langs) do
    for _, linter in ipairs(entry.lint or {}) do
      for _, ft in ipairs(entry.ft) do
        out[ft] = out[ft] or {}
        table.insert(out[ft], linter)
      end
    end
  end
  return out
end

---Filetypes grouped by conform.nvim formatter, ready for formatters_by_ft.
---@return table<string, string[]>
function M.formatters_by_ft()
  local out = {}
  for _, entry in pairs(langs) do
    for _, formatter in ipairs(entry.fmt or {}) do
      for _, ft in ipairs(entry.ft) do
        out[ft] = out[ft] or {}
        table.insert(out[ft], formatter)
      end
    end
  end
  return out
end

---Every mason package the language set needs, deduplicated.
---@return string[]
function M.all_packages()
  local out = {}
  for name in pairs(M.server_filetypes()) do
    out[#out + 1] = lsp_package(name)
  end
  for _, entry in pairs(langs) do
    for _, linter in ipairs(entry.lint or {}) do
      out[#out + 1] = tool_package(linter)
    end
    for _, formatter in ipairs(entry.fmt or {}) do
      out[#out + 1] = tool_package(formatter)
    end
  end
  return sorted_unique(out)
end

return M
