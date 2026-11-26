class_name Memorial
extends RefCounted
## A starter that was lost to mold (data-models.md §6, D-002). Saved list, never trimmed.

var starter_id: String = ""
var name: String = ""
var born_unix: int = 0
var ended_unix: int = 0
var feeds_count: int = 0
## &"mold" is the only cause.
var cause: StringName = &"mold"


func to_dict() -> Dictionary:
	return {
		"starter_id": starter_id, "name": name, "born_unix": born_unix, "ended_unix": ended_unix,
		"feeds_count": feeds_count, "cause": String(cause),
	}


static func from_dict(d: Dictionary) -> Memorial:
	var r := DictReader.new(d)
	var m := Memorial.new()
	m.starter_id = r.text("starter_id")
	m.name = r.text("name")
	m.born_unix = r.integer("born_unix")
	m.ended_unix = r.integer("ended_unix")
	m.feeds_count = r.integer("feeds_count")
	m.cause = r.id("cause")
	return m if r.ok else null
