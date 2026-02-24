vim.g.mapleader = " "

-- 기본 옵션
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = 'a'
vim.opt.clipboard = "unnamedplus"
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Lazy.nvim 자동 설치
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- 플러그인
require("lazy").setup({
  -- 테마
  { "folke/tokyonight.nvim", lazy = false, priority = 1000, config = function() vim.cmd([[colorscheme tokyonight-night]]) end },
  
  -- 파일 찾기 (Space+f/g/e)
  { "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-telescope/telescope-file-browser.nvim" },
    keys = {
      { "<leader>f", "<cmd>Telescope find_files<cr>", desc = "Find Files" },
      { "<leader>g", "<cmd>Telescope live_grep<cr>", desc = "Grep Text" },
      { "<leader>e", "<cmd>Telescope file_browser<cr>", desc = "File Browser" },
    },
    config = function()
      require("telescope").load_extension("file_browser")
    end,
  },

  -- 구문 강조
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate", config = function()
      require("nvim-treesitter.config").setup {
        ensure_installed = { "c", "cpp", "python", "lua", "bash", "dockerfile", "json" },
        highlight = { enable = true }
      }
    end
  },
  
  -- 상태바
  { "nvim-lualine/lualine.nvim", config = true },
})