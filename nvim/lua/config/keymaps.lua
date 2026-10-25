-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

local keymap = vim.keymap

-- ============================================================
-- SYSTEM CLIPBOARD, SELECT ALL & FILE SAVING (NO SPACE)
-- ============================================================
-- Select All (Ctrl+A)
keymap.set({ "n", "v" }, "<C-a>", "ggVG", { desc = "Select all" })
keymap.set("i", "<C-a>", "<esc>ggVG", { desc = "Select all" })

-- Copy (Ctrl+C)
keymap.set("v", "<C-c>", '"+y', { desc = "Copy to clipboard" })

-- Cut (Ctrl+X): cuts selection in visual mode, cuts current line in normal/insert mode
keymap.set("v", "<C-x>", '"+d', { desc = "Cut selection to clipboard" })
keymap.set("n", "<C-x>", '"+dd', { desc = "Cut line to clipboard" })
keymap.set("i", "<C-x>", '<esc>"+ddi', { desc = "Cut line to clipboard" })

-- Paste (Ctrl+V)
keymap.set({ "n", "v" }, "<C-v>", '"+p', { desc = "Paste from clipboard" })
keymap.set("c", "<C-v>", "<C-r>+", { desc = "Paste from clipboard in command line" })

-- Save (Ctrl+S)
keymap.set({ "i", "x", "n", "s" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save File" })

-- ============================================================
-- LINE & BLOCK CLONING (DUPLICATION) (NO SPACE)
-- ============================================================
-- Clone single line down / up: Alt+Shift+Down or Ctrl+Shift+D
keymap.set("n", "<A-S-Down>", "<cmd>copy .<cr>", { desc = "Duplicate line down" })
keymap.set("n", "<A-S-Up>", "<cmd>copy .-1<cr>", { desc = "Duplicate line up" })
keymap.set("n", "<C-S-d>", "<cmd>copy .<cr>", { desc = "Duplicate line down" })

-- Clone visual selection down / up
keymap.set("v", "<A-S-Down>", ":'<,'>copy '><cr>gv", { desc = "Duplicate block down" })
keymap.set("v", "<A-S-Up>", ":'<,'>copy '<-1<cr>gv", { desc = "Duplicate block up" })
keymap.set("v", "<C-S-d>", ":'<,'>copy '><cr>gv", { desc = "Duplicate block down" })

-- ============================================================
-- LANGUAGE-AWARE MULTI-LINE COMMENTING (Ctrl+K) (NO SPACE)
-- ============================================================
keymap.set("n", "<C-k>", "gcc", { remap = true, desc = "Toggle line comment" })
keymap.set("v", "<C-k>", "gc", { remap = true, desc = "Toggle comment block" })

-- ============================================================
-- BRACKET & SCOPE MATCH JUMPER (%) (NO SPACE)
-- ============================================================
keymap.set({ "n", "v" }, "<M-m>", "%", { remap = true, desc = "Jump to matching bracket/tag" })

-- ============================================================
-- VISUAL DEBUGGER CONTROLS (DAP) (NO SPACE - FUNCTION & ALT KEYS)
-- ============================================================
keymap.set("n", "<F9>", function() require("dap").toggle_breakpoint() end, { desc = "Toggle Breakpoint" })
keymap.set("n", "<F5>", function() require("dap").continue() end, { desc = "Debugger: Continue / Start" })
keymap.set("n", "<F10>", function() require("dap").step_over() end, { desc = "Debugger: Step Over" })
keymap.set("n", "<F11>", function() require("dap").step_into() end, { desc = "Debugger: Step Into" })
keymap.set("n", "<F12>", function() require("dap").step_out() end, { desc = "Debugger: Step Out" })
keymap.set("n", "<S-F5>", function() require("dap").terminate() end, { desc = "Terminate Debug Session" })
keymap.set("n", "<M-t>", function() require("dap").terminate() end, { desc = "Terminate Debug Session" })
keymap.set("n", "<F8>", function() require("dapui").toggle() end, { desc = "Toggle Debugger UI (Variables & Scopes)" })
keymap.set("n", "<M-u>", function() require("dapui").toggle() end, { desc = "Toggle Debugger UI (Variables & Scopes)" })
keymap.set({ "n", "v" }, "<F4>", function() require("dapui").eval() end, { desc = "Evaluate / Inspect Variable Result" })
keymap.set({ "n", "v" }, "<M-e>", function() require("dapui").eval() end, { desc = "Evaluate / Inspect Variable Result" })
keymap.set("n", "<M-r>", function() require("dap").repl.toggle() end, { desc = "Toggle Debug REPL Console" })

-- ============================================================
-- QUICK TERMINAL CODE RUNNER (F6 / Ctrl+F5) (NO SPACE)
-- ============================================================
local function run_current_file()
  local ft = vim.bo.filetype
  local file = vim.fn.expand("%:p")
  if file == "" then
    vim.notify("No file to run", vim.log.levels.WARN)
    return
  end
  vim.cmd("silent! write")

  local cmd = nil
  if ft == "python" then
    local venv_python = vim.fn.findfile(".venv/bin/python", ".;")
    local py = (venv_python ~= "" and venv_python)
      or (os.getenv("VIRTUAL_ENV") and (os.getenv("VIRTUAL_ENV") .. "/bin/python"))
      or "python3"
    cmd = string.format("%s %s", py, vim.fn.shellescape(file))
  elseif ft == "sh" or ft == "bash" then
    cmd = string.format("bash %s", vim.fn.shellescape(file))
  elseif ft == "lua" then
    cmd = string.format("nvim -l %s", vim.fn.shellescape(file))
  elseif ft == "javascript" or ft == "typescript" then
    cmd = string.format("node %s", vim.fn.shellescape(file))
  elseif ft == "rust" then
    cmd = "cargo run"
  elseif ft == "java" then
    cmd = string.format("java %s", vim.fn.shellescape(file))
  end

  if cmd then
    if package.loaded["snacks"] and Snacks and Snacks.terminal then
      Snacks.terminal(cmd, { win = { position = "bottom", height = 0.3 } })
    else
      vim.cmd("split | terminal " .. cmd)
    end
  else
    vim.notify("No runner configured for filetype: " .. ft, vim.log.levels.INFO)
  end
end

keymap.set("n", "<F6>", run_current_file, { desc = "Run current file in terminal" })
keymap.set("n", "<C-F5>", run_current_file, { desc = "Run current file in terminal" })
keymap.set("n", "<M-F5>", run_current_file, { desc = "Run current file in terminal" })
