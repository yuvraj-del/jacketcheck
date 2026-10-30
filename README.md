# jacketcheck

A Bash script that tells you what to wear based on the weather when your classes end.

## Goal

Weather at Purdue changes a lot during the day. This tool checks the forecast for when each class ends so I know what to bring before I leave.

## MVP

- Read my class schedule from `schedule.txt`
- Get the hourly forecast from the National Weather Service API
- Show the weather when each class ends
- Recommend a jacket, umbrella, or light clothes

## Tech Stack

- Bash
- curl, jq, date
- National Weather Service API

## Future Plans

- Morning cron job
- `--tomorrow` flag
- MWF vs. TTh schedules
- Forecast caching
- Error messages and `--help`
- Colored output

## Planning

- [Eisenhower Matrix](docs/eisenhower-matrix.pdf)
- [System Diagram](docs/diagram.drawio.png)
