return {
  {
    "folke/persistence.nvim",
    init = function()
      vim.api.nvim_create_autocmd("VimEnter", {
        group = vim.api.nvim_create_augroup("auto_restore_tmux_session", { clear = true }),
        once = true,
        callback = function()
          if vim.env.TMUX == nil or vim.fn.argc() ~= 0 then
            return
          end

          vim.schedule(function()
            require("persistence").load()
          end)
        end,
      })
    end,
  },
}
