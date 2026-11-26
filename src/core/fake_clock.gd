class_name FakeClock
extends Clock
## The test clock (test-plan.md §12). Wall time and monotonic time move separately, so tests can fake
## clock jumps (set_now) and real elapsed time (advance) independently.

var _now: int = 0
var _offset: int = 0
var _mono_ms: int = 0


func _init(start_unix: int = 1795651200, offset_s: int = 0) -> void:
	_now = start_unix
	_offset = offset_s


## A wall-clock jump (the user or the network changed the clock). Monotonic time does not move.
func set_now(unix: int) -> void:
	_now = unix


## Real time passing: wall and monotonic both move by `seconds`.
func advance(seconds: int) -> void:
	_now += seconds
	_mono_ms += seconds * 1000


## The local UTC offset changes (travel, daylight saving).
func set_offset(offset_s: int) -> void:
	_offset = offset_s


## Monotonic time only (for the in-session guard, CLK-09).
func advance_monotonic_ms(ms: int) -> void:
	_mono_ms += ms


func now_unix() -> int:
	return _now


func local_utc_offset_s() -> int:
	return _offset


func monotonic_msec() -> int:
	return _mono_ms
