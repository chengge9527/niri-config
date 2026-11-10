#!/bin/bash

# 5分钟锁屏，10分钟熄屏，20分钟休眠
# exec swayidle -w \
# timeout 300  'swaylock -f' \
# timeout 600  'niri msg action power-off-monitors' \
# resume       'niri msg action power-on-monitors' \
# timeout 1200 'systemctl suspend' \
# before-sleep 'swaylock -f'

# exec swayidle -d -w \
#     timeout 300  'pgrep -x hyprlock >/dev/null || hyprlock &' \
#     timeout 600  'niri msg action power-off-monitors' \
#     resume       'niri msg action power-on-monitors' \
#     timeout 1200 'systemctl suspend' \
#     before-sleep 'pgrep -x hyprlock >/dev/null || hyprlock &'


exec swayidle -w \
    timeout 300  'hyprlock &' \
    timeout 600  'niri msg action power-off-monitors' \
    resume       'niri msg action power-off-monitors' \
    timeout 1200 'systemctl suspend' \
    before-sleep 'hyprlock &'
