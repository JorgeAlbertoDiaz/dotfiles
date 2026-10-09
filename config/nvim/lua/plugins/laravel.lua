-- Domain: laravel (PHP/Laravel project tooling).
--
-- adalessa/laravel.nvim turns a Laravel project into a first-class editing
-- experience: pickers (artisan, routes, makes, resources, commands), virtual
-- information on models/controllers/composer.json, Eloquent completion, code
-- actions, an integrated Tinker, and an Artisan Hub.
--
-- Requirements (verified against the plugin's own README on install):
--   * Neovim >= 0.10                -- already covered by this config's baseline.
--   * ripgrep (rg)                  -- already installed (packages/dev-core.txt).
--   * tree-sitter parsers php, json -- php comes from the `php` entry in
--                                      lua/config/langs.lua; `json` was added to
--                                      that table for exactly this consumer.
--   * plenary.nvim, nui.nvim        -- already present transitively (telescope,
--                                      neo-tree), re-declared here so the plugin
--                                      does not depend on load order.
--   * nvim-nio                      -- new; the only dependency this spec adds.
--   * A picker backend              -- telescope/fzf-lua already installed; the
--                                      default (telescope) is kept.
--   * nvim-cmp or blink.cmp         -- nvim-cmp is installed; the completion
--                                      source registers automatically.

return {
  {
    "adalessa/laravel.nvim",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-lua/plenary.nvim",
      "nvim-neotest/nvim-nio",
    },
    -- The plugin only activates inside a Laravel project. ft covers the PHP
    -- and Blade buffers; BufEnter composer.json catches a project open before
    -- any PHP file is visited (the README's own recommendation).
    ft = { "php", "blade" },
    event = { "BufEnter composer.json" },
    keys = {
      { "<leader>ll", function() Laravel.pickers.laravel() end, desc = "Laravel: Picker" },
      { "<leader>la", function() Laravel.pickers.artisan() end, desc = "Laravel: Artisan Picker" },
      { "<leader>lr", function() Laravel.pickers.routes() end, desc = "Laravel: Routes Picker" },
      { "<leader>lm", function() Laravel.pickers.make() end, desc = "Laravel: Make Picker" },
      { "<leader>lc", function() Laravel.pickers.commands() end, desc = "Laravel: Custom Commands Picker" },
      { "<leader>lo", function() Laravel.pickers.resources() end, desc = "Laravel: Resources Picker" },
      { "<leader>lh", function() Laravel.run("artisan docs") end, desc = "Laravel: Documentation" },
      { "<leader>lt", function() Laravel.commands.run("actions") end, desc = "Laravel: Code Actions" },
      { "<leader>lu", function() Laravel.commands.run("hub") end, desc = "Laravel: Artisan Hub" },
      { "<leader>lp", function() Laravel.commands.run("command_center") end, desc = "Laravel: Command Center" },
      { "<c-g>", function() Laravel.commands.run("view:finder") end, desc = "Laravel: View Finder" },
      {
        "gf",
        function()
          if Laravel.app("gf").cursorOnResource() then
            return "<cmd>lua Laravel.commands.run('gf')<cr>"
          end
          return "gf"
        end,
        expr = true,
        noremap = true,
        desc = "Laravel: Go to resource",
      },
    },
    opts = {
      features = {
        pickers = {
          -- telescope and fzf-lua are both installed; telescope is the default
          -- and the one this config's <leader>b/<leader>e already use.
          provider = "telescope",
        },
      },
    },
  },
}
