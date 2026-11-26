class_name CoverProfile
extends Resource
## One cover (data-models.md §3). Spec §2.2: covers change only dryness, so the v0 fields
## evaporation_mult and mold_risk_mult are dropped. MVP: loose_lid only (D-019).

@export var id: StringName = &""
## Spec §2.2 `cover_dry`. The sim reads SimConstants.COVER_DRY.
@export var dryness_mult: float = 0.35
## GLB node (art contract): loose_lid Jar_Lid_Loose, tight_lid Jar_Lid_Tight, cloth Cloth_Cover.
@export var node_name: StringName = &""
