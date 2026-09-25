#!/bin/bash

DIR="$HOME/Pictures/screenshots"
mkdir -p "$DIR"

option1="选择截屏区域"
option2="全屏截取 (等待1秒)"
option3="全屏截取 (等待5秒)"

options="$option1\n$option2\n$option3"

choice=$(echo -e "$options" | fuzzel --dmenu --lines=3 --prompt="截图模式: ")

filename="$DIR/screenshot_$(date +%Y%m%d_%H%M%S).png"

case $choice in
    $option1)
        region=$(slurp)
        [ -z "$region" ] && exit 1
        grim -g "$region" "$filename"
        swappy -f "$filename"
        notify-send "截图完成" "模式: 区域"
    ;;
    $option2)
        sleep 1
        grim "$filename"
        swappy -f "$filename"
        notify-send "截图完成" "模式: 全屏 (1秒延时)"
    ;;
    $option3)
        sleep 5
        grim "$filename"
        swappy -f "$filename"
        notify-send "截图完成" "模式: 全屏 (5秒延时)"
    ;;
esac

