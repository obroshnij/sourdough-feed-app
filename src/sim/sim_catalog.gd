class_name SimCatalog
extends RefCounted
## Profiles by id (data-models.md §3). Session builds it once and passes it in; the sim never loads files.
## `builtin()` builds the catalog in code from SimConstants, so tests and the sim need no files.

## art-direction §20.2 (Phase 4, art-director, directions checked by the scientist): sRGB tints that read
## apart once lit, bran flecks, and per-flour dome and bubble-size factors. VisualMapper blends all of them by
## flour_mix, so a mix sits between its flours.
const TINTS: Dictionary = {
	&"white_bread": Color(0.961, 0.922, 0.839),
	&"whole_wheat": Color(0.847, 0.741, 0.596),
	&"rye": Color(0.667, 0.576, 0.475),
	&"spelt": Color(0.937, 0.863, 0.675),
}
const FLECKS: Dictionary = {&"white_bread": 0.0, &"whole_wheat": 0.6, &"rye": 0.3, &"spelt": 0.15}
## How high the dome stands (spec §4: whole grain and spelt lower, rye barely domes).
const DOME_K: Dictionary = {&"white_bread": 1.0, &"whole_wheat": 0.7, &"rye": 0.3, &"spelt": 0.7}
## Bubble size (rye holds gas poorly, so smaller, spec §4).
const SIZE_K: Dictionary = {&"white_bread": 1.0, &"whole_wheat": 0.9, &"rye": 0.75, &"spelt": 1.0}
const _COVER_NODES: Dictionary = {
	&"loose_lid": &"Jar_Lid_Loose", &"tight_lid": &"Jar_Lid_Tight", &"cloth": &"Cloth_Cover",
}

var flours: Dictionary[StringName, FlourProfile] = {}
var locations: Dictionary[StringName, LocationPreset] = {}
var containers: Dictionary[StringName, ContainerProfile] = {}
var covers: Dictionary[StringName, CoverProfile] = {}


static func builtin() -> SimCatalog:
	var c := SimCatalog.new()
	for id: StringName in SimConstants.FLOUR_IDS:
		var row: Array = SimConstants.FLOURS[id]
		var f := FlourProfile.new()
		f.id = id
		f.speed_mult = row[0]
		f.acid_mult = row[1]
		f.water_absorption = row[2]
		f.gas_retention = row[3]
		f.tint = TINTS[id]
		f.fleck = FLECKS[id]
		c.flours[id] = f
	for id: StringName in SimConstants.LOCATION_IDS:
		var row: Array = SimConstants.LOCATIONS[id]
		var l := LocationPreset.new()
		l.id = id
		l.temperature_c = row[0]
		l.humidity_pct = row[1]
		l.temperature_min_c = row[2]
		l.temperature_max_c = row[3]
		c.locations[id] = l
	for id: StringName in SimConstants.CONTAINER_IDS:
		var k := ContainerProfile.new()
		k.id = id
		k.dryness_mult = SimConstants.CONTAINER_DRY[id]
		if id == &"classic_jar":
			k.scene_path = "res://assets/3d/jar_v0.glb"
		c.containers[id] = k
	for id: StringName in SimConstants.COVER_IDS:
		var v := CoverProfile.new()
		v.id = id
		v.dryness_mult = SimConstants.COVER_DRY[id]
		v.node_name = _COVER_NODES[id]
		c.covers[id] = v
	return c
