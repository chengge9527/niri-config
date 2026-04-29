#!/bin/bash

# 锁屏3秒后挂起计算机
swaylock -f
sleep 3
systemctl suspend
# swaylock -f && sleep 3 && systemctl suspend
