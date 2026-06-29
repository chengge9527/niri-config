local map = vim.keymap.set

-- 极其好用的常规映射
map("n", "<leader>pv", vim.cmd.Ex, { desc = "返回文件树" })
-- 清除搜索高亮
map("n", "<Esc>", "<cmd>noh<CR>", { desc = "清除搜索高亮" })
