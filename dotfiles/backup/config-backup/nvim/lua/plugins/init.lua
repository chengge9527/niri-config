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
  -- {
  --   "nvim-lualine/lualine.nvim",
  --   dependencies = { "nvim-tree/nvim-web-devicons" },
  --   config = function()
  --     require("lualine").setup()
  --   end,
  -- },

  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({
        sections = {
          lualine_c = {
            {
              "filename",
              -- 关键参数设置：
              -- 0: 只显示文件名 (默认)
              -- 1: 显示相对路径 (例如: src/components/main.lua)
              -- 2: 显示绝对路径 (例如: /home/monkey/.config/nvim/init.lua)
              -- 3: 显示绝对路径，但如果是在家目录下，会自适应缩写为 ~ (例如: ~/.config/nvim/init.lua)
              path = 3, 
            },
          },
        },
      })
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
  -- {
  --   "nvim-treesitter/nvim-treesitter",
  --   build = ":TSUpdate",
  --   config = function()
  --     -- 最新版推荐直接安全调用
  --     local status_ok, ts_configs = pcall(require, "nvim-treesitter.configs")
  --     if status_ok then
  --       ts_configs.setup({
  --         ensure_installed = { "lua", "vim", "vimdoc", "query", "markdown", "javascript", "python" },
  --         highlight = { enable = true },
  --         indent = { enable = true },
  --       })
  --     else
  --       -- 针对绝对纯净最新版的 fallback 方案
  --       require("nvim-treesitter").setup({
  --         ensure_installed = { "lua", "vim", "vimdoc", "query", "markdown", "javascript", "python" },
  --         highlight = { enable = true },
  --         indent = { enable = true },
  --       })
  --     end
  --   end,
  -- },

  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      -- 极其纯粹的初始化，完全不依赖任何可能被废弃的子模块路径
      require("nvim-treesitter").setup({
        ensure_installed = { "lua", "vim", "vimdoc", "query", "markdown", "javascript", "python" },
        highlight = { enable = true },
        indent = { enable = true },
      })
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

-- =================================================================
  -- 4. AI 助手 (Gp.nvim)
  -- =================================================================
  {
    "robitx/gp.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local conf = {
        -- 配置自定义 API 供应商 (Agnes API)
        providers = {
          openai = {
            -- endpoint = "https://apihub.agnes-ai.com/v1/chat/completions",
            endpoint = "https://apihub.agnes-ai.com/v1/chat/completions",
            secret = os.getenv("AGNES_API_KEY"),
          },
        },
        -- -- 绑定 Agnes 模型到聊天和命令助手
        -- agents = {
        --   {
        --     name = "Agnes-Flash-Chat",
        --     chat = true,
        --     command = false,
        --     provider = "openai",
        --     model = { model = "agnes-2.0-flash", temperature = 0.7 },
        --     system_prompt = "你是一位精通 Linux、Neovim 和网络架构的硬核专家助手。请用简洁、精准的中文回答。",
        --   },
        --   {
        --     name = "Agnes-Flash-Cmd",
        --     chat = false,
        --     command = true,
        --     provider = "openai",
        --     model = { model = "agnes-2.0-flash", temperature = 0.1 },
        --     system_prompt = "你是一个代码重构机器人。请直接输出修改后的代码，不要包含任何 Markdown 语法标签和解释。",
        --   },
        -- },
-- 绑定 Agnes 模型到聊天和命令助手
        agents = {
          {
            name = "Agnes-Deep-Analyze", -- 升级为深度分析智能体
            chat = true,
            command = false,
            provider = "openai",
            model = { 
              model = "agnes-2.0-flash", 
              temperature = 0.2, -- 调低随机性，让分析和 Bug 排查更严谨精确
              -- 💥 核心：注入文档中要求的 Thinking 开启参数
              chat_template_kwargs = {
                enable_thinking = true
              }
            },
            system_prompt = "你是一位精通 Linux 内核、系统架构、高级网络（如 MikroTik ROS）以及 Neovim 开发的资深架构师。请利用你的思维链（Thinking）对用户提供的整段代码进行深度审查，指出潜在 Bug、内存/性能瓶颈、安全风险，并给出符合该语言最佳实践的重构建议。",
          },
          {
            name = "Agnes-Flash-Cmd", -- 原地写代码/修改代码智能体
            chat = false,
            command = true,
            provider = "openai",
            model = { 
              model = "agnes-2.0-flash", 
              temperature = 0.1,
              -- 写代码也可以开启思维模式，以保障逻辑完全正确
              chat_template_kwargs = {
                enable_thinking = true
              }
            },
            system_prompt = "你是一个硬核的代码重构机器人。请直接输出修改后的代码，不要包含任何 Markdown 语法标签，不要带任何寒暄和多余的解释。",
          },
        },     
    }

      -- 初始化插件
      require("gp").setup(conf)

      -- 绑定快捷键
      local function map(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { desc = "AI: " .. desc, silent = true })
      end

      -- 快捷键设置：
      -- Normal/Insert 模式下，按 Ctrl + g 再按 c 键：在右侧垂直分屏打开 AI 聊天
      map({"n", "i"}, "<C-g>c", "<cmd>GpChatNew vsplit<cr>", "在新垂直分屏开启对话")
      -- Visual 模式下选定代码，按 Ctrl + g 再按 r 键：原地输入指令重构/修改该段代码
      map({"v"}, "<C-g>z", ":<C-u>'<,'>GpImplement<cr>", "原地重构选中的代码")
      -- Normal 模式下直接按 Ctrl + g 再按 r 键：在当前光标行生成/插入新代码
      map({"n"}, "<C-g>z", "<cmd>GpImplement<cr>", "在当前位置生成代码")
    end,
  },

}
