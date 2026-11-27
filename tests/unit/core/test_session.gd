extends CoreCase
## GameSession with a FakeClock and a temp SaveStore (architecture.md §4 to §6; test-plan INT-01, INT-06,
## INT-07, CLK-01 to CLK-05, SAVE-12, SAVE-14). No rendering, no autoload. Owner: T1.


func _boot(case_name: String, clock: FakeClock) -> GameSession:
	var s: GameSession = session(fresh_dir(case_name), clock)
	s.boot()
	return s


func test_first_boot_starts_a_new_game_and_saves() -> void:
	if not require(&"m4_save"):
		return
	var clock := FakeClock.new(T0)
	var s: GameSession = _boot("first", clock)
	check(s.is_first_run(), "SAVE-07 no files: first run")
	check_eq(s.get_snapshot().state, &"at_peak", "new_game starts at_peak")
	check_eq(s.get_starter().id.length(), 16, "a 16-hex starter id")
	var payload: Dictionary = s._store.load_from_path(s._store.path_of("save.json"))
	check_eq(payload.keys().size(), 8, "the save has all 8 sections")
	s.free()


func test_feed_pipeline_saves_before_signals() -> void:
	if not require(&"m4_save"):
		return
	var clock := FakeClock.new(T0)
	var s: GameSession = _boot("feed", clock)
	clock.advance(3 * 3600 + 17)
	var seen: Array = []
	s.action_applied.connect(func(r: ActionResult) -> void:
		var p: Dictionary = s._store.load_from_path(s._store.path_of("save.json"))
		var starter: Dictionary = p.get("starter", {})
		seen.append([r.ok, starter.get("since_feed_s", -1.0)]))
	var order: Array[String] = []
	s.state_changed.connect(func(_snap: StarterSnapshot, _v: VisualParams) -> void: order.append("state"))
	s.action_applied.connect(func(_r: ActionResult) -> void: order.append("applied"))
	s.journal_appended.connect(func(_e: JournalEntry) -> void: order.append("journal"))
	var r: ActionResult = s.apply(FeedAction.from_ratio(1.0, 1.0, &"white_bread"))
	check(r.ok, "the feed is accepted")
	check(seen.size() == 1 and seen[0][0] == true and float(seen[0][1]) == 0.0, "INT-01 the save already holds the feed")
	# With the slice rules live, the step-1 sync may journal an event too (peak_now here); it comes after.
	check_eq(order.slice(0, 3), ["applied", "state", "journal"],
		"step 9 order: action_applied, state_changed, journal_appended")
	check(order.slice(3).all(func(x: String) -> bool: return x == "journal"), "anything after is journal entries")
	check_eq(r.journal_entry.kind, &"feed", "one journal entry")
	check_eq(s.get_starter().sim_time_unix, Sim.grid(clock.now_unix()), "CLK-18 applied at grid(now)")
	check_eq(r.journal_entry.at_unix, clock.now_unix(), "the journal records the real time")
	s.free()


func test_rejected_action_changes_nothing() -> void:
	if not require(&"m4_save"):
		return
	var clock := FakeClock.new(T0)
	var s: GameSession = _boot("reject", clock)
	var before: String = payload_text(s.build_payload())
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(s._store.path_of("save.json"))
	var r: ActionResult = s.apply(RenameAction.new("   "))
	check(not r.ok and r.reason_key == GameAction.REASON_NAME, "INT-07 rejected with a reason key")
	check_eq(payload_text(s.build_payload()), before, "state and journal unchanged")
	check_eq(FileAccess.get_file_as_bytes(s._store.path_of("save.json")), bytes, "no save written")
	check(not s.apply(AckEventAction.new(42)).ok, "acking a missing event is rejected")
	s.free()


func test_close_and_reopen_catches_up() -> void:
	if not require(&"m4_save"):
		return
	var clock := FakeClock.new(T0)
	var s: GameSession = _boot("reopen", clock)
	s.on_background()
	clock.set_now(T0 + 8 * 3600)
	var r: CatchUpResult = s.on_resume()
	check(r.steps == 480 and r.simulated_s == 28800, "CLK-01 480 steps")
	s.on_background()
	clock.set_now(T0 + 7 * 3600)
	check_eq(s.on_resume().steps, 0, "CLK-03 clock 1 h back: nothing simulated")
	clock.set_now(T0 + 10 * 3600)
	check_eq(s.on_resume().simulated_s, 2 * 3600, "CLK-04 then 2 h later: 2 h")
	s.free()


func test_reanchor_after_a_corrected_jump() -> void:
	if not require(&"m4_save"):
		return
	var clock := FakeClock.new(T0)
	var s: GameSession = _boot("reanchor", clock)
	clock.set_now(T0 + 5 * 365 * 86400)
	var far: CatchUpResult = s.on_resume()
	check(far.capped and far.simulated_s == 14 * 86400, "CLK-02 capped at 14 d")
	clock.set_now(T0 + 3600)
	var back: CatchUpResult = s.on_resume()
	check(back.reanchored and back.steps == 0, "CLK-05 corrected clock re-anchors")
	clock.set_now(T0 + 7200)
	check_eq(s.on_resume().simulated_s, 3600, "CLK-05 the next open simulates 1 h")
	check_eq(int(s.build_payload()["meta"]["clock_reanchors"]), 1, "meta.clock_reanchors = 1")
	s.free()


func test_live_ticks_equal_one_catch_up() -> void:
	if not require(&"m4_save"):
		return
	var clock_a := FakeClock.new(T0)
	var a: GameSession = _boot("live_a", clock_a)
	var dir_b: String = fresh_dir("live_b")
	copy_file(a._store.path_of("save.json"), dir_b + "/save.json")
	var clock_b := FakeClock.new(T0)
	var b: GameSession = session(dir_b, clock_b)
	b.boot()
	for i: int in 37:
		clock_a.advance(293)
		a.tick()
	b.on_background()
	clock_b.set_now(T0 + 37 * 293)
	b.on_resume()
	check_eq(JSON.stringify(a.get_starter().to_dict()), JSON.stringify(b.get_starter().to_dict()),
		"CLK-14 3 h open equals 3 h closed")
	clock_a.set_now(clock_a.now_unix() + 301)
	a.tick()
	check_eq(a.get_starter().sim_time_unix, Sim.grid(T0 + 37 * 293), "CLK-09 a 301 s wall jump in session is ignored")
	a.free()
	b.free()


func test_rng_survives_save_and_load() -> void:
	if not require(&"m4_save"):
		return
	var seed_clock := FakeClock.new(T0)
	var origin: GameSession = _boot("rng_origin", seed_clock)
	var save_path: String = origin._store.path_of("save.json")
	var dir_a: String = fresh_dir("rng_a")
	var dir_b: String = fresh_dir("rng_b")
	copy_file(save_path, dir_a + "/save.json")
	copy_file(save_path, dir_b + "/save.json")
	var feed: FeedAction = FeedAction.from_ratio(1.0, 1.0, &"white_bread")
	var ca := FakeClock.new(T0)
	var a: GameSession = session(dir_a, ca)
	a.boot()
	for i: int in 3:
		ca.advance(4 * 3600)
		a.apply(feed)
	var cb := FakeClock.new(T0)
	var b: GameSession = session(dir_b, cb)
	b.boot()
	cb.advance(4 * 3600)
	b.apply(feed)
	b.on_background()
	var b2: GameSession = session(dir_b, cb)
	b2.boot()
	for i: int in 2:
		cb.advance(4 * 3600)
		b2.apply(feed)
	check_eq(JSON.stringify(b2.get_starter().to_dict()), JSON.stringify(a.get_starter().to_dict()),
		"SAVE-14 3 feeds equal 1 feed, save, load, 2 feeds")
	var rng: Dictionary = a.build_payload()["rng"]
	check(String(rng["sim_state"]).is_valid_int() and String(rng["sim_seed"]).is_valid_int(), "RNG saved as decimal strings")
	for x: GameSession in [origin, a, b, b2]:
		x.free()


func test_discard_moldy_starter_leaves_a_memorial() -> void:
	if not require(&"m4_save"):
		return
	var clock := FakeClock.new(T0)
	var s: GameSession = _boot("discard", clock)
	check(not s.apply(DiscardStarterAction.new("Second")).ok, "discard needs a moldy starter")
	var payload: Dictionary = s.build_payload()
	var starter: Dictionary = payload["starter"]
	starter["moldy"] = true
	starter["mold_risk"] = 1.0
	var fixture: String = fresh_dir("discard_fixture") + "/moldy.json"
	write_text(fixture, JSON.stringify(payload))
	var m: GameSession = session(fresh_dir("discard_session"), clock)
	m.boot_from_fixture(fixture)
	check_eq(m.get_snapshot().state, &"moldy", "the fixture loads moldy")
	check(not m.apply(FeedAction.from_ratio(1.0, 1.0, &"white_bread")).ok, "feeding a moldy starter is refused")
	var old_id: String = m.get_starter().id
	var r: ActionResult = m.apply(DiscardStarterAction.new("Second"))
	check(r.ok and r.journal_entry.kind == &"memorial", "INT-06 a memorial entry")
	check_eq(m.get_memorials().size(), 1, "one memorial")
	check(m.get_starter().id != old_id and m.get_starter().name == "Second", "a new starter with a new id")
	var d: DerivedState = m.get_derived()
	check(d.state == &"dormant" and d.dormant_cause == &"cold", "the first restart is M.'s spare from the fridge")
	check_eq(r.journal_entry.starter_id, old_id, "the memorial keeps the old starter id")
	s.free()
	m.free()


func test_payload_is_stable_across_save_and_load() -> void:
	if not require(&"m4_save"):
		return
	var clock := FakeClock.new(T0)
	var a: GameSession = _boot("stable", clock)
	clock.advance(5 * 3600 + 11)
	a.apply(FeedAction.from_ratio(2.0, 2.0, &"whole_wheat"))
	clock.advance(2 * 3600)
	a.apply(SmellAction.new())
	a.apply(InspectAction.new(&"height"))
	a.apply(SetEnvironmentAction.to_location(&"warm_spot"))
	var b: GameSession = session(a._store.base_dir, clock)
	b.boot()
	check_eq(payload_text(b.build_payload()), payload_text(a.build_payload()), "PROP-02 the same payload text after a load")
	check(a.get_journal().size() >= 4, "the journal holds the acts")
	a.free()
	b.free()


func test_save_failure_fires_once_and_keeps_state() -> void:
	if not require(&"m4_save"):
		return
	var clock := FakeClock.new(T0)
	var s: GameSession = _boot("savefail", clock)
	var fails: Array = []
	s.save_failed.connect(func(key: StringName) -> void: fails.append(key))
	s._store.fault_point = &"before_tmp_write"
	clock.advance(600)
	s.apply(SmellAction.new())
	clock.advance(600)
	s.apply(InspectAction.new(&"height"))
	check_eq(fails.size(), 1, "SAVE-09 save_failed fires once")
	s._store.fault_point = &""
	clock.advance(60)
	check(s.apply(InspectAction.new(&"surface")).ok, "the next trigger retries")
	check(fails.size() == 1, "and succeeds")
	s.free()
