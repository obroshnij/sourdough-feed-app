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


static func location(location_id: StringName) -> StringName:
	return StringName("LOC_%s" % up(location_id))


static func flour(flour_id: StringName) -> StringName:
	return StringName("FLOUR_%s" % up(flour_id))
