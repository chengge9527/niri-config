#!/usr/bin/env bash

# ==============================================================================
# Waybar Weather Module - HeFeng Weather (QWeather)
# ==============================================================================
# Description: Fetches weather data from QWeather API, maps icons/classes,
#              and outputs valid JSON for Waybar.
# Dependencies: curl, jq, bash
# Author: Agnes-2.0-Flash (Architecture Review)
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

# ⚠️ 重要：请在此处填入你的和风天气 API Key 和 Location ID
# API Key: https://dev.qweather.com/
# Location ID: 可在和风天气官网查询城市对应的 ID (如北京: 101010100)
# HEFENG_API_KEY="${HEFENG_API_KEY:-}"
# HEFENG_LOCATION_ID="${HEFENG_LOCATION_ID:-}"

# 单位: m=公制(metric), i=英制(imperial)
UNIT="m"
# 语言: zh=中文, en=英文
LANG_CODE="zh"

# 更新间隔(秒)。和风免费 API 限制较多，建议 >= 600 秒 (10分钟)
UPDATE_INTERVAL=600

# 缓存文件路径，避免频繁请求同一数据
CACHE_DIR="/tmp/waybar"
CACHE_FILE="${CACHE_DIR}/weather_cache.json"

# ------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------

log_error() {
    echo "[ERROR] $1" >&2
}

log_info() {
    echo "[INFO] $1" >&2
}

# 检查必要依赖
check_dependencies() {
    local deps=("curl" "jq")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "Dependency '$dep' is not installed."
            exit 1
        fi
    done
}

# 验证配置
# validate_config() {
#     if [[ -z "$HEFENG_API_KEY" ]]; then
#         log_error "HEFENG_API_KEY is not set."
#         exit 1
#     fi
#     if [[ -z "$HEFENG_LOCATION_ID" ]]; then
#         log_error "HEFENG_LOCATION_ID is not set."
#         exit 1
#     fi
# }

# 获取天气数据 (带缓存逻辑)
fetch_weather_data() {
    # 如果缓存存在且未过期，直接读取缓存
    if [[ -f "$CACHE_FILE" ]]; then
        local cache_age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
        if (( cache_age < UPDATE_INTERVAL )); then
            log_info "Using cached data (${cache_age}s old)."
            cat "$CACHE_FILE"
            return 0
        fi
    fi

    log_info "Fetching fresh data from QWeather API..."
    
    local url="https://m53aarq76h.re.qweatherapi.com/v7/weather/now?location=106.49,29.51&key=112310dffc8c406586becdfc554c9275"
    
    local response
    # 使用 curl 获取数据，设置超时
    if ! response=$(curl -s --max-time 10 "$url"); then
        log_error "Failed to connect to QWeather API."
        # 即使失败，也尝试返回旧缓存，避免 Waybar 显示空白
        if [[ -f "$CACHE_FILE" ]]; then
            cat "$CACHE_FILE"
            return 0
        fi
        return 1
    fi

    # 验证 JSON 格式
    if ! echo "$response" | jq empty 2>/dev/null; then
        log_error "Invalid JSON response from API."
        return 1
    fi

    # 检查 API 返回码
    local code
    code=$(echo "$response" | jq -r '.code // empty')
    if [[ "$code" != "200" ]]; then
        log_error "API Error Code: $code"
        # 尝试返回旧缓存
        if [[ -f "$CACHE_FILE" ]]; then
            cat "$CACHE_FILE"
            return 0
        fi
        return 1
    fi

    # 保存缓存
    mkdir -p "$CACHE_DIR"
    echo "$response" > "$CACHE_FILE"
    
    echo "$response"
}

# 映射天气代码到图标和 CSS 类
map_weather_icon() {
    local code="$1"
    local icon=""
    local class_name=""

    # 使用用户提供的精确映射逻辑
    case "$code" in
        100|105)
            icon=""
            class_name="clear"
            ;;
        10[1-4]|15[1-3])
            icon="󰖐"
            class_name="clouds"
            ;;
        30[0-4])
            icon=""
            class_name="thunderstorm"
            ;;
        30[5-9]|31[0-8]|399)
            icon=""
            class_name="rain"
            ;;
        40[0-9]|410|456|457|499)
            icon=""
            class_name="snow"
            ;;
        500|501|509|510|514|515)
            icon=""
            class_name="fog"
            ;;
        502|51[1-3])
            icon=""
            class_name="haze"
            ;;
        50[3-4]|50[7-8])
            icon=""
            class_name="dust"
            ;;
        900)
            icon=""
            class_name="hot"
            ;;
        901)
            icon=""
            class_name="cold"
            ;;
        *)
            icon=""
            class_name="unknown"
            ;;
    esac

    echo "${icon}|${class_name}"
}

# 生成 Waybar 兼容的 JSON 输出
generate_waybar_json() {
    local raw_json="$1"
    
    # 使用 jq 一次性提取所有必要字段，提高效率
    local temp code text humidity wind_speed
    eval "$(echo "$raw_json" | jq -r '
        .now | 
        "temp=\(.temp)",
        "code=\(.code)",
        "text=\(.text)",
        "humidity=\(.humidity)",
        "wind_speed=\(.windSpeed)"
    ')"

    # 如果提取失败，使用默认值
    temp="${temp:-0}"
    code="${code:-100}"
    text="${text:-Unknown}"
    humidity="${humidity:-0}"
    wind_speed="${wind_speed:-0}"

    # 获取图标和类名
    local mapping_result
    mapping_result=$(map_weather_icon "$code")
    local icon="${mapping_result%%|*}"
    local class_name="${mapping_result##*|}"

    # 构建显示文本: Icon Temp Text
    local display_text="${icon} ${temp}°C ${text}"
    
    # 构建 Tooltip/Alt 文本: 详细信息
    local tooltip_text="Temp: ${temp}°C\nHumidity: ${humidity}%\nWind: ${wind_speed} km/h\nCondition: ${text}"

    # 生成最终 JSON
    # 使用 jq 确保特殊字符被正确转义
    jq -n \
        --arg text "$display_text" \
        --arg class "$class_name" \
        --arg alt "$tooltip_text" \
        '{
            text: $text,
            class: $class,
            alt: $alt,
            tooltip: $alt
        }'
}

# ------------------------------------------------------------------------------
# Main Execution
# ------------------------------------------------------------------------------

main() {
    check_dependencies
    

    local raw_data
    if ! raw_data=$(fetch_weather_data); then
        # 如果获取失败且无缓存，输出错误信息
        echo '{"text": "Weather Error", "class": "error", "alt": "Failed to fetch weather data"}'
        exit 1
    fi

    generate_waybar_json "$raw_data"
}

main "$@"
