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
  vim.system({ "make", "-C", notes_site, target }, { text = true }, function(result)
    vim.schedule(function()
      local stdout = vim.trim(result.stdout or "")
      local stderr = vim.trim(result.stderr or "")

      if result.code == 0 then
        local message = stdout:find("already up to date", 1, true)
            and "Course notes are already up to date"
          or "Course notes committed and pushed successfully"
        vim.notify(message, vim.log.levels.INFO, { title = "Publish notes" })
        return
      end

      local details = table.concat(vim.tbl_filter(function(output)
        return output ~= ""
      end, { stderr, stdout }), "\n")

      if details ~= "" then
        vim.api.nvim_echo({
          { "[publish-notes error]\n" .. details, "ErrorMsg" },
        }, true, {})
      end

      vim.notify(
        "Course notes publish failed; see :messages",
        vim.log.levels.ERROR,
        { title = "Publish notes" }
      )
    end)
  end)
end

vim.keymap.set("n", "<leader>mn", function()
  run_notes_target("publish-notes")
end, { desc = "Compile and publish course notes" })
