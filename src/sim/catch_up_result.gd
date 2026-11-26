class_name CatchUpResult
extends RefCounted
## What a catch-up produced (data-models.md §8). Carried by session_ready and resumed; may be empty.

const MAX_SNAPSHOTS: int = 30

var from_unix: int = 0
var to_unix: int = 0
var simulated_s: int = 0
## The absence passed the 14-day cap; the state was held and the clock jumped to now.
var capped: bool = false
## The clock was more than 6 h behind the anchor and was re-anchored (architecture §5.3).
var reanchored: bool = false
var steps: int = 0
## Each {"at_unix": int, "from": String, "to": String}.
var transitions: Array[Dictionary] = []
var events: Array[SimEvent] = []
## At most 30, evenly spaced, for the time-lapse.
var snapshots: Array[VisualParams] = []
## For example peak_unix, peak_rise, hooch_first_unix.
var notable: Dictionary = {}


static func empty(at_unix: int) -> CatchUpResult:
	var r := CatchUpResult.new()
	r.from_unix = at_unix
	r.to_unix = at_unix
	return r
