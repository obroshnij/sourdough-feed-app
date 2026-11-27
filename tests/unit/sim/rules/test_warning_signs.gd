extends RulesCase
## warning_signs (events-catalog §3.6, game-mechanics §7.4): the state is `unhealthy` (mold_risk >= 0.5).
## attention, once per episode, re-armed after 24 h out of unhealthy. Safety: CLAUDE.md rule 5. Owner: T4.

const ID: StringName = &"warning_signs"


## A new game fed 1:1:1 at 07:00 and then left unfed on the counter (spec V9).
static func _neglected() -> World:
	var w: World = new_game(T0 + 7 * H)
	w.feed()
	return w


func test_fires_on_the_step_it_becomes_unhealthy() -> void:
	if not require(&"m5_catchup"):
		return
	var w: World = _neglected()
	var onset: int = first_time(w, T0 + 7 * H + 14 * DAY, enters_state(&"unhealthy"))
	check_between(float(onset - (T0 + 7 * H)) / H, 104.0, 111.0, "V9: unhealthy 104 to 111 h after the feed")
	w.away_to(onset - SimConstants.GRID_S)
	check(w.state.mold_risk < SimConstants.MOLD_WARN, "one step before, mold_risk is %.4f" % w.state.mold_risk)
	check_eq(w.of(ID).size(), 0, "nothing one step before")
	w.away_to(onset)
	check_eq(w.times(ID), [onset], "fires on the onset step (%s)" % hours(onset))
	var e: SimEvent = w.of(ID)[0]
	check_eq(e.tier, &"attention", "tier")
	check_eq(e.payload, {"began_unix": onset}, "the payload is only the onset time")
	check_eq(e.expires_if, &"", "attention is never dropped as stale (game-mechanics §7.3)")


func test_once_per_episode() -> void:
	if not require(&"m5_catchup"):
		return
	var w: World = _neglected()
	var onset: int = first_time(w, T0 + 7 * H + 14 * DAY, enters_state(&"unhealthy"))
	var mold: int = first_time(w, T0 + 7 * H + 14 * DAY, enters_state(&"moldy"))
	w.away_to(onset + 2 * H)
	w.ack_all()
	w.away_to(mold - SimConstants.GRID_S)
	check_eq(w.derived().state, &"unhealthy", "still in the same episode %s later" % hours(T0 + mold - onset))
	check_eq(w.times(ID), [onset], "one warning per episode, also after the sheet is closed")


func test_a_rescue_feed_ends_the_episode_and_the_next_one_fires_again() -> void:
	if not require(&"m5_catchup"):
		return
	var w: World = _neglected()
	var onset: int = first_time(w, T0 + 7 * H + 14 * DAY, enters_state(&"unhealthy"))
	w.away_to(onset + H)
	w.ack_all()
	w.feed()
	check_ne(w.derived().state, &"unhealthy", "one feed takes it out of unhealthy (L-9)")
	var fed: int = w.state.sim_time_unix
	var second: int = first_time(w, fed + 14 * DAY, enters_state(&"unhealthy"))
	check(second - fed >= RuleFacts.WARNING_REARM_S, "the next onset is %s after the rescue" % hours(T0 + second - fed))
	w.away_to(second)
	check_eq(w.times(ID), [onset, second], "a new episode gets a new warning")


func test_the_first_restart_starter_gets_its_own_warning() -> void:
	if not require(&"m5_catchup"):
		return
	# M.'s spare (game-mechanics §8.2) carries a feed from 14 days before it is adopted, so the previous
	# starter's warning falls inside its "cycle". It must still be warned (spec V15: unhealthy 55 to 65 h
	# after leaving the fridge when left unfed).
	var w: World = _neglected()
	w.away_to(T0 + 7 * H + 10 * DAY)
	check_eq(w.of(ID).size(), 1, "the first starter was warned")
	w.ack_all()
	var t: int = w.state.sim_time_unix
	w.new_starter(&"first_restart")
	check(RuleFacts.feed_unix(w.state) < w.of(ID)[0].created_unix, "its last feed predates the old warning")
	var onset: int = first_time(w, t + 6 * DAY, enters_state(&"unhealthy"))
	w.away_to(t + 6 * DAY)
	check_between(float(onset - t) / H, 50.0, 70.0, "the spare, unfed, is unhealthy about 60 h in")
	check_eq(w.times(ID), [w.of(ID)[0].created_unix, onset], "and gets its own warning at the onset")


func test_not_re_armed_within_24_hours_of_leaving() -> void:
	if not require(&"m5_catchup"):
		return
	# The sim can't re-enter unhealthy within 24 h of a feed, so the gap is set on the history's timestamp
	# (PlayerHistory.unhealthy_left_unix). The starter's state is a real V9 onset.
	var w: World = _neglected()
	var onset: int = first_time(w, T0 + 7 * H + 14 * DAY, enters_state(&"unhealthy"))
	w.away_to(onset - SimConstants.GRID_S)
	w.history.unhealthy_left_unix = onset - 23 * H
	w.away_to(onset)
	check_eq(w.of(ID).size(), 0, "23 h out of unhealthy is still the same episode")
	w.away_to(onset - 23 * H + RuleFacts.WARNING_REARM_S)
	check_eq(w.times(ID), [onset - 23 * H + RuleFacts.WARNING_REARM_S], "fires once 24 h have passed")


func test_mold_replaces_it_and_it_never_fires_when_moldy() -> void:
	if not require(&"m5_catchup"):
		return
	var w: World = _neglected()
	var mold: int = first_time(w, T0 + 7 * H + 14 * DAY, enters_state(&"moldy"))
	w.away_to(mold + 2 * DAY)
	check_eq(w.of(ID).size(), 1, "one warning before the mold")
	check(w.of(ID)[0].created_unix < mold, "and it came first")
	check_eq(w.ledger.pending_attention().id, &"mold_found", "mold_found replaced the waiting warning")
	check_eq(w.ledger.pending.filter(func(e: SimEvent) -> bool: return e.id == ID).size(), 0, "no warning waits")


func test_same_in_live_play_and_catch_up() -> void:
	if not require(&"m5_catchup"):
		return
	var live: World = _neglected()
	var onset: int = first_time(live, T0 + 7 * H + 14 * DAY, enters_state(&"unhealthy"))
	live.away_to(onset - 2 * H)
	live.live_to(onset + H)
	var away: World = _neglected()
	away.away_to(onset + H)
	check_eq(live.of(ID).size(), 1, "live fires once")
	check_eq(away.times(ID), live.times(ID), "catch-up fires on the same step")
