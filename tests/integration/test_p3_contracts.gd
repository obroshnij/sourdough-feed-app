extends SliceCase
## T1's Phase 3 contracts (p3_contracts) through the real Session: the return summary's threshold and
## size (AC-09.2, 09.3), the 14-day cap (CLK-02), the time-lapse keyframes (AC-09.5), feed like last
## time (AC-05.3, data side) and the debug time travel sandbox (OD-19). With T4's slice rules live.


func ready_for_contracts() -> bool:
	return ready_for_integration() and require(&"p3_contracts")


## AC-09.2: the summary shows only after an hour away with a change. Away 3,599 s from a grid-aligned
## close (3,540 s simulated) shows nothing even though the starter changed state; 3,600 s shows it.
## A starter asleep in the fridge for 2 h, with nothing happening, shows nothing either.
func test_ac_09_2_summary_needs_an_hour_and_a_change() -> void:
	if not ready_for_contracts():
		return
	for away: int in [3599, 3600]:
		var h: SliceHarness = mature_phone("summary_%d" % away, 3)
		h.apply(feed_111())
		h.reopen_at(T0 + away)
		var r: CatchUpResult = h.session.get_last_catch_up()
		check(not r.transitions.is_empty(), "%d s: the starter changed state while away" % away)
		check_eq(h.session.get_return_summary().show, away >= 3600, "%d s: the summary shows" % away)
	var cold: StarterState = SliceHarness.mature()
	cold.temp_c = 4.0
	var f: SliceHarness = phone("summary_fridge")
	f.seed_save(cold, EnvironmentState.at_location(&"fridge"), 3)
	f.launch()
	check_eq(f.state(), &"dormant", "asleep in the fridge")
	f.reopen_at(T0 + 2 * HOUR)
	var quiet: CatchUpResult = f.session.get_last_catch_up()
	check(quiet.transitions.is_empty() and quiet.events.is_empty(), "nothing happened in 2 h")
	check(not f.session.get_return_summary().show, "no summary without a change")


## AC-09.3 and BT-15: 7 days away at the counter. At most 3 lines and 1 prompt, every line is a real
## catalog key, the title says it was a long time, and every event the summary dropped is still in the
## journal.
func test_ac_09_3_a_week_away_fits_in_three_lines_and_one_prompt() -> void:
	if not ready_for_contracts():
		return
	var h: SliceHarness = mature_phone("week", SliceHarness.seed_for_draw(0.5))
	h.apply(feed_111())
	h.reopen_at(T0 + 7 * DAY)
	var s: ReturnSummary = h.session.get_return_summary()
	check(s.show, "the summary shows")
	check_between(s.lines.size(), 1, ReturnSummary.MAX_LINES, "lines")
	check_eq(s.title_key, &"AWAY_TITLE_LONG", "a week reads as a long time")
	for line: ReturnLine in s.lines:
		check(line.text_key != &"" and tr(line.text_key) != String(line.text_key), "line key %s is in the catalog" % line.text_key)
	var journaled: Dictionary[int, bool] = {}
	for e: JournalEntry in h.journal_of(&"event"):
		journaled[int(e.data.get("event_uid", 0))] = true
	for e: SimEvent in s.dropped:
		check(journaled.has(e.uid), "dropped %s (uid %d) is in the journal" % [e.id, e.uid])
	if s.prompt != null:
		check(s.prompt.tier == &"attention" or s.prompt.tier == &"nudge", "the prompt is an attention or a nudge")


## CLK-02: 30 days away. The summary says the cap was reached and that it was a long time.
func test_clk_02_thirty_days_summary_is_capped_and_long() -> void:
	if not ready_for_contracts():
		return
	var h: SliceHarness = mature_phone("month", 3)
	h.reopen_at(T0 + 30 * DAY)
	var s: ReturnSummary = h.session.get_return_summary()
	check(s.show and s.capped, "the summary shows and says capped")
	check_eq(s.title_key, &"AWAY_TITLE_LONG", "long title")


## AC-09.5: the time-lapse keyframes for a return to mold. At most 30, oldest first, the last one is
## the end of the absence, and every state change is a keyframe marked as a transition. The time-lapse
## plays only when the summary shows and the setting is on.
func test_ac_09_5_keyframes_keep_every_transition() -> void:
	if not ready_for_contracts():
		return
	var h: SliceHarness = mature_phone("keyframes", SliceHarness.seed_for_draw(0.5))
	h.apply(feed_111())
	h.reopen_at(T0 + 225 * HOUR)
	var r: CatchUpResult = h.session.get_last_catch_up()
	var frames: Array[TimeLapseKeyframe] = r.keyframes
	check_between(frames.size(), 2, CatchUpResult.MAX_KEYFRAMES, "keyframe count")
	var times: Dictionary[int, bool] = {}
	var ordered: bool = true
	for i: int in frames.size():
		times[frames[i].at_unix] = frames[i].transition
		if i > 0 and frames[i].at_unix <= frames[i - 1].at_unix:
			ordered = false
	check(ordered, "oldest first, no duplicates")
	check_eq(frames[frames.size() - 1].at_unix, r.to_unix, "the last frame is the end of the absence")
	for t: Dictionary in r.transitions:
		var at: int = t.get("at_unix", 0)
		check(times.get(at, false), "the change to %s at %s is a transition keyframe" % [t.get("to", ""), hours(at)])
	check(r.play_time_lapse, "the time-lapse plays")
	h.settings.show_time_lapse = false
	check_eq(h.session.save_settings(), OK, "setting saved")
	h.reopen_at(T0 + 230 * HOUR)
	check(not h.session.get_last_catch_up().play_time_lapse, "with the setting off it doesn't play")


## AC-05.3 (data side): last_feed_action() is the last accepted feed, field by field, and survives a
## relaunch. Before any feed it is 1:1:1 white_bread with pour_off. Applying it gives the same grams
## and choice in the journal.
func test_ac_05_3_feed_like_last_time_is_the_same_feed() -> void:
	if not ready_for_contracts():
		return
	var h: SliceHarness = mature_phone("last_feed", 3)
	var first: FeedAction = h.session.last_feed_action()
	check_eq(first.to_dict(), FeedAction.from_ratio(1.0, 1.0, &"white_bread").to_dict(), "the default before any feed")
	var feed: FeedAction = FeedAction.from_ratio(5.0, 5.0, &"whole_wheat")
	feed.hooch_choice = &"stir_in"
	check(h.apply(feed).ok, "a 1:5:5 whole_wheat stir-in feed")
	h.reopen_at(T0 + 9 * HOUR)
	var again: FeedAction = h.session.last_feed_action()
	check_eq(again.to_dict(), feed.to_dict(), "the same feed after a relaunch, field by field")
	var r: ActionResult = h.apply(again)
	check(r.ok, "feed like last time is accepted")
	var feeds: Array[JournalEntry] = h.journal_of(&"feed")
	if check_eq(feeds.size(), 2, "two feeds"):
		# Saved journal data is canonical (whole floats become ints), so compare canonical forms.
		for key: String in ["kept_g", "flour_g", "water_g", "hooch_choice"]:
			check_eq(DictReader.canonical(feeds[1].data.get(key)), DictReader.canonical(feeds[0].data.get(key)),
				"journal %s matches" % key)


## OD-19: debug time travel never touches the real save. The first set_debug_time_scale() saves the
## real state once at real time; after that a debug_advance of 8 h and a feed go to the sandbox, the
## real save.json stays byte-identical, and the next normal launch neither holds nor re-anchors.
func test_od_19_time_travel_never_touches_the_real_save() -> void:
	if not ready_for_contracts():
		return
	var now: int = int(Time.get_unix_time_from_system())
	var h: SliceHarness = phone("time_travel", now)
	h.seed_save(SliceHarness.mature(), null, 3)
	h.launch_with(DebugClock.new(1.0))
	check(h.session.set_debug_time_scale(60.0), "the time scale is accepted in a debug build")
	check(h.session.is_time_traveling(), "the run now saves to the sandbox")
	var real_bytes: PackedByteArray = h.bytes_of(SaveStore.FILE_MAIN)
	var real_starter: StarterState = h.disk_starter()
	var jump: CatchUpResult = h.session.debug_advance(8 * HOUR)
	check(jump.simulated_s >= 8 * HOUR - MIN, "debug_advance caught up 8 h (%d s)" % jump.simulated_s)
	check(h.apply(feed_111()).ok, "a feed in the sandbox")
	h.close()
	check_eq(h.bytes_of(SaveStore.FILE_MAIN), real_bytes, "the real save.json is byte-identical")
	var sandbox := SaveStore.new(h.dir + GameSession.TIME_TRAVEL_SUFFIX)
	check(FileAccess.file_exists(sandbox.path_of(SaveStore.FILE_MAIN)), "the sandbox holds the scaled save")
	check(real_starter != null and real_starter.sim_time_unix <= Sim.grid(int(Time.get_unix_time_from_system())),
		"the real save's time is not in the future")
	h.clock.set_now(int(Time.get_unix_time_from_system()))
	h.launch()
	var back: CatchUpResult = h.session.get_last_catch_up()
	check(not back.reanchored, "the next normal launch does not re-anchor")
	check(back.steps <= 5, "and has nothing big to catch up (%d steps)" % back.steps)
	check_eq(int(h.disk_meta().get("clock_reanchors", 0)), 0, "no clock re-anchor recorded")
	check_eq(h.journal_of(&"feed").size(), 0, "the sandbox feed is not in the real game")
