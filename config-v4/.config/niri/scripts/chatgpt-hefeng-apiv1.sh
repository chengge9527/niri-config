#!/usr/bin/env bash
set -euo pipefail

########################
# 用户配置
########################

API_KEY="${HF_API_KEY:?ERROR: API_KEY is not set}"
LAT="29.51"
LON="106.49"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-weather"
CACHE_FILE="$CACHE_DIR/weather-v1.json"
CURL_CONNECT_TIMEOUT=5                     # curl 连接超时 (秒)
CURL_MAX_TIME=10                           # curl 最大执行时间 (秒)
# 新增重试
CURL_RETRY=3                               # 重试次数
CURL_RETRY_DELAY=2                         # 重试延迟（秒）
CURL_RETRY_MAX_TIME=30                     # 总重试时间上限


CACHE_EXPIRE=600

mkdir -p "$CACHE_DIR"

########################

now=$(date +%s)

need_update=1

if [[ -f "$CACHE_FILE" ]]; then
    file_time=$(stat -c %Y "$CACHE_FILE")
    if (( now - file_time < CACHE_EXPIRE )); then
        need_update=0
    fi
fi

if (( need_update )); then

    if curl -fsS \
        --compressed \
        --connect-timeout "$CURL_CONNECT_TIMEOUT" \
        --max-time "$CURL_MAX_TIME" \
        --retry "$CURL_RETRY" \
        --retry-delay "$CURL_RETRY_DELAY" \
        --retry-max-time "$CURL_RETRY_MAX_TIME" \
        "https://m53aarq76h.re.qweatherapi.com/weather/v1/current/${LAT}/${LON}?key=${API_KEY}" \
        -o "${CACHE_FILE}.tmp"
    then
        mv "${CACHE_FILE}.tmp" "$CACHE_FILE"
    fi

fi

[[ -f "$CACHE_FILE" ]] || exit 1

# jq提取字段
IFS=$'\t' read -r text icon temperature feelsLike humidity speed windGust amount intensity pressure visibility dewPoint cloudCover uvIndex < <(
    jq -r '[
        .condition.text,
        .condition.code,
        (.temperature.value * 10 | round) / 10,
        (.feelsLike.value * 10 | round) / 10,
        (.humidity * 100 | round),
        .wind.speed.value,
        .windGust.value,
        .precipitation.amount.value,
        .precipitation.intensity.value,
        (.pressure.value | round),
        (.visibility.value / 1000 * 100 | round) / 100,
        .dewPoint.value,
        (.cloudCover * 100 | round),
        .uvIndex
    ] | @tsv' "$CACHE_FILE" 2>/dev/null || echo ""
)

icon_code="$icon"

        # .condition.text,
        # .condition.code,
        # (.temperature.value * 10 | round) / 10,   天气保留1小数点一位
        # (.feelsLike.value * 10 | round) / 10,
        # (.humidity * 100 | round),
        # .wind.speed.value,
        # .windGust.value,
        # .precipitation.amount.value,
        # .precipitation.intensity.value,
        # .pressure.value,
        # (.visibility.value / 1000 * 100 | round) / 100,
        # .dewPoint.value,
        # (.cloudCover * 100 | round),
        # .uvIndex


case "$icon" in
    100|150)                    icon=""; class="clear" ;;
    10[1-4]|15[1-3])            icon=""; class="clouds" ;;
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

# 格式化时间
formatted_cachetime=$(date -r "$CACHE_FILE" "+%m-%d %H:%M" 2>/dev/null || echo "")

tooltip="天气: ${text} (${icon_code})
温度: ${temperature}°
体感: ${feelsLike}°
湿度: ${humidity}%
气压: ${pressure} hPa
风速: ${speed} m/s
云量: ${cloudCover}
紫外线: ${uvIndex}
能见度: ${visibility} km
降水强度: ${intensity} mm/h
小时降水: ${amount} mm/h
--------------------
缓存时间: ${formatted_cachetime}"

jq -cn \
    --arg text "${icon} ${temperature}°" \
    --arg tooltip "$tooltip" \
    --arg class "$class" \
    '{
        text: $text,
        tooltip: $tooltip,
        class: $class
    }'
