-- Entry point of the declarative Neovim configuration.
--
-- The load order below is deliberate and must not be shuffled:
--
--   1. 'mapleader' first. Every spec in lua/plugins/*.lua is written against
--      the leader, and lazy.nvim resolves those specs while installing keys.
--   2. Base options and autocmds next, still *before* the plugin manager, so
--      that a missing or broken lazy.nvim never takes the base editor down
--      with it. The reference config (docs/referencia/) was supposed to be
--      the safety net; here it actually is one.
--   3. lazy.nvim setup last, because it is what triggers the plugin specs.
--   4. Only then the two modules that need lazy's effects: the LSP wiring
--      registers vim.lsp.config entries and calls vim.lsp.enable(), and the
--      keymap module uses the leader that step 1 set. Both are cheap and both
--      belong to the config rather than to a plugin spec.

vim.g.mapleader = ","

-- lazy.nvim is not vendored in the repo: config/ is declarative and
-- scripts/04-setup-dotfiles.sh would overwrite any state kept here. It lives
-- in stdpath("data") (XDG_DATA_HOME/nvim), which is exactly the split
-- Neovim 0.12 expects: declarative in ~/.config, mutable in ~/.local/share.
--
-- The clone deliberately does NOT pass --branch. Cloning a branch by name
-- leaves a DETACHED HEAD, and `git pull --ff-only` then fails with "you are
-- not currently on a branch". It is a plain, complete clone for the same
-- reason: a --filter=blob:none partial clone would need a promisor fetch to
-- materialize doc/ on first use, and the manager should not depend on network
-- access after the initial clone. The version pin belongs to
-- config/nvim/lazy-lock.json, which is committed and deployed with the rest
-- of the config -- not to the bootstrap clone.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system({
    "git",
    "clone",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Could not clone lazy.nvim: " .. out, "WarningMsg" },
      { "Base config is still loaded; no plugins were installed.", "WarningMsg" },
    }, true, {})
  end
end

require("config.options")
require("config.autocmds")

if vim.uv.fs_stat(lazypath) then
  vim.opt.rtp:prepend(lazypath)
  require("lazy").setup({
    -- Root options. These apply to the manager itself, so they belong here
    -- rather than on the folke/lazy.nvim spec entry in lua/plugins/core.lua
    -- (where they do get merged, but through an obscure path).
    --
    -- badwolf is lazy-loaded, so lazy needs a colorscheme to draw its own
    -- progress UI while installing. That is `install.colorscheme`, and it must
    -- be a builtin that needs no plugin: habamax ships with Neovim.
    colorscheme = "badwolf",
    install = { colorscheme = { "habamax" } },
    ui = { border = "rounded" },
    -- Repaint on FocusGained/ShellCmdPost and re-stat on CursorHold, so
    -- files edited outside Neovim show up. notify = false keeps it silent:
    -- an out-of-date file after a git pull is normal, not worth a message.
    change_detection = { enabled = true, notify = false },
    checker = { enabled = true, notify = false },
    -- Applies to every plugin in the spec unless that spec overrides it.
    -- `lazy = true` means "load on demand", so nothing loads on startup
    -- except the specs that opt out explicitly with `lazy = false`
    -- (colorscheme and statusline have to be ready before the user can type).
    defaults = { lazy = true },
    performance = {
      rtp = {
        -- Only options VERIFIED to exist in the 0.12.5 runtime are listed
        -- here; there is no point disabling a plugin file that is not there.
        --
        -- netrw is deliberately kept. neo-tree is the file explorer, but
        -- dropping netrw would leave no browser at all if neo-tree ever
        -- fails to load.
        disabled_plugins = { "gzip", "tarPlugin", "tutor", "zipPlugin" },
      },
    },
    spec = {
      -- `import = "plugins"` picks up lua/plugins/*.lua. The older
      -- `{ "folke/lazy.nvim", import = "lazy" }` form is rejected by lazy
      -- 11.17.5: on a plugin spec, `import` names a module to import, and
      -- `lazy` is already the manager itself.
      { import = "plugins" },
    },
  })

  -- vim.lsp.config is a runtime API, not a plugin: registering the servers here
  -- means a language server starts on the first buffer of its filetype instead
  -- of on the first InsertEnter. It also runs after the manager on purpose, so
  -- that a config that is missing lazy.nvim still starts with a working editor
  -- and no servers, rather than throwing in step 3.
  require("config.lsp").setup()
  require("config.keymaps")
end
