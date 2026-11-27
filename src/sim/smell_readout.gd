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
## Phase 4 (spec v1.1 §13.1): &"musty", &"faint" or &"". When not empty, the smell card offers "Try inspecting
## the surface" (SMELL_TRY_INSPECT_BTN, which opens the surface inspection). Only &"faint" shows the "Hard to
## say" line (SMELL_TRY_INSPECT); musty keeps its warning meaning instead.
var check: StringName = &""
## With check &"faint": &"cold" (ferm(temp_c) < 0.30, a fridge-cold jar) or &"mild". Else &"".
var faint_cause: StringName = &""
