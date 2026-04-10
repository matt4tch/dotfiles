return {
  "chomosuke/typst-preview.nvim",
  ft = "typst",
  version = "1.*",
  opts = {
    open_cmd = "qutebrowser %s",
    dependencies_bin = {
      ["tinymist"] = "tinymist",
    },
  }, -- lazy.nvim will call setup({})
  keys = {
    -- Core
    { "<leader>tu", "<cmd>TypstPreviewUpdate<cr>", desc = "Typst: Update/refresh binaries" },
    { "<leader>ts", "<cmd>TypstPreview document<cr>", desc = "Typst: Start preview (document)" },
    { "<leader>tS", "<cmd>TypstPreview slide<cr>", desc = "Typst: Start preview (slide)" },
    { "<leader>tq", "<cmd>TypstPreviewStop<cr>", desc = "Typst: Stop preview" },
    { "<leader>tt", "<cmd>TypstPreviewToggle<cr>", desc = "Typst: Toggle preview" },

    -- Follow-cursor controls
    { "<leader>tfy", "<cmd>TypstPreviewFollowCursor<cr>", desc = "Typst: Follow cursor (enable)" },
    { "<leader>tfn", "<cmd>TypstPreviewNoFollowCursor<cr>", desc = "Typst: Follow cursor (disable)" },
    { "<leader>tft", "<cmd>TypstPreviewFollowCursorToggle<cr>", desc = "Typst: Follow cursor (toggle)" },

    -- One-shot sync (jump preview to current cursor)
    { "<leader>tc", "<cmd>TypstPreviewSyncCursor<cr>", desc = "Typst: Sync preview to cursor" },
  },
}
