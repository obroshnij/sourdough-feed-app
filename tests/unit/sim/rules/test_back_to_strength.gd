extends RulesCase
## back_to_strength (events-catalog §3.5, game-mechanics §7.4, spec §14.1): after a very_late feed or a
## fridge wake, a cycle with vigor_at_feed >= 0.75 peaks at >= 0.85 x last_strong_peak_rise. info, 24 h
## cooldown, once per arming. Needs T1's PlayerHistory.last_very_late_feed_unix and fridge_left_unix.
## Owner: T4.

const ID: StringName = &"back_to_strength"


## Neglect long enough to be dormant (starved), then a very_late feed. Returns the pre-neglect peak_rise.
static func _neglect_then_feed(w: World, away_h: int) -> float:
	w.away_to(w.state.sim_time_unix + away_h * H)
	var pre_neglect_peak: float = w.state.peak_rise
	w.feed()
	return pre_neglect_peak


## Feeds every 12 h until a cycle starts with vigor_at_feed >= 0.75. Returns that feed's time, or -1.
static func _feed_until_strong(w: World, max_feeds: int) -> int:
	for i: int in max_feeds:
		w.away_to(w.state.sim_time_unix + 12 * H)
		w.feed()
		if w.state.vigor_at_feed >= PlayerHistory.STRONG_VIGOR_AT_FEED:
			return w.state.sim_time_unix
	return -1


func test_fires_at_the_peak_of_the_first_strong_cycle_after_neglect() -> void:
	if not require(&"m5_catchup"):
		return
	var w: World = new_game(T0 + 7 * H)
	w.feed()
	var reference: float = _neglect_then_feed(w, 84)
	check_eq(w.history.last_strong_peak_rise, reference, "the reference is the pre-neglect peak")
	check(w.state.vigor_at_feed < PlayerHistory.STRONG_VIGOR_AT_FEED,
		"after 84 h the first feed is a recovering one (vigor_at_feed %.3f)" % w.state.vigor_at_feed)
	w.away_to(w.state.sim_time_unix + 12 * H)
	check(w.state.peak_rise >= RuleFacts.STRENGTH_SHARE * reference,
		"the recovering cycle reaches %.3f, over 85%% of %.3f" % [w.state.peak_rise, reference])
	check_eq(w.of(ID).size(), 0, "but it doesn't fire while vigor_at_feed is under 0.75 (spec §14.1)")
	w.feed()
	var strong: int = w.state.sim_time_unix if w.state.vigor_at_feed >= PlayerHistory.STRONG_VIGOR_AT_FEED \
		else _feed_until_strong(w, 3)
	check(strong > 0, "a strong cycle within 3 more feeds (spec §15: normal by feed 2 to 3)")
	var peak: int = first_time(w, strong + 20 * H, enters_phase(&"at_peak"))
	w.away_to(peak - SimConstants.GRID_S)
	check_eq(w.of(ID).size(), 0, "nothing one step before the peak")
	w.away_to(peak)
	check_eq(w.times(ID), [peak], "fires as the strong cycle reaches at_peak (%s)" % hours(peak))
	check(w.state.peak_rise >= RuleFacts.STRENGTH_SHARE * reference, "at %.3f of %.3f" % [w.state.peak_rise, reference])


func test_once_per_arming_and_re_armed_by_the_next_neglect() -> void:
	if not require(&"m5_catchup"):
		return
	var w: World = new_game(T0 + 7 * H)
	w.feed()
	_neglect_then_feed(w, 84)
	_feed_until_strong(w, 4)
	for i: int in 4:
		w.away_to(w.state.sim_time_unix + 12 * H)
		w.feed()
	check_eq(w.of(ID).size(), 1, "one per comeback, even after the 24 h cooldown has passed")
	_neglect_then_feed(w, 84)
	_feed_until_strong(w, 4)
	w.away_to(w.state.sim_time_unix + 12 * H)
	check_eq(w.of(ID).size(), 2, "the next neglect arms it again")


func test_fridge_wake_arms_it() -> void:
	if not require(&"m5_catchup"):
		return
	# V7: fed, an hour on the counter, 3 days in the fridge. Out of the fridge, warmed up, then fed.
	var w: World = new_game(T0 + 7 * H)
	w.feed()
	w.away_to(T0 + 8 * H)
	w.move(&"fridge")
	w.away_to(T0 + 8 * H + 3 * DAY)
	check_eq(w.derived().dormant_cause, &"cold", "dormant from the cold")
	w.move(&"counter")
	w.away_to(w.state.sim_time_unix + 3 * H)
	check_ne(w.derived().state, &"dormant", "warmed up before the feed, so the feed is not very_late")
	w.feed()
	check(w.state.vigor_at_feed >= PlayerHistory.STRONG_VIGOR_AT_FEED, "3 days in the fridge leaves it strong")
	var peak: int = first_time(w, w.state.sim_time_unix + 20 * H, enters_phase(&"at_peak"))
	w.away_to(w.state.sim_time_unix + 20 * H)
	check_eq(w.times(ID), [peak], "the first peak after the fridge wake fires it")


func test_a_short_fridge_visit_does_not_arm_it() -> void:
	if not require(&"m5_catchup"):
		return
	var w: World = new_game(T0 + 7 * H)
	w.feed()
	w.away_to(T0 + 9 * H)
	w.move(&"fridge")
	w.away_to(T0 + 9 * H + 10 * 60)
	w.move(&"counter")
	for i: int in 4:
		w.away_to(w.state.sim_time_unix + 12 * H)
		w.feed()
	w.away_to(w.state.sim_time_unix + 12 * H)
	check_eq(w.of(ID).size(), 0, "ten minutes in the fridge is not a fridge wake")


func test_never_on_a_normal_routine() -> void:
	if not require(&"m5_catchup"):
		return
	var w: World = new_game(T0 + 7 * H)
	w.feed()
	for i: int in 6:
		w.away_to(w.state.sim_time_unix + 12 * H)
		w.feed()
	w.away_to(w.state.sim_time_unix + 12 * H)
	check_eq(w.of(ID).size(), 0, "twice-daily feeds never arm it")


func test_same_in_live_play_and_catch_up() -> void:
	if not require(&"m5_catchup"):
		return
	var worlds: Array[World] = []
	for live: bool in [true, false]:
		var w: World = new_game(T0 + 7 * H)
		w.feed()
		_neglect_then_feed(w, 84)
		var strong: int = _feed_until_strong(w, 4)
		if live:
			w.live_to(strong + 16 * H)
		else:
			w.away_to(strong + 16 * H)
		worlds.append(w)
	check_eq(worlds[0].of(ID).size(), 1, "live fires once")
	check_eq(worlds[1].times(ID), worlds[0].times(ID), "catch-up fires on the same step")
