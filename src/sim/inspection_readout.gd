class_name InspectionReadout
extends RefCounted
## The result of an inspection (data-models.md §8, spec §14).

var inspect_kind: StringName = &""
## 0..4.
var level: int = 0
## Spec §14 readout ids in display order, for example [&"doubled", &"rising", &"streak_line"].
var observations: Array[StringName] = []
var text_key: StringName = &""
var is_warning: bool = false
## &"bubbles", &"top", &"height", &"surface" or &"home".
var camera_target: StringName = &"home"
