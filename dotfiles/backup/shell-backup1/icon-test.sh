

read -r icon_cod updateTime < <(
    jq -r '[
        .now.icon,
        .updateTime
    ] | @tsv' "${XDG_CACHE_HOME:-$HOME/.cache}/hefeng-weather/weather.json" 2>/dev/null || echo ""
)





case "${icon_cod}" in
    100|105)            icon=""; class="clear" ;;
    10[1-4]|15[1-3])    icon="󰖐"; class="clouds" ;;
    30[0-4])            icon=""; class="thunderstorm" ;;
    30[5-9]|31[0-8])    icon=""; class="rain" ;;
    4[0-9][0-9])        icon=""; class="snow" ;;
    5[0-9][0-9])        icon=""; class="fog" ;;
    9[0-9][0-9])        icon=""; class="extreme" ;;
    *)                  icon=""; class="unknown" ;;
esac

echo "$icon $class $updateTime"


