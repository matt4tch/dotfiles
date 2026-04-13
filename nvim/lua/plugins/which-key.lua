return {
  "folke/which-key.nvim",
  opts = function(_, opts)
    opts.spec = opts.spec or {}
    table.insert(opts.spec, { "<leader>t", group = "Typst", icon = "󰈙" })
    table.insert(opts.spec, { "<leader>tu", icon = "󱎘" })
    table.insert(opts.spec, { "<leader>ts", icon = "󰐊" })
    table.insert(opts.spec, { "<leader>tS", icon = "󰗚" })
    table.insert(opts.spec, { "<leader>tq", icon = "󰅖" })
    table.insert(opts.spec, { "<leader>tt", icon = "󰔡" })
    table.insert(opts.spec, { "<leader>tfy", icon = "󰆏" })
    table.insert(opts.spec, { "<leader>tfn", icon = "󰜺" })
    table.insert(opts.spec, { "<leader>tft", icon = "󰯎" })
    table.insert(opts.spec, { "<leader>tc", icon = "󰑓" })
  end,
}
