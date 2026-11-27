class_name RuleHungryAgain
extends EventRule
## hungry_again (events-catalog §3.3, game-mechanics §7.4): the state label enters `hungry`.
## nudge, 12 h cooldown. In quiet hours the scheduler defers it to 08:00, and Session drops it if it is no
## longer hungry by then (expires_if). Payload: time_unix (for {time}), the moment it became hungry.

const COOLDOWN_S: int = 12 * 3600


func _init() -> void:
	id = &"hungry_again"
	tier = &"nudge"
	cooldown_s = COOLDOWN_S


func evaluate(ctx: EventContext) -> SimEvent:
	if ctx.derived.state != &"hungry" or ctx.prev_derived.state == &"hungry":
		return null
	var e: SimEvent = make_event(ctx, {"time_unix": ctx.state.sim_time_unix})
	e.expires_if = &"state_not_hungry"
	return e
