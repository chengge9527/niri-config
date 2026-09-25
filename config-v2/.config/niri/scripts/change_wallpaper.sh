#!/usr/bin/env bash
# 启用严格模式：遇到错误退出，未定义变量报错，管道中任何命令失败则整体失败
set -euo pipefail

# 配置
WALL_DIR="$HOME/Pictures/Wallpapers"
CACHE="$HOME/.cache/current_wallpaper"

# 确保缓存目录存在
mkdir -p "$(dirname "$CACHE")"

# 获取当前壁纸路径
CURRENT=""
if [[ -f "$CACHE" ]]; then
    # 读取并去除可能的尾随换行符和空白
    CURRENT="$(<"$CACHE")"
    CURRENT="${CURRENT%$'\n'}" # 去除末尾换行
    CURRENT="${CURRENT% }"     # 去除末尾空格
fi

# 检查壁纸目录是否存在
if [[ ! -d "$WALL_DIR" ]]; then
    # echo "Error: Wallpaper directory '$WALL_DIR' does not exist." >&2
    notify-send -u low -t 3000 "错误: 壁纸目录 '$WALL_DIR' 不存在" || true
    exit 1
fi

# 使用 find 获取所有图片文件，支持含空格/换行的文件名
# -print0 输出 null 分隔，mapfile -d '' 读取 null 分隔
mapfile -d '' -t ALL < <(find "$WALL_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" \) -print0 2>/dev/null)

# 如果没有找到任何图片
if [[ ${#ALL[@]} -eq 0 ]]; then
    # echo "No wallpaper images found in '$WALL_DIR'." >&2
    notify-send -u low -t 3000 "未找到任何图片在 '$WALL_DIR'" || true
    exit 1
fi

# 过滤掉当前壁纸（使用 -x 精确匹配整行，-F 固定字符串，避免正则和子串误匹配）
# 注意：如果 CURRENT 为空，grep -vxF "" 会匹配所有非空行，这正是我们想要的
# mapfile -d '' -t CANDIDATES < <(printf '%s\0' "${ALL[@]}" | grep -z -vxF "$CURRENT")
mapfile -d '' -t CANDIDATES < <({ printf '%s\0' "${ALL[@]}"; } | grep -z -vxF "$CURRENT" || true)

# 如果过滤后为空（例如只有一张图片，且它就是当前壁纸），则重新使用全部图片
if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
    CANDIDATES=("${ALL[@]}")
fi

# 随机选择一张
# 使用 $RANDOM 并处理模偏差（对于少量图片影响极小，但保持严谨）
COUNT=${#CANDIDATES[@]}
INDEX=$(( RANDOM % COUNT ))
NEXT="${CANDIDATES[$INDEX]}"

# 更新缓存
echo -n "$NEXT" > "$CACHE"

# 调用 awww 切换壁纸
# 添加错误检查，确保命令执行成功
if ! awww img "$NEXT" \
    --transition-type grow \
    --transition-duration 2.5; then
    # echo "Error: Failed to change wallpaper using 'awww'." >&2
    notify-send -u low -t 3000 "错误: 更换壁纸失败" || true
    # 可选：回滚缓存或记录日志
    exit 1
fi

# 可选：打印成功信息到 stderr 以避免干扰 stdout（如果脚本被其他程序调用）
# echo "Wallpaper changed to: $NEXT" >&2
notify-send -u low -t 3000 "壁纸已更换: $(basename "$NEXT")" || true
