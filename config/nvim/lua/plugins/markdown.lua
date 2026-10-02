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
      -- Alt + p toggles the browser preview while editing a markdown file.
      vim.keymap.set(
        "n",
        "<A-p>",
        "<Plug>MarkdownPreviewToggle",
        { silent = true, desc = "Toggle Markdown preview in browser" }
      )
    end,
  },
}
