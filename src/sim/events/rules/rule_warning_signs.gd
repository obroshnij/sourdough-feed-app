class_name RuleWarningSigns
extends EventRule
## warning_signs (events-catalog §3.6, game-mechanics §7.4): the state is `unhealthy` (mold_risk >= 0.5,
## spec §12.2). attention, once per episode, re-armed after 24 h out of unhealthy.
##
## Safety (CLAUDE.md rule 5, spec §10): it fires while unhealthy until admitted, not only on the entering
## step, so a warning is never lost. Only a feed ends an episode, so "this episode" is "this cycle of this
## starter" (RuleFacts.cycle_start). A moldy starter is not `unhealthy` (moldy wins, spec §12.2);
## mold_found covers it.
## Payload: began_unix, for EVENT_WARNING_SIGNS_AWAY_HOURS / _DAYS. Nothing in it says or implies safe.


func _init() -> void:
	id = &"warning_signs"
	tier = &"attention"


func evaluate(ctx: EventContext) -> SimEvent:
	if ctx.derived.state != &"unhealthy":
		return null
	var s: StarterState = ctx.state
	if RuleFacts.fired_after(ctx.ledger, id, RuleFacts.cycle_start(s)):
		return null
	var left: int = ctx.history.unhealthy_left_unix
	if left > 0 and s.sim_time_unix - left < RuleFacts.WARNING_REARM_S:
		return null
	return make_event(ctx, {"began_unix": s.sim_time_unix})
