#!/bin/bash
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-weather"
CACHE_FILE="${CACHE_DIR}/weather.json"

if [ ! -f "$CACHE_FILE" ]; then
    echo "缓存文件不存在"
    exit 1
fi

# 获取修改时间戳（秒）
file_mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null)

# 获取当前时间戳
current_time=$(date +%s)

# 计算文件存在多久了（秒）
age=$((current_time - file_mtime))

echo "缓存文件修改时间: $(date -d @$file_mtime)"
echo "距今已过: $age 秒"

# 举例：如果超过 3600 秒（1小时），认为缓存过期
if [ $age -gt 3600 ]; then
    echo "缓存已过期，需要重新生成"
else
    echo "缓存有效"
fi

# 方法 A：使用 date + stat 组合
time_part=$(date -d "@$(stat -c %Y "$CACHE_FILE")" +%H:%M:%S)
echo "修改时间（时分秒）: $time_part"

# 方法 B：直接用 date -r（更简洁）
time_part=$(date -r "$CACHE_FILE" +%H:%M:%S)
echo "修改时间（时分秒）: $time_part"
