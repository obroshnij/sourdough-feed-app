extends SliceCase
## Phase 4, AC-16.5 and EC-20, EC-31: renaming through the real Session. Synthetic names only.
## 1 to 16 characters after trimming (data-models §4, narrative §6.1, ux §14). The UI's text filter drops
## emoji (narrative §6.1); the Session and the save must still round-trip any UTF-8 they are given.

const GOOD: Array[String] = ["B", "Sixteen chars ok", " Dough ", "Bubbles 🍞", "عجينة"]
const BAD: Array[String] = ["", "    ", "Seventeen chars!!"]


func test_ac_16_5_names_are_trimmed_bounded_and_survive_a_reload() -> void:
	if not require(&"p3_contracts"):
		return
	check_eq(GOOD[1].length(), GameAction.NAME_MAX_CHARS, "the long good name is at the limit")
	check_eq(GameAction.NAME_MAX_CHARS, 16, "the limit is 16 (data-models §4)")
	check_eq(BAD[2].length(), 17, "the long bad name is 17 characters")
	var h: SliceHarness = phone("ac16_5")
	h.seed_save(SliceHarness.mature())
	var s: GameSession = h.launch()
	for name_text: String in GOOD:
		h.play(MIN)
		var before: int = h.journal_of(&"rename").size()
		var r: ActionResult = h.apply(RenameAction.new(name_text))
		check(r.ok, "%s applies" % show(name_text))
		check_eq(s.get_starter().name, name_text.strip_edges(), "the name is trimmed")
		check_eq(h.journal_of(&"rename").size(), before + 1, "one rename journal entry")
		check_eq(String(r.journal_entry.args.get("name", "")), name_text.strip_edges(), "the entry names it")
		s = h.reopen_at(h.clock.now_unix() + MIN)
		check(s.get_starter().name.to_utf8_buffer() == name_text.strip_edges().to_utf8_buffer(),
			"%s survives a save and reload byte for byte" % show(name_text))
	for name_text: String in BAD:
		var save_before: PackedByteArray = h.bytes_of(SaveStore.FILE_MAIN)
		var name_before: String = s.get_starter().name
		var r: ActionResult = h.apply(RenameAction.new(name_text))
		check(not r.ok, "%s is rejected" % show(name_text))
		check_eq(r.reason_key, GameAction.REASON_NAME, "with REASON_NAME")
		check_eq(s.get_starter().name, name_before, "the name is unchanged")
		check(h.bytes_of(SaveStore.FILE_MAIN) == save_before, "the save is unchanged")


func test_ec_31_two_hundred_renames_stay_inside_the_journal_caps() -> void:
	if not require(&"p3_contracts"):
		return
	var h: SliceHarness = phone("ec31")
	h.seed_save(SliceHarness.mature())
	var s: GameSession = h.launch()
	for i: int in 200:
		h.play(MIN)
		var r: ActionResult = h.apply(RenameAction.new("Name %d" % i))
		if not r.ok:
			fail("rename %d was rejected: %s" % [i, r.reason_key])
			return
	check_eq(s.get_starter().name, "Name 199", "the last name wins")
	check(s.get_journal().size() <= 400, "the journal holds at most 400 entries (%d)" % s.get_journal().size())
	check(h.bytes_of(SaveStore.FILE_MAIN).size() <= 128 * 1024, "the save stays inside 128 KB")
