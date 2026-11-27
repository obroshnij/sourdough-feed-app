class_name EventRules
extends RefCounted
## The rule registry and the per-step evaluation (architecture.md §7).
## The rules themselves are T4's: src/sim/events/rules/rule_<id>.gd, listed in RuleIndex.all() (T4 owns the
## list and its order). Rules are pure and keep no state between calls, so one list serves every caller.

static var _registry: Array[EventRule] = []


## Every slice rule, in RuleIndex order (the tie-break when two fire on one step). Built once, then shared.
static func registry() -> Array[EventRule]:
	if _registry.is_empty():
		_registry = RuleIndex.all()
	return _registry


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
## The ledger's day rolls only when the local day changes (the day key is a string, too slow to build on
## every one of a catch-up's 20,160 steps).
static func process(ctx: EventContext, rules: Array[EventRule]) -> Array[SimEvent]:
	var admitted: Array[SimEvent] = []
	process_into(ctx, rules, admitted)
	return admitted


## process(), appending to `out` instead of returning a new array (catch-up calls it 20,160 times).
static func process_into(ctx: EventContext, rules: Array[EventRule], out: Array[SimEvent]) -> void:
	if rules.is_empty():
		return
	var day: int = LocalDay.day_index(ctx.state.sim_time_unix, ctx.utc_offset_s)
	if day != ctx.day_index:
		ctx.ledger.roll_day(LocalDay.day_key(ctx.state.sim_time_unix, ctx.utc_offset_s))
		ctx.day_index = day
	for rule: EventRule in rules:
		var e: SimEvent = rule.evaluate(ctx)
		if e == null:
			continue
		if EventScheduler.admit(e, ctx.ledger, ctx.local_minute_of_day, rule.cooldown_s, rule.one_time):
			out.append(e)
