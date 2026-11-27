class_name RuleHoochForming
extends EventRule
## hooch_forming (events-catalog §3.4, game-mechanics §7.4): `hooch` crosses HOOCH_VISIBLE (0.10,
## spec §14.1) upward. Happens in `hungry` and in `dormant`, the fridge included. info, 24 h cooldown.
## A feed sets hooch to 0, so an action never crosses upward. Its toast says "it just means hungry", so it
## never fires while warning signs or mold show (CLAUDE.md rule 5).

const COOLDOWN_S: int = 24 * 3600


func _init() -> void:
	id = &"hooch_forming"
	tier = &"info"
	cooldown_s = COOLDOWN_S


func evaluate(ctx: EventContext) -> SimEvent:
	# Inlined crossing test: this runs on every grid step of a catch-up.
	if ctx.state.hooch < CatchUp.HOOCH_VISIBLE or ctx.prev_state.hooch >= CatchUp.HOOCH_VISIBLE:
		return null
	if RuleFacts.shows_danger(ctx.derived):
		return null
	return make_event(ctx)
