return {
  -- 1. 现代暗色主题
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000, -- 确保主题最早加载
    config = function()
      vim.cmd.colorscheme("catppuccin-mocha") -- 激活 mocha (暗色) 主题
    end,
  },

  -- 2. 自动配对括号 (演示延迟加载)
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter", -- 只有进入插入模式时才加载，省内存！
    config = true,         -- 相当于调用 require("nvim-autopairs").setup({})
  },
}
