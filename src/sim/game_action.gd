class_name GameAction
extends RefCounted
## Base of every player act (data-models.md §4). UI builds one and hands it to `Session.apply()`.
## `at_unix` is set by Session, never by UI. `validate` returns &"" when ok, else a reason key.

## Reason keys (tr keys, UPPER_SNAKE). MOLD_FEED_BLOCKED is narrative's; the others are placeholders
## that T1 adds to src/i18n/pending_core.csv.
const REASON_MOLDY: StringName = &"MOLD_FEED_BLOCKED"
const REASON_MOLDY_LOCKED: StringName = &"REASON_MOLDY_LOCKED"
const REASON_KEEP_RANGE: StringName = &"REASON_KEEP_RANGE"
const REASON_FLOUR: StringName = &"REASON_FLOUR"
const REASON_WATER: StringName = &"REASON_WATER"
const REASON_MASS: StringName = &"REASON_MASS"
const REASON_HOOCH_CHOICE: StringName = &"REASON_HOOCH_CHOICE"
const REASON_ENVIRONMENT: StringName = &"REASON_ENVIRONMENT"
const REASON_INSPECT_KIND: StringName = &"REASON_INSPECT_KIND"
const REASON_NAME: StringName = &"REASON_NAME"
const REASON_EVENT: StringName = &"REASON_EVENT"
const REASON_NOT_MOLDY: StringName = &"REASON_NOT_MOLDY"

const NAME_MAX_CHARS: int = 24

var kind: StringName = &""
var at_unix: int = 0


func validate(_state: StarterState, _env: EnvironmentState, _catalog: SimCatalog) -> StringName:
	return &""


## Facts for the journal entry's `data`.
func to_dict() -> Dictionary:
	return {"kind": String(kind), "at_unix": at_unix}


static func valid_name(text: String) -> bool:
	var n: int = text.strip_edges().length()
	return n >= 1 and n <= NAME_MAX_CHARS
