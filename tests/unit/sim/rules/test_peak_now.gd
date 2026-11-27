extends RulesCase
## peak_now (events-catalog §3.2, game-mechanics §7.4): the player sees the starter at its peak.
## Fires on the first foreground step or action of a cycle whose rise_phase is at_peak. info, once per rise
## cycle, shared with peaked_while_away. Owner: T4.

const ID: StringName = &"peak_now"
const AWAY_ID: StringName = &"peaked_while_away"


func test_fires_on_the_step_it_enters_at_peak_in_the_foreground() -> void:
	if not require(&"m5_catchup"):
		return
	var w: World = new_game(T0 + 7 * H)
	w.feed()
	var entry: int = first_time(w, T0 + 30 * H, enters_phase(&"at_peak"))
	check(entry > 0, "the cycle reaches at_peak")
	w.live_to(entry - SimConstants.GRID_S)
	check_ne(w.derived().rise_phase, &"at_peak", "one step before, not yet at_peak")
	check_eq(w.of(ID).size(), 0, "nothing one step before")
	w.live_to(entry)
	check_eq(w.times(ID), [entry], "fires on the entry step (%s)" % hours(entry))
	check_eq(w.of(ID)[0].payload, {"time_unix": entry}, "payload is the time for {time}")


func test_once_per_rise_cycle() -> void:
	if not require(&"m5_catchup"):
		return
	var w: World = new_game(T0 + 7 * H)
	w.feed()
	w.live_to(T0 + 21 * H)
	check_eq(w.derived().state, &"hungry", "the cycle has ended")
	check_eq(w.of(ID).size(), 1, "one peak_now for the whole at_peak phase")
	check_eq(w.of(AWAY_ID).size(), 0, "and no peaked_while_away: the player saw it")
	w.feed()
	w.live_to(T0 + 35 * H)
	check_eq(w.of(ID).size(), 2, "the next cycle has its own peak_now")


func test_returning_in_the_middle_of_the_peak() -> void:
	if not require(&"m5_catchup"):
		return
	var w: World = new_game(T0 + 7 * H)
	w.feed()
	var entry: int = first_time(w, T0 + 30 * H, enters_phase(&"at_peak"))
	w.away_to(entry + 30 * 60)
	check_eq(w.derived().rise_phase, &"at_peak", "still at its peak on return")
	check_eq(w.of(ID).size(), 0, "nothing while away")
	w.live_to(entry + 31 * 60)
	check_eq(w.times(ID), [entry + 31 * 60], "fires on the first foreground step")
	w.live_to(T0 + 21 * H)
	check_eq(w.of(AWAY_ID).size(), 0, "leaving the peak after being seen is not peaked_while_away")


func test_an_action_at_the_peak_counts_as_seeing_it() -> void:
	if not require(&"m5_catchup"):
		return
	var w: World = new_game(T0 + 7 * H)
	w.feed()
	var entry: int = first_time(w, T0 + 30 * H, enters_phase(&"at_peak"))
	w.away_to(entry + 10 * 60)
	var fired: Array[SimEvent] = w.act(InspectAction.new(&"height"))
	check_eq(signature(fired), ["peak_now@%s" % hours(entry + 10 * 60)], "an inspect at the peak fires it")


func test_never_in_the_background() -> void:
	if not require(&"m5_catchup"):
		return
	var w: World = new_game(T0 + 7 * H)
	w.feed()
	w.away_to(T0 + 21 * H)
	check_eq(w.of(ID).size(), 0, "no peak_now while away")
	check_eq(w.of(AWAY_ID).size(), 1, "peaked_while_away instead (events-catalog §3.2)")
