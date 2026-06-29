#!/usr/bin/env bash

set -euo pipefail

# ---------------- 配置 ----------------
LAT="${WEATHER_LAT:-29.5625}"
LON="${WEATHER_LON:-106.5000}"

CACHE_DIR="$HOME/.cache/weather"
CACHE="$CACHE_DIR/weather.json"
EXPIRE=600

URL="https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&current=temperature_2m,relative_humidity_2m,pressure_msl,wind_speed_10m,precipitation,weather_code&timezone=auto"

# ---------------- 天气映射 (关联数组) ----------------
declare -A WEATHER_MAP=(
    [0]="☀️|晴|sunny"
    [1]="🌤️|晴间多云|partly-cloudy"
    [2]="⛅|多云|cloudy"
    [3]="☁️|阴|overcast"
    [45]="🌫️|雾|fog"
    [48]="🌫️|雾|fog"
    [51]="🌦️|毛毛雨|drizzle"
    [53]="🌦️|毛毛雨|drizzle"
    [55]="🌦️|毛毛雨|drizzle"
    [56]="🌧️|冻毛毛雨|freezing-drizzle"
    [57]="🌧️|冻毛毛雨|freezing-drizzle"
    [61]="🌧️|小雨|rain"
    [63]="🌧️|中雨|rain"
    [65]="🌧️|大雨|rain"
    [66]="🌧️|冻雨|freezing-rain"
    [67]="🌧️|冻雨|freezing-rain"
    [71]="❄️|雪|snow"
    [73]="❄️|雪|snow"
    [75]="❄️|雪|snow"
    [77]="❄️|冰粒|ice-pellets"
    [80]="🌦️|阵雨|rain-showers"
    [81]="🌦️|阵雨|rain-showers"
    [82]="🌦️|阵雨|rain-showers"
    [85]="❄️|阵雪|snow-showers"
    [86]="❄️|阵雪|snow-showers"
    [95]="⛈️|雷暴|thunderstorm"
    [96]="⛈️|雷暴|thunderstorm"
    [99]="⛈️|雷暴|thunderstorm"
)

get_weather_info() {
    local code="$1"
    local info="❓|未知|unknown"
    
    if [[ -n "${WEATHER_MAP[$code]+x}" ]]; then
        info="${WEATHER_MAP[$code]}"
    fi
    
    IFS='|' read -r icon desc class <<< "$info"
    echo "$icon|$desc|$class"
}

# ---------------- 获取缓存 ----------------
load_cache() {
    [[ -f "$CACHE" ]] || return 1
    
    local file_mtime
    file_mtime=$(stat -c %Y "$CACHE" 2>/dev/null || stat -f %m "$CACHE" 2>/dev/null || echo 0)
    local current_time
    current_time=$(date +%s)
    
    (( current_time - file_mtime < EXPIRE ))
}

# ---------------- 主逻辑 ----------------

# 1. 检查缓存是否有效
if ! load_cache; then
    mkdir -p "$(dirname "$CACHE")"
    
    # 2. 尝试下载新数据
    download_success=false
    retry_count=0
    max_retries=3
    
    while [[ $retry_count -lt $max_retries ]]; do
        if curl -fsS --max-time 10 "$URL" -o "${CACHE}.tmp" 2>/dev/null; then
            download_success=true
            break
        fi
        retry_count=$((retry_count + 1))
        sleep 1
    done
    
    if [[ "$download_success" == true ]]; then
        mv "${CACHE}.tmp" "$CACHE"
    else
        # 下载失败
        if [[ -f "$CACHE" ]]; then
            # 如果有旧缓存，保留它（虽然它已过期，但至少比没有好）
            # 注意：这里不删除旧缓存，下次运行时会再次尝试下载
            : 
        else
            # 既没有新数据也没有旧缓存
            printf '{"text":" N/A","tooltip":"无法获取天气数据"}\n'
            exit 0
        fi
    fi
fi

# 3. 解析 JSON
# 使用 jq 显式提取字段，处理 null 值
read -r temp hum press wind rain code < <(
    jq -r '
        .current |
        [
            (.temperature_2m // "N/A"),
            (.relative_humidity_2m // "N/A"),
            (.pressure_msl // "N/A"),
            (.wind_speed_10m // "N/A"),
            (.precipitation // "N/A"),
            (.weather_code // "N/A")
        ] | join("|")
    ' "$CACHE"
)

# 4. 获取天气信息
IFS='|' read -r icon desc class <<< "$(get_weather_info "$code")"

# 5. 构建最终 JSON 输出
jq -n \
    --arg text "${icon} ${temp}°C" \
    --arg tooltip "🌡 温度：${temp}°C\n💧 湿度：${hum}%\n🧭 气压：${press} hPa\n🌬 风速：${wind} km/h\n☔ 降雨：${rain} mm" \
    --arg class "$class" \
    '{
        text: $text,
        tooltip: $tooltip,
        class: $class
    }'
