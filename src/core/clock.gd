class_name Clock
extends RefCounted
## The time seam (architecture.md §5.2). Session owns one; tests pass a FakeClock.


## Unix seconds, UTC.
func now_unix() -> int:
	return 0


## Local offset from UTC in seconds. Read for quiet hours and day keys only, never by the sim equations.
func local_utc_offset_s() -> int:
	return 0


## Monotonic milliseconds for the in-session guard (architecture §5.3). Never saved.
func monotonic_msec() -> int:
	return 0
