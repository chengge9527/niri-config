#!/usr/bin/env bash
# =============================================================================
# Waybar 天气模块脚本 (OpenWeatherMap API)
# =============================================================================
# 严格模式：遇到错误退出 (-e)，未定义变量报错 (-u)，管道中任何命令失败则失败 (-o pipefail)
set -euo pipefail

# ==========================================
# 集中配置区 (Configurations)
# ==========================================
API_KEY="${OWM_API_KEY:?ERROR: OWM_API_KEY is not set}"                # 替换为你的 OpenWeatherMap API Key
LAT="29.5625"                              # 纬度
LON="106.5000"                             # 经度
UNITS="metric"                             # 单位: metric(摄氏度) / imperial(华氏度)
LANG="zh_cn"                               # 语言: zh_cn / en
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-weather"
CACHE_FILE="${CACHE_DIR}/weather.json"
CACHE_TIMEOUT=300                          # 缓存有效期 (秒)
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
get_weather_meta() {
    local condition_id="$1"
    local tod="$2"
    local icon class

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

    # 以空格分隔输出，供外部读取
    echo "$icon $class"
}

# 从 API 拉取数据并原子写入缓存
fetch_weather() {
    local url="https://api.openweathermap.org/data/2.5/weather?lat=${LAT}&lon=${LON}&appid=${API_KEY}&units=${UNITS}&lang=${LANG}"
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
read -r temp feels_like humidity pressure grnd_level desc condition_id icon_code wind_speed rain_1h snow_1h city_name < <(
    jq -r '[
        .main.temp,
        .main.feels_like,
        .main.humidity,
        .main.pressure,
        .main.grnd_level,
        .weather[0].description,
        .weather[0].id,
        .weather[0].icon,
        .wind.speed,
        (.rain."1h" // 0),
        (.snow."1h" // 0),
        .name
    ] | @tsv' "$CACHE_FILE" 2>/dev/null || echo ""
)

# 5. 校验提取到的核心数据有效性
if [[ -z "${temp:-}" || "$temp" == "null" ]]; then
    # 通常是因为 API Key 错误、欠费或并发受限被 OpenWeatherMap 返回报错 JSON
    print_error "API 响应异常，请检查 API Key 或请求配额"
fi

# 6. 数据格式化处理
temp_round=$(printf "%.1f" "$temp")
feels_like_round=$(printf "%.1f" "$feels_like")
time_of_day="${icon_code: -1}"

# 合并调用：一次性获取图标和 CSS Class
read -r icon weather_class <<< "$(get_weather_meta "$condition_id" "$time_of_day")"

# 7. 组装输出所需的数据变量
# Alt (替代文本) 和 Percentage (百分比，这里绑定到湿度)
alt="$desc"
percentage="$humidity"

# 动态构建降水量文本
precip_info=""
# 使用 bc 进行浮点数比较，或者简单判断字符串不等于 "0"
if awk "BEGIN {exit !($rain_1h > 0)}"; then
    precip_info+=$'\n'"降雨量(1h): ${rain_1h} mm"
fi
if awk "BEGIN {exit !($snow_1h > 0)}"; then
    precip_info+=$'\n'"降雪量(1h): ${snow_1h} mm"
fi



# if [[ "$snow_1h" != "0" ]]; then
#     precip_info+=$'\n'"降雪量(1h): ${snow_1h} mm"
# fi

# 添加下次更新时间
# new_time=$(date +"%H:%M:%S" -d "+${CACHE_TIMEOUT} seconds")
# 缓存文件更改时间
time_part=$(date -r "$CACHE_FILE" +%H:%M:%S)

# Tooltip (多行详细信息)
# 直接利用 Bash 的原生多行字符串，传递给 jq 时会自动转换成合法的 \n 换行符
tooltip="${city_name} 天气实况
------------------
天气状况: ${desc}
当前温度: ${temp_round}°C
体感温度: ${feels_like_round}°C
相对湿度: ${humidity}%
当前风速: ${wind_speed} m/s
当前气压: ${grnd_level}hPa${precip_info}
------------------
更新时间: ${time_part}
API状态码: ${condition_id}"

# 8. 一次性生成标准 Waybar JSON (利用 jq 安全转义所有变量)
jq -n -c \
    --arg text "${icon} ${temp_round}°C" \
    --arg tooltip "$tooltip" \
    --arg alt "$alt" \
    --arg class "$weather_class" \
    --arg percentage "$percentage" \
    '{
        text: $text,
        tooltip: $tooltip,
        alt: $alt,
        class: $class,
        percentage: ($percentage | tonumber)
    }'
