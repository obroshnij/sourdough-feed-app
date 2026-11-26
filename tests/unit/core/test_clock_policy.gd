extends CoreCase
## The clock seam and the clock rules (architecture.md §5.2, §5.3; test-plan CLK-09, CLK-16). Owner: T1.


func test_fake_clock_moves_wall_and_monotonic_separately() -> void:
	if not require(&"m3_clock"):
		return
	var c := FakeClock.new(T0, 3600)
	check_eq(c.now_unix(), T0, "start")
	check_eq(c.local_utc_offset_s(), 3600, "offset")
	c.advance(90)
	check(c.now_unix() == T0 + 90 and c.monotonic_msec() == 90000, "advance moves both")
	c.set_now(T0 + 10000)
	check(c.now_unix() == T0 + 10000 and c.monotonic_msec() == 90000, "set_now is a wall jump only")
	c.set_offset(-18000)
	check_eq(c.local_utc_offset_s(), -18000, "set_offset")


func test_system_and_debug_clocks_are_sane() -> void:
	if not require(&"m3_clock"):
		return
	var sys := SystemClock.new()
	check(sys.now_unix() > 1700000000, "system clock reads a plausible time")
	var dbg := DebugClock.new(1.0)
	var before: int = dbg.now_unix()
	dbg.advance(3600.0)
	check_between(float(dbg.now_unix() - before), 3599.0, 3602.0, "DebugClock.advance jumps forward")
	dbg.set_time_scale(0.0)
	var frozen: int = dbg.now_unix()
	check_eq(dbg.now_unix(), frozen, "time scale 0 freezes the debug clock")


func test_resolve_follows_the_gap_table() -> void:
	if not require(&"m3_clock"):
		return
	check_eq(TimePolicy.CLOCK_REANCHOR_GAP_S, 21600, "re-anchor gap is 6 h")
	var r: TimeResolution = TimePolicy.resolve(T0, T0 + 3600)
	check(r.action == &"catch_up" and r.target_unix == T0 + 3600, "gap < 0: catch up to now")
	r = TimePolicy.resolve(T0, T0)
	check_eq(r.action, &"catch_up", "gap 0: catch up (nothing to do)")
	r = TimePolicy.resolve(T0, T0 - 21600)
	check(r.action == &"hold" and r.target_unix == T0, "CLK-16 gap 21,600 s: hold the anchor")
	r = TimePolicy.resolve(T0, T0 - 21601)
	check(r.action == &"reanchor" and r.target_unix == Sim.grid(T0 - 21601), "CLK-16 gap 21,601 s: re-anchor at grid(now)")


func test_monotonic_guard() -> void:
	if not require(&"m3_clock"):
		return
	check_eq(TimePolicy.foreground_elapsed_s(299, 0), 299, "CLK-09 299 s ahead: wall delta")
	check_eq(TimePolicy.foreground_elapsed_s(301, 0), 0, "CLK-09 301 s ahead: monotonic delta only")
	check_eq(TimePolicy.foreground_elapsed_s(60, 60), 60, "agreeing clocks")


func test_local_day_math() -> void:
	if not require(&"m3_clock"):
		return
	check_eq(LocalDay.day_key(0, 0), "1970-01-01", "epoch")
	check_eq(LocalDay.day_key(951782400, 0), "2000-02-29", "leap day 2000")
	check_eq(LocalDay.day_key(1709164800, 0), "2024-02-29", "leap day 2024")
	check_eq(LocalDay.day_key(1735689599, 0), "2024-12-31", "CLK-15 last second of the year")
	check_eq(LocalDay.day_key(1735689599, 1), "2025-01-01", "an offset crosses midnight")
	check_eq(LocalDay.minute_of_day(T0, 0), (T0 % 86400) / 60, "minute of day")
	check_eq(LocalDay.minute_of_day(0, -60), 1439, "negative offsets wrap")
