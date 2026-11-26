class_name TimePolicy
extends RefCounted
## Clock rules (architecture.md §5.3, D-024, ADR-006). Pure; tests read the constants from here.
## gap = sim_time_unix - now_unix:
##   gap <= 0                 catch up min(-gap, 14 d)
##   0 < gap <= 21,600 s      hold: elapsed 0, keep the anchor (the clock went back a little)
##   gap > 21,600 s           re-anchor: sim_time_unix = grid(now), state unchanged

const CLOCK_REANCHOR_GAP_S: int = 21600
const MONOTONIC_GUARD_S: int = 300
const CATCH_UP_CAP_S: int = SimConstants.CATCH_UP_CAP_S


static func resolve(sim_time_unix: int, now_unix: int) -> TimeResolution:
	var r := TimeResolution.new()
	r.gap_s = sim_time_unix - now_unix
	if r.gap_s <= 0:
		r.action = &"catch_up"
		r.target_unix = now_unix
	elif r.gap_s <= CLOCK_REANCHOR_GAP_S:
		r.action = &"hold"
		r.target_unix = sim_time_unix
	else:
		r.action = &"reanchor"
		r.target_unix = Sim.grid(now_unix)
	return r


## In session: if wall time moved more than 300 s further than monotonic time, trust only the monotonic
## delta (a clock change while foregrounded). Otherwise use the wall delta.
static func foreground_elapsed_s(wall_delta_s: int, monotonic_delta_s: int) -> int:
	if wall_delta_s - monotonic_delta_s > MONOTONIC_GUARD_S:
		return monotonic_delta_s
	return wall_delta_s
