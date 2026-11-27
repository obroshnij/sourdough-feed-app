class_name StartAgainAction
extends GameAction
## "Start again" from the empty jar (Phase 4, narrative §9.2 steps 6 and 7): a fresh spoonful, named.
## Valid only while the jar is empty (after DiscardStarterAction.to_empty_jar()). Session builds the start
## from Session.restart_preset(): `first_restart` (M.'s spare, cold dormant) after the first loss, else
## `restart` (a friend's spoonful, at_peak). Earned knowledge and unlocks stay (game-design §5).

var starter_name: String = ""


func _init(name_text: String = "") -> void:
	kind = &"start_again"
	starter_name = name_text


func validate(state: StarterState, _env: EnvironmentState, _catalog: SimCatalog) -> StringName:
	if not state.empty:
		return REASON_NOT_EMPTY
	return &"" if valid_name(starter_name) else REASON_NAME


func to_dict() -> Dictionary:
	return {"kind": "start_again", "name": starter_name.strip_edges()}
