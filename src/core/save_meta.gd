class_name SaveMeta
extends RefCounted
## The payload's `meta` section (data-models.md §9.6). Excluded from determinism comparisons (PROP-01).

var app_version: String = "0.2.0"
var clock_reanchors: int = 0
var created_unix: int = 0
## "" or "quarantine" (every candidate save failed and a new starter began).
var recovered_from: String = ""
var save_count: int = 0
var saved_unix: int = 0


func to_dict() -> Dictionary:
	return {
		"app_version": app_version, "clock_reanchors": clock_reanchors, "created_unix": created_unix,
		"recovered_from": recovered_from, "save_count": save_count, "saved_unix": saved_unix,
	}


static func from_dict(d: Dictionary) -> SaveMeta:
	var r := DictReader.new(d)
	var m := SaveMeta.new()
	m.app_version = r.text("app_version")
	m.clock_reanchors = r.integer("clock_reanchors")
	m.created_unix = r.integer("created_unix")
	m.recovered_from = r.text("recovered_from")
	m.save_count = r.integer("save_count")
	m.saved_unix = r.integer("saved_unix")
	return m if r.ok else null
