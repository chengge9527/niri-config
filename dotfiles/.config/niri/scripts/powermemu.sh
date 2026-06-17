#!/bin/bash

# 使用 fuzzel 渲染选项
SELECTION=$(echo -e "取消\n确认" | fuzzel --dmenu --prompt="确定要退出niri桌面吗？" --lines 2 --width 25)

case "$SELECTION" in
    "确认")
        waydroid session stop
        sleep 1
        niri msg action quit --skip-confirmation
        ;;
    *)
        # 选择了取消或者直接按了 Esc，不执行任何操作优雅退出
        exit 0
        ;;
esac
