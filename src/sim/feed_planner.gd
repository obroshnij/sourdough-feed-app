class_name FeedPlanner
extends RefCounted
## The slice's feed sheet logic (game-mechanics §2.1 to §2.5, D-020). Pure: the state, environment and
## history arrive as arguments, and nothing here mutates them. Session.plan_feed() and preview_feed() wrap it.
##
## The schedule question ("When will you check next?") has three answers. Each picks the ratio preset whose
## forecast at_peak start falls inside the answer's window at the current location, the one closest to the
## window's center if several do. At the counter each answer maps to exactly one preset (BT-17). If none fits,
## the answer's own preset is kept and `fit_key` says why in plain words. Nothing here ever blocks a feed.

const ANSWERS: Array[StringName] = [&"soon", &"later", &"tomorrow"]
## The answer's own preset, used when no preset fits its window.
const ANSWER_RATIO: Dictionary[StringName, Vector2] = {
	&"soon": Vector2(1.0, 1.0), &"later": Vector2(2.0, 2.0), &"tomorrow": Vector2(5.0, 5.0),
}
## Target windows after feeding, in hours (game-mechanics §2.2).
const ANSWER_WINDOW_H: Dictionary[StringName, Vector2] = {
	&"soon": Vector2(4.0, 7.0), &"later": Vector2(7.0, 10.0), &"tomorrow": Vector2(10.0, 16.0),
}
## The slice's ratio presets, 1 : x : y (the exact-preset picker offers these three).
const RATIOS: Array[Vector2] = [Vector2(1.0, 1.0), Vector2(2.0, 2.0), Vector2(5.0, 5.0)]
## Flours offered in the slice (D-020). All four exist in the sim; rye and spelt unlock in P1.
const SLICE_FLOURS: Array[StringName] = [&"white_bread", &"whole_wheat"]
## Hydration is fixed at 100% in the slice. P1 presets (game-mechanics §2.1, spec §5 and V6), keyed like the
## catalog's HYDRATION_<ID> and HYDRATION_<ID>_NOTE strings. The `hydration` unlock opens stiff and loose.
const SLICE_HYDRATION_PCT: float = 100.0
const HYDRATION_PRESETS: Dictionary[StringName, float] = {&"stiff": 60.0, &"standard": 100.0, &"loose": 125.0}
const HYDRATION_IDS: Array[StringName] = [&"stiff", &"standard", &"loose"]
const ROUTINE_GAP_S: int = 20 * 3600
const ROUTINE_PEAK_S: float = 10.0 * 3600.0
const ROUTINE_EVERY_S: int = 7 * 86400


## Plans a feed for a schedule answer. `now_unix` and `utc_offset_s` only pick the {window} words.
## Runs up to three forecasts (about 40 ms on the Mac, estimate), so call it when the sheet opens or the
## answer changes, not every frame. `hydration_pct` is a HYDRATION_PRESETS value; the grams come from
## FeedAction.from_preset.
static func plan(state: StarterState, env: EnvironmentState, history: PlayerHistory, answer: StringName,
		flour_id: StringName, hooch_choice: StringName, now_unix: int, utc_offset_s: int,
		hydration_pct: float = SLICE_HYDRATION_PCT) -> FeedPreview:
	var window_h: Vector2 = ANSWER_WINDOW_H.get(answer, ANSWER_WINDOW_H[&"soon"])
	var lo: float = window_h.x * 3600.0
	var hi: float = window_h.y * 3600.0
	var center: float = (lo + hi) * 0.5
	var own: Vector2 = ANSWER_RATIO.get(answer, ANSWER_RATIO[&"soon"])
	var best: FeedPreview = null
	var best_dist: float = INF
	var own_preview: FeedPreview = null
	for r: Vector2 in RATIOS:
		var a: FeedAction = FeedAction.from_preset(r.x, flour_id, hydration_pct)
		a.hooch_choice = hooch_choice
		var p: FeedPreview = preview(state, env, history, a, answer, now_unix, utc_offset_s)
		if r == own:
			own_preview = p
		if not p.forecast.has_window:
			continue
		var start: float = _at_peak_start_mid(p.forecast)
		if start >= lo and start <= hi and absf(start - center) < best_dist:
			best = p
			best_dist = absf(start - center)
	if best != null:
		best.fits_window = true
		return best
	var out: FeedPreview = own_preview
	out.fits_window = false
	if env.location == &"fridge":
		out.fit_key = &"FEED_FIT_FRIDGE"
	elif out.forecast.has_window:
		var start: float = _at_peak_start_mid(out.forecast)
		if start < lo:
			out.fit_key = &"FEED_FIT_TOO_WARM"
		elif start > hi:
			out.fit_key = &"FEED_FIT_TOO_COOL"
	return out


## What `action` would do if applied now: grams, discard, forecast, notes and the reason it would be refused.
static func preview(state: StarterState, env: EnvironmentState, history: PlayerHistory, action: FeedAction,
		answer: StringName, now_unix: int, utc_offset_s: int) -> FeedPreview:
	var p := FeedPreview.new()
	p.action = action
	p.answer = answer
	p.reason_key = action.validate(state, env, null)
	p.kept_g = roundi(action.kept_g)
	p.flour_g = roundi(action.flour_total_g())
	p.water_g = roundi(action.water_g)
	p.discard_g = roundi(maxf(state.mass_g - action.kept_g, 0.0))
	p.ratio_text = action.ratio_text()
	var d: DerivedState = StateDeriver.derive(state, env)
	p.timing = PlayerHistory.feed_timing_class(d)
	if p.timing == &"early":
		p.note_key = &"FEED_EARLY_NOTE"
	elif p.timing == &"rescue":
		p.note_key = &"FEED_RESCUE_NOTE"
	p.hooch_step = state.hooch >= CatchUp.HOOCH_VISIBLE
	p.forecast = Forecast.peak_window(state, env, action) if p.reason_key == &"" else PeakForecast.new()
	p.window_key = ForecastWindow.for_forecast(p.forecast, state.sim_time_unix, now_unix, utc_offset_s)
	if env.location == &"fridge" and answer == &"":
		p.fit_key = &"FEED_FIT_FRIDGE"
	p.routine_hint = routine_hint(history, p.forecast, now_unix)
	return p


## game-mechanics §2.2: the last 3 feeds were each at least 20 h apart, this feed's forecast peak is under
## 10 h, and the hint wasn't shown in the last 7 days. `now_unix` is real time, like recent_feed_unix.
static func routine_hint(history: PlayerHistory, forecast: PeakForecast, now_unix: int) -> bool:
	if history == null or forecast == null or not forecast.has_window:
		return false
	if history.recent_feed_unix.size() < PlayerHistory.RECENT_FEEDS_CAP:
		return false
	for i: int in range(1, history.recent_feed_unix.size()):
		if history.recent_feed_unix[i] - history.recent_feed_unix[i - 1] < ROUTINE_GAP_S:
			return false
	if (forecast.peak_min_s + forecast.peak_max_s) * 0.5 >= ROUTINE_PEAK_S:
		return false
	return history.routine_hint_unix == 0 or now_unix - history.routine_hint_unix >= ROUTINE_EVERY_S


static func _at_peak_start_mid(f: PeakForecast) -> float:
	return (f.at_peak_start_min_s + f.at_peak_start_max_s) * 0.5
