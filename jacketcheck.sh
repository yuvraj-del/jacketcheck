+#!/bin/bash
+# jacketcheck: shows the weather for the walk to and from each class and what to bring
+
+# Configuration and API settings
+SCHEDULE="schedule.txt"
+FORECAST="forecast.json"
+URL="https://api.weather.gov/gridpoints/IND/30,97/forecast/hourly"
+USER_AGENT="jacketcheck (github.com/yuvraj-del)"
+
+# Make sure the schedule file exists before proceeding
+if [ ! -f "$SCHEDULE" ]; then
+    echo "Error: $SCHEDULE not found."
+    exit 1
+fi
