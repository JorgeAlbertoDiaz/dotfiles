-- Domain: desktop theme (light/dark), shared with the sway session.
--
-- The desktop theme is ONE file: $XDG_STATE_HOME/dotfiles/tema, containing
-- "dark" or "light". It is written by config/sway/scripts/sway-theme.sh, the
-- same script the notification panel button and Super+Shift+t call. Neovim only
-- reads it: the editor never diverges from the session on its own.
--
-- `apply()` is what the toggle calls over `nvim --server <socket>
-- --remote-expr`, so an editor that is already open switches theme without
-- losing buffers.
--
-- Palette values mirror docs/tema-claro-oscuro.md (the same rust palette the
-- rest of the desktop uses); if they change there, they change here.

local M = {}

M.palette = {
  dark = { background = "#2b2b27", foreground = "#cecece" },
  light = { background = "#e1e1db", foreground = "#262625" },
}

M.colorschemes = { dark = "badwolf", light = "dayfox" }

-- Path of the shared state file, honouring XDG when the session sets it.
function M.state_path()
  local state = vim.env.XDG_STATE_HOME
  if state == nil or state == "" then
    state = (vim.env.HOME or "~") .. "/.local/state"
  end
  return state .. "/dotfiles/tema"
end

-- Current theme: "dark" when the file is missing or unreadable (a fresh clone
-- has never toggled, and dark is the default the dotfiles deploy).
function M.current()
  local file = io.open(M.state_path(), "r")
  if file == nil then
    return "dark"
  end
  local line = file:read("*l") or ""
  file:close()
  return line:match("^%s*light") and "light" or "dark"
end

function M.colorscheme()
  return M.colorschemes[M.current()]
end

-- Apply the current theme to this instance.
-- pcall keeps a missing plugin from turning the toggle into an error: without
-- dayfox installed, light mode simply keeps whatever colorscheme is loaded.
function M.apply()
  local theme = M.current()
  vim.o.background = theme
  local ok, err = pcall(vim.cmd.colorscheme, M.colorschemes[theme])
  if not ok then
    vim.notify(("colorscheme %s no disponible: %s"):format(M.colorschemes[theme], err), vim.log.levels.WARN)
  end
  return theme
end

return M
