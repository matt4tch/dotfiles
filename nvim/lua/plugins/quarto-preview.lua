return {
  {
    "quarto-dev/quarto-nvim",
    ft = { "quarto" },
    dependencies = {
      "jmbuhr/otter.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    opts = {
      debug = false,
      closePreviewOnExit = true,
      lspFeatures = {
        enabled = true,
        chunks = "curly",
        languages = { "python", "bash", "html" },
        diagnostics = {
          enabled = true,
          triggers = { "BufWritePost" },
        },
        completion = {
          enabled = true,
        },
      },
      codeRunner = {
        enabled = false,
      },
    },
    init = function()
      vim.env.BROWSER = "/opt/homebrew/bin/qutebrowser"
      vim.env.QUARTO_PYTHON = "/opt/homebrew/bin/python3"
    end,
    keys = {
      { "<leader>ms", "<cmd>QuartoPreview<cr>", desc = "Quarto: Start preview" },
      { "<leader>mq", "<cmd>QuartoClosePreview<cr>", desc = "Quarto: Stop preview" },
    },
  },
}
