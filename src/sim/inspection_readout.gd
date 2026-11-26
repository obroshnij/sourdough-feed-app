class_name InspectionReadout
extends RefCounted
## The result of an inspection (data-models.md §8, spec §14).

var inspect_kind: StringName = &""
## 0..4.
var level: int = 0
## Spec §14 readout ids in display order, for example [&"doubled", &"rising", &"streak_line"].
var observations: Array[StringName] = []
## The observation line, for example INSPECT_HEIGHT_AT_PEAK_DOUBLE_OBS.
var text_key: StringName = &""
## The meaning line (fades after 3 views unless it is a warning), for example INSPECT_HEIGHT_AT_PEAK_MEAN.
## Not in data-models v0; added so the UI never builds keys itself.
var meaning_key: StringName = &""
var is_warning: bool = false
## &"bubbles", &"top", &"height", &"surface" or &"home".
var camera_target: StringName = &"home"
