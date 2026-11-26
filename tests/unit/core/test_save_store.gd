extends CoreCase
## SaveStore, SaveCodec and migrations (data-models.md §9, D-024; test-plan SAVE-02 to SAVE-10, SAVE-17, SAVE-20).
## Every corrupt case must load silently: the runner fails any test that logs an engine error. Owner: T1.


func _payload(n: int) -> Dictionary:
	return {"meta": {"save_count": n}, "starter": {"rise": 1.0 / 3.0, "n": n, "name": "Dough \"Nut\""}}


func _n(p: Dictionary) -> int:
	var starter: Dictionary = p.get("starter", {})
	return int(starter.get("n", -1))


func test_round_trip_and_header() -> void:
	if not require(&"m4_save"):
		return
	var d: String = fresh_dir("roundtrip")
	var store := SaveStore.new(d)
	check_eq(store.save(_payload(1)), OK, "save")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(d + "/save.json")
	var nl: int = bytes.find(10)
	var header: Dictionary = JSON.parse_string(bytes.slice(0, nl).get_string_from_utf8())
	var body: String = bytes.slice(nl + 1).get_string_from_utf8()
	check_eq(header.get("format"), "sourdough.save", "SAVE-02 format")
	check_eq(header.get("version"), 1, "SAVE-02 version")
	check_eq(header.get("bytes"), bytes.size() - nl - 1, "SAVE-02 byte count")
	check_eq(header.get("sha256"), body.sha256_text(), "SAVE-02 checksum of the stored bytes")
	check(not body.contains("\n"), "payload is one line")
	var report: SaveLoadReport = SaveStore.new(d).load_latest()
	check(report.ok and report.source == "save.json", "loads save.json")
	var starter: Dictionary = report.payload["starter"]
	check_eq(starter["rise"], DictReader.float_to_hex(1.0 / 3.0), "D-040 floats are stored as hex bits")
	check_eq(DictReader.float_of(starter["rise"]), 1.0 / 3.0, "1/3 round-trips exactly")
	check_eq(starter["name"], "Dough \"Nut\"", "strings round-trip")


func test_rotation_only_from_a_trusted_file() -> void:
	if not require(&"m4_save"):
		return
	var d: String = fresh_dir("rotation")
	var store := SaveStore.new(d)
	store.save(_payload(1))
	store.save(_payload(2))
	check_eq(_n(SaveStore.new(d).load_from_path(d + "/save.prev")), 1, "trusted save.json rotates to save.prev")
	# SAVE-17: a store that never loaded or wrote save.json must not rotate it into save.prev.
	var stranger := SaveStore.new(d)
	stranger.save(_payload(3))
	check_eq(_n(stranger.load_from_path(d + "/save.prev")), 1, "untrusted save.json is not rotated")
	check(DirAccess.get_files_at(d + "/quarantine").size() == 1, "it is quarantined instead")


func test_fault_points_leave_old_or_new() -> void:
	if not require(&"m4_save"):
		return
	for fault: StringName in SaveStore.FAULT_POINTS:
		var d: String = fresh_dir("fault_" + String(fault))
		var store := SaveStore.new(d)
		store.save(_payload(1))
		store.fault_point = fault
		check_ne(store.save(_payload(2)), OK, "%s reports failure" % fault)
		var report: SaveLoadReport = SaveStore.new(d).load_latest()
		check(report.ok, "%s: a save still loads" % fault)
		var n: int = _n(report.payload)
		check(n == 1 or n == 2, "%s: exactly the old or the new state, got %d" % [fault, n])
		if fault == &"after_rename":
			check(report.source == "save.tmp" and n == 2, "after_rename: save.tmp wins")
			check(FileAccess.file_exists(d + "/save.json") and not FileAccess.file_exists(d + "/save.tmp"), "promoted to save.json at once")


func test_corrupt_files_fall_back_and_are_quarantined() -> void:
	if not require(&"m4_save"):
		return
	var cases: Dictionary = {
		"truncated": PackedByteArray(),
		"garbage": PackedByteArray([0xFF, 0xFE, 0x00, 0x80, 0x0A, 0xC3, 0x28, 0xA0, 0xA1]),
		"array": "[1, 2, 3]".to_utf8_buffer(),
		"header_only": "{\"format\":\"sourdough.save\",\"version\":1,\"bytes\":10,\"sha256\":\"00\"}\n".to_utf8_buffer(),
		"nan": "{\"format\":\"sourdough.save\",\"version\":1,\"bytes\":3,\"sha256\":\"x\"}\nNaN".to_utf8_buffer(),
	}
	for name: String in cases:
		var d: String = fresh_dir("corrupt_" + name)
		var store := SaveStore.new(d)
		store.save(_payload(1))
		store.save(_payload(2))
		var good: PackedByteArray = FileAccess.get_file_as_bytes(d + "/save.json")
		var bad: PackedByteArray = cases[name]
		if name == "truncated":
			bad = good.slice(0, good.size() - 1)
		write_bytes(d + "/save.json", bad)
		var report: SaveLoadReport = SaveStore.new(d).load_latest()
		check(report.ok and report.source == "save.prev" and _n(report.payload) == 1, "%s: falls back to save.prev" % name)
		check_eq(report.quarantined.size(), 1, "%s: one file quarantined" % name)
		if report.quarantined.size() == 1:
			check_eq(FileAccess.get_file_as_bytes(d + "/" + report.quarantined[0]), bad, "%s: quarantined byte-identical" % name)


func test_validator_failure_counts_as_corrupt() -> void:
	if not require(&"m4_save"):
		return
	var d: String = fresh_dir("validator")
	var store := SaveStore.new(d)
	store.save(_payload(1))
	store.save(_payload(2))
	var only_one: Callable = func(p: Dictionary) -> bool: return _n(p) == 1
	var report: SaveLoadReport = SaveStore.new(d).load_latest(only_one)
	check(report.ok and report.source == "save.prev", "a payload that fails from_dict falls back")


func test_all_bad_quarantines_everything_and_keeps_five_sets() -> void:
	if not require(&"m4_save"):
		return
	var d: String = fresh_dir("allbad")
	for i: int in 6:
		for n: String in ["save.json", "save.tmp", "save.prev"]:
			write_text(d + "/" + n, "not a save %d" % i)
		var report: SaveLoadReport = SaveStore.new(d).load_latest()
		check(not report.ok and not report.first_run and report.recovered_from == "quarantine", "SAVE-06 attempt %d recovers" % i)
	var stamps: Dictionary = {}
	for f: String in DirAccess.get_files_at(d + "/quarantine"):
		stamps[f.get_slice("_", 0)] = true
	check_eq(stamps.size(), 5, "SAVE-06 six failures leave exactly 5 sets")
	check_eq(DirAccess.get_files_at(d + "/quarantine").size(), 15, "3 files per set")
	check(SaveStore.new(fresh_dir("empty")).load_latest().first_run, "SAVE-07 no files: first run")


func test_newer_version_is_quarantined() -> void:
	if not require(&"m4_save"):
		return
	var d: String = fresh_dir("newer")
	var store := SaveStore.new(d)
	store.save(_payload(1))
	store.save(_payload(2))
	var text: String = SaveCodec.payload_text(_payload(9))
	var header: String = JSON.stringify({"bytes": text.to_utf8_buffer().size(), "format": "sourdough.save",
		"sha256": text.sha256_text(), "version": 99}, "", true, true)
	write_text(d + "/save.json", header + "\n" + text)
	var report: SaveLoadReport = SaveStore.new(d).load_latest()
	check(report.ok and _n(report.payload) == 1, "SAVE-10 the next candidate loads")
	check_eq(SaveCodec.decode(FileAccess.get_file_as_bytes(d + "/" + report.quarantined[0])).reason, &"too_new", "SAVE-10 moved aside, not overwritten")


## D-040: a save round trip is lossless. Plain JSON changed about 1 in 4 of these by 1 ulp.
func test_floats_round_trip_losslessly() -> void:
	if not require(&"m4_save"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var values: Array = []
	for i: int in 100000:
		values.append(rng.randf() * pow(10.0, rng.randi_range(-6, 6)))
	values.append_array([0.0, -0.0, 1.0 / 3.0, 0.1, 1e-300, 123456789.125, -2.5])
	var dec: SaveDecoded = SaveCodec.decode(SaveCodec.encode({"v": values}))
	check(dec.ok, "decodes")
	var back: Array = dec.payload.get("v", [])
	check_eq(back.size(), values.size(), "same count")
	var changed: int = 0
	for i: int in mini(back.size(), values.size()):
		var x: float = DictReader.float_of(back[i])
		var want: float = values[i]
		if x != want or (want == 0.0 and DictReader.float_to_hex(x) != DictReader.float_to_hex(want)):
			changed += 1
	check_eq(changed, 0, "values changed by a save round trip")
	check_eq(SaveCodec.payload_text({"a": 0.25}), "{\"a\":\"000000000000d03f\"}", "the D-040 contract example")
	var fixture := DictReader.new({"x": 22.5, "y": "000000000000d03f", "z": "Dough Nut"})
	check(fixture.num("x") == 22.5 and fixture.num("y") == 0.25 and fixture.ok, "plain numbers and hex both read")
	fixture.num("z")
	check(not fixture.ok, "any other string is rejected")


func test_load_from_path_accepts_a_bare_payload() -> void:
	if not require(&"m4_save"):
		return
	var d: String = fresh_dir("bare")
	write_text(d + "/fixture.json", JSON.stringify(_payload(7)))
	check_eq(_n(SaveStore.new(d).load_from_path(d + "/fixture.json")), 7, "bare payload")
	check(SaveStore.new(d).load_from_path(d + "/missing.json").is_empty(), "missing file: {}")
	check(SaveMigrations.migrate({"a": 1}, 2).is_empty() and not SaveMigrations.migrate({"a": 1}, 1).is_empty(), "migration by version")
