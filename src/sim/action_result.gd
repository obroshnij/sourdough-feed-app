class_name ActionResult
extends RefCounted
## What `Session.apply()` returns and `action_applied` carries (data-models.md §4).

var ok: bool = false
## &"" when ok, else a tr key.
var reason_key: StringName = &""
var action_kind: StringName = &""
## A SmellReadout, an InspectionReadout or null.
var readout: RefCounted = null
var events: Array[SimEvent] = []
## Null when rejected, or when a smell or inspect was deduped (game-mechanics §4).
var journal_entry: JournalEntry = null


static func rejected(kind: StringName, key: StringName) -> ActionResult:
	var r := ActionResult.new()
	r.ok = false
	r.action_kind = kind
	r.reason_key = key
	return r


static func accepted(kind: StringName) -> ActionResult:
	var r := ActionResult.new()
	r.ok = true
	r.action_kind = kind
	return r
