return {
  -- =================================================================
  -- 1. 配色方案 (Theme)
  -- =================================================================
  {
    "folke/tokyonight.nvim",
    lazy = false,    -- 启动时立即加载
    priority = 1000, -- 确保最高优先级加载
    config = function()
      vim.cmd([[colorscheme tokyonight-moon]]) -- 使用暗色主题
    end,
  },

  -- =================================================================
  -- 2. 状态栏 (Statusline)
  -- =================================================================
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup()
    end,
  },

  -- =================================================================
  -- 3. 文件树 (File Explorer)
  -- =================================================================
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup()
      -- 快捷键：空格 + e 打开/关闭文件树
      vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>", { silent = true })
    end,
  },

  -- =================================================================
  -- 4. 模糊搜索 (Fuzzy Finder)
  -- =================================================================
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.8",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local builtin = require("telescope.builtin")
      -- 快捷键设置
      vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "查找文件" })
      vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "全局搜索文本" })
      vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "查找缓冲区" })
    end,
  },

  -- =================================================================
  -- 5. 语法高亮 (Treesitter)
  -- =================================================================
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      -- 最新版推荐直接安全调用
      local status_ok, ts_configs = pcall(require, "nvim-treesitter.configs")
      if status_ok then
        ts_configs.setup({
          ensure_installed = { "lua", "vim", "vimdoc", "query", "markdown", "javascript", "python" },
          highlight = { enable = true },
          indent = { enable = true },
        })
      else
        -- 针对绝对纯净最新版的 fallback 方案
        require("nvim-treesitter").setup({
          ensure_installed = { "lua", "vim", "vimdoc", "query", "markdown", "javascript", "python" },
          highlight = { enable = true },
          indent = { enable = true },
        })
      end
    end,
  },

  -- =================================================================
  -- 6. 自动闭合括号与常用辅助
  -- =================================================================
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = true, -- 相当于 require("nvim-autopairs").setup()
  },
}
