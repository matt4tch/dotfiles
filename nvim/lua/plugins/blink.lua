return {
  "saghen/blink.cmp",
  dependencies = {
    { "L3MON4D3/LuaSnip", version = "v2.*" },
  },
  opts = {
    snippets = { preset = "luasnip" },
    sources = {
      default = {
        "lsp",
        "path",
        "snippets",
        "buffer",
      },
    },
    completion = {
      ghost_text = { enabled = false },
    },
  },
}
