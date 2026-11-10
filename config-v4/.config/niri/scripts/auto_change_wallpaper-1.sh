#!/usr/bin/env bash

# 启用严格模式：
# -e: 任何命令失败则退出
# -u: 使用未定义变量则报错
# -o pipefail: 管道中任一命令失败则整个管道失败
set -euo pipefail

# --- 配置区域 ---
WALL_DIR="$HOME/Pictures/Wallpapers"
CACHE_FILE="$HOME/.cache/current_wallpaper"
LOCKFILE="$HOME/.cache/auto_change_wallpaper_daemon.lock"

# 确保壁纸目录存在
if [[ ! -d "$WALL_DIR" ]]; then
    echo "Error: Wallpaper directory '$WALL_DIR' does not exist." >&2
    exit 1
fi

# 确保缓存目录存在
mkdir -p "$(dirname "$CACHE_FILE")"

# --- 单实例锁 ---
exec 9>"$LOCKFILE"
if ! flock -n 9; then
    echo "Another instance is already running." >&2
    exit 0
fi

# --- 初始化文件列表 ---
# 使用 null 分隔符安全地读取所有文件路径
declare -a ALL_WALLPAPERS=()
while IFS= read -r -d '' file; do
    ALL_WALLPAPERS+=("$file")
done < <(find "$WALL_DIR" -type f -print0)

if [[ ${#ALL_WALLPAPERS[@]} -eq 0 ]]; then
    echo "No wallpapers found in '$WALL_DIR'." >&2
    exit 1
fi

# --- 辅助函数：获取随机整数 [min, max] ---
get_random_range() {
    local min=$1
    local max=$2
    local range=$((max - min + 1))
    # 使用 $RANDOM 生成，虽然有小偏差，但对于壁纸切换足够
    echo $(( min + RANDOM % range ))
}

# --- 主循环 ---
while true; do
    # 1. 获取当前壁纸
    CURRENT=""
    if [[ -f "$CACHE_FILE" ]]; then
        CURRENT="$(cat "$CACHE_FILE")"
    fi

    # 2. 构建候选列表（排除当前壁纸）
    declare -a CANDIDATES=()
    for wallpaper in "${ALL_WALLPAPERS[@]}"; do
        if [[ "$wallpaper" != "$CURRENT" ]]; then
            CANDIDATES+=("$wallpaper")
        fi
    done

    # 如果所有壁纸都相同（或只有一张），则允许重复选择
    if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
        CANDIDATES=("${ALL_WALLPAPERS[@]}")
    fi

    # 3. 随机选择下一张
    RANDOM_INDEX=$(get_random_range 0 $((${#CANDIDATES[@]} - 1)))
    NEXT="${CANDIDATES[$RANDOM_INDEX]}"

    # 4. 更新缓存（原子性写入）
    # 先写入临时文件，再移动，防止部分写入导致读取错误
    TEMP_CACHE="${CACHE_FILE}.tmp.$$"
    echo "$NEXT" > "$TEMP_CACHE"
    mv -f "$TEMP_CACHE" "$CACHE_FILE"

    # 5. 切换壁纸
    # 检查 awww 命令是否存在
    if command -v awww &> /dev/null; then
        awww img "$NEXT" \
            --transition-type grow \
            --transition-duration 2.5 \
            || echo "Warning: awww command failed." >&2
    else
        echo "Warning: 'awww' command not found. Skipping wallpaper change." >&2
    fi

    # 6. 计算随机延迟 (5-10 分钟 = 300-600 秒)
    # 注释原代码是 1200+601，这里修正为符合注释的 5-10 分钟
    DELAY_SECONDS=$(get_random_range 300 600)
    
    # 可选：打印日志
    # echo "Switched to: $NEXT. Next switch in $DELAY_SECONDS seconds."

    # 7. 等待
    sleep "$DELAY_SECONDS"
done
