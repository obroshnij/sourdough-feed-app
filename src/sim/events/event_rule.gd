class_name EventRule
extends RefCounted
## Base of every rule (architecture.md §7). Rules live in src/sim/events/rules/rule_<id>.gd (T4),
## are pure and deterministic, and take no RNG.

var id: StringName = &""
var tier: StringName = &"info"
## Minimum seconds between two firings of this id. 0 = none.
var cooldown_s: int = 0
## Fires at most once per save.
var one_time: bool = false
## Phase 4 (PERF-03). False for a rule that can only fire right after an action (it returns null whenever
## ctx.last_action is null). Plain steps, and so every catch-up, then skip it.
var on_steps: bool = true
## Phase 4 (PERF-03). False for a rule that never fires with ctx.app_foreground false. Background catch-ups
## (launch, resume) then skip it.
var background: bool = true


## Returns an event, or null when the rule doesn't fire on this step.
func evaluate(_ctx: EventContext) -> SimEvent:
	return null


## Helper for subclasses: a pending event stamped with the context's sim time.
func make_event(ctx: EventContext, payload: Dictionary = {}) -> SimEvent:
	var e := SimEvent.new()
	e.id = id
	e.tier = tier
	e.created_unix = ctx.state.sim_time_unix
	e.local_minute_of_day = ctx.local_minute_of_day
	e.payload = payload
	return e
