-- ╔══════════════════════════════════════════════════════╗
-- ║          OMGENTLY — Neovim Configuration            ║
-- ╚══════════════════════════════════════════════════════╝

vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- ── Options ─────────────────────────────────────────────
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.termguicolors = true
vim.opt.clipboard = "unnamedplus"
vim.opt.updatetime = 50
vim.opt.signcolumn = "yes"
vim.opt.cursorline = true
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.wrap = false

-- Indentation
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.smartindent = true

-- Search
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.incsearch = true

-- Persistent undo
vim.opt.undofile = true
vim.opt.swapfile = false
vim.opt.backup = false

-- ── Keymaps ─────────────────────────────────────────────
vim.keymap.set("n", "<leader>w", "<cmd>w<CR>", { desc = "Save" })
vim.keymap.set("n", "<leader>q", "<cmd>q<CR>", { desc = "Quit" })
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear highlights" })

-- Window navigation
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Focus left" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Focus down" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Focus up" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Focus right" })

-- Move lines
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Better paste (don't clobber register)
vim.keymap.set("x", "<leader>p", '"_dP', { desc = "Paste without yank" })

-- ── Minimal Tokyo Night Colorscheme (No plugins) ────────
-- Jika Anda ingin plugin manager (lazy.nvim), ganti blok
-- ini dengan: require("lazy").setup({ "folke/tokyonight.nvim" })
vim.cmd [[
  highlight Normal        guifg=#a9b1d6 guibg=#1a1b26
  highlight NormalFloat    guifg=#a9b1d6 guibg=#24283b
  highlight CursorLine     guibg=#24283b
  highlight Visual         guibg=#414868
  highlight LineNr         guifg=#565f89
  highlight CursorLineNr   guifg=#7aa2f7 gui=bold
  highlight Comment        guifg=#565f89 gui=italic
  highlight String         guifg=#9ece6a
  highlight Function       guifg=#7aa2f7
  highlight Keyword        guifg=#bb9af7
  highlight Number         guifg=#ff9e64
  highlight Type           guifg=#0db9d7
  highlight Constant       guifg=#ff9e64
  highlight Identifier     guifg=#c0caf5
  highlight Statement      guifg=#bb9af7
  highlight Operator       guifg=#89ddff
  highlight PreProc        guifg=#7aa2f7
  highlight Special        guifg=#f7768e
  highlight Error          guifg=#f7768e guibg=NONE
  highlight StatusLine     guifg=#a9b1d6 guibg=#24283b
  highlight StatusLineNC   guifg=#565f89 guibg=#1a1b26
  highlight Pmenu          guifg=#a9b1d6 guibg=#24283b
  highlight PmenuSel       guifg=#1a1b26 guibg=#7aa2f7
  highlight Search         guifg=#1a1b26 guibg=#e0af68
  highlight MatchParen     guifg=#ff9e64 gui=bold
  highlight DiagnosticError guifg=#f7768e
  highlight DiagnosticWarn  guifg=#e0af68
  highlight DiagnosticInfo  guifg=#7aa2f7
  highlight DiagnosticHint  guifg=#9ece6a
  highlight SignColumn      guibg=#1a1b26
]]
