class_name AdoptStarterAction
extends GameAction
## The naming moment of a new game (narrative.md §6 and §8, mvp-scope "new-game start"). Valid only while the
## gifted starter has no name, which is exactly `Session.is_first_run()`. Session then makes the gifted starter
## the player's: a fresh `new_game` preset (at_peak, maturity 0.2, counter) timestamped now, so the first feed
## lands on time (game-mechanics §8.1), with this name. The Day one journal entry follows the first feed.
## After a discard, the new starter is named by DiscardStarterAction instead.

## &"tour" (the guided beats, Phase 4) or &"skip" ("I know starters"). Picks JOURNAL_DAY_ONE_BODY or
## JOURNAL_DAY_ONE_SKIP_BODY.
var path: StringName = &"skip"
var starter_name: String = ""


func _init(name_text: String = "", path_id: StringName = &"skip") -> void:
	kind = &"adopt"
	starter_name = name_text
	path = path_id


func validate(state: StarterState, _env: EnvironmentState, _catalog: SimCatalog) -> StringName:
	if not state.name.is_empty() or not PlayerHistory.ONBOARDING_PATHS.has(path):
		return REASON_ADOPT
	return &"" if valid_name(starter_name) else REASON_NAME


func to_dict() -> Dictionary:
	return {"kind": "adopt", "name": starter_name.strip_edges(), "path": String(path)}
