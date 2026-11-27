class_name RuleFirstRise
extends EventRule
## first_rise (events-catalog §3.1, game-mechanics §7.4): after the first real-time feed of this starter,
## `rise` crosses RISE_NOTICEABLE (1.25, spec §14.1) upward. info, one-time per starter.
## "Real-time feed" means the cycle's feed happened on this starter's own clock (at or after born_unix),
## so the preset's and the B6 demo's cycles never count. The first such cycle that reaches 1.25 fires.


func _init() -> void:
	id = &"first_rise"
	tier = &"info"


func evaluate(ctx: EventContext) -> SimEvent:
	var s: StarterState = ctx.state
	if not RuleFacts.crossed_up(ctx.prev_state.rise, s.rise, RuleFacts.RISE_NOTICEABLE):
		return null
	if RuleFacts.shows_danger(ctx.derived):
		return null
	if RuleFacts.feed_unix(s) < Sim.grid(s.born_unix):
		return null
	if RuleFacts.fired_for_starter(ctx.ledger, id, s):
		return null
	return make_event(ctx)
