#!/bin/bash
# jacketcheck: shows the weather for the walk to and from each class and what to bring

# Configuration and API settings
SCHEDULE="schedule.txt"
FORECAST="forecast.json"
URL="https://api.weather.gov/gridpoints/IND/30,97/forecast/hourly"
USER_AGENT="jacketcheck (github.com/yuvraj-del)"

JACKET_TEMP=55
RAIN_CHANCE=40
HOT_TEMP=75

# Helper function: turn a time like "9:30" into a 2-digit hour key like "09"
format_hour() {
    local h=${1%%:*}
    printf "%02d" "$((10#$h))"
}

# Helper function: query the JSON forecast for a specific hour key
get_forecast_data() {
    local key=$1
    jq -r --arg k "$key" '
        .properties.periods[]
        | select(.startTime | startswith($k))
        | "\(.temperature) \(.probabilityOfPrecipitation.value // 0) \(.shortForecast)"
    ' "$FORECAST" | head -n 1 | tr -d '\r'
}

# Make sure the schedule file exists before proceeding
if [ ! -f "$SCHEDULE" ]; then
    echo "Error: $SCHEDULE not found."
    exit 1
fi

# Fetch the latest hourly forecast from NWS API
if ! curl -sf -H "User-Agent: $USER_AGENT" "$URL" -o "$FORECAST"; then
    echo "Error: could not get the forecast. Check your internet connection."
    exit 1
fi

# Print table header with widened condition column (40 chars)
printf "%-12s %-6s %-6s %-6s %-6s %-40s %s\n" "CLASS" "START" "END" "TEMP" "RAIN" "CONDITIONS" "BRING"

# Determine today's date
today=$(date +%Y-%m-%d)

while IFS=, read -r days class start end || [ -n "$days" ]; do
    # Strip carriage returns and skip empty lines
    end=${end%$'\r'}
    [ -z "$class" ] && continue

    # Build timestamp keys for start and end walk times
    start_key="${today}T$(format_hour "$start")"
    end_key="${today}T$(format_hour "$end")"

    # Fetch weather data for both walk times
    read -r start_temp start_rain start_cond < <(get_forecast_data "$start_key")
    read -r end_temp end_rain end_cond < <(get_forecast_data "$end_key")

    # Fall back if a class is already in progress and one hour key is missing
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

    # Determine colder temperature and its condition
    if [ "$start_temp" -lt "$end_temp" ]; then
        temp="$start_temp"
        temp_cond="$start_cond (walk there)"
    else
        temp="$end_temp"
        temp_cond="$end_cond (walk back)"
    fi

    # Determine higher rain chance and its condition
    if [ "$start_rain" -gt "$end_rain" ]; then
        rain="$start_rain"
        rain_cond="$start_cond (walk there)"
    else
        rain="$end_rain"
        rain_cond="$end_cond (walk back)"
    fi

    # Align condition with rain if precipitation threshold is met, otherwise use temp condition
    if [ "$rain" -ge "$RAIN_CHANCE" ]; then
        cond="$rain_cond"
    else
        cond="$temp_cond"
    fi

    # Evaluate clothing recommendations based on configurable weather thresholds
    bring=""
    [ "$temp" -lt "$JACKET_TEMP" ] && bring+="jacket "
    [ "$rain" -ge "$RAIN_CHANCE" ] && bring+="umbrella "
    [ "$temp" -gt "$HOT_TEMP" ] && bring+="light clothes "
    [ -z "$bring" ] && bring="nothing extra"

    # Print formatted row for today's class
    printf "%-12s %-6s %-6s %-6s %-6s %-40s %s\n" "$class" "$start" "$end" "${temp}F" "${rain}%" "$cond" "$bring"

done < "$SCHEDULE"