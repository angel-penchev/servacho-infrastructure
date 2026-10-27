-- lazyvim.nix's check: `nvim --headless hello.c -c 'luafile lazyvim-check.lua'`,
-- run in the build sandbox, which has no network, with lazyvim.nix's init.lua
-- as the system config. Fails unless LazyVim starts with every plugin from
-- Nix, highlights C with treesitter and gets clangd, without an error.
local failures = {}
local function check(ok, what)
  if not ok then
    failures[#failures + 1] = what
  end
end

local function run()
  local Config = require("lazy.core.config")
  check(Config.plugins.LazyVim and Config.plugins.LazyVim._.loaded, "LazyVim isn't loaded")
  for name, plugin in pairs(Config.plugins) do
    check(
      plugin._.installed and vim.startswith(plugin.dir, "/nix/store/"),
      ("%s isn't from Nix: %s"):format(name, plugin.dir)
    )
  end

  -- Everything lazy.nvim would load later, now, to see each one load.
  require("lazy").load({ plugins = vim.tbl_keys(Config.plugins) })

  local buf = vim.api.nvim_get_current_buf()
  check(vim.bo[buf].filetype == "c", "hello.c isn't C but " .. vim.bo[buf].filetype)
  check(LazyVim.treesitter.have("c"), "no C parser")
  check(vim.treesitter.highlighter.active[buf] ~= nil, "no treesitter highlighting in hello.c")
  check(
    vim.wait(30000, function()
      return #vim.lsp.get_clients({ bufnr = buf, name = "clangd" }) > 0
    end, 200),
    "clangd didn't attach to hello.c"
  )

  local messages = vim.api.nvim_exec2("messages", { output = true }).output
  check(not messages:find("E%d+:") and not messages:lower():find("error"), "errors: " .. messages)

  if #failures > 0 then
    io.stderr:write("LazyVim check failed:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
  end
  io.stdout:write("LazyVim check passed\n")
  vim.cmd("qall!")
end

-- Headless, there is no UI, so lazy.nvim's VeryLazy (after UIEnter) and what
-- LazyVim loads on it would never come; pretend one attached.
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.api.nvim_exec_autocmds("UIEnter", {})
    vim.defer_fn(function()
      local ok, err = pcall(run)
      if not ok then
        io.stderr:write("LazyVim check failed: " .. tostring(err) .. "\n")
        vim.cmd("cquit 1")
      end
    end, 500)
  end,
})
