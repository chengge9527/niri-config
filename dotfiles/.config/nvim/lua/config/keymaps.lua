-- 键位映射
local map = vim.keymap.set
map("n", "<Space>", "<Nop>", { silent = true })

-- 快捷键示例
map("n", "<leader>w", ":w<CR>", { desc = "保存文件" })
map("n", "<leader>q", ":q<CR>", { desc = "退出" })
map("n", "<leader>h", ":nohlsearch<CR>", { desc = "取消搜索高亮" })
