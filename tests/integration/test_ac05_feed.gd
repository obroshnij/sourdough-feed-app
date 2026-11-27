extends SliceCase
## AC-05 (feeding) through the real Session: the derived discard for each slice preset and flour,
## the timing class recorded at Mix, the hooch choice (V20), and a kill at Mix. Also CLK-10 and
## EC-18 (the feed sheet left open across a background), CLK-18 (two feeds in one minute) and
## EC-04 (feeding every 10 minutes). Feed sheet UI rows (AC-05.2 to 05.4, 05.7, 05.9) are T3's.

## game-mechanics §2.3: [f, w, keep, flour, water, total] for 1 : f : w at 100% hydration.
const PRESETS: Array[Array] = [
	[1.0, 1.0, 50.0, 50.0, 50.0, 150.0],
	[2.0, 2.0, 30.0, 60.0, 60.0, 150.0],
	[5.0, 5.0, 14.0, 70.0, 70.0, 154.0],
]
const SLICE_FLOURS: Array[StringName] = [&"white_bread", &"whole_wheat"]


## AC-05.1: each preset and slice flour. Keep, flour and water match the §2.3 table, the discard is
## the grams above the keep, and one Mix gives: freshly_fed, since_feed_s 0, the new mass, one
## journal entry with the grams, one action_applied and one state_changed, a save that already holds
## the feed, and exactly one sim draw (feed_u, D-030).
func test_ac_05_1_every_preset_and_flour() -> void:
	if not ready_for_integration():
		return
	var rng_seed: int = 7
	for preset: Array in PRESETS:
		for flour: StringName in SLICE_FLOURS:
			var label: String = "1:%d:%d %s" % [int(preset[0]), int(preset[1]), flour]
			var h: SliceHarness = mature_phone("feed_" + label.validate_filename(), rng_seed)
			var feed: FeedAction = FeedAction.from_ratio(preset[0], preset[1], flour)
			check_eq(feed.kept_g, preset[2], label + " keep (g)")
			check_eq(feed.flour_g.get(flour, -1.0), preset[3], label + " flour (g)")
			check_eq(feed.water_g, preset[4], label + " water (g)")
			check_eq(feed.mass_after_g(), preset[5], label + " total (g)")
			var mass_before: float = h.session.get_starter().mass_g
			var discard_g: float = mass_before - feed.kept_g
			check(discard_g >= 0.0 and discard_g == roundf(discard_g), label + " discard is whole grams (%s g)" % discard_g)
			var saves_before: int = int(h.disk_meta().get("save_count", 0))
			h.forget()
			var r: ActionResult = h.apply(feed)
			if not check(r.ok, label + " accepted"):
				continue
			var s: StarterState = h.session.get_starter()
			check_eq(s.mass_g, preset[5], label + " mass after the feed")
			check_eq(s.since_feed_s, 0.0, label + " since_feed_s")
			check_eq(h.state(), &"freshly_fed", label + " state")
			check(s.flour_mix.get(flour, 0.0) > 0.0, label + " the new flour is in the mix")
			check_eq(h.journal_of(&"feed").size(), 1, label + " one feed journal entry")
			var e: JournalEntry = r.journal_entry
			if check(e != null and e.kind == &"feed", label + " the result carries the entry"):
				check_eq(e.data.get("kept_g"), preset[2], label + " journal kept_g")
				check_eq(e.args.get("grams"), int(preset[2]), label + " journal grams")
				check_eq(e.args.get("ratio"), "1:%d:%d" % [int(preset[0]), int(preset[1])], label + " journal ratio")
				check_eq(e.args.get("flour"), String(Keys.flour(flour)), label + " journal flour key")
			check_eq(h.count(&"action_applied"), 1, label + " one action_applied")
			check_eq(h.count(&"state_changed"), 1, label + " one state_changed")
			var disk: StarterState = h.disk_starter()
			check(disk != null and disk.since_feed_s == 0.0 and disk.mass_g == preset[5], label + " the save holds the feed")
			check_eq(int(h.disk_meta().get("save_count", 0)), saves_before + 1, label + " exactly one save")
			var u: float = SliceHarness.first_draw(rng_seed)
			check_eq(s.feed_u, u, label + " feed_u is the seed's first draw")
			check_close(s.feed_jitter, 0.95 + 0.10 * u, 0.0, 1e-15, label + " feed_jitter")
			var rng := RandomNumberGenerator.new()
			rng.seed = rng_seed
			rng.randf()
			var rng_saved: Dictionary = h.disk_payload().get("rng", {})
			check_eq(rng_saved.get("sim_state", ""), str(rng.state), label + " exactly one draw from sim_rng")


## AC-05.6 and game-mechanics §2.4: the timing class recorded with the feed matches the state at Mix,
## including the rows that read rise_phase. EC-09: a feed in the fridge still shows dormant.
func test_ac_05_6_timing_class_matches_the_state_at_mix() -> void:
	if not ready_for_integration():
		return
	# [hours after a 1:1:1 feed on MATURE at the counter, expected state, class, journal key]
	var rows: Array[Array] = [
		[0.1, &"freshly_fed", &"early", &"JOURNAL_LOG_FEED"],
		[0.65, &"developing", &"early", &"JOURNAL_LOG_FEED"],
		[3.0, &"active", &"early", &"JOURNAL_LOG_FEED"],
		[5.5, &"near_peak", &"on_time", &"JOURNAL_LOG_FEED_AT_PEAK"],
		[6.8, &"at_peak", &"on_time", &"JOURNAL_LOG_FEED_AT_PEAK"],
		[10.0, &"collapsing", &"on_time", &"JOURNAL_LOG_FEED_AT_PEAK"],
		[14.0, &"hungry", &"late", &"JOURNAL_LOG_FEED"],
		[80.0, &"dormant", &"very_late", &"JOURNAL_LOG_FEED"],
		[115.0, &"unhealthy", &"rescue", &"JOURNAL_LOG_FEED_RESCUE"],
	]
	for row: Array in rows:
		var at_h: float = row[0]
		var h: SliceHarness = mature_phone("timing_%s" % row[1], SliceHarness.seed_for_draw(0.5))
		h.apply(feed_111())
		h.reopen_at(T0 + roundi(at_h * HOUR))
		var want_state: StringName = row[1]
		if not check_eq(h.state(), want_state, "state at %.2f h" % at_h):
			continue
		var r: ActionResult = h.apply(feed_111())
		check(r.ok, "%s: the feed is accepted" % want_state)
		var e: JournalEntry = r.journal_entry
		if check(e != null, "%s: a journal entry" % want_state):
			check_eq(e.data.get("timing"), String(row[2]), "%s: timing class" % want_state)
			check_eq(e.text_key, row[3], "%s: journal line" % want_state)
	# recovering (V9b): 120 h unfed, one feed, then 4 h later it's recovering.
	var rec: SliceHarness = mature_phone("timing_recovering", SliceHarness.seed_for_draw(0.5))
	rec.apply(feed_111())
	rec.reopen_at(T0 + 120 * HOUR)
	rec.apply(feed_111())
	rec.reopen_at(T0 + 124 * HOUR)
	if check_eq(rec.state(), &"recovering", "4 h after a rescue feed"):
		var r2: ActionResult = rec.apply(feed_111())
		check_eq(r2.journal_entry.data.get("timing") if r2.journal_entry != null else "", "very_late", "recovering: very_late")
	# EC-09: moved to the fridge at its peak, fed there 3 h later.
	var cold: SliceHarness = mature_phone("timing_fridge", SliceHarness.seed_for_draw(0.5))
	cold.apply(feed_111())
	cold.reopen_at(T0 + roundi(6.8 * HOUR))
	check(cold.apply(SetEnvironmentAction.to_location(&"fridge")).ok, "moved to the fridge")
	cold.play(3 * HOUR)
	if check_eq(cold.session.get_snapshot().dormant_cause, &"cold", "dormant (cold) 3 h into the fridge"):
		var r3: ActionResult = cold.apply(feed_111())
		check(r3.ok, "a feed in the fridge is accepted")
		check_eq(r3.journal_entry.data.get("timing") if r3.journal_entry != null else "", "very_late", "cold dormant: very_late")
		check_eq(cold.state(), &"dormant", "EC-09: dormant beats freshly_fed right after a fridge feed")
		check_eq(cold.session.get_starter().since_feed_s, 0.0, "EC-09: the feed is still recorded")


## AC-05.5 and V20: 36 h unfed (hooch about 0.46), then pour_off or stir_in. Both leave no hooch,
## stir-in adds 0.5 to 1.1 hydration points with no acid change, the peaks land within 0.05 h and
## 0.01x, and the journal records the hooch choice.
func test_ac_05_5_hooch_pour_off_vs_stir_in() -> void:
	if not ready_for_integration():
		return
	var rng_seed: int = SliceHarness.seed_for_draw(0.5)
	var results: Dictionary[StringName, Array] = {}
	for choice: StringName in [&"pour_off", &"stir_in"]:
		var h: SliceHarness = mature_phone("hooch_" + String(choice), rng_seed)
		h.apply(feed_111())
		h.reopen_at(T0 + 36 * HOUR)
		var hooch: float = h.session.get_starter().hooch
		check_between(hooch, 0.40, 0.52, "%s: hooch at 36 h (V20 about 0.46)" % choice)
		var feed: FeedAction = feed_111()
		feed.hooch_choice = choice
		var r: ActionResult = h.apply(feed)
		check(r.ok, "%s: accepted" % choice)
		var s: StarterState = h.session.get_starter()
		check_eq(s.hooch, 0.0, "%s: no hooch after the feed" % choice)
		if r.journal_entry != null:
			check_eq(r.journal_entry.data.get("hooch_choice"), String(choice), "%s: journal choice" % choice)
			check_eq(r.journal_entry.data.get("had_hooch"), true, "%s: journal had_hooch" % choice)
		var hydration: float = s.culture_hydration
		var acid: float = s.acid
		var peak_at: int = 0
		var peak: float = 0.0
		for minute: int in 12 * 60:
			h.play(MIN)
			var rise: float = h.session.get_starter().rise
			if rise > peak:
				peak = rise
				peak_at = h.clock.now_unix()
		results[choice] = [hydration, acid, float(peak_at - (T0 + 36 * HOUR)) / HOUR, peak]
	var pour: Array = results[&"pour_off"]
	var stir: Array = results[&"stir_in"]
	check_close(pour[0], 100.0, 0.0, 1e-9, "pour_off hydration stays 100%")
	check_between(float(stir[0]) - float(pour[0]), 0.5, 1.1, "stir_in hydration gain (points)")
	check_eq(stir[1], pour[1], "acid identical")
	check(absf(float(stir[2]) - float(pour[2])) <= 0.05, "peak times within 0.05 h (%.3f vs %.3f)" % [pour[2], stir[2]])
	check(absf(float(stir[3]) - float(pour[3])) <= 0.01, "peak heights within 0.01x (%.4f vs %.4f)" % [pour[3], stir[3]])


## AC-05.8: the process is killed right after Mix (the sequence plays on, nothing else saves). The
## relaunch has the feed exactly once, in the state and the journal. Killed inside the save at each
## fault point, the relaunch has it once or not at all, never half, and never a new starter.
func test_ac_05_8_kill_at_mix_never_duplicates_or_half_applies() -> void:
	if not ready_for_integration():
		return
	for fault: StringName in [&""] + SaveStore.FAULT_POINTS:
		var label: String = String(fault) if fault != &"" else "after_the_save"
		var h: SliceHarness = mature_phone("kill_" + label, 3)
		h.play(2 * HOUR)
		var id_before: String = h.session.get_starter().id
		h.store.fault_point = fault
		h.apply(feed_111())
		h.kill()
		h.launch()
		var s: StarterState = h.session.get_starter()
		check_eq(s.id, id_before, label + ": the same starter")
		check(not h.session.is_first_run(), label + ": not a first run")
		var fed_in_state: bool = s.since_feed_s < float(HOUR)
		var fed_in_journal: int = h.journal_of(&"feed").size()
		check(fed_in_journal <= 1, label + ": the feed is never duplicated")
		check_eq(fed_in_journal == 1, fed_in_state, label + ": state and journal agree")
		if fault == &"" or fault == &"after_rename":
			check(fed_in_state and fed_in_journal == 1, label + ": the feed survived")


## CLK-10 and EC-18: the feed sheet is open when the app goes to the background for 8 h. On resume
## the catch-up runs first, the sheet's preview (forecast_feed) changes, and Mix then applies exactly
## one feed at grid(now).
func test_clk_10_feed_sheet_open_across_8_hours_in_the_background() -> void:
	if not ready_for_integration():
		return
	var h: SliceHarness = mature_phone("clk10", 5)
	var preview_before: PeakForecast = h.session.forecast_feed(feed_111())
	h.forget()
	var resumed: CatchUpResult = h.resume_at(T0 + 8 * HOUR + 17)
	check_eq(resumed.simulated_s, 8 * HOUR, "8 h caught up on resume")
	var preview_after: PeakForecast = h.session.forecast_feed(feed_111())
	check(preview_before.has_window and preview_after.has_window, "forecast_feed has a window before and after")
	check_ne([preview_after.at_peak_start_min_s, preview_after.peak_rise_min],
		[preview_before.at_peak_start_min_s, preview_before.peak_rise_min],
		"the sheet's preview changes after the catch-up (the starter is hungrier)")
	var r: ActionResult = h.apply(feed_111())
	check(r.ok, "Mix after the resume is accepted")
	check_eq(h.session.get_starter().sim_time_unix, Sim.grid(T0 + 8 * HOUR + 17), "applied at grid(now)")
	check_eq(h.journal_of(&"feed").size(), 1, "exactly one feed")
	var order: Array[StringName] = h.names()
	check(order.find(&"resumed") >= 0 and order.find(&"resumed") < order.find(&"action_applied"),
		"resumed fires before the feed's action_applied")


## CLK-18: two feeds in the same grid minute apply in order at the same grid point, and the journal
## keeps each one's real time.
func test_clk_18_two_feeds_in_one_minute() -> void:
	if not ready_for_integration():
		return
	var h: SliceHarness = mature_phone("clk18", 5)
	h.play(30 * MIN)
	h.clock.advance(10)
	var first: ActionResult = h.apply(feed_111())
	h.clock.advance(40)
	var second: ActionResult = h.apply(FeedAction.from_ratio(2.0, 2.0, &"white_bread"))
	check(first.ok and second.ok, "both accepted")
	check_eq(h.session.get_starter().sim_time_unix, T0 + 30 * MIN, "both at the same grid point")
	var feeds: Array[JournalEntry] = h.journal_of(&"feed")
	if check_eq(feeds.size(), 2, "two feed entries"):
		check_eq(feeds[0].at_unix, T0 + 30 * MIN + 10, "first: its real time")
		check_eq(feeds[1].at_unix, T0 + 30 * MIN + 50, "second: its real time")
		check_eq(feeds[1].args.get("ratio"), "1:2:2", "in order: the 1:2:2 came second")
	check_eq(h.session.get_starter().mass_g, 150.0, "the second feed's mass wins")


## EC-04: 12 feeds of 1:1:1, 10 minutes apart. The starter stays freshly_fed or developing, every feed
## is journaled and saved, the first is on time (fed in collapse) and the other 11 are early, and the
## populations stay at or above the floor.
func test_ec_04_feeding_every_ten_minutes() -> void:
	if not ready_for_integration():
		return
	var h: SliceHarness = mature_phone("ec04", 11)
	var saves_before: int = int(h.disk_meta().get("save_count", 0))
	var states: Dictionary[StringName, bool] = {}
	for i: int in 12:
		var r: ActionResult = h.apply(feed_111())
		check(r.ok, "feed %d accepted" % (i + 1))
		for minute: int in 10:
			h.play(MIN)
			states[h.state()] = true
	var timings: Array[String] = []
	for e: JournalEntry in h.journal_of(&"feed"):
		timings.append(String(e.data.get("timing", "")))
	check_eq(timings.size(), 12, "12 journal lines")
	check_eq(timings.slice(0, 1), ["on_time"], "the first feed lands in the collapse")
	check_eq(timings.count("early"), 11, "the other 11 are early")
	check_eq(h.session.get_history().consecutive_early_feeds, 11, "history counts the early run")
	check(int(h.disk_meta().get("save_count", 0)) >= saves_before + 12, "at least one save per feed")
	for s: StringName in states:
		check(s == &"freshly_fed" or s == &"developing", "only freshly_fed or developing (saw %s)" % s)
	var st: StarterState = h.session.get_starter()
	check(st.yeast >= SimConstants.POP_FLOOR and st.lab >= SimConstants.POP_FLOOR, "populations at or above the floor")
