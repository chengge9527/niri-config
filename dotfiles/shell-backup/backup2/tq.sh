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

    if ! curl -fsS --max-time 3 "$URL" -o "$CACHE.tmp"; then
        [[ -f "$CACHE" ]] || {
            printf '{"text":" N/A","tooltip":"无法获取天气"}\n'
            exit
        }
    else
        mv "$CACHE.tmp" "$CACHE"
    fi
fi

# ---------------- 解析 JSON（一次 jq） ----------------
read -r temp hum press wind rain code <<EOF
$(jq -r '
.current |
[
    .temperature_2m,
    .relative_humidity_2m,
    .pressure_msl,
    .wind_speed_10m,
    .precipitation,
    .weather_code
] | @tsv
' "$CACHE")
EOF

IFS='|' read -r icon desc class <<<"$(weather_info "$code")"

TEXT="${icon} ${temp}°C"

TOOLTIP="$icon  $desc

🌡 温度：${temp}°C
💧 湿度：${hum}%
🧭 气压：${press} hPa
🌬 风速：${wind} km/h
☔ 降雨：${rain} mm"

# JSON 转义
tooltip=${TOOLTIP//$'\n'/\\n}
tooltip=${tooltip//\"/\\\"}
text=${TEXT//\"/\\\"}

printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' \
    "$text" \
    "$tooltip" \
    "$class"
