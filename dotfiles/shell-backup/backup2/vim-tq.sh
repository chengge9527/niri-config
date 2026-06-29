# ---------------- 配置 ----------------
LAT="${WEATHER_LAT:-29.5625}"
LON="${WEATHER_LON:-106.5000}"

CACHE_DIR="$HOME/.cache/weather"
CACHE="$CACHE_DIR/weather-vim-tq.json"
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
    
    # 检查 key 是否存在
    if [[ -v "WEATHER_MAP[$code]" ]]; then
        info="${WEATHER_MAP[$code]}"
    fi
    
    IFS='|' read -r icon desc class <<< "$info"
    echo "$icon|$desc|$class"
}

# ---------------- 获取缓存 ----------------
load_cache() {
    [[ -f "$CACHE" ]] || return 1
    
    local file_mtime
    # 兼容 GNU stat 和 BSD stat
    if command -v stat &> /dev/null; then
        # 尝试 GNU stat
        file_mtime=$(stat -c %Y "$CACHE" 2>/dev/null) || \
        # 尝试 BSD stat
        file_mtime=$(stat -f %m "$CACHE" 2>/dev/null) || \
        file_mtime=0
    else
        file_mtime=0
    fi
    
    local current_time
    current_time=$(date +%s)
    
    (( current_time - file_mtime < EXPIRE ))
}

# ---------------- 主逻辑 ----------------

# 1. 检查缓存是否有效
if ! load_cache; then
    mkdir -p "$(dirname "$CACHE")"
    
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
        if [[ -f "$CACHE" ]]; then
            : # 保留旧缓存
        else
            printf '{"text":" N/A","tooltip":"无法获取天气数据"}\n'
            exit 0
        fi
    fi
fi

# 2. 解析 JSON
# 【关键修复】：使用 IFS='|' 明确指定分隔符
# 【关键修复】：jq 输出确保是单行，且用 | 连接
raw_data=$(jq -r '
    .current |
    [
        (.temperature_2m // "N/A"),
        (.relative_humidity_2m // "N/A"),
        (.pressure_msl // "N/A"),
        (.wind_speed_10m // "N/A"),
        (.precipitation // "N/A"),
        (.weather_code // "N/A")
    ] | join("|")
' "$CACHE")

# 调试：取消下面注释可查看 jq 原始输出
# echo "DEBUG raw_data: $raw_data" >&2

IFS='|' read -r temp hum press wind rain code <<< "$raw_data"

# 清理可能的空白字符
temp=$(echo "$temp" | xargs)
hum=$(echo "$hum" | xargs)
press=$(echo "$press" | xargs)
wind=$(echo "$wind" | xargs)
rain=$(echo "$rain" | xargs)
code=$(echo "$code" | xargs)

# 3. 获取天气信息
IFS='|' read -r icon desc class <<< "$(get_weather_info "$code")"

# 4. 构建最终 JSON 输出
# 使用 jq 确保 JSON 合法性
jq -n \
    --arg text "${icon} ${temp}°C" \
    --arg tooltip "🌡 温度：${temp}°C\n💧 湿度：${hum}%\n🧭 气压：${press} hPa\n🌬 风速：${wind} km/h\n☔ 降雨：${rain} mm" \
    --arg class "$class" \
    '{
        text: $text,
        tooltip: $tooltip,
        class: $class
    }'
