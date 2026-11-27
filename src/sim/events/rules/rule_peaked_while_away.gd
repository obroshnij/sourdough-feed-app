class_name RulePeakedWhileAway
extends EventRule
## peaked_while_away (events-catalog §3.2, game-mechanics §7.4): `rise_phase` entered and left `at_peak`
## with no foreground step in between, so the player never saw it. Fires on the plain step that leaves
## at_peak (a feed is not "leaving"; it starts a new cycle). info, once per rise cycle, shared with peak_now.
## Payload: time_unix = the peak time (spec §14.1, the step that set the cycle max), peak_rise, and
## rise_word (spec §14.1 bands, from Inspection.peak_word) for the EVENT_PEAKED_WHILE_AWAY_AWAY_<WORD> line.

const OTHER: StringName = &"peak_now"


func _init() -> void:
	id = &"peaked_while_away"
	tier = &"info"


func evaluate(ctx: EventContext) -> SimEvent:
	if ctx.last_action != null:
		return null
	if ctx.prev_derived.rise_phase != &"at_peak" or ctx.derived.rise_phase == &"at_peak":
		return null
	if RuleFacts.shows_danger(ctx.derived):
		return null
	if ctx.history.peak_seen_foreground:
		return null
	var s: StarterState = ctx.state
	var cycle: int = RuleFacts.cycle_start(s)
	if RuleFacts.fired_after(ctx.ledger, id, cycle) or RuleFacts.fired_after(ctx.ledger, OTHER, cycle):
		return null
	# A preset adopted mid-cycle may have no recorded peak time of its own yet; then "around now".
	var peak_unix: int = ctx.history.cycle_peak_unix
	if peak_unix <= cycle:
		peak_unix = s.sim_time_unix
	return make_event(ctx, {
		"time_unix": peak_unix,
		"peak_rise": s.peak_rise,
		"rise_word": String(Inspection.peak_word(s.peak_rise)),
	})
