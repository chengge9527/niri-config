 --require("config.options")
 

 -- 1. 确保 Leader 键在所有插件加载前映射好 (推荐用空格)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- 2. 自动安装 lazy.nvim (如果新系统上没有的话)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- 3. 加载基础设置
require("config.options")
require("config.keymaps")

-- 4. 启动 lazy.nvim，并让它自动去 lua/plugins/ 目录下加载所有插件配置
require("lazy").setup({
  spec = {
    { import = "plugins" },
  },
  -- 界面设置：给 lazy 的弹窗加个好看的边框
  ui = {
    border = "rounded",
  },
})
