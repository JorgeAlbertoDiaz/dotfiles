-- T4.3/T4.4: the native LSP wiring and the mason package installer.
--
-- The plan's wording was "mason.nvim wires the LSP servers ... through
-- vim.lsp.config", and mason 2.3.1 does no such thing: mason is a binary
-- installer, and `vim.lsp.config` is Neovim's own API. So this file does both
-- halves explicitly, and mason is asked for nothing more than the binaries.
--
-- There is no nvim-lspconfig here, deliberately. Neovim 0.11+ ships the LSP
-- client, and every `cmd` below is copied from nvim-lspconfig's own config for
-- the same server -- that file is the maintained authority on argv, and
-- re-deriving it from a blog post is how people end up launching
-- `typescript-language-server` without `--stdio`.
--
-- The `cmd` values, VERIFIED against nvim-lspconfig master on 2026-09-28:
--
--   html      vscode-html-language-server --stdio
--   css       vscode-css-language-server  --stdio
--   ts_ls     typescript-language-server  --stdio
--   lua_ls    lua-language-server
--   pyright   pyright-langserver          --stdio
--   phpactor  phpactor language-server
--   svelte    svelteserver                --stdio
--
-- The two entries that do not match their package name are the two that used
-- to be wrong in the wild: mason's `html-lsp` installs a binary called
-- `vscode-html-language-server`, and mason's `svelte-language-server` installs
-- one called `svelteserver`.

local langs = require("config.langs")

---Per-server settings, keyed by the name a language's `lsp` field points at.
---
---Filetypes are NOT here: they are derived from the language table, because
---javascript and typescript share ts_ls and two languages cannot both own its
---filetype list without one of them being wrong.
local servers = {
  html = {
    cmd = { "vscode-html-language-server", "--stdio" },
    init_options = {
      provideFormatter = true,
      embeddedLanguages = { css = true, javascript = true },
      configurationSection = { "html", "css", "javascript" },
    },
  },
  css = {
    cmd = { "vscode-css-language-server", "--stdio" },
    init_options = { provideFormatter = true },
    settings = { css = { validate = true } },
  },
  ts_ls = {
    cmd = { "typescript-language-server", "--stdio" },
    init_options = { hostInfo = "neovim" },
  },
  lua_ls = {
    cmd = { "lua-language-server" },
    settings = {
      Lua = {
        -- Diagnostics for `---@class`, `---@field` and friends. lua_ls
        -- understands EmmyLua annotations, and the reference's completion came
        -- from UltiSnips plus jedi, so this is the part of "Lua support" that
        -- actually pays for itself.
        diagnostics = { globals = { "vim" } },
        workspace = { checkThirdParty = false },
      },
    },
  },
  pyright = {
    cmd = { "pyright-langserver", "--stdio" },
  },
  phpactor = {
    cmd = { "phpactor", "language-server" },
  },
  svelte = {
    cmd = { "svelteserver", "--stdio" },
  },
}

-- Diagnostics presentation. This is a global option, so it is set once here
-- rather than from on_attach: an on_attach that assigns vim.diagnostic.config
-- would work, and would also mean the values depend on which buffer happened to
-- open first.
vim.diagnostic.config({
  severity_sort = true,
  float = { border = "rounded", source = true },
  -- The sign column is the point: gitsigns already owns the left margin, and
  -- this is how a lint finding becomes visible without stealing focus.
  signs = { text = { hint = ">", info = ">", warn = ">", error = ">" } },
  underline = true,
  virtual_text = { spacing = 2, source = "if_many" },
  -- Nothing about a diagnostic is more urgent while the cursor is mid-keystroke.
  update_in_insert = false,
})

---Buffer-local LSP keymaps.
---
---Single home, on purpose: the alternative is a global table in
---lua/config/keymaps.lua that only applies to files with a server attached,
---which is exactly the kind of half-mapping that silently does nothing.
---`K` is deliberately absent -- Neovim 0.12 already maps it to
---vim.lsp.buf.hover() on LspAttach (see :h lsp.txt "Defaults"), and a second
---mapping would be a duplicate of a built-in.
local function attach_keymaps(client, bufnr)
  local opts = { buffer = bufnr, silent = true }
  local map = function(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, vim.tbl_extend("force", opts, { desc = desc }))
  end

  -- gd is the reference's vim-racer `gd` (def), the one mapping the pruned
  -- reference carries over verbatim. It is a no-leader key, so it does not
  -- collide with fugitive's <leader>gd (Gvdiffsplit).
  map("gd", vim.lsp.buf.definition, "LSP: go to definition")
  -- Also no-leader, and for the same reason: <leader>gr is fugitive's GRemove.
  map("gr", vim.lsp.buf.references, "LSP: list references")
  map("<leader>rn", vim.lsp.buf.rename, "LSP: rename symbol")
  map("<leader>ra", vim.lsp.buf.code_action, "LSP: code action")
  map("<leader>ld", vim.diagnostic.open_float, "LSP: show diagnostic under cursor")
  map("[d", vim.diagnostic.goto_prev, "LSP: previous diagnostic")
  map("]d", vim.diagnostic.goto_next, "LSP: next diagnostic")

  if client.supports_method("textDocument/hover") then
    -- K is Neovim's default here. Mapping it again would only risk diverging
    -- from the built-in, so the reference's phpactor `<Leader>K` and jedi's
    -- documentation_command = "K" are both satisfied by the 0.12 default.
    map("gK", vim.lsp.buf.hover, "LSP: hover documentation")
  end
end

local function setup_lsp()
  for name, server in pairs(servers) do
    vim.lsp.config(name, vim.tbl_extend("force", server, {
      filetypes = langs.server_filetypes()[name],
      -- The reference's <leader>e / <leader>te workflow, and everything else it
      -- had, went through ':e' with no project-root notion. root_markers is how
      -- Neovim finds one, and it is the piece that replaces the tool-specific
      -- "cd to the project" commands the reference called.
      root_markers = { ".git", "package.json", "composer.json", "pyproject.toml", ".luarc.json" },
      on_attach = attach_keymaps,
    }))
    vim.lsp.enable(name)
  end
end

---Install every mason package the language table asks for.
---
---The plan called for `mason.ensure_installed`. mason 2.3.1 has no such
---function -- it was removed with the `ensure_installed` option, and the
---replacement is a manual loop, which is what this is.
---
---VERIFIED against mason 2.3.1 source (commit 2a6940a) on 2026-09-28:
---   * `mason-registry.get_package(name)` returns a Package, or errors.
---   * `Package:is_installed()` and `Package:install(opts, callback)` exist;
---     install() returns an InstallHandle.
---   * The events `package:install:success` / `package:install:failed` are
---     emitted on the `mason-registry` singleton, so subscribing to them is the
---     supported way to know when a binary landed.
---
---It is deliberately fire-and-forget. Blocking startup on a ~200 MB download
---would make the first `:nvim` after a fresh deploy unusable, and the servers
---start themselves as soon as their binary exists -- see the LspAttach retry
---below.
local function setup_mason()
  local registry = require("mason-registry")
  local wanted = langs.all_packages()
  local pending = {}

  for _, name in ipairs(wanted) do
    local ok, pkg = pcall(registry.get_package, name)
    if not ok then
      -- get_package errors on an unknown name, which is what "this tool is not
      -- in the registry" looks like. Silently skipping would hide a typo in
      -- lua/config/langs.lua behind a server that never starts.
      vim.notify(
        ("mason: %q is not in the registry, nothing installed for it"):format(name),
        vim.log.levels.ERROR
      )
    elseif not pkg:is_installed() then
      pending[#pending + 1] = name
    end
  end

  if #pending == 0 then
    return
  end

  -- A client whose binary was missing when the buffer opened never started:
  -- vim.lsp's own enable-callback checks `executable(cmd[1])` and refuses to
  -- start, logging an error instead. Re-firing FileType is the supported way to
  -- make it try again -- the callback re-runs `can_start` for every
  -- uninitialized client on that buffer, so nothing here has to poke a Client
  -- object. It is scoped to buffers that are actually loaded and actually claim
  -- a filetype we know, so it cannot fire for a buffer that has no business
  -- starting a server.
  local function retry_open_buffers()
    local claimed = langs.filetypes()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        local ft = vim.bo[bufnr].filetype
        if ft ~= "" and vim.tbl_contains(claimed, ft) then
          pcall(vim.api.nvim_exec_autocmds, "FileType", { buffer = bufnr })
        end
      end
    end
  end

  registry:on("package:install:success", function(pkg)
    if vim.tbl_contains(pending, pkg.name) then
      vim.notify(("mason: installed %s"):format(pkg.name))
      retry_open_buffers()
    end
  end)

  registry:on("package:install:failed", function(pkg)
    if vim.tbl_contains(pending, pkg.name) then
      vim.notify(
        ("mason: failed to install %s -- the LSP for that language will not start"):format(pkg.name),
        vim.log.levels.ERROR
      )
    end
  end)

  for _, name in ipairs(pending) do
    local pkg = registry.get_package(name)
    if pkg then
      pcall(pkg.install, pkg)
    end
  end
end

local M = {}

function M.setup()
  setup_lsp()
  -- Mason is a lazy spec loaded on its own commands, so it may not be on the
  -- runtimepath yet when this file runs. Its bin directory only appears on
  -- PATH once mason itself loads, and the servers are started by FileType
  -- events that fire later -- so the installer is deferred to the end of the
  -- startup, by which time lazy has loaded it.
  vim.defer_fn(function()
    local ok, err = pcall(require, "mason-registry")
    if not ok then
      -- Mason is only absent if the deploy script has not run yet. Nothing to
      -- install, nothing broken: :Mason is still the manual way in.
      vim.g.mason_setup_error = tostring(err)
      return
    end
    setup_mason()
  end, 0)
end

return M
