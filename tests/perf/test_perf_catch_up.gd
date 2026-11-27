extends TestCase
## PERF-03 and AC-09.7 (D-051): a 14-day catch-up (20,160 steps) with the full slice rule registry, on the
## synchronous path (CatchUp.run, as boot() and on_resume() use with async_catch_up off). Fails when the
## fastest of 7 runs is above 250 ms (OD-26, director 2026-11-27: load from other processes only ever adds
## time, so the fastest run tracks the code; the median and spread are printed too). Every number is a Mac
## estimate (D-004); the iPhone 13 Pro number is recorded by hand (MAN-D7).
## The case is a 1:1:1 feed on MATURE left at the counter, so the rules see hunger, hooch, dormancy, the
## warning and mold. Setup is outside the timed span; only CatchUp.run is timed.
## Near the limit, report the spread (fastest, median, slowest) rather than raising the budget (D-051).

const BUDGET_MS: float = 250.0
const RUNS: int = 7
const T0: int = 1795651200
const DAYS: int = 14


func test_perf_03_fourteen_day_catch_up_with_every_rule() -> void:
	if not (require(&"m5_catchup") and require(&"p3_rules")):
		return
	var times_ms: Array[float] = []
	var steps: int = 0
	var events: int = 0
	for run: int in RUNS:
		var s: StarterState = SimFixtures.mature()
		SimFixtures.feed_ratio(s)
		s.born_unix = T0 - 30 * 86400
		s.sim_time_unix = T0
		var env: EnvironmentState = EnvironmentState.at_location(&"counter")
		var history := PlayerHistory.new()
		var ledger := EventLedger.new()
		var catalog: SimCatalog = SimCatalog.builtin()
		var start: int = Time.get_ticks_usec()
		var r: CatchUpResult = CatchUp.run(s, env, history, ledger, catalog, T0 + DAYS * 86400, 0, false)
		times_ms.append(float(Time.get_ticks_usec() - start) / 1000.0)
		steps = r.steps
		events = r.events.size()
	check_eq(steps, DAYS * 1440, "20,160 steps")
	check(events >= 4, "the rules ran and fired (%d events)" % events)
	check_eq(EventRules.registry().size(), RuleIndex.all().size(), "the full rule registry")
	var sorted: Array[float] = times_ms.duplicate()
	sorted.sort()
	var fastest: float = sorted[0]
	var line: String = "PERF-03 14-day catch-up, Mac estimate (D-004): fastest %.1f ms of %d runs (median %.1f, slowest %.1f, spread %.1f ms; all %s), budget %.0f ms on the fastest (OD-26)" % [
		fastest, RUNS, sorted[RUNS / 2], sorted[RUNS - 1], sorted[RUNS - 1] - fastest,
		", ".join(times_ms.map(func(t: float) -> String: return "%.1f" % t)), BUDGET_MS]
	print("    " + line)
	check(fastest <= BUDGET_MS, line)
