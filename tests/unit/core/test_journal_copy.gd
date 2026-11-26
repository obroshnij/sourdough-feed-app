extends CoreCase
## Every journal and event entry Session writes renders to finished text: the key exists, nested keys
## (flour, smell) are translated, and no `{placeholder}` is left for the player to see (game-copy §1.3, §11).
## Owner: T1.

var _key_shape: RegEx = RegEx.create_from_string("\\b[A-Z][A-Z0-9]*_[A-Z0-9_]+\\b")


func before_each() -> void:
	I18nLoader.load_all()


func _check_rendered(e: JournalEntry) -> void:
	var where: String = "%s entry %s" % [e.kind, e.text_key]
	if not check(e.text_key != &"", where + ": has a text key"):
		return
	check(TranslationServer.translate(e.text_key) != e.text_key, where + ": key exists in the catalogs")
	var text: String = Keys.format(e.text_key, e.args)
	check(not text.contains("{") and not text.contains("}"), "%s: no leftover placeholder in \"%s\"" % [where, text])
	check(_key_shape.search(text) == null, "%s: no untranslated key in \"%s\"" % [where, text])


func test_every_journal_entry_renders() -> void:
	if not require(&"m4_save"):
		return
	var clock := FakeClock.new(T0)
	var s: GameSession = session(fresh_dir("journal_copy"), clock)
	s.boot()
	var feed: FeedAction = FeedAction.from_ratio(1.0, 1.0, &"whole_wheat")
	s.apply(feed)
	clock.advance(2 * 3600)
	s.apply(FeedAction.from_ratio(2.0, 2.0, &"white_bread"))
	clock.advance(3 * 3600)
	s.apply(SmellAction.new())
	for kind: StringName in SimConstants.INSPECT_KINDS:
		s.apply(InspectAction.new(kind))
	s.apply(RenameAction.new("Bubbles"))
	for place: StringName in [&"warm_spot", &"window_sill", &"proofing_box", &"fridge"]:
		s.apply(SetEnvironmentAction.to_location(place))
		clock.advance(3 * 3600)
		s.tick()
	s.apply(SetEnvironmentAction.to_location(&"counter"))
	s.on_background()
	clock.set_now(clock.now_unix() + 5 * 86400)
	s.on_resume()
	check_eq(s.get_snapshot().state, &"unhealthy", "5 days unfed at the counter")
	s.apply(FeedAction.from_ratio(1.0, 1.0, &"white_bread"))
	s.on_background()
	clock.set_now(clock.now_unix() + 14 * 86400)
	s.on_resume()
	check_eq(s.get_snapshot().state, &"moldy", "14 days unfed")
	s.apply(DiscardStarterAction.new("Second"))
	var kinds: Dictionary = {}
	var keys: Dictionary = {}
	for e: JournalEntry in s.get_journal():
		kinds[e.kind] = true
		keys[e.text_key] = true
		_check_rendered(e)
	for kind: StringName in [&"feed", &"environment", &"smell", &"inspect", &"state_change", &"rename", &"memorial"]:
		check(kinds.has(kind), "the script wrote a %s entry" % kind)
	for key: StringName in [&"JOURNAL_LOG_FEED", &"JOURNAL_LOG_FEED_AT_PEAK", &"JOURNAL_LOG_FEED_RESCUE",
			&"JOURNAL_LOG_MOVE_FRIDGE", &"JOURNAL_LOG_MOVE_PROOFING_BOX", &"STATUS_DORMANT_COLD_WORD",
			&"STATUS_DORMANT_STARVED_WORD"]:
		check(keys.has(key), "covered %s" % key)
	s.free()


func test_every_event_journal_entry_renders() -> void:
	if not require(&"m4_save"):
		return
	var clock := FakeClock.new(T0)
	var s: GameSession = session(fresh_dir("event_copy"), clock)
	s.boot()
	var ids: Array[StringName] = []
	var f: FileAccess = FileAccess.open("res://src/i18n/en.csv", FileAccess.READ)
	f.get_csv_line()
	var title := RegEx.create_from_string("^EVENT_([A-Z0-9_]+)_JOURNAL_TITLE$")
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() > 0:
			var m: RegExMatch = title.search(row[0])
			if m != null:
				ids.append(StringName(m.get_string(1).to_lower()))
	check(ids.size() >= 6, "the catalog has the slice events, found %d" % ids.size())
	var events: Array[SimEvent] = []
	for id: StringName in ids:
		var e := SimEvent.new()
		e.id = id
		e.created_unix = T0
		events.append(e)
	var before: int = s.get_journal().size()
	s._emit_events(events)
	var journal: Array[JournalEntry] = s.get_journal()
	check_eq(journal.size() - before, ids.size(), "one journal entry per event")
	for i: int in range(before, journal.size()):
		_check_rendered(journal[i])
	s.free()


func test_feed_and_smell_args_use_the_copy_names() -> void:
	if not require(&"m4_save"):
		return
	var clock := FakeClock.new(T0)
	var s: GameSession = session(fresh_dir("args"), clock)
	s.boot()
	var r: ActionResult = s.apply(FeedAction.from_ratio(1.0, 1.0, &"whole_wheat"))
	check_eq(r.journal_entry.args, {"ratio": "1:1:1", "flour": "FLOUR_WHOLE_WHEAT", "grams": 50}, "feed args")
	check_eq(Keys.format(r.journal_entry.text_key, r.journal_entry.args).contains(String(TranslationServer.translate(&"FLOUR_WHOLE_WHEAT"))),
		true, "the flour's display name is shown")
	clock.advance(600)
	var smell: ActionResult = s.apply(SmellAction.new())
	check(smell.journal_entry != null and smell.journal_entry.args.has("smell"), "smell args")
	check_eq(GameAction.NAME_MAX_CHARS, 16, "names are 1 to 16 characters (ux-design §18)")
	check(not s.apply(RenameAction.new("Seventeen chars!!")).ok, "17 characters are refused")
	s.free()
