extends SliceCase
## AC-06 (temperature by place, D-018) through the real Session: a move with
## SetEnvironmentAction applies at once with the place's fixed climate, the starter's own temperature
## follows over the 1.5 h lag, a move is exactly a move at its grid point, warm_spot peaks first, the
## fridge puts it to sleep and the counter wakes it, and flipping places changes nothing but the
## time spent in each. The sheet rows (AC-06.4 tween, AC-06.6 offered places, AC-06.7 taps) are T3's.

## Spec §2.2 and D-018: [temperature °C, humidity %] per slice place.
const PLACES: Dictionary[StringName, Vector2] = {
	&"counter": Vector2(22.0, 50.0), &"warm_spot": Vector2(26.0, 40.0), &"fridge": Vector2(4.0, 70.0),
}


## AC-06.1: each slice place applies at once, with its fixed temperature and humidity (a humidity
## sent by the caller is ignored, D-018). The temperature is not a free input. The move is journaled,
## signaled and saved, and the starter's temperature approaches the room with the 1.5 h constant and
## never overshoots.
func test_ac_06_1_each_place_applies_with_its_fixed_climate() -> void:
	if not ready_for_integration():
		return
	for place: StringName in PLACES:
		var start_place: StringName = &"warm_spot" if place == &"counter" else &"counter"
		var starter: StarterState = SliceHarness.mature()
		starter.temp_c = PLACES[start_place].x
		var h: SliceHarness = phone("place_" + String(place))
		h.seed_save(starter, EnvironmentState.at_location(start_place), 9)
		h.launch()
		var move: SetEnvironmentAction = SetEnvironmentAction.to_location(place)
		move.env.humidity_pct = 99.0
		h.forget()
		var r: ActionResult = h.apply(move)
		if not check(r.ok, "%s: the move is accepted" % place):
			continue
		var env: EnvironmentState = h.session.get_environment()
		check_eq(env.location, place, "%s: location" % place)
		check_eq(env.temperature_c, PLACES[place].x, "%s: temperature" % place)
		check_eq(env.humidity_pct, PLACES[place].y, "%s: humidity is the place's, not the caller's" % place)
		check_eq(env.changed_unix, h.session.get_starter().sim_time_unix, "%s: changed at the grid point" % place)
		check(r.journal_entry != null and r.journal_entry.kind == &"environment", "%s: journaled" % place)
		check_eq(r.journal_entry.text_key if r.journal_entry != null else &"",
			StringName("JOURNAL_LOG_MOVE_%s" % String(place).to_upper()), "%s: journal line" % place)
		check_eq(h.count(&"state_changed"), 1, "%s: one state_changed" % place)
		var saved_env: Variant = h.disk_payload().get("environment", {})
		check(typeof(saved_env) == TYPE_DICTIONARY and (saved_env as Dictionary).get("location") == String(place),
			"%s: the save holds the move" % place)
		var target: float = PLACES[place].x
		var t0: float = h.session.get_starter().temp_c
		var prev_gap: float = absf(t0 - target)
		var overshoot: bool = false
		var widened: bool = false
		for minute: int in 90:
			h.play(MIN)
			var t: float = h.session.get_starter().temp_c
			if signf(t - target) != signf(t0 - target) and t != target:
				overshoot = true
			if absf(t - target) > prev_gap:
				widened = true
			prev_gap = absf(t - target)
		check(not overshoot, "%s: no overshoot" % place)
		check(not widened, "%s: the gap only closes" % place)
		check_close(absf(h.session.get_starter().temp_c - target), absf(t0 - target) * exp(-1.0), 1e-9, 0.0,
			"%s: after 1.5 h the gap is 1/e of the start (tau 1.5 h)" % place)


## AC-06.1: the temperature is read only, and an unknown place is refused. Neither changes anything.
func test_ac_06_1_temperature_is_not_a_free_input() -> void:
	if not ready_for_integration():
		return
	var h: SliceHarness = mature_phone("place_refused", 9)
	var before: String = SliceHarness.payload_text(h.session.build_payload())
	var hot: SetEnvironmentAction = SetEnvironmentAction.to_location(&"counter", 30.0)
	var r: ActionResult = h.apply(hot)
	check(not r.ok and r.reason_key == GameAction.REASON_ENVIRONMENT, "the counter at 30 °C is refused")
	var oven := SetEnvironmentAction.new()
	oven.env = EnvironmentState.at_location(&"counter")
	oven.env.location = &"oven"
	check_eq(h.apply(oven).reason_key, GameAction.REASON_ENVIRONMENT, "an unknown place is refused")
	check_eq(SliceHarness.payload_text(h.session.build_payload()), before, "refused moves change nothing")


## AC-06.2: a move 17 s after a grid point gives exactly the state of a move at that grid point, and
## both equal the pure sim stepping the counter, then warm_spot, with no Session involved.
func test_ac_06_2_a_move_is_a_move_at_its_grid_point() -> void:
	if not ready_for_integration():
		return
	var a: SliceHarness = mature_phone("grid_a", 13)
	var b: SliceHarness = mature_phone("grid_b", 13)
	var reference: StarterState = a.session.get_starter()
	a.play(3 * HOUR)
	a.clock.advance(17)
	check(a.apply(SetEnvironmentAction.to_location(&"warm_spot")).ok, "A: moved 17 s after the grid")
	a.play(5 * HOUR - 17)
	b.play(3 * HOUR)
	check(b.apply(SetEnvironmentAction.to_location(&"warm_spot")).ok, "B: moved on the grid")
	b.play(5 * HOUR)
	var counter: EnvironmentState = EnvironmentState.at_location(&"counter")
	var warm: EnvironmentState = EnvironmentState.at_location(&"warm_spot")
	for i: int in 3 * 60:
		Sim.step(reference, counter)
	for i: int in 5 * 60:
		Sim.step(reference, warm)
	check_eq(a.session.get_starter().to_dict(), b.session.get_starter().to_dict(), "A equals B")
	check_eq(a.session.get_environment().to_dict(), b.session.get_environment().to_dict(), "same environment record")
	check_eq(a.session.get_starter().to_dict(), reference.to_dict(), "A equals the pure sim")


## AC-06.3: the same 1:1:1 feed peaks earlier at warm_spot than at the counter, and the counter's
## at_peak starts inside V2's 22 °C window (6.0 to 6.2 h, plus 0.3 h drift).
func test_ac_06_3_warm_spot_peaks_before_the_counter() -> void:
	if not ready_for_integration():
		return
	var rng_seed: int = SliceHarness.seed_for_draw(0.5)
	var starts: Dictionary[StringName, float] = {}
	for place: StringName in [&"counter", &"warm_spot"]:
		var h: SliceHarness = mature_phone("peak_" + String(place), rng_seed)
		if place != &"counter":
			check(h.apply(SetEnvironmentAction.to_location(place)).ok, "moved to " + String(place))
		check(h.apply(feed_111()).ok, String(place) + ": fed")
		var played: int = h.play_until(func() -> bool: return h.state() == &"at_peak", 10 * HOUR)
		check(played > 0, String(place) + ": reaches at_peak within 10 h")
		starts[place] = float(played) / HOUR
	check(starts[&"warm_spot"] < starts[&"counter"],
		"warm_spot at_peak (%.2f h) comes before the counter's (%.2f h)" % [starts[&"warm_spot"], starts[&"counter"]])
	check_between(starts[&"counter"], 6.0 - TOL_H, 6.2 + TOL_H, "counter at_peak start (h, V2 22 °C)")


## AC-06.3 and L-11: moved to the fridge at its peak, the starter is dormant (cold) exactly while
## ferm(temp_c) < 0.30, within 3 h of the move, and the move itself doesn't pop the jar (AC-06.4, sim
## side). After a day in the fridge, the counter wakes it within 6 h.
func test_ac_06_3_fridge_sleeps_and_the_counter_wakes() -> void:
	if not ready_for_integration():
		return
	var h: SliceHarness = mature_phone("fridge", SliceHarness.seed_for_draw(0.5))
	h.apply(feed_111())
	h.play(roundi(6.8 * HOUR))
	check_eq(h.state(), &"at_peak", "at its peak before the move")
	var before_move: VisualParams = h.session.get_visuals()
	check(h.apply(SetEnvironmentAction.to_location(&"fridge")).ok, "moved to the fridge")
	check(pops_between(before_move, h.session.get_visuals()).is_empty(), "the move itself doesn't pop the jar")
	var mismatches: int = 0
	var dormant_after: int = -1
	var prev: VisualParams = h.session.get_visuals()
	var pops: PackedStringArray = PackedStringArray()
	for minute: int in range(1, 3 * 60 + 1):
		h.play(MIN)
		var snap: StarterSnapshot = h.session.get_snapshot()
		var cold: bool = Sim.ferm(h.session.get_starter().temp_c) < SimConstants.DORMANT_COLD_FERM
		if cold != (snap.state == &"dormant" and snap.dormant_cause == &"cold"):
			mismatches += 1
		if cold and dormant_after < 0:
			dormant_after = minute
		var v: VisualParams = h.session.get_visuals()
		pops.append_array(pops_between(prev, v))
		prev = v
	check_eq(mismatches, 0, "dormant (cold) exactly while ferm(temp_c) < 0.30")
	check(dormant_after > 0 and dormant_after <= 3 * 60, "dormant within 3 h of the move (%d min)" % dormant_after)
	check(pops.is_empty(), "no pop while it cools: " + ", ".join(pops.slice(0, 6)))
	h.play_irregular(DAY)
	check_eq(h.state(), &"dormant", "still dormant after a day in the fridge")
	check(h.apply(SetEnvironmentAction.to_location(&"counter")).ok, "back to the counter")
	var woke: int = h.play_until(func() -> bool: return h.state() != &"dormant", 6 * HOUR)
	check(woke > 0, "L-11: leaves dormant within 6 h of the counter (%d s)" % woke)


## AC-06.5 and EC-10: 50 moves between the fridge and the counter within one minute equal no move at
## all (no grid step passes between them), and moves every 10 minutes for 2 h equal the pure sim with
## one segment per stay.
func test_ac_06_5_flipping_places_is_one_segment_per_stay() -> void:
	if not ready_for_integration():
		return
	var flips: SliceHarness = mature_phone("flips", 17)
	var still: SliceHarness = mature_phone("still", 17)
	flips.play(HOUR)
	still.play(HOUR)
	for i: int in 50:
		var place: StringName = &"fridge" if i % 2 == 0 else &"counter"
		check(flips.apply(SetEnvironmentAction.to_location(place)).ok, "flip %d accepted" % (i + 1))
		flips.clock.advance(1)
	flips.play(2 * HOUR - 50)
	still.play(2 * HOUR)
	check_eq(flips.session.get_starter().to_dict(), still.session.get_starter().to_dict(),
		"50 flips in a minute leave the starter exactly as if it never moved")
	var spread: SliceHarness = mature_phone("spread", 17)
	var reference: StarterState = spread.session.get_starter()
	var places: Array[StringName] = [&"fridge", &"counter", &"warm_spot", &"fridge", &"counter", &"fridge",
		&"warm_spot", &"counter", &"fridge", &"counter", &"warm_spot", &"counter"]
	for place: StringName in places:
		check(spread.apply(SetEnvironmentAction.to_location(place)).ok, "moved to " + String(place))
		spread.play_irregular(10 * MIN)
		var env: EnvironmentState = EnvironmentState.at_location(place)
		for i: int in 10:
			Sim.step(reference, env)
	check_eq(spread.session.get_starter().to_dict(), reference.to_dict(),
		"12 stays of 10 min equal the pure sim with one segment per stay")
	check_eq(spread.journal_of(&"environment").size(), places.size(), "one journal line per move")
