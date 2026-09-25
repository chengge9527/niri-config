#!/bin/bash

# 单实例锁以免重复运行脚本
LOCKFILE="$HOME/.cache/auto_change_wallpaper_daemon.lock"

exec 9>"$LOCKFILE"
flock -n 9 || exit 0

WALL_DIR="$HOME/Pictures/Wallpapers"
CACHE="$HOME/.cache/current_wallpaper"

mkdir -p "$(dirname "$CACHE")"

while true; do
    # 当前壁纸（如果不存在则设为空）
    if [ -f "$CACHE" ]; then
        CURRENT="$(cat "$CACHE")"
    else
        CURRENT=""
    fi

    # 找出所有壁纸
    mapfile -t ALL < <(find "$WALL_DIR" -type f)

    # 过滤掉当前壁纸
    mapfile -t CANDIDATES < <(printf "%s\n" "${ALL[@]}" | grep -vF "$CURRENT")

    # 如果过滤后为空（说明只有一张壁纸）
    if [ ${#CANDIDATES[@]} -eq 0 ]; then
        CANDIDATES=("${ALL[@]}")
    fi

    # 随机选一张
    NEXT="${CANDIDATES[RANDOM % ${#CANDIDATES[@]}]}"

    # 保存为当前壁纸
    echo "$NEXT" > "$CACHE"

    # 调用 awww 切换
    awww img "$NEXT" \
        --transition-type grow \
        --transition-duration 2.5 \
    #    --transition-step 90

    # 4. 🔥 核心：计算 5 到 10 分钟的随机秒数
    # 5分钟 = 300秒，10分钟 = 600秒
    # 随机范围大小 = 600 - 300 = 300秒
    RANDOM_DELAY=$(( 1200 + RANDOM % 601 ))

    # 转换为分钟打印到终端（如果你把日志重定向了，方便调试看下一次要等多久）
    # echo "壁纸已换，下一次切换将在 $((RANDOM_DELAY / 60)) 分 $((RANDOM_DELAY % 60)) 秒后"

    # 5. 挂起等待
    sleep "$RANDOM_DELAY"
done
