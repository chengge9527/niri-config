#!/usr/bin/env bash

if ! pgrep -x "hyprlock" > /dev/null; then
    hyprlock
fi



# if pgrep -f "hyprlock" > /dev/null; then
#     exit 0
# fi
#
# # 启动锁屏
# hyprlock


