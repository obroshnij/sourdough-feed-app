class_name RuleMoldFound
extends EventRule
## mold_found (events-catalog §4.9, game-mechanics §7.4): the starter is `moldy` (mold_risk reached 1.0,
## latched, spec §10). attention, once per starter. The scheduler lets it replace a waiting attention sheet.
##
## Safety (CLAUDE.md rule 5): it fires while moldy until admitted, not only on the latching step, so a
## moldy starter always gets the discard sheet, also after a load or a blocked admission. "Once" is per
## starter, never per save: the next starter must get its own sheet if it molds. No payload: the sheet's
## copy needs none, and the MVP shows no tint (D-026).


func _init() -> void:
	id = &"mold_found"
	tier = &"attention"


func evaluate(ctx: EventContext) -> SimEvent:
	if ctx.derived.state != &"moldy":
		return null
	if RuleFacts.fired_for_starter(ctx.ledger, id, ctx.state):
		return null
	return make_event(ctx)
