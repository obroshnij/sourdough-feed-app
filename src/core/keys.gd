class_name Keys
extends RefCounted
## Builds tr keys from canonical ids (architecture.md §10), so the uppercase mapping lives in one place.
## Patterns follow the generated src/i18n/en.csv.


static func up(id: StringName) -> String:
	return String(id).to_upper()


## STATUS_<STATE>_<PART>, with dormant split by cause: STATUS_DORMANT_COLD_WORD.
static func status(state_id: StringName, part: String, dormant_cause: StringName = &"") -> StringName:
	var mid: String = up(state_id)
	if state_id == &"dormant":
		mid += "_" + up(dormant_cause if dormant_cause != &"" else &"starved")
	return StringName("STATUS_%s_%s" % [mid, part])


static func status_word(state_id: StringName, dormant_cause: StringName = &"") -> StringName:
	return status(state_id, "WORD", dormant_cause)


static func status_hint(state_id: StringName, dormant_cause: StringName = &"") -> StringName:
	return status(state_id, "HINT", dormant_cause)


static func status_tap(state_id: StringName, dormant_cause: StringName = &"") -> StringName:
	return status(state_id, "TAP", dormant_cause)


## SMELL_<DESCRIPTOR>_<PART>: TITLE, MEANING, NOTE, or a variant number 1 to 3.
static func smell(descriptor: StringName, part: String) -> StringName:
	return StringName("SMELL_%s_%s" % [up(descriptor), part])


## Args that hold a Unix time and the placeholder they fill (game-copy §1.3). Times show as a local clock
## time ("11:30 PM"), dates as a local date ("Nov 26, 2026"), both built from tr keys.
const TIME_ARGS: Dictionary = {"time_unix": "time"}
const DATE_ARGS: Dictionary = {"start_unix": "start_date", "end_unix": "end_date"}


## The display text for a key with args, such as a JournalEntry's text_key and args. An arg whose value is
## itself a key (UPPER_SNAKE, like "FLOUR_WHOLE_WHEAT" or "SMELL_YOGURT_TITLE") is translated first, so the
## save stores keys, never text in one language (game-copy §1.3, §11). Time args (TIME_ARGS, DATE_ARGS)
## are formatted in local time `utc_offset_s` seconds ahead of UTC (Session.format_text() passes the
## device's offset).
static func format(text_key: StringName, args: Dictionary, utc_offset_s: int = 0) -> String:
	var resolved: Dictionary = {}
	var key_shape := RegEx.create_from_string("^[A-Z][A-Z0-9_]*$")
	for k: Variant in args:
		var v: Variant = args[k]
		var arg_name: String = str(k)
		if TIME_ARGS.has(arg_name) and _is_number(v):
			resolved[TIME_ARGS[arg_name]] = format_time(int(DictReader.float_of(v)), utc_offset_s)
		elif DATE_ARGS.has(arg_name) and _is_number(v):
			resolved[DATE_ARGS[arg_name]] = format_date(int(DictReader.float_of(v)), utc_offset_s)
		if typeof(v) == TYPE_STRING and key_shape.search(String(v)) != null:
			resolved[k] = TranslationServer.translate(StringName(String(v)))
		else:
			resolved[k] = v
	return String(TranslationServer.translate(text_key)).format(resolved)


## A local clock time, "11:30 PM" ({time}, game-copy §1.3). The words are tr keys (TIME_AM, TIME_PM). The
## pattern is the US English one; a localized pattern needs new placeholders in narrative's copy checker
## (an open decision), so it stays in code for the English-only MVP (D-003).
static func format_time(unix: int, utc_offset_s: int) -> String:
	var minute_of_day: int = LocalDay.minute_of_day(unix, utc_offset_s)
	@warning_ignore("integer_division")
	var hour: int = minute_of_day / 60
	var hour12: int = hour % 12
	if hour12 == 0:
		hour12 = 12
	var period: StringName = &"TIME_AM" if hour < 12 else &"TIME_PM"
	return "%d:%02d %s" % [hour12, minute_of_day % 60, TranslationServer.translate(period)]


## A local date, "Nov 26, 2026" ({start_date}, {end_date}). Month names are tr keys MONTH_SHORT_01 to _12;
## the pattern is US English, like format_time().
static func format_date(unix: int, utc_offset_s: int) -> String:
	var t: int = unix + utc_offset_s
	@warning_ignore("integer_division")
	var days: int = (t - posmod(t, 86400)) / 86400
	var ymd: Vector3i = LocalDay.civil_from_days(days)
	var month: String = String(TranslationServer.translate(StringName("MONTH_SHORT_%02d" % ymd.y)))
	return "%s %d, %d" % [month, ymd.z, ymd.x]


## NAME_SUGGEST_01 to _24 (narrative §6.1): index (starter_seed + presses) % 24, plus 1.
static func name_suggestion(starter_seed: int, presses: int) -> StringName:
	return StringName("NAME_SUGGEST_%02d" % (1 + posmod(starter_seed + presses, 24)))


static func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


static func location(location_id: StringName) -> StringName:
	return StringName("LOC_%s" % up(location_id))


static func flour(flour_id: StringName) -> StringName:
	return StringName("FLOUR_%s" % up(flour_id))
