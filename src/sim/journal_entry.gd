class_name JournalEntry
extends RefCounted
## One journal line (data-models.md §6). The journal outlives a starter (memorial, then a new one).

const CAP: int = 400
const KINDS: Array[StringName] = [
	&"feed", &"environment", &"smell", &"inspect", &"event", &"state_change", &"milestone", &"rename", &"memorial",
]

var uid: int = 0
var starter_id: String = ""
## Real time of the act, not grid time.
var at_unix: int = 0
var kind: StringName = &"feed"
var state_id: StringName = &""
var text_key: StringName = &""
## Primitives the UI formats into the translated text.
var args: Dictionary = {}
## Facts, for example a feed's grams, ratio and hydration.
var data: Dictionary = {}


## Appends and trims to `cap`: the oldest state_change first, then the oldest inspect or smell, then the
## oldest of any other kind. memorial and milestone entries are never dropped.
static func append_capped(list: Array[JournalEntry], entry: JournalEntry, cap: int = CAP) -> void:
	list.append(entry)
	while list.size() > cap:
		var drop: int = _first_index(list, [&"state_change"])
		if drop < 0:
			drop = _first_index(list, [&"inspect", &"smell"])
		if drop < 0:
			drop = _first_index(list, [&"feed", &"environment", &"event", &"rename"])
		if drop < 0:
			return
		list.remove_at(drop)


static func _first_index(list: Array[JournalEntry], kinds: Array[StringName]) -> int:
	for i: int in list.size():
		if kinds.has(list[i].kind):
			return i
	return -1


func to_dict() -> Dictionary:
	return {
		"uid": uid, "starter_id": starter_id, "at_unix": at_unix, "kind": String(kind),
		"state_id": String(state_id), "text_key": String(text_key), "args": args.duplicate(true),
		"data": data.duplicate(true),
	}


static func from_dict(d: Dictionary) -> JournalEntry:
	var r := DictReader.new(d)
	var e := JournalEntry.new()
	e.uid = r.integer("uid")
	e.starter_id = r.text("starter_id")
	e.at_unix = r.integer("at_unix")
	e.kind = r.id("kind")
	e.state_id = r.id("state_id")
	e.text_key = r.id("text_key")
	e.args = r.dict("args")
	e.data = r.dict("data")
	if not r.ok or not KINDS.has(e.kind):
		return null
	return e
