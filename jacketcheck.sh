#!/bin/bash
# jacketcheck: shows the weather for the walk to and from each class and what to bring

# Configuration and API settings
SCHEDULE="schedule.txt"
FORECAST="forecast.json"
URL="https://api.weather.gov/gridpoints/IND/30,97/forecast/hourly"
USER_AGENT="jacketcheck (github.com/yuvraj-del)"

# Make sure the schedule file exists before proceeding
if [ ! -f "$SCHEDULE" ]; then
    echo "Error: $SCHEDULE not found."
    exit 1
fi

while IFS=, read -r days class start end; do
    # Strip carriage returns and skip empty lines
    end=${end%$'\r'}
    [ -z "$class" ] && continue

    echo "$class: $start - $end"
done < "$SCHEDULE"

#Fetch the latest hourly forecast from NWS API
if ! curl -sf -H "User-Agent: $USER_AGENT" "$URL" -o "$FORECAST"; then
    echo "Error: could not get the forecast. Check your internet connection."
    exit 1
fi