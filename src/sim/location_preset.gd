class_name LocationPreset
extends Resource
## One place the jar can sit (data-models.md §3, spec §2.2, D-018). Humidity is fixed, not a control.

@export var id: StringName = &""
@export var temperature_c: float = 22.0
@export var temperature_min_c: float = 22.0
@export var temperature_max_c: float = 22.0
@export var humidity_pct: float = 50.0
