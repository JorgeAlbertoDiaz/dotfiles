-- Domain: core (the plugin manager itself).
--
-- The bootstrap -- cloning lazy.nvim into stdpath("data") and putting it on
-- 'runtimepath' -- has to run before this file is even readable, so it lives
-- in init.lua. What is left here is the manager's own spec and the options
-- that apply to every other plugin in lua/plugins/.

return {
  {
    "folke/lazy.nvim",
    --
    -- No `version` on purpose. The usual "version = 'stable'" is not a real
    -- value here: folke/lazy.nvim has no `stable` branch (only `main`), so
    -- lazy silently resolves it to the default branch anyway. lazy's own docs
    -- are explicit that a stale `version` tends to break the install. The real
    -- pin is config/nvim/lazy-lock.json, which is committed and deployed with
    -- the rest of the config, so every machine lands on the same commits.
    --
    -- This entry exists to register the manager. The manager's root options
    -- (colorscheme, ui, change_detection, checker, defaults, performance) live
    -- in the setup() call in init.lua, NOT here: lazy builds Config.options
    -- from the setup() arguments only, so keys on this spec entry are inert.
  },
}
