extends RulesCase
## hooch_forming (events-catalog §3.4, game-mechanics §7.4): hooch crosses HOOCH_VISIBLE (0.10, spec §14.1)
## upward, in hungry or dormant, the fridge included. info, 24 h cooldown. Owner: T4.

const ID: StringName = &"hooch_forming"
const COOLDOWN_S: int = 24 * 3600


static func _hooch_visible() -> Callable:
	return func(p: StarterState, _pd: DerivedState, s: StarterState, _d: DerivedState) -> bool:
		return p.hooch < CatchUp.HOOCH_VISIBLE and s.hooch >= CatchUp.HOOCH_VISIBLE


func test_fires_on_the_step_hooch_becomes_visible() -> void:
	if not require(&"m5_catchup"):
		return
	var w: World = new_game(T0 + 7 * H)
	w.feed()
	var seen: int = first_time(w, T0 + 40 * H, _hooch_visible())
	check(seen > 0, "hooch shows within a day and a half")
	w.away_to(seen - SimConstants.GRID_S)
	check(w.state.hooch < CatchUp.HOOCH_VISIBLE, "one step before, hooch is %.4f" % w.state.hooch)
	check_eq(w.of(ID).size(), 0, "nothing one step before")
	w.away_to(seen)
	check_eq(w.times(ID), [seen], "fires on the step (%s)" % hours(seen))
	check_eq(w.derived().state, &"hungry", "a sign of hunger, not danger")
	check_eq(w.of(ID)[0].tier, &"info", "tier")


func test_24_hour_cooldown() -> void:
	if not require(&"m5_catchup"):
		return
	var w: World = new_game(T0 + 7 * H)
	w.feed()
	var first: int = first_time(w, T0 + 40 * H, _hooch_visible())
	w.away_to(first)
	w.feed()
	var second: int = first_time(w, first + 30 * H, _hooch_visible())
	w.away_to(second)
	check(second - first < COOLDOWN_S, "hooch shows again %s later" % hours(T0 + second - first))
	check_eq(w.times(ID), [first], "inside 24 h it is not admitted")
	w.feed()
	var third: int = first_time(w, second + 30 * H, _hooch_visible())
	w.away_to(third)
	check(third - first >= COOLDOWN_S, "the third is %s after the first" % hours(T0 + third - first))
	check_eq(w.times(ID), [first, third], "after 24 h it is admitted again")


func test_also_in_the_fridge() -> void:
	if not require(&"m5_catchup"):
		return
	# Spec §15 and V7: fed, an hour on the counter, then the fridge. Hooch shows around day 7.
	var w: World = new_game(T0 + 7 * H)
	w.feed()
	w.away_to(T0 + 8 * H)
	w.move(&"fridge")
	w.away_to(T0 + 8 * H + 10 * DAY)
	check_eq(w.of(ID).size(), 1, "hooch forms in the fridge too")
	check_eq(w.derived().state, &"dormant", "while dormant")
	check_between(float(w.times(ID)[0] - (T0 + 8 * H)) / DAY, 5.0, 9.0, "around day 7 in the fridge")


func test_same_in_live_play_and_catch_up() -> void:
	if not require(&"m5_catchup"):
		return
	var live: World = new_game(T0 + 7 * H)
	live.feed()
	live.away_to(T0 + 24 * H)
	live.live_to(T0 + 27 * H)
	var away: World = new_game(T0 + 7 * H)
	away.feed()
	away.away_to(T0 + 27 * H)
	check_eq(live.of(ID).size(), 1, "live fires once")
	check_eq(away.times(ID), live.times(ID), "catch-up fires on the same step")
