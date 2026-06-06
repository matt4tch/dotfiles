local quarto_preview_job = nil
local quarto_preview_port = 5015
local quarto_preview_url = "http://127.0.0.1:" .. quarto_preview_port .. "/"

local function quarto_preview_running()
  return quarto_preview_job and quarto_preview_job:wait(0) == nil
end

local function quarto_preview_port_busy()
  vim.fn.system({
    "lsof",
    "-nP",
    "-iTCP:" .. quarto_preview_port,
    "-sTCP:LISTEN",
  })
  return vim.v.shell_error == 0
end

local function open_quarto_preview()
  vim.system({ "/opt/homebrew/bin/qutebrowser", quarto_preview_url }, { detach = true })
end

local function quarto_preview_bg()
  if quarto_preview_running() then
    return
  end

  if quarto_preview_port_busy() then
    open_quarto_preview()
    return
  end

  local file = vim.api.nvim_buf_get_name(0)
  if vim.fn.fnamemodify(file, ":e") ~= "qmd" then
    return
  end

  local cwd = vim.fs.dirname(file)

  quarto_preview_job = vim.system({
    "quarto",
    "preview",
    file,
    "--render",
    "html",
    "--execute",
    "--cache",
    "--execute-daemon",
    "--port",
    tostring(quarto_preview_port),
    "--no-browser",
  }, {
    cwd = cwd,
    text = true,
  }, function(obj)
    quarto_preview_job = nil
    if obj.code ~= 0 then
      vim.schedule(function()
        vim.notify(obj.stderr ~= "" and obj.stderr or "Quarto preview failed", vim.log.levels.ERROR)
      end)
    end
  end)

  vim.defer_fn(function()
    open_quarto_preview()
  end, 1200)
end

local function quarto_close_preview_bg()
  if quarto_preview_running() then
    quarto_preview_job:kill(15)
    quarto_preview_job = nil
    vim.notify("Closed Quarto preview")
  end
end

vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = quarto_close_preview_bg,
})

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
      { "<leader>ms", quarto_preview_bg, desc = "Quarto: Start HTML preview" },
      { "<leader>mq", quarto_close_preview_bg, desc = "Quarto: Stop preview" },
    },
  },
}
