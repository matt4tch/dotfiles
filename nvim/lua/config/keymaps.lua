-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", "<leader>yp", function()
  local path = vim.fn.fnamemodify(vim.fn.expand("%:p"), ":.")
  if path == "" then
    vim.notify("No file in current buffer")
    return
  end
  local line = vim.fn.line(".")
  local result = path .. ":" .. line
  vim.fn.setreg("+", result)
  vim.notify("Yanked relative path: " .. result)
end, { desc = "Yank relative file path with line number" })

vim.keymap.set("n", "<leader>yP", function()
  local path = vim.fn.expand("%:p")
  if path == "" then
    vim.notify("No file in current buffer")
    return
  end
  local line = vim.fn.line(".")
  local result = path .. ":" .. line
  vim.fn.setreg("+", result)
  vim.notify("Yanked absolute path: " .. result)
end, { desc = "Yank absolute file path with line number" })

local notes_site = "/Users/matthew4.tch/dev/matt4tch.github.io"

local function run_notes_target(target)
  vim.cmd("botright 12split")
  vim.cmd("terminal make -C " .. vim.fn.shellescape(notes_site) .. " " .. target)
  vim.cmd("startinsert")
end

vim.keymap.set("n", "<leader>mn", function()
  run_notes_target("publish-notes")
end, { desc = "Compile and publish course notes" })
