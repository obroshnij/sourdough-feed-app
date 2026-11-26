class_name DebugClock
extends Clock
## Debug builds only (architecture.md §5.2, LINT-10): the system clock plus a time scale and manual advance.
## Session constructs it only when OS.is_debug_build(). Scaled time is never ahead of how the sim steps:
## the sim still takes ordinary 60 s steps, just more of them per real second.

var _sys: SystemClock = SystemClock.new()
var _anchor_sys: float = 0.0
var _anchor_now: float = 0.0
var _time_scale: float = 1.0


func _init(time_scale: float = 1.0) -> void:
	_anchor_sys = Time.get_unix_time_from_system()
	_anchor_now = _anchor_sys
	_time_scale = maxf(time_scale, 0.0)


func get_time_scale() -> float:
	return _time_scale


func set_time_scale(scale: float) -> void:
	var now: float = _now_float()
	_anchor_sys = Time.get_unix_time_from_system()
	_anchor_now = now
	_time_scale = maxf(scale, 0.0)


## Jumps forward by `seconds` at once.
func advance(seconds: float) -> void:
	_anchor_now += seconds


func now_unix() -> int:
	return int(_now_float())


func local_utc_offset_s() -> int:
	return _sys.local_utc_offset_s()


## Scaled like now_unix, so the in-session guard sees consistent deltas.
func monotonic_msec() -> int:
	return int(_now_float() * 1000.0)


func _now_float() -> float:
	return _anchor_now + (Time.get_unix_time_from_system() - _anchor_sys) * _time_scale
