extends RulesCase
## first_rise (events-catalog §3.1, game-mechanics §7.4): after the first real-time feed, rise crosses
## RISE_NOTICEABLE (1.25, spec §14.1) upward. info, one-time per starter. Owner: T4.

const ID: StringName = &"first_rise"


static func _crosses_noticeable() -> Callable:
	return func(p: StarterState, _pd: DerivedState, s: StarterState, _d: DerivedState) -> bool:
		return p.rise < RuleFacts.RISE_NOTICEABLE and s.rise >= RuleFacts.RISE_NOTICEABLE


func test_fires_on_the_step_rise_crosses_1_25() -> void:
	if not require(&"m5_catchup"):
		return
	var w: World = new_game(T0 + 7 * H)
	w.feed()
	var cross: int = first_time(w, T0 + 20 * H, _crosses_noticeable())
	check(cross > 0, "the new game's first 1:1:1 feed crosses 1.25 within 13 h")
	w.live_to(cross - SimConstants.GRID_S)
	check(w.state.rise < RuleFacts.RISE_NOTICEABLE, "one step before, rise is %.4f, under 1.25" % w.state.rise)
	check_eq(w.of(ID).size(), 0, "nothing one step before the crossing")
	w.live_to(cross)
	check_eq(w.times(ID), [cross], "fires on the crossing step (%s)" % hours(cross))
	check_eq(w.of(ID)[0].tier, &"info", "tier")


func test_one_time_per_starter() -> void:
	if not require(&"m5_catchup"):
		return
	var w: World = new_game(T0 + 7 * H)
	w.feed()
	w.away_to(T0 + 19 * H)
	check_eq(w.of(ID).size(), 1, "the first cycle fires it")
	w.feed()
	var cross: int = first_time(w, T0 + 40 * H, _crosses_noticeable())
	w.away_to(T0 + 40 * H)
	check(cross > 0, "the second cycle crosses 1.25 too (%s)" % hours(cross))
	check_eq(w.of(ID).size(), 1, "the second crossing doesn't fire it again")
	# The starter is discarded and a new one starts (GameSession._discard_starter): same ledger, new born_unix.
	var t: int = w.state.sim_time_unix
	w.new_starter(&"restart")
	w.feed()
	w.away_to(t + 12 * H)
	check_eq(w.of(ID).size(), 2, "a new starter gets its own first_rise")


func test_a_cycle_fed_before_adoption_never_counts() -> void:
	if not require(&"m5_catchup"):
		return
	# Adopting a starter mid-rise (StarterState.rebase_to, as Session.adopt_starter does after the demo):
	# the cycle's feed happened before born_unix, so its crossing is not a real-time first rise.
	var w: World = new_game(T0 + 7 * H)
	w.feed()
	w.away_to(T0 + 7 * H + 30 * 60)
	w.state.rebase_to(w.state.sim_time_unix)
	var cross: int = first_time(w, T0 + 20 * H, _crosses_noticeable())
	w.away_to(T0 + 20 * H)
	check(cross > w.state.born_unix, "rise crosses 1.25 after adoption (%s)" % hours(cross))
	check_eq(w.of(ID).size(), 0, "no first_rise for a cycle fed before adoption")
	w.feed()
	w.away_to(T0 + 32 * H)
	check_eq(w.of(ID).size(), 1, "the first real-time feed's crossing fires it")


func test_same_in_live_play_and_catch_up() -> void:
	if not require(&"m5_catchup"):
		return
	var live: World = new_game(T0 + 7 * H)
	live.feed()
	live.live_to(T0 + 12 * H)
	var away: World = new_game(T0 + 7 * H)
	away.feed()
	away.away_to(T0 + 12 * H)
	check_eq(live.of(ID).size(), 1, "live fires once")
	check_eq(away.times(ID), live.times(ID), "catch-up fires on the same step")
