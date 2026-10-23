-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--
local keymap = vim.keymap

-- Copy / Cut / Paste with System Clipboard using Ctrl keybindings
keymap.set("v", "<C-c>", '"+y', { desc = "Copy to clipboard" })
keymap.set("v", "<C-x>", '"+d', { desc = "Cut to clipboard" })
keymap.set({ "n", "v" }, "<C-v>", '"+p', { desc = "Paste from clipboard" })
keymap.set({ "i", "x", "n", "s" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save File" })
