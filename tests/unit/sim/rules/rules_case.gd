class_name RulesCase
extends TestCase
## Shared helpers for the slice event rule tests (T4). Every scenario runs the real sim from a real
## preset, through the same code paths the game uses:
## - catch-up: one CatchUp.run_with_rules call with the app in the background (GameSession._sync_to_clock)
## - live play: one call per 60 s grid step with the app in the foreground (GameSession.tick)
## - actions: GameSession.apply() steps 3 to 6 (mutate, derive, history, events)
## Owner: T4.

## 2026-11-25 00:00 UTC. With utc_offset 0, local time equals UTC.
const T0: int = 1795651200
const H: int = 3600
const DAY: int = 86400


## A starter, its surroundings and everything admitted so far.
class World:
	var state: StarterState = null
	var env: EnvironmentState = null
	var history: PlayerHistory = PlayerHistory.new()
	var ledger: EventLedger = EventLedger.new()
	var catalog: SimCatalog = SimCatalog.builtin()
	var rules: Array[EventRule] = []
	var utc_offset_s: int = 0
	## Every admitted event, in order.
	var events: Array[SimEvent] = []

	## Background catch-up to `t` in one call.
	func away_to(t: int) -> CatchUpResult:
		var r: CatchUpResult = CatchUp.run_with_rules(state, env, history, ledger, catalog, t, utc_offset_s,
			false, rules)
		events.append_array(r.events)
		return r

	## Live play to `t`: one grid step per call, app in the foreground.
	func live_to(t: int) -> void:
		var target: int = Sim.grid(t)
		while state.sim_time_unix < target:
			var r: CatchUpResult = CatchUp.run_with_rules(state, env, history, ledger, catalog,
				state.sim_time_unix + SimConstants.GRID_S, utc_offset_s, true, rules)
			events.append_array(r.events)

	## A player action at the current sim time, as GameSession.apply() does it after its sync.
	func act(action: GameAction, foreground: bool = true) -> Array[SimEvent]:
		action.at_unix = state.sim_time_unix
		var before: StarterState = state.copy()
		var derived_before: DerivedState = StateDeriver.derive(state, env)
		match action.kind:
			&"feed":
				var feed: FeedAction = action
				Sim.feed(state, feed.kept_g, feed.flour_g, feed.water_g, 0.5, feed.hooch_choice == &"stir_in")
			&"environment":
				var move: SetEnvironmentAction = action
				env = move.env.copy()
				env.changed_unix = state.sim_time_unix
		var derived: DerivedState = StateDeriver.derive(state, env)
		history.record_action(action, before, derived_before)
		var ctx := EventContext.new()
		ctx.prev_state = before
		ctx.prev_derived = derived_before
		ctx.state = state
		ctx.derived = derived
		ctx.env = env
		ctx.history = history
		ctx.ledger = ledger
		ctx.now_unix = state.sim_time_unix
		ctx.utc_offset_s = utc_offset_s
		ctx.local_minute_of_day = LocalDay.minute_of_day(state.sim_time_unix, utc_offset_s)
		ctx.app_foreground = foreground
		ctx.last_action = action
		ctx.catalog = catalog
		var admitted: Array[SimEvent] = EventRules.process(ctx, rules)
		events.append_array(admitted)
		return admitted

	## A 1:f:f feed of white_bread at 100% (game-mechanics §2.3), feed_u 0.5.
	func feed(f: float = 1.0) -> Array[SimEvent]:
		return act(FeedAction.from_ratio(f, f, &"white_bread"))

	func move(location: StringName) -> Array[SimEvent]:
		return act(SetEnvironmentAction.to_location(location))

	## The player acknowledges every waiting event (closes the sheet or card).
	func ack_all() -> void:
		ledger.pending.clear()

	func derived() -> DerivedState:
		return StateDeriver.derive(state, env)

	func of(id: StringName) -> Array[SimEvent]:
		var out: Array[SimEvent] = []
		for e: SimEvent in events:
			if e.id == id:
				out.append(e)
		return out

	## Creation times of `id`, untyped so check_eq can compare it with a literal.
	func times(id: StringName) -> Array:
		var out: Array = []
		for e: SimEvent in of(id):
			out.append(e.created_unix)
		return out


## A new game as GameSession starts it: the `new_game` preset (at_peak, maturity 0.2) adopted at `t` on the
## counter. `rules` defaults to the full RuleIndex.
static func new_game(t: int = T0, rules: Array[EventRule] = []) -> World:
	return from_preset(&"new_game", t, rules)


static func from_preset(preset: StringName, t: int, rules: Array[EventRule] = []) -> World:
	var w := World.new()
	w.state = StarterPresets.make(preset, t)
	w.state.id = "t4_%s" % preset
	w.env = StarterPresets.environment_for(preset, t)
	w.rules = rules if not rules.is_empty() else RuleIndex.all()
	return w


## The first sim time in [from, to] where `pred` holds for a rules-free copy of `w` stepped on the grid,
## or -1. Steps a copy; `w` is untouched. Lets a test name the exact step a rule must fire on.
static func first_time(w: World, to: int, pred: Callable) -> int:
	var s: StarterState = w.state.copy()
	var env: EnvironmentState = w.env.copy()
	var prev: StarterState = s.copy()
	var prev_d: DerivedState = StateDeriver.derive(s, env)
	while s.sim_time_unix < to:
		prev = s.copy()
		Sim.step(s, env)
		var d: DerivedState = StateDeriver.derive(s, env)
		if pred.call(prev, prev_d, s, d):
			return s.sim_time_unix
		prev_d = d
	return -1


## Hours after T0, for readable failure messages.
static func hours(t: int) -> String:
	return "%.2f h" % (float(t - T0) / 3600.0)


## "id@hours" for each event, untyped, for readable live-vs-catch-up comparisons.
static func signature(events: Array[SimEvent]) -> Array:
	var out: Array = []
	for e: SimEvent in events:
		out.append("%s@%s" % [e.id, hours(e.created_unix)])
	return out


## Only the events whose id is in `ids`.
static func only(events: Array[SimEvent], ids: Array[StringName]) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e: SimEvent in events:
		if ids.has(e.id):
			out.append(e)
	return out


## Predicates for first_time(). Each takes (prev, prev_derived, state, derived).
static func enters_state(id: StringName) -> Callable:
	return func(_p: StarterState, pd: DerivedState, _s: StarterState, d: DerivedState) -> bool:
		return pd.state != id and d.state == id


static func enters_phase(id: StringName) -> Callable:
	return func(_p: StarterState, pd: DerivedState, _s: StarterState, d: DerivedState) -> bool:
		return pd.rise_phase != id and d.rise_phase == id


static func leaves_phase(id: StringName) -> Callable:
	return func(_p: StarterState, pd: DerivedState, _s: StarterState, d: DerivedState) -> bool:
		return pd.rise_phase == id and d.rise_phase != id
