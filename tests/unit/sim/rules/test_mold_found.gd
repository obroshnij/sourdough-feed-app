extends RulesCase
## mold_found (events-catalog §4.9, game-mechanics §7.4): the starter is moldy (mold_risk reached 1.0,
## latched). attention, once per starter, replaces a waiting attention sheet. Safety: CLAUDE.md rule 5.
## Owner: T4.

const ID: StringName = &"mold_found"


static func _neglected(t: int = T0 + 7 * H) -> World:
	var w: World = new_game(t)
	w.feed()
	return w


func test_fires_on_the_step_mold_latches() -> void:
	if not require(&"m5_catchup"):
		return
	var w: World = _neglected()
	var mold: int = first_time(w, T0 + 7 * H + 14 * DAY, enters_state(&"moldy"))
	check_between(float(mold - (T0 + 7 * H)) / H, 207.0, 219.0, "V9: moldy 207 to 219 h after the feed")
	w.away_to(mold - SimConstants.GRID_S)
	check(not w.state.moldy, "one step before, not moldy (mold_risk %.4f)" % w.state.mold_risk)
	check_eq(w.of(ID).size(), 0, "nothing one step before")
	w.away_to(mold)
	check_eq(w.times(ID), [mold], "fires on the latching step (%s)" % hours(mold))
	var e: SimEvent = w.of(ID)[0]
	check_eq(e.tier, &"attention", "tier")
	check_eq(e.payload, {}, "no payload: nothing for the copy to soften")
	check_eq(w.ledger.pending_attention(), e, "it is the waiting attention sheet")


func test_once_per_starter() -> void:
	if not require(&"m5_catchup"):
		return
	var w: World = _neglected()
	w.away_to(T0 + 7 * H + 10 * DAY)
	check_eq(w.of(ID).size(), 1, "fired once")
	w.ack_all()
	w.away_to(T0 + 7 * H + 14 * DAY)
	check_eq(w.of(ID).size(), 1, "'Not yet' closes it and nothing nags (events-catalog §4.9)")


func test_the_next_starter_gets_its_own_sheet() -> void:
	if not require(&"m5_catchup"):
		return
	var w: World = _neglected()
	w.away_to(T0 + 7 * H + 10 * DAY)
	w.ack_all()
	# Discard and restart (GameSession._discard_starter): same ledger, new starter born now.
	var t: int = w.state.sim_time_unix
	w.state = StarterPresets.make(&"restart", t)
	w.env = StarterPresets.environment_for(&"restart", t)
	w.away_to(t + 12 * DAY)
	check(w.state.moldy, "the second starter, also neglected, molds too")
	check_eq(w.of(ID).size(), 2, "and gets its own mold sheet (per starter, not per save)")


func test_a_moldy_starter_always_gets_the_sheet() -> void:
	if not require(&"m5_catchup"):
		return
	# A moldy starter with no record of the sheet (a fresh ledger, as after a lost or hand-made save) still
	# gets it on the next step. The jar never shows mold without the discard sheet.
	var w: World = _neglected()
	w.rules = []
	w.away_to(T0 + 7 * H + 10 * DAY)
	check(w.state.moldy, "moldy")
	w.rules = RuleIndex.all()
	w.ledger = EventLedger.new()
	w.away_to(w.state.sim_time_unix + SimConstants.GRID_S)
	check_eq(signature(w.events), ["mold_found@%s" % hours(w.state.sim_time_unix)], "fires on the next step")


func test_same_in_live_play_and_catch_up() -> void:
	if not require(&"m5_catchup"):
		return
	var live: World = _neglected()
	var mold: int = first_time(live, T0 + 7 * H + 14 * DAY, enters_state(&"moldy"))
	live.away_to(mold - H)
	live.live_to(mold + H)
	var away: World = _neglected()
	away.away_to(T0 + 7 * H + 14 * DAY)
	check_eq(live.of(ID).size(), 1, "live fires once")
	check_eq(away.times(ID), live.times(ID), "a 14-day catch-up fires on the same step")
