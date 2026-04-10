return {
  "nvim-mini/mini.pairs",
  ft = "typst",
  opts = {},
  config = function(_, opts)
    local mp = require("mini.pairs")
    mp.setup(opts)
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "typst",
      callback = function(ev)
        mp.map_buf(ev.buf, "i", "$", {
          action = "closeopen",
          pair = "$$",
          neigh_pattern = "[^\\].",
          register = { cr = true },
        })
      end,
    })
  end,
}
