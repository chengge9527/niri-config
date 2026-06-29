#!/usr/bin/env bash

set -euo pipefail

# ---------------- 配置 ----------------
LAT="29.5625"
LON="106.5000"

CACHE="$HOME/.cache/weather.json"
EXPIRE=600

URL="https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&current=temperature_2m,relative_humidity_2m,pressure_msl,wind_speed_10m,precipitation,weather_code&timezone=auto"

# ---------------- 天气映射 ----------------
weather_info() {
    case "$1" in
        0)  echo "☀️|晴|sunny" ;;
        1)  echo "🌤️|晴间多云|partly-cloudy" ;;
        2)  echo "⛅|多云|cloudy" ;;
        3)  echo "☁️|阴|overcast" ;;
        45|48) echo "🌫️|雾|fog" ;;
        51|53|55) echo "🌦️|毛毛雨|drizzle" ;;
        56|57) echo "🌧️|冻毛毛雨|drizzle" ;;
        61) echo "🌧️|小雨|rain" ;;
        63) echo "🌧️|中雨|rain" ;;
        65) echo "🌧️|大雨|rain" ;;
        66|67) echo "🌧️|冻雨|rain" ;;
        71|73|75) echo "❄️|雪|snow" ;;
        77) echo "🌨️|冰粒|snow" ;;
        80|81|82) echo "🌦️|阵雨|rain" ;;
        85|86) echo "❄️|阵雪|snow" ;;
        95|96|99) echo "⛈️|雷暴|storm" ;;
        *) echo "❓|未知|unknown" ;;
    esac
}

# ---------------- 获取缓存 ----------------
load_cache() {
    [[ -f "$CACHE" ]] || return 1
    (( $(date +%s) - $(stat -c %Y "$CACHE") < EXPIRE ))
}

# ---------------- 更新缓存 ----------------
if ! load_cache; then
    mkdir -p "${CACHE%/*}"
    
    # 失败时清理临时文件
    if ! curl -fsS --max-time 3 "$URL" -o "$CACHE.tmp"; then
        rm -f "$CACHE.tmp"
        [[ -f "$CACHE" ]] || {
            printf '{"text":"⚠️ N/A","tooltip":"无法获取天气"}\n'
            exit 0
        }
    else
        mv "$CACHE.tmp" "$CACHE"
    fi
fi

# ---------------- 解析基础数据 ----------------
# 使用进程替换和明确的 IFS，避免 set -e 触发退出
IFS=$'\t' read -r temp hum press wind rain code < <(jq -r '
.current | [
    .temperature_2m,
    .relative_humidity_2m,
    .pressure_msl,
    .wind_speed_10m,
    .precipitation,
    .weather_code
] | @tsv
' "$CACHE") || true

# 获取图标和描述
IFS='|' read -r icon desc class <<<"$(weather_info "$code")"

# ---------------- 使用 jq 安全构造 JSON ----------------
# 完美的转义，无需手动替换 \n 和 "
jq -n \
    --arg text "${icon} ${temp}°C" \
    --arg icon "$icon" \
    --arg desc "$desc" \
    --arg temp "$temp" \
    --arg hum "$hum" \
    --arg press "$press" \
    --arg wind "$wind" \
    --arg rain "$rain" \
    --arg class "$class" \
    '{
        text: $text,
        class: $class,
        tooltip: "\($icon)  \($desc)\n\n🌡 温度：\($temp)°C\n💧 湿度：\($hum)%\n🧭 气压：\($press) hPa\n🌬 风速：\($wind) km/h\n☔ 降雨：\($rain) mm"
    }'
