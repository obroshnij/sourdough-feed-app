class_name FlourProfile
extends Resource
## One flour (data-models.md §3, spec §4). The sim reads its numbers from SimConstants.FLOURS (the spec
## table, mirrored from the reference model); these fields mirror them for tools and tests, plus the
## look that VisualMapper needs. A unit test asserts the two agree.

@export var id: StringName = &""
@export var speed_mult: float = 1.0
@export var acid_mult: float = 1.0
@export var water_absorption: float = 1.0
## Spec §4 `retain`: how well the paste holds gas. Not in data-models v0; added from the spec.
@export var gas_retention: float = 1.0
@export var food_value: float = 1.0
@export var tint: Color = Color(1.0, 1.0, 1.0)
## 0..1 bran flecks (art-direction §6: 0.6 whole_wheat, 0.35 rye).
@export var fleck: float = 0.0
