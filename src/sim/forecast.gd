class_name Forecast
extends RefCounted
## Peak forecast (game-mechanics.md §6). Runs the same step function forward at jitter 0.95 and 1.05,
## up to 48 h (about 700 steps for a normal feed). Pure; no RNG.

const HORIZON_STEPS: int = 48 * 60
const JITTERS: Array[float] = [0.95, 1.05]
const NO_WINDOW_STATES: Array[StringName] = [&"dormant", &"unhealthy", &"moldy", &"hungry"]
## spec §14.1 `warm_and_quick`: the reference run is the same feed at 22 C.
const REFERENCE_TEMP_C: float = 22.0


## warm_and_quick's reference (spec §14.1, T4): seconds from a feed to its first at_peak step if the jar sat
## at the counter (22 C) the whole time. `after_feed` is the post-feed state, copied with its own feed_jitter
## and temp_c set to 22. -1 when there is no at_peak within HORIZON_STEPS (or the state is moldy or empty).
static func reference_at_peak_s(after_feed: StarterState) -> int:
	if after_feed.moldy or after_feed.empty:
		return -1
	var s: StarterState = after_feed.copy()
	s.temp_c = REFERENCE_TEMP_C
	var counter: EnvironmentState = EnvironmentState.at_location(&"counter")
	for i: int in HORIZON_STEPS:
		if StateDeriver.derive(s, counter).rise_phase == &"at_peak":
			return i * SimConstants.GRID_S
		Sim.step(s, counter)
	return -1


## The "warning signs" forecast (D-057): seconds until mold_risk reaches the warning threshold (the state
## turns unhealthy, spec §12.2) if nothing changes, stepping a copy in `env` for at most `max_steps` (14 days,
## the catch-up cap). 0 when it already has; -1 when it never does in time, or the starter is moldy or empty.
## Only Sim.step runs (no derivation), so 14 days take about a third of a catch-up.
static func warning_signs_after_s(state: StarterState, env: EnvironmentState,
		max_steps: int = SimConstants.CATCH_UP_CAP_STEPS) -> int:
	if state.moldy or state.empty:
		return -1
	if state.mold_risk >= SimConstants.MOLD_WARN:
		return 0
	var s: StarterState = state.copy()
	for i: int in max_steps:
		Sim.step(s, env)
		if s.mold_risk >= SimConstants.MOLD_WARN:
			return (i + 1) * SimConstants.GRID_S
	return -1


## With `feed`, forecasts the state after that feed (feed_u is irrelevant: both jitters are simulated).
## Without, forecasts from `state` as it is. Times are seconds from that starting point.
static func peak_window(state: StarterState, env: EnvironmentState, feed: FeedAction = null) -> PeakForecast:
	var out := PeakForecast.new()
	var start: StarterState = state.copy()
	if feed != null:
		if not Sim.feed(start, feed.kept_g, feed.flour_g, feed.water_g, 0.5, feed.hooch_choice == &"stir_in"):
			return out
	if NO_WINDOW_STATES.has(StateDeriver.derive(start, env).state):
		return out
	var first: bool = true
	for jitter: float in JITTERS:
		var s: StarterState = start.copy()
		s.feed_jitter = jitter
		var at_peak_s: float = -1.0
		var peak_s: float = 0.0
		var peak: float = s.rise
		for i: int in HORIZON_STEPS:
			var d: DerivedState = StateDeriver.derive(s, env)
			var t: float = i * SimConstants.DT_S
			if d.rise_phase == &"at_peak" and at_peak_s < 0.0:
				at_peak_s = t
			if s.rise > peak:
				peak = s.rise
				peak_s = t
			if at_peak_s >= 0.0 and d.rise_phase == &"collapsing":
				break
			Sim.step(s, env)
		if at_peak_s < 0.0:
			return PeakForecast.new()
		if first:
			out.at_peak_start_min_s = at_peak_s
			out.at_peak_start_max_s = at_peak_s
			out.peak_min_s = peak_s
			out.peak_max_s = peak_s
			out.peak_rise_min = peak
			out.peak_rise_max = peak
			first = false
		else:
			out.at_peak_start_min_s = minf(out.at_peak_start_min_s, at_peak_s)
			out.at_peak_start_max_s = maxf(out.at_peak_start_max_s, at_peak_s)
			out.peak_min_s = minf(out.peak_min_s, peak_s)
			out.peak_max_s = maxf(out.peak_max_s, peak_s)
			out.peak_rise_min = minf(out.peak_rise_min, peak)
			out.peak_rise_max = maxf(out.peak_rise_max, peak)
	out.has_window = true
	return out
