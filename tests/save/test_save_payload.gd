extends TestCase
## The save payload through the real Session (test-plan SAVE-01, OD-18, data-models §1 and §9.2).
## Every float is stored as a 16-char hex string, so a reload is bit-exact and the determinism
## properties stay exact with no tolerance. Waits for T1 milestones m4_save and m5_catchup.

const T := 1795651200  # on the 60 s grid

var _dir: String = ""
var _sessions: Array[GameSession] = []


func before_each() -> void:
	_dir = QaTemp.make("save_payload")
	_sessions.clear()


func after_each() -> void:
	for s: GameSession in _sessions:
		if is_instance_valid(s):
			s.free()
	_sessions.clear()
	QaTemp.remove(_dir)


## SAVE-01: relaunching at the same moment gives back exactly the state that was saved, after
## 5 h of play so the floats are far from round numbers.
func test_save_01_reload_is_bit_exact() -> void:
	if not _ready_for_sessions():
		return
	var clock: FakeClock = FakeClock.new(T)
	var first: GameSession = _launch(clock)
	for minute: int in 300:
		clock.advance(60)
		first.tick()
	first.on_background()
	var before: Dictionary = first.build_payload()
	var again: GameSession = _launch(clock)
	var after: Dictionary = again.build_payload()
	check_eq(again.get_last_catch_up().steps, 0, "nothing simulated at the same moment")
	for section: String in ["starter", "environment", "history", "rng", "events"]:
		check_eq(after.get(section), before.get(section), section + " after a reload")


## data-models §9.2: only ints and strings are JSON numbers and text, so the stored payload has
## no number with a decimal point or an exponent anywhere (strings are skipped).
func test_stored_payload_has_no_decimal_numbers() -> void:
	if not _ready_for_sessions():
		return
	var clock: FakeClock = FakeClock.new(T)
	var s: GameSession = _launch(clock)
	for minute: int in 90:
		clock.advance(60)
		s.tick()
	s.on_background()
	var bytes: PackedByteArray = QaTemp.read(_dir.path_join("save.json"))
	var text: String = bytes.slice(bytes.find(10) + 1).get_string_from_utf8()
	var hits: PackedStringArray = decimal_numbers_outside_strings(text)
	check(hits.is_empty(), "floats stored as JSON numbers (%d), first: %s" % [hits.size(), ", ".join(hits.slice(0, 5))])
	check(text.contains("\"starter\""), "the payload has a starter section")


## Number tokens with "." or an exponent that sit outside JSON strings, with a little context.
static func decimal_numbers_outside_strings(json_text: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var in_string: bool = false
	var i: int = 0
	var n: int = json_text.length()
	while i < n:
		var c: String = json_text[i]
		if in_string:
			if c == "\\":
				i += 2
				continue
			if c == "\"":
				in_string = false
			i += 1
			continue
		if c == "\"":
			in_string = true
			i += 1
			continue
		if c == "-" or c.is_valid_int():
			var start: int = i
			while i < n and "-+0123456789.eE".contains(json_text[i]):
				i += 1
			var token: String = json_text.substr(start, i - start)
			if token.contains(".") or token.contains("e") or token.contains("E"):
				out.append(json_text.substr(maxi(0, start - 24), i - maxi(0, start - 24)))
			continue
		i += 1
	return out


func _ready_for_sessions() -> bool:
	return require(&"m4_save") and require(&"m5_catchup")


func _launch(clock: FakeClock) -> GameSession:
	var s: GameSession = GameSession.new()
	_sessions.append(s)
	s.setup(clock, SaveStore.new(_dir))
	s.boot()
	return s
