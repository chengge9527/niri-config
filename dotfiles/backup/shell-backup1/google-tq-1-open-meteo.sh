#!/usr/bin/env bash
# ==============================================================================
# Waybar 天气模块 (Open-Meteo API)
# 特性: WMO完整映射, NerdFont日夜图标, 15分钟缓存, 离线回退, 原子写入, ShellCheck 零警告
# ==============================================================================

# 严格模式：遇到错误退出、未定义变量退出、管道中任何命令失败即视为失败
set -euo pipefail

# ==============================================================================
# 1. 可配置项 (Configuration)
# ==============================================================================
# 请将经纬度修改为你所在的城市 (当前默认: 北京)
LATITUDE="29.5625"
LONGITUDE="106.5000"

# 缓存与网络配置
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/"
CACHE_FILE="$CACHE_DIR/weather.json"
CACHE_TIMEOUT=900  # 缓存有效时间：900秒 (15分钟)
CURL_TIMEOUT=10    # curl 请求超时时间 (秒)

# ==============================================================================
# 2. 核心函数与逻辑 (Functions & Logic)
# ==============================================================================

# 初始化缓存目录
mkdir -p "$CACHE_DIR"

# 获取 WMO 天气描述、图标和对应 class (alt)
# 参数 1: 天气代码 (WMO Code)
# 参数 2: 是否为白天 (1 为白天, 0 为夜晚)
get_weather_info() {
    local code="$1"
    local is_day="$2"
    local text=""
    local icon=""
    local alt=""

    case "$code" in
        0)       text="晴朗";       alt="clear";             if [[ "$is_day" == "1" ]]; then icon="󰖙"; else icon="󰖔"; fi ;;
        1)       text="大部晴朗";   alt="mostly_clear";      if [[ "$is_day" == "1" ]]; then icon="󰖕"; else icon="󰼱"; fi ;;
        2)       text="局部多云";   alt="partly_cloudy";     if [[ "$is_day" == "1" ]]; then icon="󰖐"; else icon="󰼬"; fi ;;
        3)       text="阴天";       alt="overcast";          icon="󰖐" ;;
        45|48)   text="雾";         alt="fog";               icon="󰖑" ;;
        51|53|55)text="毛毛雨";     alt="drizzle";           icon="󰖗" ;;
        56|57)   text="冻毛毛雨";   alt="freezing_drizzle";  icon="󰙿" ;;
        61)      text="小雨";       alt="light_rain";        icon="󰖗" ;;
        63)      text="中雨";       alt="rain";              icon="󰖖" ;;
        65)      text="大雨";       alt="heavy_rain";        icon="󰖖" ;;
        66|67)   text="冻雨";       alt="freezing_rain";     icon="󰙿" ;;
        71)      text="小雪";       alt="light_snow";        icon="󰖘" ;;
        73)      text="中雪";       alt="snow";              icon="󰜗" ;;
        75)      text="大雪";       alt="heavy_snow";        icon="󰜗" ;;
        77)      text="米雪";       alt="snow_grains";       icon="󰖘" ;;
        80|81|82)text="阵雨";       alt="showers";           icon="󰖖" ;;
        85|86)   text="阵雪";       alt="snow_showers";      icon="󰖘" ;;
        95)      text="雷暴";       alt="thunderstorm";      icon="󰖓" ;;
        96|99)   text="雷暴伴冰雹"; alt="thunderstorm_hail"; icon="󰖓" ;;
        *)       text="未知";       alt="unknown";           icon="󰘥" ;;
    esac

    # 使用 | 作为分隔符输出，方便外部解析
    echo "${text}|${icon}|${alt}"
}

# 检查缓存是否有效
check_cache() {
    if [[ -f "$CACHE_FILE" ]]; then
        local current_time
        local file_mtime
        current_time=$(date +%s)
        # stat 获取最后修改时间，兼容大多数 Linux 环境
        file_mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)

        if (( current_time - file_mtime < CACHE_TIMEOUT )); then
            cat "$CACHE_FILE"
            exit 0
        fi
    fi
}

# ==============================================================================
# 3. 主程序 (Main Execution)
# ==============================================================================

# 尝试读取缓存
check_cache

# Open-Meteo API 请求 URL
API_URL="https://api.open-meteo.com/v1/forecast?latitude=${LATITUDE}&longitude=${LONGITUDE}&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m&timezone=auto"

# 抓取数据并处理超时及失败。如果 curl 失败，利用 || 结构拦截，防止 set -e 直接退出脚本
response=$(curl -s -f -m "$CURL_TIMEOUT" "$API_URL") || {
    # 离线回退 (Offline Fallback)：如果网络失败但缓存存在，直接输出老缓存并成功退出
    if [[ -f "$CACHE_FILE" ]]; then
        cat "$CACHE_FILE"
        exit 0
    else
        # 无网且无缓存时，生成标准的错误提示 JSON
        jq -n -c \
            --arg text "󰖪 离线" \
            --arg tooltip "网络请求失败，且无本地缓存可用" \
            --arg class "offline" \
            '{text: $text, tooltip: $tooltip, class: $class, alt: $class, percentage: 0}'
        exit 0
    fi
}

# 使用安全 read (Process Substitution) 搭配 制表符(\t) 分隔提取数据，防止空值偏移
IFS=$'\t' read -r temp app_temp humidity is_day code wind precip < <(
    echo "$response" | jq -r '.current | "\(.temperature_2m)\t\(.apparent_temperature)\t\(.relative_humidity_2m)\t\(.is_day)\t\(.weather_code)\t\(.wind_speed_10m)\t\(.precipitation)"'
)

# 使用安全 read (Process Substitution) 搭配 管道符(|) 分隔提取天气映射信息
IFS='|' read -r w_desc w_icon w_alt < <(get_weather_info "$code" "$is_day")

# 拼接多行 Tooltip (不使用 \n 字符串拼接，利用 jq 参数传递以确保 JSON 格式绝对安全)
tooltip_text="天气: ${w_desc}
温度: ${temp} °C (体感 ${app_temp} °C)
湿度: ${humidity} %
风速: ${wind} km/h
降水: ${precip} mm"

# 使用 mktemp 创建临时文件，确保写入过程的原子性，避免 Waybar 读取到写入一半的残缺 JSON
temp_file=$(mktemp)

# Waybar JSON 一次生成 (利用 jq 原生生成，百分百规避 Bash 的引号噩梦)
jq -n -c \
    --arg text "${w_icon} ${temp}°C" \
    --arg tooltip "${tooltip_text}" \
    --arg class "${w_alt}" \
    --arg alt "${w_alt}" \
    --argjson percentage "${humidity:-0}" \
    '{text: $text, tooltip: $tooltip, class: $class, alt: $alt, percentage: $percentage}' > "$temp_file"

# 原子移动 (Atomic Write) 更新缓存，最后输出结果供 Waybar 捕获
mv "$temp_file" "$CACHE_FILE"
cat "$CACHE_FILE"
