extends TestCase
## Clock rules (test-plan §2.5, architecture §5.3, ADR-006) at their exact boundaries, against
## T1's pure TimePolicy. gap = sim_time_unix - now. Waits for T1 milestone m3_clock.

const T := 1795651200  # on the 60 s grid


func test_constants_match_architecture() -> void:
	if not require(&"m3_clock"):
		return
	check_eq(TimePolicy.CLOCK_REANCHOR_GAP_S, 21600, "CLOCK_REANCHOR_GAP_S (6 h)")
	check_eq(TimePolicy.MONOTONIC_GUARD_S, 300, "MONOTONIC_GUARD_S")
	check_eq(TimePolicy.CATCH_UP_CAP_S, 14 * 86400, "CATCH_UP_CAP_S (14 d)")


## grid(t) = t - posmod(t, 60): the last grid point at or before t (architecture §5.1).
func test_grid_is_the_last_minute_at_or_before() -> void:
	if not require(&"m3_clock"):
		return
	check_eq(Sim.grid(T), T, "on the grid")
	check_eq(Sim.grid(T + 59), T, "59 s past")
	check_eq(Sim.grid(T + 60), T + 60, "next minute")
	check_eq(Sim.grid(59), 0, "1970")


## gap <= 0 catches up to now. Includes gap 0 (no time passed).
func test_clock_forward_or_equal_catches_up_to_now() -> void:
	if not require(&"m3_clock"):
		return
	for elapsed: int in [0, 1, 60, 8 * 3600, 30 * 86400]:
		var r: TimeResolution = TimePolicy.resolve(T, T + elapsed)
		check_eq(r.action, &"catch_up", "elapsed %d s" % elapsed)
		check_eq(r.target_unix, T + elapsed, "target for elapsed %d s" % elapsed)
		check_eq(r.gap_s, -elapsed, "gap for elapsed %d s" % elapsed)


## CLK-03, CLK-16: back by up to 6 h holds the anchor. One second more re-anchors to grid(now).
func test_clk_16_reanchor_boundary() -> void:
	if not require(&"m3_clock"):
		return
	for back: int in [1, 3600, 21600]:
		var hold: TimeResolution = TimePolicy.resolve(T, T - back)
		check_eq(hold.action, &"hold", "back %d s" % back)
		check_eq(hold.target_unix, T, "the anchor is kept, back %d s" % back)
	for back: int in [21601, 2 * 86400]:
		var now: int = T - back
		var r: TimeResolution = TimePolicy.resolve(T, now)
		check_eq(r.action, &"reanchor", "back %d s" % back)
		check_eq(r.target_unix, Sim.grid(now), "re-anchor to grid(now), back %d s" % back)


## CLK-12: the clock reads 1970 after a battery drain. Re-anchor, never a 56-year rewind.
func test_clk_12_clock_reads_1970() -> void:
	if not require(&"m3_clock"):
		return
	for now: int in [0, 59, 86400 + 30]:
		var r: TimeResolution = TimePolicy.resolve(T, now)
		check_eq(r.action, &"reanchor", "now %d" % now)
		check_eq(r.target_unix, Sim.grid(now), "target for now %d" % now)


## CLK-09: in session, a wall delta more than 300 s past the monotonic delta is a clock change,
## so only the monotonic delta counts. Exactly 300 s more still uses the wall delta.
func test_clk_09_monotonic_guard() -> void:
	if not require(&"m3_clock"):
		return
	for mono: int in [0, 60, 3600]:
		check_eq(TimePolicy.foreground_elapsed_s(mono + 299, mono), mono + 299, "299 s over, mono %d" % mono)
		check_eq(TimePolicy.foreground_elapsed_s(mono + 300, mono), mono + 300, "300 s over, mono %d" % mono)
		check_eq(TimePolicy.foreground_elapsed_s(mono + 301, mono), mono, "301 s over, mono %d" % mono)
	check_eq(TimePolicy.foreground_elapsed_s(60, 60), 60, "no drift")
