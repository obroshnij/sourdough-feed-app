class_name ForecastWindow
extends RefCounted
## The {window} words of FORECAST_LINE and ONBOARD_HANDOFF_BODY (game-copy §9). Pure: local time arrives as
## a UTC offset, never from `Time`. The UI shows words only, never a countdown or digits (AC-05.7).

const SOON_S: int = 90 * 60


## The WINDOW_* key for a peak expected at `target_unix`, seen from `now_unix`. Both are sim or wall seconds;
## `utc_offset_s` is the device's local offset.
static func key(now_unix: int, target_unix: int, utc_offset_s: int) -> StringName:
	if target_unix - now_unix <= SOON_S:
		return &"WINDOW_SOON"
	var day_now: int = _local_day(now_unix, utc_offset_s)
	var day_target: int = _local_day(target_unix, utc_offset_s)
	var minute: int = LocalDay.minute_of_day(target_unix, utc_offset_s)
	var hour: int = int(minute / 60.0)
	match day_target - day_now:
		0:
			if hour < 5:
				# Today 00:00 to 04:59 isn't in the §9 table; it reads as overnight.
				return &"WINDOW_OVERNIGHT"
			if hour < 11:
				return &"WINDOW_THIS_MORNING"
			if hour < 14:
				return &"WINDOW_LUNCHTIME"
			if hour < 17:
				return &"WINDOW_THIS_AFTERNOON"
			if hour < 21:
				return &"WINDOW_THIS_EVENING"
			return &"WINDOW_TONIGHT"
		1:
			if hour < 5:
				return &"WINDOW_OVERNIGHT"
			if hour < 11:
				return &"WINDOW_TOMORROW_MORNING"
			if hour < 14:
				return &"WINDOW_TOMORROW_LUNCHTIME"
			if hour < 17:
				return &"WINDOW_TOMORROW_AFTERNOON"
			return &"WINDOW_TOMORROW_EVENING"
	return &"WINDOW_LATER"


## The forecast's peak midpoint as an absolute time, counted from `from_unix` (when the forecast starts).
static func peak_mid_unix(forecast: PeakForecast, from_unix: int) -> int:
	return from_unix + roundi((forecast.peak_min_s + forecast.peak_max_s) * 0.5)


## The window key for a forecast that starts at `from_unix`, or &"" when it has no window.
static func for_forecast(forecast: PeakForecast, from_unix: int, now_unix: int, utc_offset_s: int) -> StringName:
	if forecast == null or not forecast.has_window:
		return &""
	return key(now_unix, peak_mid_unix(forecast, from_unix), utc_offset_s)


static func _local_day(unix: int, utc_offset_s: int) -> int:
	var t: int = unix + utc_offset_s
	return int(floor(t / 86400.0))
