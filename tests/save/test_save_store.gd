extends TestCase
## Save durability (test-plan §2.4, data-models §9, ADR-005) against T1's SaveStore and SaveCodec.
## Covers SAVE-02 to SAVE-10, SAVE-15 and SAVE-17. SAVE-20 needs no code here: any engine or
## script error logged during a test fails it, so every corrupt-file case below also proves
## the loader stays silent. Tests that need T1's code wait for milestone m4_save.
## SAVE-01, 11 to 14, 16 and 18 need the full payload and Session: test_save_session.gd.

const STAMP := 1795651200
## Recorded 2026-11-26 with Godot 4.7.2 on macOS. Change it only with a written reason (an engine
## upgrade that changes JSON output also changes every existing save's checksum check).
## History: b210e5cd... (plain JSON floats) became 86d62639... when D-040 stored floats as hex.
const GOLDEN_SHA256 := "86d6263995d00f671a164659130ae3cd8915772c15e10b5049e905cbda5be0bb"

var _dir: String = ""
var _clock: FakeClock


func before_each() -> void:
	_dir = QaTemp.make("save_store")
	_clock = FakeClock.new(STAMP)


func after_each() -> void:
	QaTemp.remove(_dir)


# ------------------------------------------------------------------ runs now (engine only)

## SAVE-15: a fixed payload always encodes to the same bytes. Catches an engine change in key
## order or float formatting (the 4.8 upgrade) before it changes every player's checksum.
func test_save_15_fixed_payload_has_a_fixed_sha256() -> void:
	var bytes: PackedByteArray = QaSaveFormat.encode(QaSaveFormat.sample_payload("golden"))
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	check_eq(ctx.finish().hex_encode(), GOLDEN_SHA256, "sha256 of the encoded golden payload")


# ------------------------------------------------------------------ needs m4_save

## SAVE-02: the file is exactly the documented layout. Compared byte for byte with QA's own
## encoder, written from data-models §9.2 rather than from SaveCodec.
func test_save_02_file_matches_the_documented_layout() -> void:
	if not require(&"m4_save"):
		return
	for tag: String in ["plain", "é\U0001F35E unicode", ""]:
		var payload: Dictionary = QaSaveFormat.sample_payload(tag)
		var store: SaveStore = _store(_dir)
		check_eq(store.save(payload), OK, "save " + tag)
		var bytes: PackedByteArray = QaTemp.read(_dir.path_join("save.json"))
		check_eq(bytes, QaSaveFormat.encode(payload), "save.json bytes for \"%s\"" % tag)
		var body: PackedByteArray = bytes.slice(bytes.find(10) + 1)
		check_eq(body.find(10), -1, "payload is one line")
		var report: SaveLoadReport = _store(_dir).load_latest()
		check_eq(report.payload, QaSaveFormat.stored(payload), "round trip for \"%s\"" % tag)
	check_eq(SaveCodec.CURRENT_VERSION, 1, "schema version")


## SAVE-07: no save files at all is the first-run flow, not a recovery.
func test_save_07_no_files_is_a_first_run() -> void:
	if not require(&"m4_save"):
		return
	for dir: String in [_dir, _dir.path_join("never_created")]:
		var report: SaveLoadReport = _store(dir).load_latest()
		check(report.first_run, "first_run in " + dir)
		check(not report.ok, "nothing loaded")
		check_eq(report.recovered_from, "", "not a recovery")
		check_eq(report.quarantined.size(), 0, "nothing quarantined")


## SAVE-03, 04, 05, 10: every corrupt save.json falls back to a good save.prev. The bad file is
## moved to quarantine byte for byte, never deleted, and nothing is logged (SAVE-20).
func test_save_03_to_05_corrupt_save_json_falls_back_to_prev() -> void:
	if not require(&"m4_save"):
		return
	var good: Dictionary = QaSaveFormat.sample_payload("prev")
	var corpus: Dictionary = QaSaveFormat.corrupt_corpus(QaSaveFormat.sample_payload("json"))
	for name: String in corpus:
		var dir: String = _dir.path_join(name)
		DirAccess.make_dir_recursive_absolute(dir)
		var bad: PackedByteArray = corpus[name]
		QaTemp.write(dir.path_join("save.json"), bad)
		QaTemp.write(dir.path_join("save.prev"), QaSaveFormat.encode(good))
		var report: SaveLoadReport = _store(dir).load_latest()
		check(report.ok, name + ": loaded")
		check_eq(report.source, "save.prev", name + ": source")
		check_eq(report.payload, QaSaveFormat.stored(good), name + ": payload is save.prev's")
		_check_quarantined(dir, report, "save.json", bad, name)


## SAVE-03: a corrupt save.json and a good save.tmp. The tmp wins and is promoted to save.json
## at once, so the next write can't overwrite the only good file.
func test_save_03_corrupt_save_json_falls_back_to_tmp_and_promotes_it() -> void:
	if not require(&"m4_save"):
		return
	var good: Dictionary = QaSaveFormat.sample_payload("tmp")
	var bad: PackedByteArray = QaSaveFormat.corrupt_corpus(good)["wrong_sha256"]
	QaTemp.write(_dir.path_join("save.json"), bad)
	QaTemp.write(_dir.path_join("save.tmp"), QaSaveFormat.encode(good))
	var report: SaveLoadReport = _store(_dir).load_latest()
	check_eq(report.source, "save.tmp", "source")
	check_eq(report.payload, QaSaveFormat.stored(good), "payload")
	check_eq(QaTemp.read(_dir.path_join("save.json")), QaSaveFormat.encode(good), "save.tmp promoted to save.json")
	check(not FileAccess.file_exists(_dir.path_join("save.tmp")), "save.tmp is gone")
	_check_quarantined(_dir, report, "save.json", bad, "corrupt save.json", false)


## SAVE-06: every candidate is bad. All of them move to quarantine, unchanged, before a new
## starter begins, and the report says it was a recovery.
func test_save_06_all_candidates_bad_quarantines_every_file() -> void:
	if not require(&"m4_save"):
		return
	var corpus: Dictionary = QaSaveFormat.corrupt_corpus(QaSaveFormat.sample_payload("all"))
	var files: Dictionary = {"save.json": corpus["wrong_sha256"], "save.tmp": corpus["truncated_to_half"],
			"save.prev": corpus["binary_garbage"]}
	for file: String in files:
		QaTemp.write(_dir.path_join(file), files[file])
	var report: SaveLoadReport = _store(_dir).load_latest()
	check(not report.ok, "nothing loads")
	check(not report.first_run, "not a first run")
	check_eq(report.recovered_from, "quarantine", "recovered_from")
	check_eq(report.quarantined.size(), 3, "files quarantined")
	for file: String in files:
		_check_quarantined(_dir, report, file, files[file], "all bad")


## SAVE-06: six failures in a row leave exactly the newest 5 quarantine sets.
func test_save_06_quarantine_keeps_the_newest_5_sets() -> void:
	if not require(&"m4_save"):
		return
	for attempt: int in 6:
		QaTemp.write(_dir.path_join("save.json"), ("broken round %d" % attempt).to_utf8_buffer())
		_store(_dir).load_latest()
		_clock.advance(1)
	var stamps: Dictionary = {}
	var kept: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(_dir.path_join("quarantine")):
		stamps[file.get_slice("_", 0)] = true
		kept.append(QaTemp.read(_dir.path_join("quarantine").path_join(file)).get_string_from_utf8())
	check_eq(stamps.size(), 5, "quarantine sets kept")
	check(not kept.has("broken round 0"), "the oldest set was dropped")
	check(kept.has("broken round 5"), "the newest set was kept")


## SAVE-08: killed at each fault point while saving C over B (with A in save.prev). The next
## launch loads exactly B or exactly C, never a mix and never a new starter. After
## after_rename, save.tmp (C) wins and becomes save.json at once.
func test_save_08_kill_at_each_fault_point() -> void:
	if not require(&"m4_save"):
		return
	var a: Dictionary = QaSaveFormat.sample_payload("A")
	var b: Dictionary = QaSaveFormat.sample_payload("B")
	var c: Dictionary = QaSaveFormat.sample_payload("C")
	var expected: Dictionary = {&"before_tmp_write": b, &"mid_tmp_write": b, &"before_rename": b, &"after_rename": c}
	for point: StringName in expected:
		var dir: String = _dir.path_join(point)
		DirAccess.make_dir_recursive_absolute(dir)
		var store: SaveStore = _store(dir)
		check_eq(store.save(a), OK, "%s: save A" % point)
		check_eq(store.save(b), OK, "%s: save B" % point)
		store.fault_point = point
		check_ne(store.save(c), OK, "%s: the killed save reports failure" % point)
		var relaunched: SaveStore = _store(dir)
		var report: SaveLoadReport = relaunched.load_latest()
		check(report.ok, "%s: something loads" % point)
		check_eq(report.payload, QaSaveFormat.stored(expected[point]), "%s: loads exactly the %s state" % [point, "new" if expected[point] == c else "old"])
		if point == &"after_rename":
			check_eq(QaTemp.read(dir.path_join("save.json")), QaSaveFormat.encode(c), "after_rename: save.json now holds C")
			check(not FileAccess.file_exists(dir.path_join("save.tmp")), "after_rename: save.tmp promoted")
			check_eq(QaTemp.read(dir.path_join("save.prev")), QaSaveFormat.encode(b), "after_rename: save.prev holds B")
		var d: Dictionary = QaSaveFormat.sample_payload("D")
		check_eq(relaunched.save(d), OK, "%s: the next save works" % point)
		check_eq(_store(dir).load_latest().payload, QaSaveFormat.stored(d), "%s: and loads" % point)


## SAVE-09: a write error (here save.tmp can't be opened) leaves the old files unchanged and
## reports the error. The next attempt, once the problem is gone, succeeds.
func test_save_09_write_error_keeps_the_old_files() -> void:
	if not require(&"m4_save"):
		return
	var a: Dictionary = QaSaveFormat.sample_payload("A")
	var store: SaveStore = _store(_dir)
	check_eq(store.save(a), OK, "save A")
	DirAccess.make_dir_absolute(_dir.path_join("save.tmp"))  # a folder where the file must go
	check_ne(store.save(QaSaveFormat.sample_payload("B")), OK, "save B fails")
	check_eq(QaTemp.read(_dir.path_join("save.json")), QaSaveFormat.encode(a), "save.json still holds A")
	DirAccess.remove_absolute(_dir.path_join("save.tmp"))
	var c: Dictionary = QaSaveFormat.sample_payload("C")
	check_eq(store.save(c), OK, "the retry works")
	check_eq(_store(_dir).load_latest().payload, QaSaveFormat.stored(c), "and loads")


## SAVE-10: a save from a newer app version is never overwritten. It moves to quarantine, the
## next candidate loads, and later saves leave the quarantined copy alone.
func test_save_10_newer_version_is_quarantined_and_kept() -> void:
	if not require(&"m4_save"):
		return
	var newer: PackedByteArray = QaSaveFormat.encode(QaSaveFormat.sample_payload("v2"), 2)
	var b: Dictionary = QaSaveFormat.sample_payload("B")
	QaTemp.write(_dir.path_join("save.json"), newer)
	QaTemp.write(_dir.path_join("save.prev"), QaSaveFormat.encode(b))
	var store: SaveStore = _store(_dir)
	var report: SaveLoadReport = store.load_latest()
	check_eq(report.payload, QaSaveFormat.stored(b), "save.prev loads")
	_check_quarantined(_dir, report, "save.json", newer, "version 2")
	check_eq(store.save(QaSaveFormat.sample_payload("C")), OK, "save C")
	check_eq(QaTemp.read(_dir.path_join(report.quarantined[0])), newer, "the version 2 file is untouched")


## SAVE-17: an untrusted save.json (one that failed to load, or was never loaded) is never
## rotated into save.prev, so it can't push out the last good file.
func test_save_17_untrusted_save_json_never_becomes_save_prev() -> void:
	if not require(&"m4_save"):
		return
	var b: Dictionary = QaSaveFormat.sample_payload("B")
	var bad: PackedByteArray = QaSaveFormat.corrupt_corpus(b)["wrong_sha256"]
	# Never loaded this session: save() must not trust the existing save.json.
	QaTemp.write(_dir.path_join("save.json"), bad)
	QaTemp.write(_dir.path_join("save.prev"), QaSaveFormat.encode(b))
	check_eq(_store(_dir).save(QaSaveFormat.sample_payload("C")), OK, "save C")
	check_eq(QaTemp.read(_dir.path_join("save.prev")), QaSaveFormat.encode(b), "save.prev still holds B")
	# The plan's sequence: load from prev, save, then the new save.json goes bad too.
	var store: SaveStore = _store(_dir)
	QaTemp.write(_dir.path_join("save.json"), bad)
	check_eq(store.load_latest().payload, QaSaveFormat.stored(b), "loads B from save.prev")
	check_eq(store.save(QaSaveFormat.sample_payload("D")), OK, "save D")
	QaTemp.write(_dir.path_join("save.json"), bad)
	var report: SaveLoadReport = _store(_dir).load_latest()
	check(report.ok, "a good file still loads")
	check_eq(report.payload, QaSaveFormat.stored(b), "and it is B, the last good save.prev")


## Normal rotation: each save moves the previous good save.json to save.prev.
func test_save_rotation_keeps_the_previous_save() -> void:
	if not require(&"m4_save"):
		return
	var store: SaveStore = _store(_dir)
	var payloads: Array[Dictionary] = [QaSaveFormat.sample_payload("A"), QaSaveFormat.sample_payload("B"),
			QaSaveFormat.sample_payload("C")]
	for i: int in payloads.size():
		check_eq(store.save(payloads[i]), OK, "save %d" % i)
		check_eq(QaTemp.read(_dir.path_join("save.json")), QaSaveFormat.encode(payloads[i]), "save.json after save %d" % i)
		if i > 0:
			check_eq(QaTemp.read(_dir.path_join("save.prev")), QaSaveFormat.encode(payloads[i - 1]), "save.prev after save %d" % i)


## data-models §9.5: load_from_path accepts a full file or a bare payload, and returns {} on
## anything else, silently.
func test_load_from_path_accepts_full_and_bare_files() -> void:
	if not require(&"m4_save"):
		return
	var p: Dictionary = QaSaveFormat.sample_payload("fixture")
	QaTemp.write(_dir.path_join("full.json"), QaSaveFormat.encode(p))
	QaTemp.write(_dir.path_join("bare.json"), QaSaveFormat.payload_text(p).to_utf8_buffer())
	var store: SaveStore = _store(_dir)
	check_eq(store.load_from_path(_dir.path_join("full.json")), QaSaveFormat.stored(p), "full file")
	check_eq(store.load_from_path(_dir.path_join("bare.json")), p, "bare payload")
	check_eq(store.load_from_path(_dir.path_join("missing.json")), {}, "missing file")
	QaTemp.write(_dir.path_join("garbage.json"), QaSaveFormat.corrupt_corpus(p)["binary_garbage"])
	check_eq(store.load_from_path(_dir.path_join("garbage.json")), {}, "garbage")


# ------------------------------------------------------------------ helpers

func _store(dir: String) -> SaveStore:
	var store: SaveStore = SaveStore.new(dir)
	store.clock = _clock
	return store


## `expect_gone`: false when another file has legitimately taken `file`'s name since (a promoted
## save.tmp becomes save.json).
func _check_quarantined(dir: String, report: SaveLoadReport, file: String, original: PackedByteArray,
		label: String, expect_gone: bool = true) -> void:
	if expect_gone:
		check(not FileAccess.file_exists(dir.path_join(file)), "%s: %s left the save folder" % [label, file])
	var found: String = ""
	for rel: String in report.quarantined:
		if rel.ends_with("_" + file):
			found = rel
	if check(not found.is_empty(), "%s: %s listed as quarantined in %s" % [label, file, str(report.quarantined)]):
		check(found.begins_with("quarantine/"), "%s: quarantine path %s" % [label, found])
		check_eq(QaTemp.read(dir.path_join(found)), original, "%s: quarantined %s is byte-identical" % [label, file])
