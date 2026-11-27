extends CoreCase
## Phase 3 contracts on GameSession (D-046): the new-game start, feed like last time, the hooch and Day one
## journal entries, the moldy locks and the discard flow, event release, the return flow and time-lapse
## flag, debug time travel, shutdown, the night fade, settings and Keys formatting. Owner: T1.

const H: int = 3600


func before_each() -> void:
	I18nLoader.load_all()


func _boot(case_name: String, clock: Clock) -> GameSession:
	var s := GameSession.new()
	s.setup(clock, SaveStore.new(fresh_dir(case_name)), SettingsStore.new(fresh_dir(case_name + "_cfg") + "/s.cfg"))
	s.boot()
	return s


func _adopted(case_name: String, clock: FakeClock) -> GameSession:
	var s: GameSession = _boot(case_name, clock)
	check(s.apply(AdoptStarterAction.new("Bramble", &"skip")).ok, "adopt")
	return s


## A session booted from `s`'s payload after `edit` changed its starter dictionary.
func _from_fixture(s: GameSession, case_name: String, clock: FakeClock, starter_edits: Dictionary) -> GameSession:
	var payload: Dictionary = s.build_payload()
	var starter: Dictionary = payload["starter"]
	for k: String in starter_edits:
		starter[k] = starter_edits[k]
	var fixture: String = fresh_dir(case_name + "_fixture") + "/fixture.json"
	write_text(fixture, JSON.stringify(payload))
	var m := GameSession.new()
	m.setup(clock, SaveStore.new(fresh_dir(case_name)))
	m.boot_from_fixture(fixture)
	return m


func test_new_game_start_names_the_gifted_starter() -> void:
	if not require(&"p3_contracts"):
		return
	var clock := FakeClock.new(T0)
	var dir: String = fresh_dir("newgame")
	var s := GameSession.new()
	s.setup(clock, SaveStore.new(dir))
	s.boot()
	check(s.is_first_run() and s.get_return_summary().first_launch, "first launch: the new-game start")
	check(not s.get_return_summary().show and not s.recovered_this_launch(), "nothing to summarize, no recovery")
	check(s.name_suggestion_key(0).begins_with("NAME_SUGGEST_"), "a suggestion key")
	check_eq(s.name_suggestion_key(24), s.name_suggestion_key(0), "24 suggestions wrap")
	check(TranslationServer.translate(s.name_suggestion_key(3)) != s.name_suggestion_key(3), "suggestions exist")
	s.free()
	clock.advance(600)
	var again := GameSession.new()
	again.setup(clock, SaveStore.new(dir))
	again.boot()
	check(again.is_first_run(), "killed before naming: the new-game start runs again")
	check(not again.get_return_summary().first_launch, "but it isn't the first launch any more")
	var id: String = again.get_starter().id
	clock.advance(25 * 60)
	check_eq(again.apply(AdoptStarterAction.new("  ", &"skip")).reason_key, GameAction.REASON_NAME, "a name is needed")
	var r: ActionResult = again.apply(AdoptStarterAction.new(" Bramble ", &"skip"))
	check(r.ok and not again.is_first_run(), "named")
	check(again.get_starter().name == "Bramble" and again.get_starter().id == id, "same starter, trimmed name")
	check_eq(again.get_snapshot().state, &"at_peak", "rebased to a fresh at_peak, so the first feed is on time")
	check_eq(again.get_starter().born_unix, clock.now_unix(), "born at adoption")
	check_eq(again.apply(AdoptStarterAction.new("Other")).reason_key, GameAction.REASON_ADOPT, "only once")
	var fed: ActionResult = again.apply(FeedAction.from_ratio(1.0, 1.0, &"white_bread"))
	var journal: Array[JournalEntry] = again.get_journal()
	var day_one: JournalEntry = journal[-1]
	check(fed.ok and day_one.kind == &"milestone" and day_one.text_key == &"JOURNAL_DAY_ONE_TITLE", "Day one page")
	check_eq(day_one.body_key(), &"JOURNAL_DAY_ONE_SKIP_BODY", "the skip path's body")
	check_eq(day_one.args, {"name": "Bramble"}, "{name}")
	check_eq(fed.journal_entry.text_key, &"JOURNAL_LOG_FEED_AT_PEAK", "fed at its peak")
	again.apply(FeedAction.from_ratio(1.0, 1.0, &"white_bread"))
	var count: int = 0
	for e: JournalEntry in again.get_journal():
		if e.kind == &"milestone":
			count += 1
	check_eq(count, 1, "Day one is written once")
	again.free()


func test_quarantine_recovery_runs_the_new_game_start() -> void:
	if not require(&"p3_contracts"):
		return
	var dir: String = fresh_dir("recover")
	write_text(dir + "/save.json", "{ not a save")
	var s := GameSession.new()
	s.setup(FakeClock.new(T0), SaveStore.new(dir))
	s.boot()
	check(s.recovered_this_launch() and s.is_first_run(), "a calm notice, then naming")
	s.free()


func test_feed_like_last_time_and_hooch_entries() -> void:
	if not require(&"p3_contracts"):
		return
	var clock := FakeClock.new(T0)
	var s: GameSession = _adopted("last", clock)
	var first: FeedAction = s.last_feed_action()
	check(first.ratio_text() == "1:1:1" and first.main_flour() == &"white_bread" and first.hooch_choice == &"pour_off",
		"before any feed: 1:1:1 white, pour off")
	check(s.apply(first).ok, "the first feed (writes Day one)")
	var m: GameSession = _from_fixture(s, "hooch", clock, {"hooch": 0.3})
	var preview: FeedPreview = m.plan_feed(&"later", &"whole_wheat", &"stir_in")
	check(preview.hooch_step and preview.action.hooch_choice == &"stir_in", "the hooch step, with the choice")
	check_eq(preview.discard_g, roundi(m.get_starter().mass_g - preview.action.kept_g), "discard in grams")
	var r: ActionResult = m.apply(preview.action)
	var journal: Array[JournalEntry] = m.get_journal()
	check(r.ok and journal[-2].kind == &"hooch" and journal[-2].text_key == &"JOURNAL_LOG_HOOCH_STIRRED",
		"a hooch line just before the feed line")
	check_eq(journal[-1], r.journal_entry, "then the feed line")
	var again: FeedAction = m.last_feed_action()
	check_eq(again.to_dict(), preview.action.to_dict(), "AC-05.3 feed like last time equals the last feed")
	clock.advance(6 * H)
	var r2: ActionResult = m.apply(again)
	check(r2.ok and m.get_journal()[-2].kind != &"hooch", "no hooch line without hooch")
	var poured: GameSession = _from_fixture(s, "poured", clock, {"hooch": 0.3})
	poured.apply(FeedAction.from_ratio(1.0, 1.0, &"white_bread"))
	check_eq(poured.get_journal()[-2].text_key, &"JOURNAL_LOG_HOOCH_POURED", "pour off is logged too")
	s.free()
	m.free()
	poured.free()


func test_journal_entries_are_identical_after_a_reload() -> void:
	if not require(&"p3_contracts"):
		return
	var clock := FakeClock.new(T0)
	var dir: String = fresh_dir("journal_form")
	var s := GameSession.new()
	s.setup(clock, SaveStore.new(dir))
	s.boot()
	s.apply(AdoptStarterAction.new("Bramble"))
	s.apply(FeedAction.from_ratio(5.0, 5.0, &"whole_wheat"))
	var hoochy: GameSession = _from_fixture(s, "journal_form_hooch", clock, {"hooch": 0.3})
	hoochy.apply(FeedAction.from_ratio(2.0, 2.0, &"white_bread"))
	var before: Array[JournalEntry] = hoochy.get_journal()
	var hooch_data: Dictionary = before[-2].data
	check(typeof(hooch_data["hooch"]) == TYPE_STRING and DictReader.float_of(hooch_data["hooch"]) == 0.3,
		"a non-whole float is held as its hex string, read with float_of")
	var reloaded := GameSession.new()
	reloaded.setup(clock, SaveStore.new(hoochy._store.base_dir))
	reloaded.boot()
	var after: Array[JournalEntry] = reloaded.get_journal()
	check(after.size() >= before.size(), "the journal reloads")
	for i: int in before.size():
		check(before[i].data == after[i].data and before[i].args == after[i].args,
			"entry %d (%s) is identical after a reload" % [i, before[i].text_key])
	s.free()
	hoochy.free()
	reloaded.free()


func test_seen_states_for_the_new_dot() -> void:
	if not require(&"p3_contracts"):
		return
	var clock := FakeClock.new(T0)
	var s: GameSession = _adopted("seen", clock)
	s.apply(FeedAction.from_ratio(1.0, 1.0, &"white_bread"))
	var state: StringName = s.get_snapshot().state
	check(s.is_state_new(state) and s.is_state_new(&"moldy"), "every state starts new")
	check(not s.is_state_new(&"not_a_state") and not s.mark_state_seen(&"not_a_state"), "only canonical ids")
	var before_journal: int = s.get_journal().size()
	var before: Dictionary = s.build_payload()
	check(s.mark_state_seen(state) and not s.is_state_new(state), "marked: the dot goes")
	check(not s.mark_state_seen(state), "idempotent")
	var after: Dictionary = s.build_payload()
	check_eq(s.get_journal().size(), before_journal, "no journal entry")
	check_eq(after["starter"], before["starter"], "the starter is untouched (no time step, no sim change)")
	check_eq(after["events"], before["events"], "no events")
	check(s.is_state_new(&"hungry"), "other states stay new")
	var reloaded := GameSession.new()
	reloaded.setup(clock, SaveStore.new(s._store.base_dir))
	reloaded.boot()
	check(not reloaded.is_state_new(state), "saved: it survives a relaunch")
	var moldy: GameSession = _from_fixture(reloaded, "seen_moldy", clock, {"moldy": true, "mold_risk": 1.0})
	check(moldy.apply(DiscardStarterAction.new("Second")).ok, "discard and restart")
	check(not moldy.is_state_new(state), "per player: a new starter doesn't bring the dot back")
	var old: Dictionary = moldy.get_history().to_dict()
	old.erase("seen_states")
	var v1: PlayerHistory = PlayerHistory.from_dict(old)
	check(v1 != null and v1.seen_states.is_empty(), "a v1 history without the field loads with an empty set")
	s.free()
	reloaded.free()
	moldy.free()


func test_moldy_locks_and_the_discard_flow() -> void:
	if not require(&"p3_contracts"):
		return
	var clock := FakeClock.new(T0)
	var s: GameSession = _adopted("moldy_src", clock)
	s.apply(FeedAction.from_ratio(1.0, 1.0, &"white_bread"))
	var m: GameSession = _from_fixture(s, "moldy", clock, {"moldy": true, "mold_risk": 1.0})
	check_eq(m.apply(SmellAction.new()).reason_key, GameAction.REASON_MOLDY_LOCKED, "D-043 smell locked")
	check_eq(m.apply(SetEnvironmentAction.to_location(&"fridge")).reason_key, GameAction.REASON_MOLDY_LOCKED,
		"place locked")
	check_eq(m.apply(FeedAction.from_ratio(1.0, 1.0, &"white_bread")).reason_key, GameAction.REASON_MOLDY,
		"feed locked")
	check(m.apply(InspectAction.new(&"surface")).ok, "inspect still works")
	check(s.preview_memorial() == null, "no memorial for a healthy starter")
	var preview: Memorial = m.preview_memorial()
	check(preview != null and preview.name == "Bramble" and preview.feeds_count == 1, "the memorial page, before")
	check_eq(m.restart_preset(), &"first_restart", "first loss: M.'s spare")
	var r: ActionResult = m.apply(DiscardStarterAction.new("Second"))
	check(r.ok and r.journal_entry.kind == &"memorial", "memorial plus new starter in one action")
	var kept: Memorial = m.get_memorials()[0]
	check_eq(kept.to_dict(), preview.to_dict(), "the memorial equals its preview")
	check(kept.epitaph_key().begins_with("MEMORIAL_EPITAPH_"), "an epitaph")
	check_eq(m.restart_preset(), &"restart", "later losses: a friend's spoonful")
	check(m.get_history().real_feeds == 0 and m.get_starter().name == "Second", "the new starter starts clean")
	check(not m.is_first_run(), "the restart is named by the discard, no new-game start")
	s.free()
	m.free()


func test_events_release_once_and_withdraw_when_stale() -> void:
	if not require(&"p3_contracts"):
		return
	var clock := FakeClock.new(T0 + 10 * H)
	var dir: String = fresh_dir("release")
	var s := GameSession.new()
	s.setup(clock, SaveStore.new(dir))
	s.boot()
	s.apply(AdoptStarterAction.new("Bramble"))
	var raised: Array[int] = []
	var withdrawn: Array[int] = []
	var injected: Array[int] = []
	# The slice rules fire real events (peak_now) during these ticks too; only the injected ones count here.
	s.event_raised.connect(func(e: SimEvent) -> void:
		if injected.has(e.uid):
			raised.append(e.uid))
	s.event_withdrawn.connect(func(uid: int) -> void: withdrawn.append(uid))
	var now: int = s.get_starter().sim_time_unix
	var info: SimEvent = _pending(s, &"first_rise", &"info", now)
	var card: SimEvent = _pending(s, &"hungry_again", &"nudge", now)
	var later: SimEvent = _pending(s, &"hungry_again", &"nudge", now)
	later.not_before_unix = now + 2 * H
	var expiring: SimEvent = _pending(s, &"hungry_again", &"nudge", now)
	expiring.expires_unix = now + 3 * 60
	injected.append_array([info.uid, card.uid, later.uid, expiring.uid])
	check_eq(info.presentation(), SimEvent.PRESENT_TOAST, "info is a toast")
	check_eq(card.presentation(), SimEvent.PRESENT_CARD, "nudge is a card")
	clock.advance(60)
	s.tick()
	check_eq(raised, [info.uid, card.uid, expiring.uid], "due events raised in order; the deferred one waits")
	check(s._ledger.find_pending(info.uid) == null and s._ledger.find_pending(card.uid) != null,
		"a toast leaves the pending list, a card stays")
	clock.advance(60)
	s.tick()
	check_eq(raised.size(), 3, "raised once per run")
	clock.advance(3 * 60)
	s.tick()
	check_eq(withdrawn, [expiring.uid], "a raised card that went stale is withdrawn")
	clock.advance(2 * H)
	s.tick()
	check_eq(raised[-1], later.uid, "the deferred nudge is raised once due")
	check(s.apply(AckEventAction.new(card.uid, &"later")).ok, "a card is acknowledged")
	check_eq(s.apply(AckEventAction.new(card.uid)).reason_key, GameAction.REASON_EVENT, "only once")
	s.free()
	var again := GameSession.new()
	again.setup(clock, SaveStore.new(dir))
	var raised_again: Array[int] = []
	again.event_raised.connect(func(e: SimEvent) -> void: raised_again.append(e.uid))
	again.boot()
	check(raised_again.has(later.uid) and not raised_again.has(card.uid) and not raised_again.has(info.uid),
		"a relaunch raises the unacknowledged card again, never an acked card or a toast: %s" % [raised_again])
	again.free()


func _pending(s: GameSession, id: StringName, tier: StringName, at: int) -> SimEvent:
	var e := SimEvent.new()
	e.id = id
	e.tier = tier
	e.created_unix = at
	e.uid = s._ledger.take_uid()
	s._ledger.add_pending(e)
	return e


func test_return_flow_and_the_time_lapse_setting() -> void:
	if not require(&"p3_contracts"):
		return
	var clock := FakeClock.new(T0)
	var s: GameSession = _adopted("return", clock)
	s.apply(FeedAction.from_ratio(1.0, 1.0, &"white_bread"))
	var seen: Array[ReturnSummary] = []
	s.resumed.connect(func(_r: CatchUpResult) -> void: seen.append(s.get_return_summary()))
	s.on_background()
	clock.advance(8 * H)
	var r: CatchUpResult = s.on_resume()
	check(seen.size() == 1 and seen[0] == s.get_return_summary(), "the summary is ready inside resumed")
	check(s.get_return_summary().show and s.get_return_summary().lines.size() >= 1, "8 h after a feed: a summary")
	check(r.play_time_lapse and r.keyframes.size() >= 2, "the time-lapse plays")
	check_between(r.time_lapse_duration_s(), 3.0, 6.0, "3 to 6 s")
	s.get_settings().show_time_lapse = false
	s.on_background()
	clock.advance(8 * H)
	var off: CatchUpResult = s.on_resume()
	check(s.get_return_summary().show and not off.play_time_lapse, "setting off: summary yes, time-lapse no")
	s.get_settings().show_time_lapse = true
	s.on_background()
	clock.advance(30 * 60)
	var short: CatchUpResult = s.on_resume()
	check(not s.get_return_summary().show and not short.play_time_lapse, "30 min away: nothing")
	s.free()


func test_debug_time_travel_never_touches_the_real_save() -> void:
	if not require(&"p3_contracts"):
		return
	var dir: String = fresh_dir("travel")
	_dirs.append(dir + GameSession.TIME_TRAVEL_SUFFIX)
	var fake := GameSession.new()
	fake.setup(FakeClock.new(T0), SaveStore.new(fresh_dir("travel_fake")))
	fake.boot()
	check(not fake.set_debug_time_scale(60.0), "no DebugClock, no time scale (release builds)")
	check_eq(fake.debug_advance(86400).steps, 0, "and no jump")
	fake.free()
	var s := GameSession.new()
	s.setup(DebugClock.new(1.0), SaveStore.new(dir))
	s.boot()
	s.apply(AdoptStarterAction.new("Bramble"))
	check(not s.is_time_traveling(), "real time at first")
	check(s.set_debug_time_scale(3600.0) and s.is_time_traveling(), "scaled time moves to the sandbox")
	check_eq(s.get_debug_time_scale(), 3600.0, "the scale")
	var real_path: String = dir + "/save.json"
	var real_bytes: PackedByteArray = FileAccess.get_file_as_bytes(real_path)
	var real_payload: Dictionary = SaveStore.new(dir).load_from_path(real_path)
	var real_starter: Dictionary = real_payload["starter"]
	check(int(real_starter["sim_time_unix"]) <= int(Time.get_unix_time_from_system()),
		"the real save's last write is at real time")
	var jump: CatchUpResult = s.debug_advance(12 * 86400)
	check(jump.simulated_s >= 12 * 86400 - 60 and s.get_snapshot().state == &"moldy", "12 days on: mold, %s" %
		s.get_snapshot().state)
	check(s.get_return_summary().show, "the jump plays the return flow")
	check_eq(FileAccess.get_file_as_bytes(real_path), real_bytes, "the real save is byte-identical")
	var sandbox: Dictionary = SaveStore.new(dir + GameSession.TIME_TRAVEL_SUFFIX).load_from_path(
		dir + GameSession.TIME_TRAVEL_SUFFIX + "/save.json")
	var sandbox_starter: Dictionary = sandbox["starter"]
	check(int(sandbox_starter["sim_time_unix"]) > int(Time.get_unix_time_from_system()) + 11 * 86400,
		"the sandbox holds the future")
	s.free()
	var next := GameSession.new()
	next.setup(FakeClock.new(int(Time.get_unix_time_from_system()) + 60), SaveStore.new(dir))
	var res: CatchUpResult = next.boot()
	check(not res.reanchored and int(next.build_payload()["meta"]["clock_reanchors"]) == 0,
		"the next normal launch neither holds nor re-anchors")
	check(next.get_snapshot().state != &"moldy", "and the real starter never saw the trip")
	next.free()


func test_shutdown_allows_a_second_boot() -> void:
	if not require(&"p3_contracts"):
		return
	var clock := FakeClock.new(T0)
	var s: GameSession = _adopted("shutdown", clock)
	s.shutdown()
	check(not s.is_booted() and s.get_starter().name == "", "shut down: no state, not booted")
	s.setup(clock, SaveStore.new(fresh_dir("shutdown_again")))
	s.boot()
	check(s.is_booted() and s.is_first_run(), "a clean second boot")
	s.free()


func test_night_fade_is_one_pure_curve() -> void:
	if not require(&"p3_contracts"):
		return
	check_eq(NightFade.factor(12 * H), 0.0, "noon is day")
	check_eq(NightFade.factor(23 * H), 1.0, "23:00 is night")
	check_eq(NightFade.factor(17 * H), 0.0, "the evening fade starts at 17:00")
	check_eq(NightFade.factor(17 * H + 20 * 60), 1.0, "and ends at 17:20")
	check_between(NightFade.factor(17 * H + 10 * 60), 0.4, 0.6, "halfway at 17:10")
	check_eq(NightFade.factor(6 * H), 1.0, "06:00 still night")
	check_eq(NightFade.factor(6 * H + 20 * 60), 0.0, "06:20 day")
	var last: float = 0.0
	for m: int in 21:
		var f: float = NightFade.factor(17 * H + m * 60)
		check(f >= last, "rises monotonically at 17:%02d" % m)
		last = f
	check_eq(NightFade.at_unix(T0 + 23 * H, 0), 1.0, "UTC 23:00")
	check_eq(NightFade.at_unix(T0 + 23 * H, -10 * H), 0.0, "13:00 local at UTC-10")
	check_eq(NightFade.factor(-H), 1.0, "wraps: 23:00 the day before")
	for step: int in 288:
		var w: Vector3 = NightFade.preset_weights(step * 300)
		check(absf(w.x + w.y + w.z - 1.0) < 1e-9 and w.z == NightFade.factor(step * 300) and w.x >= 0.0 and w.y >= 0.0,
			"weights sum to 1 at %d s" % (step * 300))
	check_eq(NightFade.preset_weights(8 * H), Vector3(1.0, 0.0, 0.0), "08:00 morning")
	check_eq(NightFade.preset_weights(14 * H), Vector3(0.0, 1.0, 0.0), "14:00 afternoon")


func test_settings_fields_round_trip_with_defaults() -> void:
	if not require(&"p3_contracts"):
		return
	var path: String = fresh_dir("settings") + "/settings.cfg"
	var a := SettingsStore.new(path)
	check(a.haptics and not a.keep_messages, "defaults: haptics on, keep messages off")
	a.haptics = false
	a.keep_messages = true
	check_eq(a.save_settings(), OK, "saved")
	var b := SettingsStore.new(path)
	b.load_settings()
	check(not b.haptics and b.keep_messages, "loaded back")
	write_text(path, "[prefs]\nhaptics=\"yes\"\n")
	var c := SettingsStore.new(path)
	c.load_settings()
	check(c.haptics and not c.keep_messages, "a wrong type or missing key keeps the default")


func test_keys_format_time_and_dates() -> void:
	if not require(&"p3_contracts"):
		return
	check_eq(Keys.format_time(T0 + 23 * H + 30 * 60, 0), "11:30 PM", "{time}")
	check_eq(Keys.format_time(T0, 0), "12:00 AM", "midnight")
	check_eq(Keys.format_time(T0 + 12 * H + 5 * 60, 0), "12:05 PM", "noon")
	check_eq(Keys.format_time(T0, 2 * H), "2:00 AM", "the offset")
	var d: Dictionary = Time.get_date_dict_from_unix_time(T0)
	var months: Array[String] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var month: int = d["month"]
	check_eq(Keys.format_date(T0, 0), "%s %d, %d" % [months[month - 1], d["day"], d["year"]], "{start_date}")
	var peak: String = Keys.format(&"EVENT_PEAKED_WHILE_AWAY_AWAY_DOUBLE", {"time_unix": T0 + 23 * H + 30 * 60})
	check(peak.contains("11:30 PM") and not peak.contains("{"), "time_unix fills {time}: %s" % peak)
	var m := Memorial.new()
	m.born_unix = T0
	m.ended_unix = T0 + 9 * 86400
	var dates: String = Keys.format(&"MEMORIAL_DATES", m.dates_args())
	check(not dates.contains("{") and dates.contains(str(d["year"])), "memorial dates: %s" % dates)
