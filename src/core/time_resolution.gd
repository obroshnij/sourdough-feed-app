class_name TimeResolution
extends RefCounted
## What `TimePolicy.resolve()` decided for one launch or resume (architecture.md §5.3).

## &"catch_up", &"hold" or &"reanchor".
var action: StringName = &"hold"
## catch_up: simulate up to this time (CatchUp caps it at 14 days). reanchor: the new anchor, grid(now).
var target_unix: int = 0
## sim_time_unix - now_unix.
var gap_s: int = 0
