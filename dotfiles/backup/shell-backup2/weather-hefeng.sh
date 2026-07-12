#!/usr/bin/env bash
# =============================================================================
# Waybar 天气模块脚本 (OpenWeatherMap API)
# =============================================================================
# 严格模式：遇到错误退出 (-e)，未定义变量报错 (-u)，管道中任何命令失败则失败 (-o pipefail)
set -euo pipefail

# ==========================================
# 集中配置区 (Configurations)
# ==========================================
# API_KEY="${OWM_API_KEY:?ERROR: OWM_API_KEY is not set}"                # 替换为你的 OpenWeatherMap API Key
LAT="29.5625"                              # 纬度
LON="106.5000"                             # 经度
UNITS="metric"                             # 单位: metric(摄氏度) / imperial(华氏度)
LANG="zh_cn"                               # 语言: zh_cn / en
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hefeng-weather"
CACHE_FILE="${CACHE_DIR}/weather.json"
CACHE_TIMEOUT=60000                          # 缓存有效期 (秒)
CURL_CONNECT_TIMEOUT=5                     # curl 连接超时 (秒)
CURL_MAX_TIME=10                           # curl 最大执行时间 (秒)
# 新增重试
CURL_RETRY=3                               # 重试次数
CURL_RETRY_DELAY=2                         # 重试延迟（秒）
CURL_RETRY_MAX_TIME=30                     # 总重试时间上限

# ==========================================
# 辅助函数区
# ==========================================

# 根据 OpenWeatherMap 状态码映射 Nerd Font 图标 (支持昼/夜区分)
# 参阅: https://openweathermap.org/weather-conditions
# get_weather_meta() {
#     local condition_id="$1"
#     local tod="$2"
#     local icon class
#
#     case "$condition_id" in
#         2*) icon=""; class="thunderstorm" ;;
#         3*) icon="󰖗"; class="drizzle" ;;
#         5*) icon="󰖖"; class="rain" ;;
#         6*) icon="󰖘"; class="snow" ;;
#         7*) icon="󰖑"; class="atmosphere" ;;
#         800)
#             if [[ "$tod" == "n" ]]; then
#                 icon="󰖔"; class="clear-night"
#             else
#                 icon="󰖙"; class="clear-day"
#             fi
#             ;;
#         801)
#             class="clouds"
#             if [[ "$tod" == "n" ]]; then icon="󰼱"; else icon="󰖕"; fi
#             ;;
#         802|803|804) icon="󰖐"; class="clouds" ;;
#         *) icon="󰖐"; class="default" ;;
#     esac
#
#     # 以空格分隔输出，供外部读取
#     echo "$icon $class"
# }



# 从 API 拉取数据并原子写入缓存
fetch_weather() {
    local url="https://m53aarq76h.re.qweatherapi.com/v7/weather/now?location=106.49,29.51&key=112310dffc8c406586becdfc554c9275"
    local temp_file
    # 创建临时文件
    temp_file=$(mktemp "${CACHE_DIR}/weather_temp.XXXXXX") || return 1

    # if curl -sSf \
    #     --connect-timeout "$CURL_CONNECT_TIMEOUT" \
    #     --max-time "$CURL_MAX_TIME" \
    #     "$url" \
    #     -o "$temp_file"
    # then
    #     mv -f "$temp_file" "$CACHE_FILE"
    # else
    #     rm -f "$temp_file"
    #     return 1
    # fi

    # 如果网络不好增加重试。
    if curl -sSf \
        --connect-timeout "$CURL_CONNECT_TIMEOUT" \
        --max-time "$CURL_MAX_TIME" \
        --retry "$CURL_RETRY" \
        --retry-delay "$CURL_RETRY_DELAY" \
        --retry-max-time "$CURL_RETRY_MAX_TIME" \
        --compressed \
        "$url" \
        -o "$temp_file"
    then
        mv -f "$temp_file" "$CACHE_FILE"
        return 0
    else
        rm -f "$temp_file"
        return 1
    fi
}

# 输出错误格式的 JSON
print_error() {
    local msg="$1"
    jq -n -c \
        --arg text "󰖪 ERROR" \
        --arg tooltip "$msg" \
        --arg class "error" \
        '{"text": $text, "tooltip": $tooltip, "class": $class, "percentage": 0}'
    exit 0
}

# ==========================================
# 主逻辑流
# ==========================================

# 1. 初始化缓存目录
mkdir -p "$CACHE_DIR"

# 2. 判断缓存是否过期及是否存在
update_needed=true
if [[ -f "$CACHE_FILE" ]]; then
    current_time=$(date +%s)
    # 兼容 Linux (stat -c %Y) 获取文件修改时间
    file_mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
    time_diff=$((current_time - file_mtime))

    if (( time_diff < CACHE_TIMEOUT )); then
        update_needed=false
    fi
fi

# 3. 触发数据更新 (处理离线回退机制)
if $update_needed; then
    if ! fetch_weather; then
        # 请求失败且没有本地旧缓存 -> 彻底断网/无数据
        if [[ ! -f "$CACHE_FILE" ]]; then
            print_error "无法获取天气数据且无本地缓存 (请检查网络)"
        fi
        # 若存在旧缓存，则静默忽略更新错误，继续执行以实现“离线回退”读取旧缓存
    fi
fi

# 4. 安全提取 JSON 字段 (Process Substitution)
# 使用 jq 提取指定字段合并为制表符 (\t) 分隔的单行，避免空格断词污染 bash read
read -r temp text feelsLike humidity precip obsTime pressure vis icon_cod updateTime < <(
    jq -r '[
        .now.temp,
        .now.text,
        .now.feelsLike,
        .now.humidity,
        .now.precip,
        .now.obsTime,
        .now.pressure,
        .now.vis,
        .now.icon,
        .updateTime
    ] | @tsv' "$CACHE_FILE" 2>/dev/null || echo ""
)

case "${icon}" in
    100|105)                    icon=""; class="clear" ;;
    10[1-4]|15[1-3])            icon="󰖐"; class="clouds" ;;
    30[0-4])                    icon=""; class="thunderstorm" ;;
    30[5-9]|31[0-8]|399)        icon=""; class="rain" ;;
    40[0-9]|410|456|457|499)    icon=""; class="snow" ;;
    500|501|509|510|514|515)    icon=""; class="fog" ;;
    502|51[1-3])                icon=""; class="haze" ;;
    50[3-4]|50[7-8])            icon=""; class="dust" ;;
    900)                        icon=""; class="hot" ;;
    901)                        icon=""; class="cold" ;;
    *)                          icon=""; class="unknown" ;;
esac


# 添加下次更新时间
# new_time=$(date +"%H:%M:%S" -d "+${CACHE_TIMEOUT} seconds")
# 缓存文件更新时间
time_part=$(date -r "$CACHE_FILE" "+%m-%d %H:%M" 2>/dev/null || echo "")
formatted_updatetime=$(date -d "$updateTime" "+%m-%d %H:%M" 2>/dev/null || echo "")

# Tooltip (多行详细信息)
# 直接利用 Bash 的原生多行字符串，传递给 jq 时会自动转换成合法的 \n 换行符
tooltip=" 天气实况
------------------
天气状况: ${text}
当前温度: ${temp}°C

------------------
"

# 8. 一次性生成标准 Waybar JSON (利用 jq 安全转义所有变量)
jq -n -c \
    --arg text "${icon} ${temp}°C" \
    --arg tooltip "$tooltip" \
    --arg class "$class" \
    '{
        text: $text,
        tooltip: $tooltip,
        class: $class
    }'
