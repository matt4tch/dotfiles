return {
  "chomosuke/typst-preview.nvim",
  ft = "typst",
  version = "1.*",
  opts = {
    open_cmd = "qutebrowser %s",
    dependencies_bin = {
      ["tinymist"] = "tinymist",
    },
    get_root = function(path_of_main_file)
      local root = os.getenv("TYPST_ROOT")
      if root then
        return root
      end

      local main_dir = vim.fs.dirname(vim.fn.fnamemodify(path_of_main_file, ":p"))
      local found = vim.fs.find({ ".typst-root", "typst.toml", ".git" }, { path = main_dir, upward = true })
      if #found > 0 then
        return vim.fs.dirname(found[1])
      end

      return main_dir
    end,
  },
  keys = {
    { "<leader>tu", "<cmd>TypstPreviewUpdate<cr>", desc = "Typst: Update/refresh binaries" },
    { "<leader>ts", "<cmd>TypstPreview document<cr>", desc = "Typst: Start preview (document)" },
    { "<leader>tS", "<cmd>TypstPreview slide<cr>", desc = "Typst: Start preview (slide)" },
    { "<leader>tq", "<cmd>TypstPreviewStop<cr>", desc = "Typst: Stop preview" },
    { "<leader>tt", "<cmd>TypstPreviewToggle<cr>", desc = "Typst: Toggle preview" },
    { "<leader>tfy", "<cmd>TypstPreviewFollowCursor<cr>", desc = "Typst: Follow cursor (enable)" },
    { "<leader>tfn", "<cmd>TypstPreviewNoFollowCursor<cr>", desc = "Typst: Follow cursor (disable)" },
    { "<leader>tft", "<cmd>TypstPreviewFollowCursorToggle<cr>", desc = "Typst: Follow cursor (toggle)" },
    { "<leader>tc", "<cmd>TypstPreviewSyncCursor<cr>", desc = "Typst: Sync preview to cursor" },
  },
}
