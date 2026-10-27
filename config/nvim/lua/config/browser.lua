-- Domain: open a URL in the browser of the desktop session.
--
-- Handing a URL to a browser is two different problems depending on where
-- Neovim is running:
--
--   * Inside a graphical session, xdg-open is the opener. It honours the XDG
--     default browser (firefox.desktop here), and that is the behaviour the
--     rest of the repo already depends on -- scripts/10-setup-mime-apps.sh
--     sets that default, and :GBrowse goes through vim.ui.open.
--
--   * Inside a shell with no display -- a detached terminal server such as
--     herdr or tmux, started from a tty and therefore outside the compositor
--     -- xdg-open finds no desktop and falls back to text browsers
--     (www-browser, links2, elinks, links, lynx). None of them is installed
--     here, so it prints the page HTML to the terminal and exits 0. Because
--     the exit code is a success, the caller reports nothing: no browser, no
--     error. That is exactly how markdown-preview.nvim fails silently, since
--     it spawns xdg-open and only surfaces a message on spawn errors.
--
-- The second case is what the desktop portal exists for. xdg-desktop-portal
-- runs *inside* the graphical session, so a D-Bus call to its OpenURI method
-- opens the URL there no matter how detached the caller is. The session bus
-- address is inherited even by a tty login, so that is the only piece of
-- session state this needs.

local M = {}

---Whether this process can reach a compositor directly.
---
---An empty variable counts as absent: sessions inherit WAYLAND_DISPLAY and
---DISPLAY as empty strings often enough that a nil check would be wrong.
---@param env table<string, string|nil>|nil defaults to the process environment
---@return boolean
function M.has_display(env)
  env = env or vim.env
  return (env.WAYLAND_DISPLAY or "") ~= "" or (env.DISPLAY or "") ~= ""
end

---Decide how `url` should be opened in this session.
---
---Kept separate from the execution so the decision can be asserted without
---launching a browser. The argv is an array because both openers are spawned
---without a shell: the URL stays a single element and is never word-split.
---@param url string
---@param env table<string, string|nil>|nil defaults to the process environment
---@return { kind: "xdg-open"|"portal", argv: string[] }
function M.plan(url, env)
  if M.has_display(env) then
    return { kind = "xdg-open", argv = { "xdg-open", url } }
  end

  return {
    kind = "portal",
    argv = {
      "gdbus",
      "call",
      "--session",
      "--dest",
      "org.freedesktop.portal.Desktop",
      "--object-path",
      "/org/freedesktop/portal/desktop",
      "--method",
      "org.freedesktop.portal.OpenURI.OpenURI",
      -- parent_window: no window handle exists for a terminal caller.
      "",
      url,
      -- options: empty. OpenURI takes them as a{sv}; gdbus parses this.
      "{}",
    },
  }
end

---Open `url` in the session browser, and say so when that was impossible.
---
---The notification matters as much as the open: the failure this module was
---written for produced no feedback at all, so the URL is always shown when the
---opener cannot do its job.
---@param url string
function M.url(url)
  local plan = M.plan(url)

  local ok, err = pcall(vim.system, plan.argv, { text = true }, function(result)
    if result.code == 0 then
      return
    end
    local reason = vim.trim(result.stderr or "")
    if reason == "" then
      reason = "exit code " .. result.code
    end
    vim.schedule(function()
      vim.notify(
        string.format("Could not open %s with %s: %s", url, plan.kind, reason),
        vim.log.levels.WARN
      )
    end)
  end)

  if not ok then
    vim.notify(string.format("Could not open %s: %s", url, tostring(err)), vim.log.levels.WARN)
  end
end

return M
