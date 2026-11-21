#!/bin/bash
# jacketcheck: shows the weather for the walk to and from each class and what to bring

# Configuration and API settings
SCHEDULE="schedule.txt"
FORECAST="forecast.json"
URL="https://api.weather.gov/gridpoints/IND/30,97/forecast/hourly"
USER_AGENT="jacketcheck (github.com/yuvraj-del)"

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
    ' "$FORECAST" | head -n 1
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

while IFS=, read -r days class start end; do
    # Strip carriage returns and skip empty lines
    end=${end%$'\r'}
    [ -z "$class" ] && continue

    echo "$class: $start - $end"
done < "$SCHEDULE"