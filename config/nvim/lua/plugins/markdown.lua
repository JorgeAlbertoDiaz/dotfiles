-- Domain: markdown (preview and markdown-specific tooling).

return {
  -- markdown-preview.nvim: opens a live Markdown preview in the browser.
  --
  -- Loaded only for markdown files or when explicitly invoked. The build step
  -- installs the Node dependencies the preview server needs.
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    -- Instala las dependencias Node del servidor de preview directamente
    -- en el directorio app/ del plugin. Se evita mkdp#util#install() porque
    -- lazy.nvim no siempre tiene la función autoload disponible en build.
    build = "cd app && npm install",
    config = function()
      -- Initial preview theme. The preview server re-reads this variable on every
      -- render, so flipping it and opening a preview again is enough to switch.
      vim.g.mkdp_theme = "dark"

      -- How the preview URL reaches a browser. Left alone, the plugin spawns
      -- xdg-open from its Node process, which only reports the failure when
      -- the binary itself is missing. A shell with no display -- a detached
      -- terminal server started from a tty -- makes xdg-open fall back to text
      -- browsers and exit 0, so the preview never opens and nothing is said
      -- about it. config.browser decides between xdg-open and the desktop
      -- portal, and notifies with the URL when neither works.
      --
      -- The plugin calls the opener by name from its Node process, so it has
      -- to be a real Vimscript function. The `v:lua.name` form is an expression
      -- prefix, and nvim_call_function rejects it with E117, which the plugin
      -- reports as an unhandled rejection instead of opening anything.
      vim.cmd([[
        function! MarkdownPreviewOpenUrl(url) abort
          call luaeval('require("config.browser").url(_A)', a:url)
        endfunction
      ]])
      vim.g.mkdp_browserfunc = "MarkdownPreviewOpenUrl"

      -- Toggle the preview background between dark and light. The theme is
      -- re-read the next time a preview is opened (or reopened with <A-p>).
      _G.toggle_markdown_theme = function()
        local next = vim.g.mkdp_theme == "dark" and "light" or "dark"
        vim.g.mkdp_theme = next
        vim.notify(
          "Markdown preview theme: " .. next .. " (reopen preview to apply)",
          vim.log.levels.INFO
        )
      end

      -- Alt + p toggles the browser preview while editing a markdown file.
      vim.keymap.set(
        "n",
        "<A-p>",
        "<Plug>MarkdownPreviewToggle",
        { silent = true, desc = "Toggle Markdown preview in browser" }
      )

      -- Alt + b toggles the preview background between dark and light.
      vim.keymap.set(
        "n",
        "<A-b>",
        "<cmd>lua toggle_markdown_theme()<cr>",
        { silent = true, desc = "Toggle Markdown preview background (dark/light)" }
      )
    end,
  },
}
