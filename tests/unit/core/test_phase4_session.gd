extends CoreCase
## Phase 4 contracts on GameSession (D-059): the empty jar with the discard at "Discard", the onboarding demo
## seam, the journal merge of quick moves (OD-22), the Notifier and Haptics hooks, the sound settings,
## unlocks and the trait reveal. Owner: T1.

const H: int = 3600


func before_each() -> void:
	I18nLoader.load_all()


func _session(dir: String, clock: Clock, notes: NotifierBackend = null, buzz: HapticsBackend = null) -> GameSession:
	var s := GameSession.new()
	s.setup(clock, SaveStore.new(dir), SettingsStore.new(dir + "/settings.cfg"), notes, buzz)
	s.boot()
	return s


## A named starter fed once at T0, then left until it is moldy (V9: about 214 h).
func _moldy(dir: String, clock: FakeClock) -> GameSession:
	var s: GameSession = _session(dir, clock)
	check(s.apply(AdoptStarterAction.new("Bramble", &"skip")).ok, "adopt")
	check(s.apply(FeedAction.from_ratio(1.0, 1.0, &"white_bread")).ok, "feed")
	s.on_background()
	clock.advance(225 * H)
	s.on_resume()
	check_eq(s.get_snapshot().state, &"moldy", "moldy at 225 h")
	return s


func test_discard_commits_at_discard_and_leaves_an_empty_jar() -> void:
	if not require(&"p4_contracts"):
		return
	var clock := FakeClock.new(T0)
	var dir: String = fresh_dir("empty_jar")
	var s: GameSession = _moldy(dir, clock)
	check_eq(s.restart_preset(), &"first_restart", "the first loss: M.'s spare")
	var r: ActionResult = s.apply(DiscardStarterAction.to_empty_jar())
	check(r.ok, "Discard is accepted with no name")
	check_eq(r.journal_entry.kind if r.journal_entry != null else &"", &"memorial", "the memorial is written")
	check(s.is_jar_empty() and s.get_snapshot().empty_jar, "the jar is empty")
	check(not s.is_first_run(), "an empty jar is not a new game")
	check_eq(s.get_memorials().size(), 1, "one memorial")
	check_eq(s.restart_preset(), &"first_restart", "still M.'s spare on the restart page")
	check_eq(s.get_visuals().level_m, 0.0, "nothing in the jar")
	for a: GameAction in [FeedAction.from_ratio(1.0, 1.0, &"white_bread"), SmellAction.new(), InspectAction.new(&"surface"),
			SetEnvironmentAction.to_location(&"warm_spot")]:
		check_eq(s.apply(a).reason_key, GameAction.REASON_EMPTY_JAR, "%s waits for a starter" % a.kind)
	check_eq(s.apply(AdoptStarterAction.new("Juniper")).reason_key, GameAction.REASON_EMPTY_JAR, "no adoption")
	s.free()
	# "Not today", then a kill: the relaunch is the empty jar, days later, with nothing to summarize.
	clock.advance(3 * 86400)
	var again: GameSession = _session(dir, clock)
	check(again.is_jar_empty(), "relaunch: still the empty jar")
	check_eq(again.get_memorials().size(), 1, "exactly one memorial")
	check(not again.get_return_summary().show and not again.get_last_catch_up().play_time_lapse,
		"no away summary or time-lapse for an empty jar")
	check(again.get_pending_events().is_empty(), "no events")
	check_eq(again.apply(StartAgainAction.new("  ")).reason_key, GameAction.REASON_NAME, "a name is needed")
	var start: ActionResult = again.apply(StartAgainAction.new("Juniper"))
	check(start.ok, "Start again")
	var spare: StarterState = again.get_starter()
	check(not spare.empty and spare.name == "Juniper" and not spare.id.is_empty(), "a named new starter")
	check_eq(again.get_snapshot().state, &"dormant", "M.'s spare starts cold")
	check_eq(again.get_history().fridge_left_unix, Sim.grid(spare.born_unix), "a fridge wake for waking_up")
	check_eq(again.apply(StartAgainAction.new("Other")).reason_key, GameAction.REASON_NOT_EMPTY, "only once")
	check(again.apply(FeedAction.from_ratio(1.0, 1.0, &"white_bread")).ok, "and it can be fed")
	again.free()


func test_a_second_loss_restarts_with_a_friends_spoonful() -> void:
	if not require(&"p4_contracts"):
		return
	var clock := FakeClock.new(T0)
	var s: GameSession = _moldy(fresh_dir("second_loss"), clock)
	s.apply(DiscardStarterAction.to_empty_jar())
	s.apply(StartAgainAction.new("Juniper"))
	s.apply(FeedAction.from_ratio(1.0, 1.0, &"white_bread"))
	s.on_background()
	clock.advance(13 * 86400)
	s.on_resume()
	check_eq(s.get_snapshot().state, &"moldy", "lost again")
	check_eq(s.restart_preset(), &"restart", "before the discard: a friend's spoonful")
	check(s.apply(DiscardStarterAction.to_empty_jar()).ok, "discard")
	check_eq(s.restart_preset(), &"restart", "after it too")
	check(s.apply(StartAgainAction.new("Rye")).ok, "start again")
	check_eq(s.get_snapshot().rise_phase, &"at_peak", "the spoonful is at its peak")
	check_eq(s.get_memorials().size(), 2, "two memorials")
	s.free()


func test_the_onboarding_demo_never_touches_the_save() -> void:
	if not require(&"p4_contracts"):
		return
	var clock := FakeClock.new(T0)
	var dir: String = fresh_dir("demo")
	var s: GameSession = _session(dir, clock)
	var states: Array[StringName] = []
	var played: Array[CatchUpResult] = []
	s.state_changed.connect(func(snap: StarterSnapshot, _v: VisualParams) -> void: states.append(snap.state))
	s.demo_played.connect(func(res: CatchUpResult) -> void: played.append(res))
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(dir + "/" + SaveStore.FILE_MAIN)
	check(s.begin_demo() and s.is_in_demo(), "the tour starts on a first run")
	check_eq(states.back() if not states.is_empty() else &"", &"freshly_fed", "B1: the jar shows it just mixed")
	check_eq(s.get_snapshot().state, &"freshly_fed", "and so does the HUD")
	var smell: ActionResult = s.apply(SmellAction.new())
	var sniff: SmellReadout = smell.readout as SmellReadout
	check(smell.ok and sniff != null and sniff.primary == &"wet_flour", "B3: wet flour")
	var look: ActionResult = s.apply(InspectAction.new(&"bubbles"))
	var bubbles: InspectionReadout = look.readout as InspectionReadout
	check(look.ok and bubbles != null and bubbles.observations.has(&"few_tiny"), "B5: few, tiny bubbles")
	check_eq(s.apply(FeedAction.from_ratio(1.0, 1.0, &"white_bread")).reason_key, GameSession.NOT_READY_KEY,
		"no feeding in the demo")
	check(s.get_journal().is_empty(), "nothing journaled")
	check_eq(FileAccess.get_file_as_bytes(dir + "/" + SaveStore.FILE_MAIN), bytes, "nothing saved")
	var res: CatchUpResult = s.play_demo()
	check(res != null and played.size() == 1 and played[0] == res, "demo_played carries the playback")
	check_eq(res.time_lapse_duration_s(), Demo.DURATION_S, "played over the demo's length")
	check_eq(s.get_snapshot().rise_phase, &"at_peak", "B6 pauses at the peak")
	check_eq(FileAccess.get_file_as_bytes(dir + "/" + SaveStore.FILE_MAIN), bytes, "still nothing saved")
	var adopt: ActionResult = s.apply(AdoptStarterAction.new("Bramble", &"tour"))
	check(adopt.ok and not s.is_in_demo(), "B4: naming adopts and ends the demo")
	check_eq(s.get_snapshot().rise_phase, &"at_peak", "the adopted starter is at its peak, as watched")
	check(s.get_history().unlocks.is_empty(), "the tour earns unlocks as it goes")
	check(not s.begin_demo(), "no demo once named")
	var fed: ActionResult = s.apply(FeedAction.from_ratio(1.0, 1.0, &"white_bread"))
	var day_one: JournalEntry = null
	for e: JournalEntry in s.get_journal():
		if e.text_key == &"JOURNAL_DAY_ONE_TITLE":
			day_one = e
	check(fed.ok and day_one != null, "B7 then Day one")
	check_eq(day_one.data.get("body_key", "") if day_one != null else "", "JOURNAL_DAY_ONE_BODY",
		"fed right at its peak on the tour")
	s.free()


func test_skip_opens_every_unlock_and_end_demo_restores_the_jar() -> void:
	if not require(&"p4_contracts"):
		return
	var clock := FakeClock.new(T0)
	var s: GameSession = _session(fresh_dir("skip"), clock)
	var real: StringName = s.get_snapshot().rise_phase
	check(s.begin_demo(), "demo")
	s.end_demo()
	check(not s.is_in_demo() and s.get_snapshot().rise_phase == real, "back to the gifted starter")
	check(s.apply(AdoptStarterAction.new("Bramble", &"skip")).ok, "I know starters")
	for id: StringName in Unlocks.EARNED:
		check(s.is_unlocked(id), "%s is open" % id)
		for key: StringName in [Unlocks.toast_key(id), Unlocks.body_key(id)]:
			check_ne(TranslationServer.translate(key), String(key), "%s is in the catalog" % key)
	for t: StringName in Traits.IDS:
		for part: String in ["NAME", "JOURNAL_TITLE", "JOURNAL_BODY", "REVEAL_TOAST"]:
			var key: String = "TRAIT_%s_%s" % [String(t).to_upper(), part]
			check_ne(TranslationServer.translate(key), key, "%s is in the catalog" % key)
	s.free()
	var clock2 := FakeClock.new(T0)
	var early: GameSession = _session(fresh_dir("tour_unlocks"), clock2)
	early.apply(AdoptStarterAction.new("Bramble", &"tour"))
	check(early.is_unlocked(&"white_bread") and not early.is_unlocked(&"whole_wheat"), "the tour earns them")
	var lines: Array[JournalEntry] = []
	early.journal_appended.connect(func(e: JournalEntry) -> void: lines.append(e))
	early.apply(FeedAction.from_ratio(1.0, 1.0, &"white_bread"))
	early.on_background()
	clock2.advance(9 * H)
	early.on_resume()
	check(early.is_unlocked(&"whole_wheat"), "whole wheat after the first real peak")
	var unlock: JournalEntry = null
	for e: JournalEntry in lines:
		if e.kind == &"milestone" and str(e.data.get("unlock", "")) == "whole_wheat":
			unlock = e
	check(unlock != null, "one journal line, sent with journal_appended")
	if unlock != null:
		check_eq(unlock.text_key, &"UNLOCK_WHOLE_WHEAT_TOAST", "its toast key")
		check_ne(TranslationServer.translate(unlock.text_key), String(unlock.text_key), "a catalog string")
		check_eq(str(unlock.data.get("body_key", "")), "UNLOCK_WHOLE_WHEAT_BODY", "and its body")
	early.free()


func test_quick_moves_merge_into_one_journal_line() -> void:
	if not require(&"p4_contracts"):
		return
	var clock := FakeClock.new(T0)
	var s: GameSession = _session(fresh_dir("od22"), clock)
	s.apply(AdoptStarterAction.new("Bramble", &"skip"))
	# Freshly fed for the next 18 min, so no state change line lands between the moves.
	s.apply(FeedAction.from_ratio(1.0, 1.0, &"white_bread"))
	var heard: Array[JournalEntry] = []
	s.journal_appended.connect(func(e: JournalEntry) -> void: heard.append(e))
	var first: ActionResult = s.apply(SetEnvironmentAction.to_location(&"warm_spot"))
	clock.advance(60)
	var second: ActionResult = s.apply(SetEnvironmentAction.to_location(&"window_sill"))
	clock.advance(GameSession.MOVE_MERGE_S)
	var third: ActionResult = s.apply(SetEnvironmentAction.to_location(&"counter"))
	var moves: Array[JournalEntry] = []
	for e: JournalEntry in s.get_journal():
		if e.kind == &"environment":
			moves.append(e)
	check_eq(moves.size(), 1, "three quick moves, one line")
	check_eq(moves[0].text_key, &"JOURNAL_LOG_MOVE_COUNTER", "naming the latest place")
	check_eq(str(moves[0].data.get("from_location", "")), "counter", "and where the run started")
	check_eq(roundi(DictReader.float_of(moves[0].data.get("merged_moves", 0))), 3, "three moves")
	check(second.journal_entry == first.journal_entry and third.journal_entry == first.journal_entry,
		"the same entry each time")
	check_eq(heard.size(), 3, "journal_appended for each, with the same uid")
	check(heard.all(func(e: JournalEntry) -> bool: return e.uid == moves[0].uid), "one uid")
	clock.advance(GameSession.MOVE_MERGE_S + 1)
	s.apply(SetEnvironmentAction.to_location(&"warm_spot"))
	var count: int = 0
	for e: JournalEntry in s.get_journal():
		if e.kind == &"environment":
			count += 1
	check_eq(count, 2, "a move after the window is a new line")
	s.apply(SmellAction.new())
	clock.advance(60)
	s.apply(SetEnvironmentAction.to_location(&"counter"))
	count = 0
	for e: JournalEntry in s.get_journal():
		if e.kind == &"environment":
			count += 1
	check(count >= 2, "a line in between ends the run (smell lines are deduped, so >= 2: %d)" % count)
	s.free()


func test_notifier_plans_one_warning_with_quiet_hours() -> void:
	if not require(&"p4_contracts"):
		return
	var s: StarterState = SimFixtures.mature()
	SimFixtures.feed_ratio(s)
	s.sim_time_unix = T0
	var counter: EnvironmentState = EnvironmentState.at_location(&"counter")
	var fire: int = Notifier.plan(s, counter, T0, 0)
	var expect: int = T0 + Forecast.warning_signs_after_s(s, counter)
	check(fire >= expect, "at or after the forecast")
	var minute: int = LocalDay.minute_of_day(fire, 0)
	check(minute >= Notifier.QUIET_END_MIN and minute < Notifier.QUIET_START_MIN, "never in quiet hours")
	check_eq(Notifier.after_quiet_hours(T0 + 23 * H, 0), T0 + 32 * H, "23:00 waits for 08:00")
	check_eq(Notifier.after_quiet_hours(T0 + 3 * H, 0), T0 + 8 * H, "03:00 waits for 08:00")
	check_eq(Notifier.after_quiet_hours(T0 + 12 * H, 0), T0 + 12 * H, "noon is fine")
	check_eq(Notifier.after_quiet_hours(T0 + 12 * H, -5 * H), T0 + 13 * H, "07:00 local waits an hour")
	check_eq(Notifier.plan(s, EnvironmentState.at_location(&"fridge"), T0, 0), 0, "the fridge: none")
	var moldy: StarterState = s.copy()
	moldy.moldy = true
	check_eq(Notifier.plan(moldy, counter, T0, 0), 0, "moldy: none")
	check_eq(Notifier.plan(StarterState.make_empty(T0), counter, T0, 0), 0, "empty jar: none")


func test_session_schedules_on_background_and_cancels_on_return() -> void:
	if not require(&"p4_contracts"):
		return
	var clock := FakeClock.new(T0)
	var notes := NotifierBackend.new()
	var s: GameSession = _session(fresh_dir("notify"), clock, notes)
	s.apply(AdoptStarterAction.new("Bramble", &"skip"))
	s.apply(FeedAction.from_ratio(1.0, 1.0, &"white_bread"))
	s.on_background()
	check(notes.pending.is_empty(), "opt-in: off by default, nothing scheduled")
	check(s.set_notifications_enabled(true), "turned on (the stand-in grants permission)")
	check(s.get_settings().notifications, "saved as on")
	s.on_background()
	check_eq(notes.pending.size(), 1, "one notification")
	var pending: Dictionary = notes.pending.get(Notifier.WARNING_ID, {})
	check(int(pending.get("fire_unix", 0)) > T0 + 90 * H, "days away, not now")
	check(str(pending.get("body", "")).contains("Bramble"), "the body names the starter")
	clock.advance(H)
	s.on_resume()
	check(notes.pending.is_empty(), "cancelled when the player returns")
	s.on_background()
	check_eq(notes.pending.size(), 1, "planned again on leaving")
	s.apply(SetEnvironmentAction.to_location(&"fridge"))
	check(notes.pending.is_empty(), "a move to the fridge re-plans it: nothing to warn about")
	s.on_resume()
	s.apply(SetEnvironmentAction.to_location(&"counter"))
	s.on_background()
	check_eq(notes.pending.size(), 1, "back on the counter")
	check(not s.set_notifications_enabled(false), "opt-out")
	check(notes.pending.is_empty(), "opt-out cancels")
	notes.grant = false
	check(not s.set_notifications_enabled(true), "refused permission leaves it off")
	s.on_background()
	check(notes.pending.is_empty(), "still nothing")
	s.free()


func test_feedback_plays_haptics_only_when_on() -> void:
	if not require(&"p4_contracts"):
		return
	var buzz := HapticsBackend.new()
	var s: GameSession = _session(fresh_dir("haptics"), FakeClock.new(T0), null, buzz)
	check(s.on_feedback(&"tap"), "a tap pulses")
	check_eq(buzz.pulses.size(), 1, "one pulse")
	check(int(buzz.pulses[0]["duration_ms"]) <= 40 and float(buzz.pulses[0]["amplitude"]) <= 0.5, "short and soft")
	check(not s.on_feedback(&"no_such_moment"), "a moment with no pattern doesn't vibrate")
	s.get_settings().haptics = false
	check(not s.on_feedback(&"mix"), "haptics off: nothing")
	check_eq(buzz.pulses.size(), 1, "still one")
	for id: StringName in [&"tap", &"tick", &"toggle_on", &"toggle_off", &"mix", &"discard"]:
		check(Haptics.PATTERNS.has(id), "%s has a pattern" % id)
	s.free()


func test_sound_settings_round_trip() -> void:
	if not require(&"p4_contracts"):
		return
	var path: String = fresh_dir("sound") + "/settings.cfg"
	var a := SettingsStore.new(path)
	check(a.sound and a.master_volume == 1.0 and not a.notifications, "defaults: sound on, full volume, no notes")
	a.sound = false
	a.master_volume = 0.4
	a.notifications = true
	check_eq(a.save_settings(), OK, "saved")
	var b := SettingsStore.new(path)
	b.load_settings()
	check(not b.sound and is_equal_approx(b.master_volume, 0.4) and b.notifications, "loaded back")
	b.master_volume = 3.0
	b.save_settings()
	var c := SettingsStore.new(path)
	c.load_settings()
	check_eq(c.master_volume, 1.0, "volume is clamped to 0..1")


func test_ec_26_a_nameless_starter_never_gets_a_return_flow() -> void:
	if not require(&"p4_contracts"):
		return
	var clock := FakeClock.new(T0)
	var dir: String = fresh_dir("ec26")
	var first: GameSession = _session(dir, clock)
	check(first.is_first_run(), "first launch: no name")
	check(first.begin_demo(), "the tour starter")
	check_eq(first.get_snapshot().state, &"freshly_fed", "B1: just mixed")
	first.free()
	clock.advance(2 * 86400)
	var s: GameSession = _session(dir, clock)
	check(s.is_first_run(), "killed before naming: still nameless")
	check_eq(s.get_last_catch_up().steps, 2 * 1440, "its clock still runs (the clock rules hold)")
	check(not s.get_return_summary().show and not s.get_last_catch_up().play_time_lapse,
		"no away summary or time-lapse")
	check(s.get_journal().is_empty(), "no journal lines from the nameless days")
	check(s.get_pending_events().is_empty() and s.get_last_catch_up().events.is_empty(), "no events")
	clock.advance(3600)
	s.tick()
	check(s.get_journal().is_empty(), "a live tick writes nothing either")
	check(s.begin_demo(), "B1 again")
	check_eq(s.get_snapshot().state, &"freshly_fed", "the tour starter is fresh, however long the gap")
	var smell: SmellReadout = s.apply(SmellAction.new()).readout as SmellReadout
	check(smell != null and smell.primary == &"wet_flour", "B3: wet flour")
	check(s.get_journal().is_empty() and s.get_history().smelled_descriptors.is_empty(),
		"the tour's smell isn't journaled or counted")
	var r: ActionResult = s.adopt_starter(null, "Bramble")
	check(r != null and r.ok, "B4 adopts")
	check(s.get_journal().is_empty() and s.get_pending_events().is_empty(), "the chapter starts clean")
	check_eq(s.get_snapshot().rise_phase, &"at_peak", "fresh at its peak, however long the gap")
	s.free()


func test_v11_readouts_use_catalog_keys() -> void:
	if not require(&"p4_contracts"):
		return
	var counter: EnvironmentState = EnvironmentState.at_location(&"counter")
	var fridge: EnvironmentState = EnvironmentState.at_location(&"fridge")
	# Fed white, 4 h out, then the fridge: dormant (cold) but still risen.
	var s: StarterState = SimFixtures.mature()
	SimFixtures.feed_ratio(s)
	for i: int in 4 * 60:
		Sim.step(s, counter)
	for i: int in 2 * 60:
		Sim.step(s, fridge)
	var d: DerivedState = StateDeriver.derive(s, fridge)
	check_eq(d.state, &"dormant", "cold dormant after 2 h in the fridge")
	check(s.rise >= 1.1, "still risen (%.2fx)" % s.rise)
	var surface: InspectionReadout = Inspection.read(s, fridge, &"surface")
	check_eq(surface.meaning_key, &"INSPECT_ANY_DORMANT_RISEN_MEAN", "the shared risen meaning")
	check(not String(surface.text_key).contains("DORMANT"), "observations follow the rise phase")
	check(not Inspection.read(s, fridge, &"bubbles").observations.has(&"none"), "a risen starter keeps bubbles")
	# Every key the readouts produce over rye, rye stiff and white cycles, and the fridge, is in the catalog.
	var missing: PackedStringArray = []
	for setup: Array in [[&"rye", 100.0, counter], [&"rye", 60.0, counter], [&"white_bread", 100.0, fridge],
			[&"whole_wheat", 125.0, counter], [&"spelt", 60.0, counter]]:
		var flour: StringName = setup[0]
		var env: EnvironmentState = setup[2]
		var t: StarterState = SimFixtures.mature()
		for i: int in 4:
			SimFixtures.feed_ratio(t, 1.0, 1.0, flour, setup[1])
			for k: int in 720:
				Sim.step(t, counter)
		SimFixtures.feed_ratio(t, 1.0, 1.0, flour, setup[1])
		for hour: int in 120:
			for k: int in 60:
				Sim.step(t, env)
			for kind: StringName in SimConstants.INSPECT_KINDS:
				var r: InspectionReadout = Inspection.read(t, env, kind)
				for key: StringName in [r.text_key, r.meaning_key]:
					if TranslationServer.translate(key) == String(key) and not missing.has(String(key)):
						missing.append(String(key))
	check(missing.is_empty(), "keys missing from the catalog: " + ", ".join(missing))


func test_trait_reveal_reaches_the_snapshot_and_memorial() -> void:
	if not require(&"p4_contracts"):
		return
	var clock := FakeClock.new(T0)
	var s: GameSession = _session(fresh_dir("trait"), clock)
	s.apply(AdoptStarterAction.new("Bramble", &"skip"))
	var payload: Dictionary = s.build_payload()
	var starter: Dictionary = payload["starter"]
	starter["maturity"] = 0.36
	var fixture: String = fresh_dir("trait_fixture") + "/fixture.json"
	write_text(fixture, JSON.stringify(payload))
	s.free()
	var m := GameSession.new()
	m.setup(clock, SaveStore.new(fresh_dir("trait_run")))
	m.boot_from_fixture(fixture)
	check_eq(m.get_trait(), &"", "not revealed before a feed")
	check(m.apply(FeedAction.from_ratio(1.0, 1.0, &"white_bread")).ok, "a feed at steady")
	check(Traits.IDS.has(m.get_trait()), "revealed: %s" % m.get_trait())
	check_eq(m.get_snapshot().trait_id, m.get_trait(), "the HUD reads it")
	check_eq(m.get_history().trait_since_unix, m.get_starter().sim_time_unix, "dated to the feed")
	m.free()
