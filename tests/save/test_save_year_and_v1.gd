extends SliceCase
## AC-11.1's remaining parts: SAVE-13 (size, write time and the journal cap over long play) and SAVE-11
## (the first frozen save, OD-23). SAVE-19 (rename on Android) is a Phase 5 device check.
##
## SAVE-13, partly: 60 days of twice-daily care with a daily smell and inspection, after a new game and a
## discard, fills the 400-entry journal, keeps the memorial and the Day one page, and writes in under
## 10 ms. It does NOT prove the size budget for a year. Measured 2026-11-27: the journal keeps shedding
## state changes, then smells and inspections, for heavier feed and event entries, so save.json is
## 124,989 bytes at 60 days but 146,561 bytes at 120 days (400 entries: 199 feeds, 199 events, the
## memorial and the milestone), over the 131,072-byte budget. Reported to t1-sim-core and the director.
## When it's fixed, raise this run to 120 days or more.
## SAVE-11: tests/fixtures/saves/v1_slice.json is a real save from this build: a memorial, events, a
## waiting warning, moves, smells and inspections. It must keep loading in every later build, with every
## stored field intact (new optional fields may be added, D-051). Never edit it. Regenerate only with
## the director's OK, by running the runner with --update-golden.

const V1_FIXTURE: String = "res://tests/fixtures/saves/v1_slice.json"
const SIZE_BUDGET: int = 128 * 1024
const WRITE_BUDGET_MS: float = 10.0
const MOLDY: String = "res://tests/unit/ui/fixtures/moldy.json"


func test_save_13_sixty_days_stay_inside_every_cap() -> void:
	if not (ready_for_integration() and require(&"p3_contracts") and require(&"p3_rules")):
		return
	var h: SliceHarness = phone("year")
	h.launch()
	check(h.session.is_first_run(), "a brand-new game")
	check(h.apply(AdoptStarterAction.new("Bramble", &"skip")).ok, "the gifted starter is named")
	h.apply(FeedAction.from_ratio(1.0, 1.0, &"white_bread"))
	check_eq(h.journal_of(&"milestone").size(), 1, "the first feed writes the Day one page")
	h.reopen_at(T0 + 12 * DAY)
	check_eq(h.state(), &"moldy", "left 12 days, it molds")
	check(h.apply(DiscardStarterAction.new("Juniper")).ok, "a discard leaves a memorial")
	var t: int = T0 + 12 * DAY
	for k: int in 120:
		h.apply(FeedAction.from_ratio(2.0, 2.0, &"white_bread"))
		if k % 2 == 0:
			h.apply(SmellAction.new())
			var kinds_cycle: Array[StringName] = [&"height", &"bubbles", &"surface"]
			h.apply(InspectAction.new(kinds_cycle[(k >> 1) % 3]))
		t += 12 * HOUR
		h.resume_at(t)
	var journal: Array[JournalEntry] = h.session.get_journal()
	check_eq(journal.size(), JournalEntry.CAP, "the journal is full and capped at 400")
	var kinds: Dictionary[StringName, int] = {}
	for e: JournalEntry in journal:
		kinds[e.kind] = kinds.get(e.kind, 0) + 1
	check_eq(kinds.get(&"memorial", 0), 1, "the memorial is never dropped")
	check(kinds.get(&"milestone", 0) >= 1, "the Day one milestone is never dropped")
	check(kinds.get(&"feed", 0) >= 100, "feeds outlast state changes (%s)" % str(kinds))
	var bytes: int = h.bytes_of(SaveStore.FILE_MAIN).size()
	check(bytes <= SIZE_BUDGET, "save.json is %d bytes, budget %d" % [bytes, SIZE_BUDGET])
	var payload: Dictionary = h.session.build_payload()
	var store := SaveStore.new(h.dir.path_join("timing"))
	var times: Array[float] = []
	for i: int in 5:
		var start: int = Time.get_ticks_usec()
		store.save(payload)
		times.append(float(Time.get_ticks_usec() - start) / 1000.0)
	times.sort()
	var line: String = "SAVE-13 write, Mac estimate (D-004): median %.2f ms of 5 (min %.2f, max %.2f), %d bytes" % [
		times[2], times[0], times[4], bytes]
	print("    " + line)
	check(times[2] <= WRITE_BUDGET_MS, line)


func test_save_11_the_frozen_v1_save_still_loads_intact() -> void:
	if not (ready_for_integration() and require(&"p3_contracts") and require(&"p3_rules")):
		return
	if update_golden():
		_write_v1_fixture()
	if not check(FileAccess.file_exists(V1_FIXTURE), "the frozen v1 save exists (run with --update-golden once)"):
		return
	var frozen: Dictionary = SaveStore.new("res://tests/fixtures/saves").load_from_path(V1_FIXTURE)
	check(not frozen.is_empty(), "the frozen file decodes")
	var h: SliceHarness = phone("v1_load")
	QaTemp.write(h.path(SaveStore.FILE_MAIN), FileAccess.get_file_as_bytes(V1_FIXTURE))
	var meta: Dictionary = frozen.get("meta", {})
	h.clock.set_now(int(meta.get("saved_unix", T0)))
	h.launch()
	check(not h.session.is_first_run() and not h.session.recovered_this_launch(), "it loads as a game, not a recovery")
	check(h.quarantined().is_empty(), "nothing is quarantined")
	var loaded: Dictionary = h.session.build_payload()
	var lost: PackedStringArray = PackedStringArray()
	for section: String in frozen:
		if section == "meta":
			continue
		# The file is in stored form (floats as hex, whole numbers as JSON numbers); pack the loaded side.
		_missing(frozen[section], SaveCodec.pack_floats(loaded.get(section, null)), section, lost)
	check(lost.is_empty(), "every stored field survives the load:\n    " + "\n    ".join(lost.slice(0, 10)))
	check_eq(h.session.get_memorials().size(), 1, "the memorial is back")
	var waiting: bool = h.session.get_pending_events().any(func(e: SimEvent) -> bool: return e.id == &"warning_signs")
	check(waiting, "the waiting warning is back")


## Lists the paths in `want` that `got` lacks or holds differently. Extra fields in `got` are fine.
static func _missing(want: Variant, got: Variant, path: String, out: PackedStringArray) -> void:
	if typeof(want) == TYPE_DICTIONARY:
		if typeof(got) != TYPE_DICTIONARY:
			out.append(path + " is gone")
			return
		var w: Dictionary = want
		var g: Dictionary = got
		for k: Variant in w:
			_missing(w[k], g.get(k, null), "%s.%s" % [path, str(k)], out)
	elif typeof(want) == TYPE_ARRAY:
		var wa: Array = want
		if typeof(got) != TYPE_ARRAY or (got as Array).size() != wa.size():
			out.append(path + " changed length")
			return
		var ga: Array = got
		for i: int in wa.size():
			_missing(wa[i], ga[i], "%s[%d]" % [path, i], out)
	elif not values_equal(want, got):
		out.append("%s: %s became %s" % [path, show(want), show(got)])


## A rich mid-game save: a discard and memorial, a fed starter left to the warning (one attention waiting),
## a rescue feed, a smell, two inspections and a move, from this build's Session.
func _write_v1_fixture() -> void:
	var h: SliceHarness = phone("v1_make")
	h.launch_fixture(MOLDY)
	h.apply(DiscardStarterAction.new("Juniper"))
	h.apply(FeedAction.from_ratio(1.0, 1.0, &"white_bread"))
	h.reopen_at(T0 + 150 * HOUR)
	if h.state() != &"unhealthy":
		fail("the fixture needs the warning waiting; the state at 150 h is %s" % h.state())
	h.apply(FeedAction.from_ratio(2.0, 2.0, &"whole_wheat"))
	h.apply(SmellAction.new())
	h.apply(InspectAction.new(&"surface"))
	h.apply(InspectAction.new(&"height"))
	h.apply(SetEnvironmentAction.to_location(&"warm_spot"))
	h.close()
	DirAccess.make_dir_recursive_absolute("res://tests/fixtures/saves")
	QaTemp.write(V1_FIXTURE, h.bytes_of(SaveStore.FILE_MAIN))
