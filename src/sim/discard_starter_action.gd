class_name DiscardStarterAction
extends GameAction
## Discard a moldy starter (data-models.md §4, D-002). Only when moldy. Two forms:
## - `to_empty_jar()` (Phase 4, narrative §9.2 step 4): commits at "Discard". The memorial is written, the jar
##   is washed, and the jar stays empty until StartAgainAction. A kill after this relaunches to the empty jar.
## - `new(name)` (the slice's atomic form, D-047): memorial and the named new starter in one save.

var new_name: String = ""
## True for the empty-jar form: no new starter, no name needed.
var keep_empty: bool = false


func _init(name_text: String = "") -> void:
	kind = &"discard_starter"
	new_name = name_text


## The Phase 4 discard: memorial now, then an empty jar.
static func to_empty_jar() -> DiscardStarterAction:
	var a := DiscardStarterAction.new()
	a.keep_empty = true
	return a


func validate(state: StarterState, _env: EnvironmentState, _catalog: SimCatalog) -> StringName:
	if state.empty or not state.moldy:
		return REASON_NOT_MOLDY
	if keep_empty:
		return &""
	return &"" if valid_name(new_name) else REASON_NAME


func to_dict() -> Dictionary:
	if keep_empty:
		return {"kind": "discard_starter", "keep_empty": true}
	return {"kind": "discard_starter", "new_name": new_name.strip_edges()}
