class_name EnvironmentState
extends RefCounted
## Stored environment (data-models.md §3, spec §2.2). Humidity is a fixed property of the location (D-018).

## One of SimConstants.LOCATION_IDS, or &"" for a raw environment (trace replays, tests).
var location: StringName = &"counter"
var temperature_c: float = 22.0
var humidity_pct: float = 50.0
var container: StringName = &"classic_jar"
var cover: StringName = &"loose_lid"
var changed_unix: int = 0


## A raw environment, as the reference traces describe one (`Env(temp_c, rh, cover, container)`).
static func make(temp_c: float, rh: float, cover_id: StringName = &"loose_lid",
		container_id: StringName = &"classic_jar") -> EnvironmentState:
	var e := EnvironmentState.new()
	e.location = &""
	e.temperature_c = temp_c
	e.humidity_pct = rh
	e.cover = cover_id
	e.container = container_id
	return e


## The preset environment for a location id (spec §2.2). Unknown ids fall back to the counter.
static func at_location(location_id: StringName, changed_at_unix: int = 0,
		cover_id: StringName = &"loose_lid") -> EnvironmentState:
	var id: StringName = location_id if SimConstants.LOCATIONS.has(location_id) else &"counter"
	var row: Array = SimConstants.LOCATIONS[id]
	var e := EnvironmentState.new()
	e.location = id
	e.temperature_c = row[0]
	e.humidity_pct = row[1]
	e.cover = cover_id
	e.changed_unix = changed_at_unix
	return e


func copy() -> EnvironmentState:
	var e := EnvironmentState.new()
	e.location = location
	e.temperature_c = temperature_c
	e.humidity_pct = humidity_pct
	e.container = container
	e.cover = cover
	e.changed_unix = changed_unix
	return e


func to_dict() -> Dictionary:
	return {
		"location": String(location),
		"temperature_c": temperature_c,
		"humidity_pct": humidity_pct,
		"container": String(container),
		"cover": String(cover),
		"changed_unix": changed_unix,
	}


## Returns null on a missing key, a wrong type or a non-canonical cover or container id.
static func from_dict(d: Dictionary) -> EnvironmentState:
	var r := DictReader.new(d)
	var e := EnvironmentState.new()
	e.location = r.id("location")
	e.temperature_c = r.num("temperature_c")
	e.humidity_pct = r.num("humidity_pct")
	e.container = r.id("container")
	e.cover = r.id("cover")
	e.changed_unix = r.integer("changed_unix")
	if not r.ok:
		return null
	if not SimConstants.COVER_DRY.has(e.cover) or not SimConstants.CONTAINER_DRY.has(e.container):
		return null
	if e.location != &"" and not SimConstants.LOCATIONS.has(e.location):
		return null
	return e
