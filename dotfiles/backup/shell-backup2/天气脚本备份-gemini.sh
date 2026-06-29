#!/usr/bin/env bash

# 你可以改成自己的城市，比如 "Charlotte" / "Beijing"或者经纬度
LOCATION="Chongqing"

# 天气数据缓存在本地,每600秒更新数据
CACHE_DIR="${HOME}/.cache/waybar-weather"
CACHE_FILE="${CACHE_DIR}/${LOCATION}.cache"
CACHE_TTL=600  # 10分钟

# 确保缓存目录存在
mkdir -p "$CACHE_DIR"

# 判断是否使用缓存
use_cache=0

if [[ -f "$CACHE_FILE" ]]; then
  now=$(date +%s)
  mtime=$(stat -c %Y "$CACHE_FILE")
  if (( now - mtime < CACHE_TTL )); then
    use_cache=1
  fi
fi

# 获取数据
# 顺序：%c图标 %t温度 %h湿度 %P气压 %u紫外线 %w风速 %C天气文本(置于最后防空格截断)
if [[ $use_cache -eq 1 ]]; then
  data=$(cat "$CACHE_FILE")
else
  data=$(curl -s "wttr.in/${LOCATION}?format=%c+%t+%h+%P+%u+%w+%C&lang=zh")

  # 写入缓存（只在成功时写）
  if [[ -n "$data" ]]; then
    echo "$data" > "$CACHE_FILE"
  fi
fi

# 防止请求失败
if [[ -z "$data" ]]; then
  echo '{"text":" N/A","tooltip":"无法获取天气数据"}'
  exit 0
fi

# 解析数据
icon=$(echo "$data" | awk '{print $1}')
temp=$(echo "$data" | awk '{print $2}')
humidity=$(echo "$data" | awk '{print $3}')
pressure=$(echo "$data" | awk '{print $4}')
uv=$(echo "$data" | awk '{print $5}')
wind=$(echo "$data" | awk '{print $6}')
# 用 cut 拿走前6个字段后的所有文本，这样能完美兼容带空格的天气描述
condition=$(echo "$data" | cut -d' ' -f7-)

# 组装输出
# 在状态栏加上了实时天气文本：例如 "晴 +25°C" 或 "多云 +18°C"
echo "{\"text\":\"$icon $condition $temp\",\"tooltip\":\"城市: $LOCATION\n天气: $condition\n湿度: $humidity\n气压: $pressure\n紫外线: $uv/11\n风速: $wind\"}"
