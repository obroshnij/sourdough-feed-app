class_name CatchUp
extends RefCounted
## Offline catch-up and live grid stepping (architecture.md §5.4). Pure: mutates only the objects passed in.
## Live play and catch-up both call this, so one long catch-up equals many short sessions (V17, PROP-01).
## No RNG: catch-up contains no feeds, and event rules use none.

const HOOCH_VISIBLE: float = 0.10


## Steps `state` on the 60 s grid up to grid(to_unix), capped at 14 days. Past the cap the state is held
## and sim_time_unix jumps to grid(to_unix). After each step: derive, record history, evaluate and admit
## events. `utc_offset_s` (read once, at resume) applies to the whole window.
static func run(state: StarterState, env: EnvironmentState, history: PlayerHistory, ledger: EventLedger,
		catalog: SimCatalog, to_unix: int, utc_offset_s: int, app_foreground: bool) -> CatchUpResult:
	return run_with_rules(state, env, history, ledger, catalog, to_unix, utc_offset_s, app_foreground,
		EventRules.registry())


static func run_with_rules(state: StarterState, env: EnvironmentState, history: PlayerHistory,
		ledger: EventLedger, catalog: SimCatalog, to_unix: int, utc_offset_s: int, app_foreground: bool,
		rules: Array[EventRule]) -> CatchUpResult:
	var res := CatchUpResult.new()
	res.from_unix = state.sim_time_unix
	var target: int = Sim.grid(to_unix)
	var total_steps: int = 0
	if target > state.sim_time_unix:
		@warning_ignore("integer_division")
		total_steps = (target - state.sim_time_unix) / SimConstants.GRID_S
	var steps: int = mini(total_steps, SimConstants.CATCH_UP_CAP_STEPS)
	res.capped = total_steps > SimConstants.CATCH_UP_CAP_STEPS
	var every: int = maxi(1, ceili(float(steps) / float(CatchUpResult.MAX_SNAPSHOTS)))
	var has_rules: bool = not rules.is_empty()
	var prev_d: DerivedState = StateDeriver.derive(state, env)
	var peak_rise: float = state.rise
	var ctx: EventContext = null
	if has_rules:
		ctx = EventContext.new()
		ctx.env = env
		ctx.history = history
		ctx.ledger = ledger
		ctx.utc_offset_s = utc_offset_s
		ctx.app_foreground = app_foreground
		ctx.catalog = catalog
	for i: int in steps:
		var prev: StarterState = state.copy() if has_rules else null
		var hooch_before: float = state.hooch
		Sim.step(state, env)
		var d: DerivedState = StateDeriver.derive(state, env)
		history.record_step(state, d)
		if d.state != prev_d.state:
			res.transitions.append({
				"at_unix": state.sim_time_unix, "from": String(prev_d.state), "to": String(d.state),
			})
		if state.rise > peak_rise:
			peak_rise = state.rise
			res.notable["peak_unix"] = state.sim_time_unix
			res.notable["peak_rise"] = state.rise
		if hooch_before < HOOCH_VISIBLE and state.hooch >= HOOCH_VISIBLE and not res.notable.has("hooch_first_unix"):
			res.notable["hooch_first_unix"] = state.sim_time_unix
		if has_rules:
			ctx.prev_state = prev
			ctx.prev_derived = prev_d
			ctx.state = state
			ctx.derived = d
			ctx.now_unix = state.sim_time_unix
			ctx.local_minute_of_day = LocalDay.minute_of_day(state.sim_time_unix, utc_offset_s)
			ctx.last_action = null
			res.events.append_array(EventRules.process(ctx, rules))
		if ((i + 1) % every == 0 or i == steps - 1) and res.snapshots.size() < CatchUpResult.MAX_SNAPSHOTS:
			res.snapshots.append(VisualMapper.from_derived(state, env, d))
		prev_d = d
	if res.capped:
		state.sim_time_unix = target
	res.steps = steps
	res.simulated_s = steps * SimConstants.GRID_S
	res.to_unix = state.sim_time_unix
	return res
