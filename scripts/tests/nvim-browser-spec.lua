-- Spec: config/nvim/lua/config/browser.lua
--
-- Run from the repository root:
--
--   nvim --headless -u NONE --cmd "set rtp+=$(pwd)/config/nvim" \
--        -l scripts/tests/nvim-browser-spec.lua
--
-- The rtp entry must be absolute: Neovim's Lua loader ignores a relative one,
-- and require("config.browser") then fails with a misleading "module not
-- found".
--
-- The rules under test are the decision this module makes, not the `xdg-open`
-- or `gdbus` binary itself: whether a URL is handed to xdg-open or to the
-- desktop portal, and with exactly which argv. The argv matters because it is
-- spawned without a shell, so the URL has to be one element and never a
-- candidate for word splitting.

local failures = 0
local checks = 0

local function check(label, condition, detail)
  checks = checks + 1
  if condition then
    io.write("ok   " .. label .. "\n")
  else
    failures = failures + 1
    io.write("FAIL " .. label .. (detail and ("\n     " .. detail) or "") .. "\n")
  end
end

local function eq(label, actual, expected)
  check(label, actual == expected, string.format("expected %q, got %q", tostring(expected), tostring(actual)))
end

local function joined(argv)
  return table.concat(argv, " ")
end

local browser = require("config.browser")

-- One URL with characters that a shell would treat specially. Spawning an argv
-- array must leave it untouched.
local URL = "http://localhost:8765/page/1?x=1&y=2"

-- Rule: inside a Wayland session, xdg-open is the opener; it honours the XDG
-- default browser, which is the behaviour the rest of the repo relies on.
local wayland = browser.plan(URL, { WAYLAND_DISPLAY = "wayland-1" })
eq("wayland session uses xdg-open", wayland.kind, "xdg-open")
eq("wayland argv", joined(wayland.argv), "xdg-open " .. URL)

-- Rule: an X11 DISPLAY is equally a graphical session.
local x11 = browser.plan(URL, { DISPLAY = ":0" })
eq("x11 session uses xdg-open", x11.kind, "xdg-open")

-- Rule: with no display at all -- a terminal server such as herdr or tmux
-- started from a tty -- xdg-open would fall back to text browsers and exit 0
-- in silence. That is the case the portal covers.
local tty = browser.plan(URL, { XDG_SESSION_TYPE = "tty" })
eq("no display uses the portal", tty.kind, "portal")
check("no display never uses xdg-open", not joined(tty.argv):find("xdg%-open") , joined(tty.argv))
eq("portal argv prefix", joined({ tty.argv[1], tty.argv[2], tty.argv[3] }), "gdbus call --session")
eq(
  "portal method",
  table.concat({ tty.argv[4], tty.argv[5], tty.argv[6], tty.argv[7], tty.argv[8], tty.argv[9] }, " "),
  "--dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop --method org.freedesktop.portal.OpenURI.OpenURI"
)
eq("portal parent_window is empty", tty.argv[10], "")
eq("portal url is one argv element", tty.argv[11], URL)
eq("portal options are empty", tty.argv[12], "{}")
eq("portal argv has no extra element", #tty.argv, 12)

-- Rule: an empty variable is the same as an unset one. Sessions inherit these
-- as empty strings often enough that "not nil" would be the wrong test.
local empty = browser.plan(URL, { WAYLAND_DISPLAY = "", DISPLAY = "" })
eq("empty display variables mean no display", empty.kind, "portal")

-- Rule: a real display wins over an empty one, whatever the order.
local mixed = browser.plan(URL, { WAYLAND_DISPLAY = "", DISPLAY = ":1" })
eq("one empty and one set display is a session", mixed.kind, "xdg-open")

io.write(string.format("\n%d checks, %d failures\n", checks, failures))
os.exit(failures == 0 and 0 or 1)
