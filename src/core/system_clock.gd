class_name SystemClock
extends Clock
## The device clock. Release builds construct this directly, so no time-scale path exists there.


func now_unix() -> int:
	return int(Time.get_unix_time_from_system())


func local_utc_offset_s() -> int:
	var tz: Dictionary = Time.get_time_zone_from_system()
	var bias: int = tz.get("bias", 0)
	return bias * 60


func monotonic_msec() -> int:
	return Time.get_ticks_msec()
