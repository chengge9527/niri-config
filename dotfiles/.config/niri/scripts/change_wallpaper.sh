#!/bin/bash

WALL_DIR="$HOME/Pictures/Wallpapers"
CACHE="$HOME/.cache/current_wallpaper"

mkdir -p "$(dirname "$CACHE")"

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
   # --transition-step 90

