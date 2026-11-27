extends RulesCase
## peaked_while_away (events-catalog §3.2, game-mechanics §7.4): rise_phase enters and leaves at_peak with
## no foreground step in between. Fires on the step that leaves at_peak. info, once per rise cycle.
## Payload: time_unix (the peak time, spec §14.1), peak_rise and rise_word. Owner: T4.

const ID: StringName = &"peaked_while_away"


## The step that set the cycle max before `until` (spec §14.1 "peak time").
static func _peak_time(w: World, until: int) -> int:
	var s: StarterState = w.state.copy()
	var best: int = s.sim_time_unix
	while s.sim_time_unix < until:
		Sim.step(s, w.env)
		if s.rise >= s.peak_rise:
			best = s.sim_time_unix
	return best


func test_fires_on_the_step_it_leaves_at_peak() -> void:
	if not require(&"m5_catchup"):
		return
	var w: World = new_game(T0 + 7 * H)
	w.feed()
	var leave: int = first_time(w, T0 + 30 * H, leaves_phase(&"at_peak"))
	var peak: int = _peak_time(w, leave)
	check(leave > 0, "the cycle leaves at_peak")
	w.away_to(leave - SimConstants.GRID_S)
	check_eq(w.derived().rise_phase, &"at_peak", "one step before, still at_peak")
	check_eq(w.of(ID).size(), 0, "nothing one step before")
	w.away_to(leave)
	check_eq(w.times(ID), [leave], "fires on the leaving step (%s)" % hours(leave))
	var e: SimEvent = w.of(ID)[0]
	check_eq(e.payload.get("peak_rise"), w.state.peak_rise, "peak_rise is the cycle's")
	check_eq(e.payload.get("rise_word"), String(Inspection.peak_word(w.state.peak_rise)), "rise word")
	check_eq(e.payload.get("rise_word"), "DOUBLE", "a young 1:1:1 counter peak reads doubled (spec §14.1)")
	check_eq(e.payload.get("time_unix"), peak,
		"time is the peak (%s), not the leaving step" % hours(peak))


func test_once_per_rise_cycle() -> void:
	if not require(&"m5_catchup"):
		return
	var w: World = new_game(T0 + 7 * H)
	w.feed()
	w.away_to(T0 + 21 * H)
	check_eq(w.of(ID).size(), 1, "one per cycle")
	w.away_to(T0 + 3 * DAY)
	check_eq(w.of(ID).size(), 1, "a starved starter doesn't peak again without a feed")
	w.feed()
	w.away_to(T0 + 3 * DAY + 16 * H)
	check_eq(w.of(ID).size(), 2, "the next cycle has its own")


func test_not_when_the_player_saw_the_peak() -> void:
	if not require(&"m5_catchup"):
		return
	var w: World = new_game(T0 + 7 * H)
	w.feed()
	var entry: int = first_time(w, T0 + 30 * H, enters_phase(&"at_peak"))
	w.live_to(entry + 5 * 60)
	w.away_to(T0 + 21 * H)
	check_eq(w.of(ID).size(), 0, "seen in the foreground, then left in the background: not 'while away'")
	check_eq(w.of(&"peak_now").size(), 1, "peak_now told it")


func test_a_feed_at_the_peak_is_not_leaving_it() -> void:
	if not require(&"m5_catchup"):
		return
	var w: World = new_game(T0 + 7 * H)
	w.feed()
	var entry: int = first_time(w, T0 + 30 * H, enters_phase(&"at_peak"))
	w.away_to(entry + 20 * 60)
	var fired: Array[SimEvent] = w.feed()
	check_eq(only(fired, [ID]).size(), 0, "feeding at the peak starts a new cycle, it doesn't 'leave' the peak")


func test_live_and_catch_up_differ_only_as_the_catalog_says() -> void:
	if not require(&"m5_catchup"):
		return
	var live: World = new_game(T0 + 7 * H)
	live.feed()
	live.live_to(T0 + 21 * H)
	var away: World = new_game(T0 + 7 * H)
	away.feed()
	away.away_to(T0 + 21 * H)
	var peak_ids: Array[StringName] = [&"peak_now", ID]
	check_eq(signature(only(live.events, peak_ids)).size(), 1, "live: exactly one peak event")
	check_eq(live.of(&"peak_now").size(), 1, "live: it is peak_now")
	check_eq(away.of(ID).size(), 1, "away: it is peaked_while_away")
	var others_live: Array = signature(live.events).filter(func(x: String) -> bool: return not x.begins_with("peak"))
	var others_away: Array = signature(away.events).filter(func(x: String) -> bool: return not x.begins_with("peak"))
	check_eq(others_away, others_live, "every other event is the same in both")
