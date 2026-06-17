#!/bin/bash

# 使用 fuzzel 渲染选项
SELECTION=$(echo -e "取消\n确认" | fuzzel --dmenu --prompt="确定要挂起计算机吗？" --lines 2 --width 25)

case "$SELECTION" in
    "确认")
        swaylock -f
        sleep 3
        systemctl suspend
        ;;
    *)
        # 选择了取消或者直接按了 Esc，不执行任何操作优雅退出
        exit 0
        ;;
esac

# 用上面菜单模式
# 锁屏3秒后挂起计算机
#swaylock -f
#sleep 3
#systemctl suspend
# swaylock -f && sleep 3 && systemctl suspend

