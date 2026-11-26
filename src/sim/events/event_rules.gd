class_name EventRules
extends RefCounted
## The rule registry and the per-step evaluation (architecture.md §7). Phase 2: the engine with no rules.
## To add a rule (T4, Phase 3): write src/sim/events/rules/rule_<id>.gd and list it in `registry()`.


static func registry() -> Array[EventRule]:
	var rules: Array[EventRule] = []
	return rules


## Every rule's raw output for this context, in registry order. Nothing is admitted here.
static func evaluate(ctx: EventContext) -> Array[SimEvent]:
	return evaluate_with(ctx, registry())


static func evaluate_with(ctx: EventContext, rules: Array[EventRule]) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for rule: EventRule in rules:
		var e: SimEvent = rule.evaluate(ctx)
		if e != null:
			out.append(e)
	return out


## Evaluate, then admit through the scheduler. Returns the admitted events (now in ctx.ledger.pending).
static func process(ctx: EventContext, rules: Array[EventRule]) -> Array[SimEvent]:
	var admitted: Array[SimEvent] = []
	if rules.is_empty():
		return admitted
	ctx.ledger.roll_day(LocalDay.day_key(ctx.state.sim_time_unix, ctx.utc_offset_s))
	for rule: EventRule in rules:
		var e: SimEvent = rule.evaluate(ctx)
		if e == null:
			continue
		if EventScheduler.admit(e, ctx.ledger, ctx.local_minute_of_day, rule.cooldown_s, rule.one_time):
			admitted.append(e)
	return admitted
