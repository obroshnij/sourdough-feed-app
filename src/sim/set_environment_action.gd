class_name SetEnvironmentAction
extends GameAction
## Full replacement of the environment (data-models.md §4). Session fills humidity from the location
## preset, because humidity is not a player control (D-018).

var env: EnvironmentState = null


func _init() -> void:
	kind = &"environment"


## The usual way to build one: move to a location, optionally with a proofing-box temperature.
static func to_location(location_id: StringName, temperature_c: float = NAN) -> SetEnvironmentAction:
	var a := SetEnvironmentAction.new()
	a.env = EnvironmentState.at_location(location_id)
	if not is_nan(temperature_c):
		a.env.temperature_c = temperature_c
	return a


func validate(state: StarterState, _env: EnvironmentState, _catalog: SimCatalog) -> StringName:
	if state.moldy:
		return REASON_MOLDY_LOCKED
	if env == null or not SimConstants.LOCATIONS.has(env.location):
		return REASON_ENVIRONMENT
	if not SimConstants.COVER_DRY.has(env.cover) or not SimConstants.CONTAINER_DRY.has(env.container):
		return REASON_ENVIRONMENT
	var row: Array = SimConstants.LOCATIONS[env.location]
	var t_min: float = row[2]
	var t_max: float = row[3]
	if env.temperature_c < t_min or env.temperature_c > t_max:
		return REASON_ENVIRONMENT
	return &""


func to_dict() -> Dictionary:
	return {"kind": "environment", "env": env.to_dict() if env != null else {}}
