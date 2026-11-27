class_name LocalDay
extends RefCounted
## Pure local-time math for quiet hours and day keys. The sim never reads `Time`; the UTC offset
## arrives as an argument (architecture.md §5.1).


static func minute_of_day(unix: int, utc_offset_s: int) -> int:
	@warning_ignore("integer_division")
	var m: int = posmod(unix + utc_offset_s, 86400) / 60
	return m


## Days since 1970-01-01 in local time: changes exactly when day_key() does, without building a string.
static func day_index(unix: int, utc_offset_s: int) -> int:
	var t: int = unix + utc_offset_s
	@warning_ignore("integer_division")
	return (t - posmod(t, 86400)) / 86400


## Local calendar date as "YYYY-MM-DD" (proleptic Gregorian, H. Hinnant's civil_from_days).
static func day_key(unix: int, utc_offset_s: int) -> String:
	var t: int = unix + utc_offset_s
	@warning_ignore("integer_division")
	var days: int = (t - posmod(t, 86400)) / 86400
	var ymd: Vector3i = civil_from_days(days)
	return "%04d-%02d-%02d" % [ymd.x, ymd.y, ymd.z]


@warning_ignore("integer_division")
static func civil_from_days(days: int) -> Vector3i:
	var z: int = days + 719468
	var era: int = (z if z >= 0 else z - 146096) / 146097
	var doe: int = z - era * 146097
	var yoe: int = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
	var y: int = yoe + era * 400
	var doy: int = doe - (365 * yoe + yoe / 4 - yoe / 100)
	var mp: int = (5 * doy + 2) / 153
	var d: int = doy - (153 * mp + 2) / 5 + 1
	var m: int = mp + 3 if mp < 10 else mp - 9
	if m <= 2:
		y += 1
	return Vector3i(y, m, d)
