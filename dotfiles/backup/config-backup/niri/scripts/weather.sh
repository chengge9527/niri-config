#!/usr/bin/env bash

# 你的经纬度 (以北京为例)
LAT="29.5625"
LON="106.5000"

# 缓存
CACHE_DIR="${HOME}/.cache/waybar-weather"
CACHE_FILE="${CACHE_DIR}/${LAT},${LON}.cache"
CACHE_TTL=600  # 10分钟

mkdir -p "$CACHE_DIR"

use_cache=0

if [[ -f "$CACHE_FILE" ]]; then
  now=$(date +%s)
  mtime=$(stat -c %Y "$CACHE_FILE")
  if (( now - mtime < CACHE_TTL )); then
    use_cache=1
  fi
fi

# 获取数据
if [[ $use_cache -eq 1 ]]; then
  data=$(cat "$CACHE_FILE")
else
  data=$(curl -s "https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}\
&current=temperature_2m,weather_code,pressure_msl,wind_speed_10m,relative_humidity_2m,rain\
&timezone=auto&models=cma_grapes_global" | jq '.current')

  if [[ -n "$data" ]]; then
    echo "$data" > "$CACHE_FILE"
  fi
fi

# 请求失败
if [[ -z "$data" ]]; then
  echo '{"text":" N/A","tooltip":"Weather fetch failed"}'
  exit 0
fi

# 提取字段
code=$(echo "$data" | jq '.weather_code')
temp=$(echo "$data" | jq '.temperature_2m')
humidity=$(echo "$data" | jq '.relative_humidity_2m')
pressure=$(echo "$data" | jq '.pressure_msl')
speed=$(echo "$data" | jq '.wind_speed_10m')
rain=$(echo "$data" | jq '.rain')

# weather_code → emoji + 中文描述
declare -A WMAP=(
  [0]="☀️|晴"
  [1]="🌤️|少云"
  [2]="⛅|局部多云"
  [3]="☁️|阴天"
  [45]="🌫️|雾"
  [48]="🌫️|冰雾"
  [51]="🌦️|轻雾雨"
  [53]="🌦️|中雾雨"
  [55]="🌧️|强雾雨"
  [56]="🌧️|轻冻雾雨"
  [57]="🌧️|强冻雾雨"
  [61]="🌦️|小雨"
  [63]="🌧️|中雨"
  [65]="🌧️|大雨"
  [66]="🌧️|轻冻雨"
  [67]="🌧️|强冻雨"
  [71]="🌨️|小雪"
  [73]="❄️|中雪"
  [75]="❄️|大雪"
  [77]="❄️|雪粒"
  [80]="🌦️|小阵雨"
  [81]="🌧️|阵雨"
  [82]="🌧️|强阵雨"
  [85]="🌨️|小阵雪"
  [86]="❄️|强阵雪"
  [95]="⛈️|雷暴"
  [96]="⛈️|雷暴伴轻冰雹"
  [97]="⛈️|雷暴伴强冰雹"
  [98]="🌩️|强雷暴"
  [99]="🌩️|极强雷暴"
)

IFS="|" read -r icon desc <<< "${WMAP[$code]}"

echo "{\"text\":\"${icon} ${desc}(${temp}°C)\",\"tooltip\":\"天气: ${desc}\n湿度: ${humidity}%\n气压: ${pressure} hPa\n风速: ${speed} m/s\n降雨量: ${rain} mm\"}"
