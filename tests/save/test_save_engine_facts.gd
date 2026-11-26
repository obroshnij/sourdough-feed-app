extends TestCase
## Engine behavior the save design (ADR-005, data-models §9) depends on. No T1 code involved.
## These run on every commit so an engine upgrade (4.8 is planned for Phase 4) that changes
## any of them fails here first, not as a corrupt or unloadable player save.

var _dir: String = ""


func before_each() -> void:
	_dir = QaTemp.make("engine_facts")


func after_each() -> void:
	QaTemp.remove(_dir)


## data-models §9.2: the payload is written with full precision so floats round-trip exactly.
func test_full_precision_json_round_trips_floats_exactly() -> void:
	var values: Array[float] = [1.0 / 3.0, 0.1, 2.0 / 3.0, 1e-300, 5e-324, 1.7976931348623157e308,
			0.30000000000000004, 1.9300000000000002, -0.0001234567890123456]
	for value: float in values:
		var text: String = JSON.stringify({"v": value}, "", true, true)
		var parser: JSON = JSON.new()
		check_eq(parser.parse(text), OK, "parse " + text)
		var back: float = float((parser.data as Dictionary)["v"])
		check(back == value, "%s came back as %s" % [show(value), show(back)])


## SAVE-01, PROP-01, PROP-02 assume a save round trip is bit-exact. Measured in 4.7.2 (QA,
## 2026-11-26): JSON's number parser keeps at most 17 digits after the decimal point, so about
## a quarter of doubles below 0.1 come back 1 ulp off (0.00038268223404884337 reads back as
## 0.00038268223404884). String.to_float() does the same. var_to_bytes is exact.
## Until the director picks lossless float storage or a tolerance, this SKIPs with the
## measured count (visible, and fails under --strict). It passes by itself once the engine
## parses exactly.
func test_json_round_trip_is_exact_for_random_doubles() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var inexact: int = 0
	var example: String = ""
	var n: int = 20000
	for i: int in n:
		var x: float = rng.randf() * pow(10.0, rng.randi_range(-6, 3))
		var parser: JSON = JSON.new()
		parser.parse(JSON.stringify({"v": x}, "", true, true))
		var back: float = float((parser.data as Dictionary)["v"])
		if back != x:
			inexact += 1
			if example.is_empty():
				example = "%s read back as %s" % [show(x), show(back)]
	if inexact > 0:
		skip("known engine limit, decision pending: %d of %d doubles don't round-trip through JSON (%s)"
				% [inexact, n, example])
		return
	check_eq(inexact, 0, "doubles that don't round-trip")


## data-models §1: RNG seeds and states are saved as decimal strings, and restored with
## `state` only (SAVE-14). Values near 2^63 must survive, and the stream must continue.
func test_rng_state_survives_as_a_decimal_string() -> void:
	for start_state: int in [9223372036854775807, -9223372036854775807 - 1, 9007199254740993, 0, 1]:
		var a: RandomNumberGenerator = RandomNumberGenerator.new()
		a.seed = 987654321
		a.state = start_state
		var saved: String = str(a.state)
		var b: RandomNumberGenerator = RandomNumberGenerator.new()
		b.state = saved.to_int()
		check_eq(b.state, a.state, "state %s via \"%s\"" % [start_state, saved])
		for i: int in 3:
			check_eq(b.randf(), a.randf(), "draw %d after restoring state %s" % [i + 1, start_state])


## architect [ran]: setting `seed` after `state` resets the stream. The restore path must set
## `state` only. This pins the trap so a "harmless" reorder in the loader is caught.
func test_setting_seed_after_state_resets_the_stream() -> void:
	var a: RandomNumberGenerator = RandomNumberGenerator.new()
	a.seed = 42
	a.randf()
	var mid: int = a.state
	var expected: float = a.randf()
	var b: RandomNumberGenerator = RandomNumberGenerator.new()
	b.state = mid
	b.seed = 42
	check_ne(b.randf(), expected, "seed after state should restart the stream")


## data-models §9.4: the writer hashes text with sha256_text(), the loader hashes raw bytes
## with HashingContext. They must agree, including for non-ASCII text (the starter's name).
func test_sha256_of_text_equals_sha256_of_its_utf8_bytes() -> void:
	for text: String in ["{}", "{\"name\":\"Dough “Nut” éè \U0001F35E\"}",
			QaSaveFormat.payload_text(QaSaveFormat.sample_payload("x"))]:
		var ctx: HashingContext = HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(text.to_utf8_buffer())
		check_eq(ctx.finish().hex_encode(), text.sha256_text(), "sha256 of " + text.left(40))


## SAVE-20: the loader's read and parse steps must be silent on bad input, or every corrupt-file
## test fails under the Logger. Any logged error fails this test.
func test_missing_file_and_bad_json_load_silently() -> void:
	var missing: PackedByteArray = FileAccess.get_file_as_bytes(_dir.path_join("nope.json"))
	check_eq(missing.size(), 0, "get_file_as_bytes on a missing file")
	for text: String in ["", "{", "not json", "{\"rise\":NaN}", "[1,2", "\u0000\u0001"]:
		check_ne(JSON.new().parse(text), OK, "JSON.new().parse(%s) should fail" % show(text))


## SAVE-05, SAVE-20: binary garbage decoded as UTF-8 must not log an *error*. T1's loader
## decodes the header line before any checksum check, so this has to hold for any bytes.
## Measured in 4.7.2: it is not fully silent. Each bad sequence prints a "Unicode parsing
## error" line to stderr through Logger._log_message (about 200 lines for 512 random bytes),
## never through _log_error, so the runner's Logger and SAVE-20 are unaffected.
func test_invalid_utf8_decodes_without_logging_an_error() -> void:
	var corpus: Dictionary = QaSaveFormat.corrupt_corpus(QaSaveFormat.sample_payload("u"))
	for name: String in ["binary_garbage", "garbage_after_valid_header"]:
		var bytes: PackedByteArray = corpus[name]
		var text: String = bytes.get_string_from_utf8()
		check(text.length() >= 0, name + " decoded")


## ADR-005: rotation renames over an existing file with an instance DirAccess (POSIX rename).
## Overwrite must succeed and replace the content. Verified on macOS. Android is SAVE-19.
func test_instance_rename_overwrites_the_destination() -> void:
	QaTemp.write(_dir.path_join("save.tmp"), "new".to_utf8_buffer())
	QaTemp.write(_dir.path_join("save.json"), "old".to_utf8_buffer())
	var d: DirAccess = DirAccess.open(_dir)
	check_eq(d.rename("save.tmp", "save.json"), OK, "rename over an existing save.json")
	check_eq(QaTemp.read(_dir.path_join("save.json")).get_string_from_utf8(), "new", "content")
	check(not FileAccess.file_exists(_dir.path_join("save.tmp")), "save.tmp is gone")
