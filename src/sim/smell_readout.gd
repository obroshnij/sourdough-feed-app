class_name SmellReadout
extends RefCounted
## The result of a smell (data-models.md §8, spec §13). Deterministic: the same state gives the same smell.

## Descriptor id, or &"" when nothing reaches 0.15.
var primary: StringName = &""
## 0 to 2 more descriptors, strongest first.
var secondary: Array[StringName] = []
## &"faint", &"clear" or &"strong", for the primary.
var intensity: StringName = &""
## 0..1, not shown.
var intensity_value: float = 0.0
## True when musty is listed (it is then always first).
var is_warning: bool = false
## tr key of the primary's meaning line.
var meaning_key: StringName = &""
## Every descriptor's intensity after cold damping, for tests and the journal.
var intensities: Dictionary[StringName, float] = {}
