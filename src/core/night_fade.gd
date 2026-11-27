class_name NightFade
extends RefCounted
## The shared night fade (D-043). One pure function maps the local time of day to a night factor, so T2's
## lighting and T3's palette (surface to surface_night) change together.
##
## art-direction §3 "Time of day": evening and night run 17:00 to 06:00 local, morning 06:00 to 11:00,
## afternoon 11:00 to 17:00, and presets cross-fade over about 20 minutes. Here each fade starts at the
## boundary and eases with smoothstep: night rises 17:00 to 17:20 and falls 06:00 to 06:20; morning hands
## over to afternoon 11:00 to 11:20.
##
## Callers: Session.get_night_factor() for "now" (it follows the debug time scale), or `at_unix()` for a
## time-lapse frame's at_unix.

const DAY_S: float = 86400.0
const EVENING_START_S: float = 17.0 * 3600.0
const MORNING_START_S: float = 6.0 * 3600.0
const AFTERNOON_START_S: float = 11.0 * 3600.0
const FADE_S: float = 20.0 * 60.0


## 0 in full day, 1 in full night, smooth in between. Any seconds value works; it wraps at 24 h.
static func factor(local_seconds_of_day: float) -> float:
	var t: float = fposmod(local_seconds_of_day, DAY_S)
	if t >= EVENING_START_S:
		return _ease((t - EVENING_START_S) / FADE_S)
	if t < MORNING_START_S:
		return 1.0
	return 1.0 - _ease((t - MORNING_START_S) / FADE_S)


## The night factor at a Unix time, in a time zone `utc_offset_s` seconds ahead of UTC.
static func at_unix(unix: float, utc_offset_s: int) -> float:
	return factor(unix + float(utc_offset_s))


## Weights of art-direction's three light presets as Vector3(morning, afternoon, night), summing to 1.
## z is exactly factor().
static func preset_weights(local_seconds_of_day: float) -> Vector3:
	var t: float = fposmod(local_seconds_of_day, DAY_S)
	var night: float = factor(t)
	var morning_share: float = 0.0
	if t >= MORNING_START_S and t < EVENING_START_S:
		morning_share = 1.0 - _ease((t - AFTERNOON_START_S) / FADE_S)
	var morning: float = (1.0 - night) * morning_share
	return Vector3(morning, 1.0 - night - morning, night)


static func _ease(x: float) -> float:
	return smoothstep(0.0, 1.0, clampf(x, 0.0, 1.0))
