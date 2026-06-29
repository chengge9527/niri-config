-- 基础设置
vim.o.number = true            -- 显示行号
vim.o.relativenumber = true    -- 相对行号
vim.o.cursorline = true        -- 高亮当前行
vim.o.wrap = false             -- 不自动换行
vim.o.termguicolors = true     -- 启用真彩色
vim.o.signcolumn = "yes"       -- 永远显示 signcolumn

-- 缩进
vim.o.tabstop = 4              -- Tab 显示为 4 空格
vim.o.shiftwidth = 4           -- >> << 缩进宽度
vim.o.expandtab = true         -- Tab 转空格
vim.o.smartindent = true       -- 智能缩进

-- 搜索
vim.o.ignorecase = true        -- 搜索忽略大小写
vim.o.smartcase = true         -- 有大写时不忽略
vim.o.incsearch = true         -- 实时搜索
vim.o.hlsearch = true          -- 高亮搜索结果

-- 剪贴板
vim.o.clipboard = "unnamedplus" -- 使用系统剪贴板

-- 编码
vim.o.encoding = "utf-8"
--vim.o.fileencoding = "utf-8"
