extends CoreCase
## CatchUp.run (architecture.md §5.4; test-plan PROP-01, CLK-08, V13). Pure, so no files. Owner: T1.


func _start() -> Array:
	var s: StarterState = SimFixtures.mature()
	SimFixtures.feed_ratio(s)
	s.sim_time_unix = T0
	return [s, EnvironmentState.at_location(&"counter"), PlayerHistory.new(), EventLedger.new()]


func _run(parts: Array, to_unix: int) -> CatchUpResult:
	var s: StarterState = parts[0]
	var env: EnvironmentState = parts[1]
	var h: PlayerHistory = parts[2]
	var l: EventLedger = parts[3]
	return CatchUp.run(s, env, h, l, SimCatalog.builtin(), to_unix, 0, false)


func test_steps_on_the_60s_grid() -> void:
	if not require(&"m5_catchup"):
		return
	var p: Array = _start()
	var r: CatchUpResult = _run(p, T0 + 8 * 3600 + 59)
	var s: StarterState = p[0]
	check_eq(r.steps, 480, "CLK-01 8 h is 480 steps")
	check_eq(r.simulated_s, 28800, "simulated_s")
	check_eq(s.sim_time_unix, T0 + 28800, "sim time stays on the grid")
	check(r.snapshots.size() > 0 and r.snapshots.size() <= 30, "at most 30 snapshots, got %d" % r.snapshots.size())
	check(not r.transitions.is_empty(), "the rise passes through states")
	check(r.notable.has("peak_unix") and float(r.notable["peak_rise"]) > 2.0, "notable peak recorded")
	check_eq(_run(p, T0).steps, 0, "a target in the past does nothing")


func test_one_long_catch_up_equals_many_short_ones() -> void:
	if not require(&"m5_catchup"):
		return
	var whole: Array = _start()
	var total: int = 3 * 86400 + 1234
	_run(whole, T0 + total)
	var rng := RandomNumberGenerator.new()
	for trial: int in 3:
		rng.seed = 99 + trial
		var split: Array = _start()
		var t: int = T0
		while t < T0 + total:
			t = mini(T0 + total, t + rng.randi_range(1, 7200))
			_run(split, t)
		var a: StarterState = whole[0]
		var b: StarterState = split[0]
		check_eq(JSON.stringify(b.to_dict(), "", true, true), JSON.stringify(a.to_dict(), "", true, true),
			"PROP-01 trial %d: split sessions with off-grid boundaries equal one catch-up" % trial)


func test_cap_at_14_days_holds_the_state() -> void:
	if not require(&"m5_catchup"):
		return
	for row: Array in [[14 * 86400 - 60, false], [14 * 86400, false], [14 * 86400 + 60, true], [30 * 86400, true]]:
		var p: Array = _start()
		var elapsed: int = row[0]
		var r: CatchUpResult = _run(p, T0 + elapsed)
		var s: StarterState = p[0]
		check_eq(r.simulated_s, mini(elapsed, 14 * 86400), "CLK-08 simulated_s for %d s" % elapsed)
		check_eq(r.capped, row[1], "capped for %d s" % elapsed)
		check_eq(s.sim_time_unix, Sim.grid(T0 + elapsed), "the clock jumps to now")
	var neglect: Array = _start()
	_run(neglect, T0 + 30 * 86400)
	var n: StarterState = neglect[0]
	check(n.moldy, "V13 counter, 30 days: moldy (latched) at the cap")


func test_rules_never_touch_the_sim() -> void:
	if not require(&"m5_catchup"):
		return
	# T0 is 00:00 UTC, so stop one step before the third local day starts.
	var plain: Array = _start()
	_run(plain, T0 + 2 * 86400 - 60)
	var ruled: Array = _start()
	var rules: Array[EventRule] = [EveryHourRule.new()]
	var r: CatchUpResult = CatchUp.run_with_rules(ruled[0], ruled[1], ruled[2], ruled[3], SimCatalog.builtin(),
		T0 + 2 * 86400 - 60, 0, false, rules)
	var a: StarterState = plain[0]
	var b: StarterState = ruled[0]
	check_eq(JSON.stringify(b.to_dict()), JSON.stringify(a.to_dict()), "PROP-13 a rule changes no starter variable")
	check_eq(r.events.size(), 8, "the info cap allows 4 a local day, over 2 days")


## A test-only rule: an info event at most once an hour.
class EveryHourRule:
	extends EventRule

	func _init() -> void:
		id = &"test_every_hour"
		tier = &"info"
		cooldown_s = 3600

	func evaluate(ctx: EventContext) -> SimEvent:
		return make_event(ctx, {"rise": ctx.state.rise})
