class_name ContainerProfile
extends Resource
## One container (data-models.md §3). MVP: classic_jar only (D-019).

@export var id: StringName = &""
@export var inner_radius_m: float = 0.0385
@export var inner_height_m: float = 0.162
@export var liner_height_m: float = 0.125
@export var scene_path: String = ""
## Spec §2.2 `container_dry`. The sim reads SimConstants.CONTAINER_DRY.
@export var dryness_mult: float = 1.0
