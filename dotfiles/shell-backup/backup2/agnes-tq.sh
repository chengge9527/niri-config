#!/usr/bin/env bash
# =============================================================================
# Waybar 天气模块脚本 (OpenWeatherMap API) - 重构版
# =============================================================================
set -euo pipefail

# ==========================================
# 配置区 (Configurations)
# ==========================================
# 安全提示：请通过环境变量设置 API_KEY，不要硬编码
API_KEY="OWM_API_KEY"
LAT="${OWM_LAT:-29.5625}"
LON="${OWM_LON:-106.5000}"
UNITS="${OWM_UNITS:-metric}"
LANG="${OWM_LANG:-zh_cn}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-weather/"
CACHE_FILE="${CACHE_DIR}weather.json"
CACHE_TIMEOUT=900
CURL_CONNECT_TIMEOUT=5
CURL_MAX_TIME=10

# ==========================================
# 辅助函数
# ==========================================

# 获取图标和类名
get_weather_meta() {
    local condition_id="$1"
    local tod="$2"
    local icon class

    # 默认值
    icon="󰖐"
    class="default"

    case "$condition_id" in
        2*) icon=""; class="thunderstorm" ;;
        3*) icon="󰖗"; class="drizzle" ;;
        5*) icon="󰖖"; class="rain" ;;
        6*) icon="󰖘"; class="snow" ;;
        7*) icon="󰖑"; class="atmosphere" ;;
        800)
            if [[ "$tod" == "n" ]]; then
                icon="󰖔"; class="clear-night"
            else
                icon="󰖙"; class="clear-day"
            fi
            ;;
        801)
            class="clouds"
            if [[ "$tod" == "n" ]]; then icon="󰼱"; else icon="󰖕"; fi
            ;;
        802|803|804) icon="󰖐"; class="clouds" ;;
        *) icon="󰖐"; class="default" ;;
    esac

    echo "$icon $class"
}

# 打印错误并退出
print_error() {
    local msg="$1"
    # 使用 printf 避免 echo 的解释问题
    printf '{"text":"󰖪 ERROR","tooltip":"%s","class":"error","percentage":0}\n' \
        "$(echo "$msg" | sed 's/"/\\"/g')"
    exit 0
}

# ==========================================
# 主逻辑
# ==========================================

# 1. 初始化缓存目录
mkdir -p "$CACHE_DIR"

# 2. 检查缓存有效性
update_needed=true
if [[ -f "$CACHE_FILE" ]]; then
    # 使用 stat 获取修改时间 (Linux)
    file_mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
    current_time=$(date +%s)
    
    if (( current_time - file_mtime < CACHE_TIMEOUT )); then
        update_needed=false
    fi
fi

# 3. 获取数据
if $update_needed; then
    temp_file=$(mktemp "${CACHE_DIR}weather_temp.XXXXXX")
    
    # 构建 URL
    url="https://api.openweathermap.org/data/2.5/weather?lat=${LAT}&lon=${LON}&appid=${API_KEY}&units=${UNITS}&lang=${LANG}"
    
    # 下载并验证 HTTP 状态码
    http_code=$(curl -sSf -w "%{http_code}" --connect-timeout "$CURL_CONNECT_TIMEOUT" --max-time "$CURL_MAX_TIME" "$url" -o "$temp_file")
    
    if [[ "$http_code" -ne 200 ]]; then
        rm -f "$temp_file"
        # 如果是 401/403/429，通常是 Key 问题或限流
        if [[ "$http_code" -eq 401 || "$http_code" -eq 403 || "$http_code" -eq 429 ]]; then
            print_error "API 访问失败 (HTTP $http_code). 请检查 API Key 或配额."
        else
            print_error "网络错误: HTTP $http_code"
        fi
    fi

    # 验证 JSON 格式
    if ! jq empty "$temp_file" 2>/dev/null; then
        rm -f "$temp_file"
        print_error "缓存文件损坏，无法解析 JSON"
    fi

    # 原子移动
    mv "$temp_file" "$CACHE_FILE"
else
    # 如果不需要更新，验证现有缓存是否有效
    if ! jq empty "$CACHE_FILE" 2>/dev/null; then
        # 缓存损坏，强制更新
        rm -f "$CACHE_FILE"
        update_needed=true
        # 重新进入获取流程 (简化起见，这里直接重试一次 fetch，实际生产中可重构为函数)
        temp_file=$(mktemp "${CACHE_DIR}weather_temp.XXXXXX")
        url="https://api.openweathermap.org/data/2.5/weather?lat=${LAT}&lon=${LON}&appid=${API_KEY}&units=${UNITS}&lang=${LANG}"
        http_code=$(curl -sSf -w "%{http_code}" --connect-timeout "$CURL_CONNECT_TIMEOUT" --max-time "$CURL_MAX_TIME" "$url" -o "$temp_file")
        if [[ "$http_code" -ne 200 ]]; then
             rm -f "$temp_file"
             print_error "API 访问失败 (HTTP $http_code)"
        fi
        mv "$temp_file" "$CACHE_FILE"
    fi
fi

# 4. 解析数据
# 使用 jq 一次性提取所有需要的字段，并处理可能的 null 值
read -r temp feels_like humidity desc condition_id icon_code wind_speed rain_1h snow_1h city_name < <(
    jq -r '
        [
            (.main.temp // 0),
            (.main.feels_like // 0),
            (.main.humidity // 0),
            (.weather[0].description // "Unknown"),
            (.weather[0].id // 0),
            (.weather[0].icon // "01d"),
            (.wind.speed // 0),
            (.rain."1h" // 0),
            (.snow."1h" // 0),
            .name // "Unknown"
        ] | @tsv
    ' "$CACHE_FILE" 2>/dev/null
)

# 5. 数据校验
if [[ -z "$city_name" || "$city_name" == "null" ]]; then
    print_error "无法解析城市名称，API 响应异常"
fi

# 6. 格式化
temp_round=$(printf "%.0f" "$temp")
feels_like_round=$(printf "%.0f" "$feels_like")

# 提取昼夜标识 (d/n)
if [[ ${#icon_code} -ge 1 ]]; then
    time_of_day="${icon_code: -1}"
else
    time_of_day="d" # 默认白天
fi

# 获取图标和类
read -r icon weather_class <<< "$(get_weather_meta "$condition_id" "$time_of_day")"

# 湿度作为百分比
percentage="$humidity"

# 动态构建降水量文本 (处理浮点数比较)
precip_info=""
# 使用 bc 进行浮点数比较，或者简单判断字符串不等于 "0"
if [[ "$rain_1h" != "0" ]]; then
    precip_info+=$'\n'"降雨量(1h): ${rain_1h} mm"
fi
if [[ "$snow_1h" != "0" ]]; then
    precip_info+=$'\n'"降雪量(1h): ${snow_1h} mm"
fi

# Tooltip 构建
tooltip="${city_name} 天气实况
-------------------------
天气状况: ${desc}
当前温度: ${temp_round}°C
体感温度: ${feels_like_round}°C
相对湿度: ${humidity}%
当前风速: ${wind_speed} m/s${precip_info}
API状态码: ${condition_id}"

# 7. 输出 JSON
# 使用 jq 确保所有特殊字符被正确转义
jq -n -c \
    --arg text "${icon} ${temp_round}°C" \
    --arg tooltip "$tooltip" \
    --arg alt "$desc" \
    --arg class "$weather_class" \
    --argjson percentage "$percentage" \
    '{
        text: $text,
        tooltip: $tooltip,
        alt: $alt,
        class: $class,
        percentage: $percentage
    }'
