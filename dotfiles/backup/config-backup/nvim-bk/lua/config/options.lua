local opt = vim.opt

opt.number = true          -- 显示行号
opt.relativenumber = true  -- 相对行号 (极度适合键盘流)
opt.clipboard = "unnamedplus" -- 共享系统剪贴板 (Wayland 下需安装 wl-clipboard)
opt.tabstop = 4            -- Tab 占 4 个空格
opt.shiftwidth = 4
opt.expandtab = true       -- 将 Tab 转换为 空格
opt.smartindent = true
opt.termguicolors = true   -- 开启真彩色支持
opt.cursorline = true      -- 高亮当前行
