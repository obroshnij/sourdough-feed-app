extends SliceCase
## AC-11 (save and load) through the real Session: a corrupt save.json falls back to save.prev and the
## catch-up rebuilds the rest; every file bad starts a calm new starter (never onboarding); a kill at
## each fault point mid-game leaves the state just before or just after the last action; every save
## trigger writes; a kill during catch-up redoes it; settings and saves never touch each other; and
## poking the starter changes nothing (INT-08). SaveStore-level cases are in tests/save/.


## AC-11.1 (SAVE-03 through Session): save.json is corrupt after an hour of quiet play. The launch
## loads save.prev, catches up the minutes in between, and ends exactly where a clean launch would.
## The bad file is quarantined byte for byte, and this is not a recovery.
func test_ac_11_corrupt_save_json_falls_back_to_prev_and_catches_up() -> void:
	if not ready_for_integration():
		return
	var h: SliceHarness = mature_phone("prev_quiet", 31)
	h.play(HOUR)
	h.close()
	var clean: SliceHarness = phone("prev_quiet_control")
	QaTemp.copy_files(h.dir, clean.dir)
	clean.clock.set_now(h.clock.now_unix())
	clean.launch()
	var bad: PackedByteArray = h.bytes_of(SaveStore.FILE_MAIN)
	bad[bad.size() / 2] = bad[bad.size() / 2] ^ 0x20
	QaTemp.write(h.path(SaveStore.FILE_MAIN), bad)
	h.launch()
	check(not h.session.is_first_run(), "not a first run")
	check_eq(h.session.get_starter().id, SliceHarness.STARTER_ID, "the same starter")
	check_eq(h.session.get_starter().to_dict(), clean.session.get_starter().to_dict(),
		"save.prev plus the catch-up equals the clean launch")
	var q: PackedStringArray = h.quarantined()
	if check_eq(q.size(), 1, "one file quarantined"):
		check(q[0].ends_with("_" + SaveStore.FILE_MAIN), "it is save.json (%s)" % q[0])
		check_eq(QaTemp.read(h.path(SaveStore.QUARANTINE_DIR).path_join(q[0])), bad, "quarantined byte for byte")
	check_eq(h.disk_meta().get("recovered_from", "?"), "", "a fallback is not a recovery")


## AC-11.1 (SAVE-03, the cost): when the corrupt save.json held a feed, save.prev is one save behind,
## so the feed is gone, but the starter, its journal and its name stay (never a new starter).
func test_ac_11_corrupt_save_json_loses_at_most_the_last_action() -> void:
	if not ready_for_integration():
		return
	var h: SliceHarness = mature_phone("prev_feed", 31)
	h.play(HOUR)
	check(h.apply(feed_111()).ok, "fed")
	h.kill()
	var bad: PackedByteArray = h.bytes_of(SaveStore.FILE_MAIN)
	bad[bad.size() - 3] = bad[bad.size() - 3] ^ 0x01
	QaTemp.write(h.path(SaveStore.FILE_MAIN), bad)
	h.launch()
	check_eq(h.session.get_starter().id, SliceHarness.STARTER_ID, "the same starter")
	check_eq(h.session.get_starter().name, SliceHarness.STARTER_NAME, "its name")
	check_eq(h.journal_of(&"feed").size(), 0, "the last action (the feed) is lost")
	check(h.session.get_starter().since_feed_s > float(HOUR), "and the state agrees: not fed")


## AC-11.1 (SAVE-06 through Session): save.json, save.tmp and save.prev are all bad. All three are
## quarantined unchanged, a new starter begins, the save says it was recovered, and it is not treated
## as a first run (so no onboarding replays).
func test_ac_11_every_file_bad_starts_a_new_starter_calmly() -> void:
	if not ready_for_integration():
		return
	var h: SliceHarness = mature_phone("all_bad", 31)
	h.play(30 * MIN)
	h.close()
	var garbage: Dictionary[String, PackedByteArray] = {
		SaveStore.FILE_MAIN: "not a save".to_utf8_buffer(),
		SaveStore.FILE_TMP: PackedByteArray([0, 255, 1, 254, 123, 10]),
		SaveStore.FILE_PREV: h.bytes_of(SaveStore.FILE_PREV).slice(0, 40),
	}
	for file_name: String in garbage:
		QaTemp.write(h.path(file_name), garbage[file_name])
	h.launch()
	check_ne(h.session.get_starter().id, SliceHarness.STARTER_ID, "a new starter")
	check(not h.session.is_first_run(), "not a first run: no onboarding")
	check_eq(h.disk_meta().get("recovered_from", ""), "quarantine", "the save records the recovery")
	var q: PackedStringArray = h.quarantined()
	check_eq(q.size(), 3, "all three files quarantined")
	for file_name: String in garbage:
		var found: bool = false
		for f: String in q:
			if f.ends_with("_" + file_name):
				found = QaTemp.read(h.path(SaveStore.QUARANTINE_DIR).path_join(f)) == garbage[file_name]
		check(found, file_name + " quarantined byte for byte")
	check(h.disk_starter() != null, "a valid save.json exists again")


## AC-11.2: a running game is killed inside the save of a move, at each fault point. The relaunch
## shows the state just before or just after the move, the journal agrees with it, and it is never
## a new starter. After after_rename the move survives (save.tmp is promoted).
func test_ac_11_2_killed_at_each_fault_point_mid_game() -> void:
	if not ready_for_integration():
		return
	for fault: StringName in SaveStore.FAULT_POINTS:
		var h: SliceHarness = mature_phone("fault_" + String(fault), 33)
		h.play(30 * MIN)
		h.store.fault_point = fault
		h.apply(SetEnvironmentAction.to_location(&"warm_spot"))
		h.kill()
		h.launch()
		check_eq(h.session.get_starter().id, SliceHarness.STARTER_ID, "%s: the same starter" % fault)
		check(not h.session.is_first_run(), "%s: not a first run" % fault)
		var moved: bool = h.session.get_environment().location == &"warm_spot"
		check_eq(h.journal_of(&"environment").size(), 1 if moved else 0, "%s: the journal agrees with the place" % fault)
		check_eq(moved, fault == &"after_rename", "%s: before or after, as the fault point implies" % fault)


## SAVE-12: every trigger writes a save with a higher save_count and saved_unix = now: launch, each
## action, a tick that changes the state, a quiet tick 10 min after the last save, background and
## resume. A quiet tick before 10 min writes nothing.
func test_save_12_every_trigger_writes_and_quiet_ticks_do_not() -> void:
	if not ready_for_integration():
		return
	var h: SliceHarness = mature_phone("triggers", 35)
	var count: int = _save_count(h)
	check_eq(count, 1, "launch saves once")
	var actions: Array[GameAction] = [
		feed_111(), SetEnvironmentAction.to_location(&"warm_spot"), SmellAction.new(),
		InspectAction.new(&"bubbles"), RenameAction.new("Fern"),
	]
	for action: GameAction in actions:
		h.clock.advance(7)
		check(h.apply(action).ok, "%s accepted" % action.kind)
		count += 1
		check_eq(_save_count(h), count, "%s saves" % action.kind)
		check_eq(int(h.disk_meta().get("saved_unix", 0)), h.clock.now_unix(), "%s: saved_unix is now" % action.kind)
	var wrong: PackedStringArray = PackedStringArray()
	var changes: int = 0
	var autosaves: int = 0
	for minute: int in 2 * 60:
		var state_before: StringName = h.state()
		var last_save: int = int(h.disk_meta().get("saved_unix", 0))
		h.play(MIN)
		var changed: bool = h.state() != state_before
		var due: bool = h.clock.now_unix() - last_save >= GameSession.AUTOSAVE_INTERVAL_S
		var wrote: bool = _save_count(h) > count
		count = _save_count(h)
		changes += 1 if changed else 0
		autosaves += 1 if due and not changed else 0
		if wrote != (changed or due):
			wrong.append("%s: changed %s, due %s, wrote %s" % [hours(h.clock.now_unix()), changed, due, wrote])
	check(changes >= 1 and autosaves >= 3, "the 2 h covered state changes (%d) and quiet autosaves (%d)" % [changes, autosaves])
	check(wrong.is_empty(), "a tick saves exactly when the state changed or 10 min passed: " + "; ".join(wrong.slice(0, 5)))
	h.session.on_background()
	check_eq(_save_count(h), count + 1, "background saves")
	h.clock.advance(HOUR)
	h.session.on_resume()
	check_eq(_save_count(h), count + 2, "resume saves")


## SAVE-16 and EC-15: the app is killed during the launch catch-up, before its save. The next launch
## catches up again from the same file and gets exactly the same result as an undisturbed launch.
func test_save_16_killed_during_catch_up_redoes_it_the_same() -> void:
	if not ready_for_integration():
		return
	var h: SliceHarness = mature_phone("catchup_kill", 37)
	h.apply(feed_111())
	h.close()
	var clean: SliceHarness = phone("catchup_clean")
	QaTemp.copy_files(h.dir, clean.dir)
	var file_before: PackedByteArray = h.bytes_of(SaveStore.FILE_MAIN)
	h.clock.set_now(T0 + 3 * DAY)
	clean.clock.set_now(T0 + 3 * DAY)
	h.store = null
	var interrupted: GameSession = GameSession.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(interrupted)
	var dying := SaveStore.new(h.dir)
	dying.fault_point = &"before_tmp_write"
	interrupted.setup(h.clock, dying, SettingsStore.new(h.path("settings.cfg")))
	interrupted.boot()
	interrupted.free()
	check_eq(h.bytes_of(SaveStore.FILE_MAIN), file_before, "the killed catch-up left the file untouched")
	h.launch()
	clean.launch()
	check_eq(h.session.get_starter().to_dict(), clean.session.get_starter().to_dict(), "the redo equals an undisturbed launch")
	check_eq(h.journal_of(&"state_change").size(), clean.journal_of(&"state_change").size(), "no doubled journal entries")


## SAVE-18 and A11Y settings: saving settings emits Bus.settings_changed once and never touches the
## save. A corrupt settings.cfg gives defaults and leaves the save alone; a lost save leaves the
## settings alone.
func test_save_18_settings_and_saves_never_touch_each_other() -> void:
	if not ready_for_integration():
		return
	var h: SliceHarness = mature_phone("settings", 39)
	var save_bytes: PackedByteArray = h.bytes_of(SaveStore.FILE_MAIN)
	var prefs: SettingsStore = h.session.get_settings()
	prefs.reduce_motion = true
	prefs.text_scale = 1.5
	h.forget()
	check_eq(h.session.save_settings(), OK, "settings saved")
	check_eq(h.count(&"settings_changed"), 1, "Bus.settings_changed fires once")
	check_eq(h.bytes_of(SaveStore.FILE_MAIN), save_bytes, "the save is untouched")
	for file_name: String in [SaveStore.FILE_MAIN, SaveStore.FILE_PREV]:
		QaTemp.write(h.path(file_name), "gone".to_utf8_buffer())
	h.kill()
	h.launch()
	check(h.settings.reduce_motion and h.settings.text_scale == 1.5, "a lost save keeps the settings")
	var cfg_text: String = "[prefs]\ntext_scale=\"huge\"\nreduce_motion=12\n"
	QaTemp.write(h.path("settings.cfg"), cfg_text.to_utf8_buffer())
	save_bytes = h.bytes_of(SaveStore.FILE_MAIN)
	h.kill()
	h.launch()
	check(not h.settings.reduce_motion and h.settings.text_scale == 1.0, "bad settings values fall back to defaults")
	check_eq(h.session.get_starter().id, h.disk_starter().id if h.disk_starter() != null else "", "the save still loads")
	check_eq(h.quarantined().size() >= 2, true, "the earlier lost save files stay in quarantine")


## INT-08 and EC-24: 100 pokes (Bus.starter_tapped) change nothing: no state, no journal, no save.
func test_int_08_pokes_never_change_the_sim() -> void:
	if not ready_for_integration():
		return
	var h: SliceHarness = mature_phone("pokes", 41)
	var bus: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Bus")
	if not check(bus != null, "the Bus autoload exists"):
		return
	var text: String = SliceHarness.payload_text(h.session.build_payload())
	var bytes: PackedByteArray = h.bytes_of(SaveStore.FILE_MAIN)
	h.forget()
	for i: int in 100:
		bus.emit_signal(&"starter_tapped", &"starter" if i % 2 == 0 else &"glass")
	check_eq(h.count(&"starter_tapped"), 100, "100 pokes heard on the Bus")
	check_eq(h.count(&"state_changed") + h.count(&"journal_appended") + h.count(&"action_applied"), 0,
		"no Session signal")
	check_eq(SliceHarness.payload_text(h.session.build_payload()), text, "the payload is byte-unchanged")
	check_eq(h.bytes_of(SaveStore.FILE_MAIN), bytes, "no save written")


# ------------------------------------------------------------------ helpers

func _save_count(h: SliceHarness) -> int:
	return int(h.disk_meta().get("save_count", 0))
