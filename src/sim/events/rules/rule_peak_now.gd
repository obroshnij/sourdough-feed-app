class_name RulePeakNow
extends EventRule
## peak_now (events-catalog §3.2, game-mechanics §7.4): the player sees the starter at its peak.
## Fires on the first foreground step or action of a cycle whose `rise_phase` is `at_peak`. That covers
## the catalog's case (in the foreground when it enters at_peak) and a return in the middle of the peak.
## Reads `rise_phase`, never the label, because `recovering` hides the phase. info, once per rise cycle,
## shared with peaked_while_away. Payload: time_unix (for {time}).

const OTHER: StringName = &"peaked_while_away"


func _init() -> void:
	id = &"peak_now"
	tier = &"info"


func evaluate(ctx: EventContext) -> SimEvent:
	if not ctx.app_foreground or ctx.derived.rise_phase != &"at_peak":
		return null
	if RuleFacts.shows_danger(ctx.derived):
		return null
	var cycle: int = RuleFacts.cycle_start(ctx.state)
	if RuleFacts.fired_after(ctx.ledger, id, cycle) or RuleFacts.fired_after(ctx.ledger, OTHER, cycle):
		return null
	return make_event(ctx, {"time_unix": ctx.state.sim_time_unix})
