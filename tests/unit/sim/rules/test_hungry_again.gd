extends RulesCase
## hungry_again (events-catalog §3.3, game-mechanics §7.4): the state label enters `hungry`. nudge, 12 h
## cooldown, deferred to 08:00 in quiet hours, dropped when no longer hungry (expires_if). Owner: T4.

const ID: StringName = &"hungry_again"


func test_fires_on_the_step_it_becomes_hungry() -> void:
	if not require(&"m5_catchup"):
		return
	var w: World = new_game(T0 + 7 * H)
	w.feed()
	var hungry: int = first_time(w, T0 + 30 * H, enters_state(&"hungry"))
	check(hungry > 0, "the cycle ends hungry")
	w.away_to(hungry - SimConstants.GRID_S)
	check_ne(w.derived().state, &"hungry", "one step before, not hungry yet")
	check_eq(w.of(ID).size(), 0, "nothing one step before")
	w.away_to(hungry)
	check_eq(w.times(ID), [hungry], "fires on the step (%s)" % hours(hungry))
	var e: SimEvent = w.of(ID)[0]
	check_eq(e.tier, &"nudge", "tier")
	check_eq(e.expires_if, &"state_not_hungry", "dropped once fed")
	check_eq(e.payload, {"time_unix": hungry}, "payload is the time for {time}")
	check_eq(e.not_before_unix, 0, "%s local is outside quiet hours" % hours(hungry))


func test_quiet_hours_defer_to_8am() -> void:
	if not require(&"m5_catchup"):
		return
	var w: World = new_game(T0 + 12 * H)
	w.feed()
	var hungry: int = first_time(w, T0 + 40 * H, enters_state(&"hungry"))
	check(EventScheduler.in_quiet_hours(LocalDay.minute_of_day(hungry, 0)), "a noon feed is hungry after 22:00")
	w.away_to(T0 + 40 * H)
	check_eq(w.times(ID), [hungry], "created when it happened")
	check_eq(w.of(ID)[0].not_before_unix, T0 + 32 * H, "shown at 08:00 the next day")


func test_12_hour_cooldown() -> void:
	if not require(&"m5_catchup"):
		return
	var w: World = new_game(T0 + 7 * H)
	w.feed()
	var first: int = first_time(w, T0 + 30 * H, enters_state(&"hungry"))
	w.away_to(first)
	# A trip to the fridge and back: dormant (cold) on the way, hungry again once it warms up.
	w.move(&"fridge")
	w.away_to(first + 3 * H)
	check_eq(w.derived().state, &"dormant", "cold in the fridge")
	w.move(&"counter")
	var again: int = first_time(w, first + 8 * H, enters_state(&"hungry"))
	w.away_to(first + 8 * H)
	check(again > 0 and again - first < ID_COOLDOWN, "hungry again %s after the first" % hours(T0 + again - first))
	check_eq(w.times(ID), [first], "re-entering hungry inside 12 h is not admitted")
	w.move(&"fridge")
	w.away_to(first + 13 * H)
	w.move(&"counter")
	var later: int = first_time(w, first + 18 * H, enters_state(&"hungry"))
	w.away_to(first + 18 * H)
	check(later - first >= ID_COOLDOWN, "the third entry is %s after the first" % hours(T0 + later - first))
	check_eq(w.times(ID), [first, later], "after 12 h it is admitted again")


func test_same_in_live_play_and_catch_up() -> void:
	if not require(&"m5_catchup"):
		return
	var live: World = new_game(T0 + 7 * H)
	live.feed()
	live.away_to(T0 + 19 * H)
	live.live_to(T0 + 22 * H)
	var away: World = new_game(T0 + 7 * H)
	away.feed()
	away.away_to(T0 + 22 * H)
	check_eq(live.of(ID).size(), 1, "live fires once")
	check_eq(away.times(ID), live.times(ID), "catch-up fires on the same step")


const ID_COOLDOWN: int = 12 * 3600
