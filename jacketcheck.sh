#!/bin/bash
# jacketcheck: shows the weather for the walk to and from each class and what to bring

# Configuration and API settings
SCHEDULE="schedule.txt"
FORECAST="forecast.json"
URL="https://api.weather.gov/gridpoints/IND/30,97/forecast/hourly"
USER_AGENT="jacketcheck (github.com/yuvraj-del)"

# Clothing thresholds kept as variables so they're easy to change
JACKET_TEMP=55
RAIN_CHANCE=40
HOT_TEMP=75

# Helper function: turn "9:30" into "09"
format_hour() {
    local h=${1%%:*}
    # Why: 10# forces base 10, else Bash reads "08" and "09" as invalid octal numbers
    printf "%02d" "$((10#$h))"
}

# Helper function: query the JSON forecast for a specific hour key
get_forecast_data() {
    local key=$1
    # Why: only match date + hour, because the timezone offset changes at daylight savings
    # Why: tr -d '\r' because jq on Windows adds \r, which made rows overwrite themselves
    jq -r --arg k "$key" '
        .properties.periods[]
        | select(.startTime | startswith($k))
        | "\(.temperature) \(.probabilityOfPrecipitation.value // 0) \(.shortForecast)"
    ' "$FORECAST" | head -n 1 | tr -d '\r'
}

if [ ! -f "$SCHEDULE" ]; then
    echo "Error: $SCHEDULE not found." >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required but not installed. Install it with 'winget install jqlang.jq', 'sudo apt install jq', or 'brew install jq'." >&2
    exit 1
fi

# Why: NWS rejects requests without a User-Agent
# Why: -f so errors don't get saved as the forecast
if ! curl -sf -H "User-Agent: $USER_AGENT" "$URL" -o "$FORECAST"; then
    echo "Error: could not get the forecast. Check your internet connection." >&2
    exit 1
fi

# Why: CONDITIONS is 40 wide to fit NWS text like "Slight Chance Rain Showers (walk there)"
printf "%-12s %-6s %-6s %-6s %-6s %-40s %s\n" "CLASS" "START" "END" "TEMP" "RAIN" "CONDITIONS" "BRING"

today=$(date +%Y-%m-%d)
# Why: date +%u gives 1-7 for Mon-Sun, and "x" gets index 0 so the numbers line up with the letters
day_letters=(x M T W R F S U)
today_letter=${day_letters[$(date +%u)]}

count=0
# Why: || [ -n "$days" ] keeps it from skipping the last line if it doesn't end with a newline
while IFS=, read -r days class start end || [ -n "$days" ]; do
    # Why: Windows adds \r at the end of each line, which would break the hour math
    end=${end%$'\r'}
    [ -z "$class" ] && continue

    # Why: missing time would make format_hour crash, so warn and skip
    if [ -z "$start" ] || [ -z "$end" ]; then
        echo "Warning: skipping $class due to missing start or end time." >&2
        continue
    fi

    [[ "$days" != *"$today_letter"* ]] && continue
    count=$((count + 1))

    start_key="${today}T$(format_hour "$start")"
    end_key="${today}T$(format_hour "$end")"

    read -r start_temp start_rain start_cond < <(get_forecast_data "$start_key")
    read -r end_temp end_rain end_cond < <(get_forecast_data "$end_key")

    # Why: NWS hourly data starts at the current hour, so if class already started use the end time
    if [ -z "$start_temp" ] && [ -z "$end_temp" ]; then
        printf "%-12s %-6s %-6s %s\n" "$class" "$start" "$end" "No forecast available"
        continue
    elif [ -z "$start_temp" ]; then
        start_temp="$end_temp"
        start_rain="$end_rain"
        start_cond="$end_cond"
    elif [ -z "$end_temp" ]; then
        end_temp="$start_temp"
        end_rain="$start_rain"
        end_cond="$start_cond"
    fi

    # Why: use the worse of the two walks (colder temp, higher rain chance)
    # Why: if either one needs a jacket/umbrella you need it
    if [ "$start_temp" -lt "$end_temp" ]; then
        temp="$start_temp"
        temp_cond="$start_cond (walk there)"
    else
        temp="$end_temp"
        temp_cond="$end_cond (walk back)"
    fi

    if [ "$start_rain" -gt "$end_rain" ]; then
        rain="$start_rain"
        rain_cond="$start_cond (walk there)"
    else
        rain="$end_rain"
        rain_cond="$end_cond (walk back)"
    fi

    # Why: show the rainy walk's conditions when an umbrella is recommended, so the text matches the advice
    if [ "$rain" -ge "$RAIN_CHANCE" ]; then
        cond="$rain_cond"
    else
        cond="$temp_cond"
    fi

    bring=""
    [ "$temp" -lt "$JACKET_TEMP" ] && bring+="jacket "
    [ "$rain" -ge "$RAIN_CHANCE" ] && bring+="umbrella "
    [ "$temp" -gt "$HOT_TEMP" ] && bring+="light clothes "
    [ -z "$bring" ] && bring="nothing extra"

    printf "%-12s %-6s %-6s %-6s %-6s %-40s %s\n" "$class" "$start" "$end" "${temp}F" "${rain}%" "$cond" "$bring"

done < "$SCHEDULE"

if [ "$count" -eq 0 ]; then
    echo "No classes today."
fi