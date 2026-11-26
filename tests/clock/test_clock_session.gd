extends TestCase
## Clock scenarios through T1's GameSession (test-plan §2.5): close the app (on_background, then
## drop the session), move the FakeClock, and launch again (a new session on the same save
## folder, boot()). Waits for T1 milestones m4_save and m5_catchup.
## Not here yet: CLK-06, 07 and 15 (quiet hours and day keys, Phase 3 events), CLK-10 and 18
## (need FeedAction through apply, Phase 3 integration), CLK-13 (export templates).

const T := 1795651200  # on the 60 s grid
const HOUR := 3600
const DAY := 86400
const CAP := 14 * DAY

var _dir: String = ""
var _sessions: Array[GameSession] = []


func before_each() -> void:
	_dir = QaTemp.make("clock_session")
	_sessions.clear()


func after_each() -> void:
	for s: GameSession in _sessions:
		if is_instance_valid(s):
			s.free()
	_sessions.clear()
	QaTemp.remove(_dir)


## CLK-01: closed at T, opened at T + 8 h: 480 steps, 28,800 s.
func test_clk_01_eight_hours_away() -> void:
	if not _ready_for_sessions():
		return
	var clock: FakeClock = FakeClock.new(T)
	_close(_launch(_dir, clock))
	clock.set_now(T + 8 * HOUR)
	var s: GameSession = _launch(_dir, clock)
	var r: CatchUpResult = s.get_last_catch_up()
	check_eq(r.steps, 480, "steps")
	check_eq(r.simulated_s, 28800, "simulated_s")
	check(not r.capped and not r.reanchored, "neither capped nor re-anchored")
	check_eq(s.get_starter().sim_time_unix, T + 8 * HOUR, "sim_time_unix")


## CLK-02: opened 30 days later: 14 days simulated, capped, and the anchor jumps to grid(now).
func test_clk_02_thirty_days_away_is_capped() -> void:
	if not _ready_for_sessions():
		return
	var clock: FakeClock = FakeClock.new(T)
	_close(_launch(_dir, clock))
	clock.set_now(T + 30 * DAY)
	var s: GameSession = _launch(_dir, clock)
	var r: CatchUpResult = s.get_last_catch_up()
	check_eq(r.simulated_s, CAP, "simulated_s")
	check_eq(r.steps, CAP / 60, "steps")
	check(r.capped, "capped")
	check_eq(s.get_starter().sim_time_unix, T + 30 * DAY, "sim_time_unix = grid(now)")


## CLK-03: opened 1 h before it was closed: nothing simulated, the anchor and state are kept,
## and nothing is added to the journal.
func test_clk_03_clock_back_one_hour_changes_nothing() -> void:
	if not _ready_for_sessions():
		return
	var clock: FakeClock = FakeClock.new(T)
	var first: GameSession = _launch(_dir, clock)
	_close(first)
	var before: Dictionary = _saved_starter(_dir)
	var journal_before: int = first.get_journal().size()
	clock.set_now(T - HOUR)
	var s: GameSession = _launch(_dir, clock)
	check_eq(s.get_last_catch_up().steps, 0, "steps")
	check(not s.get_last_catch_up().reanchored, "not re-anchored")
	check_eq(s.get_starter().to_dict(), before, "starter unchanged, anchor kept")
	check_eq(s.get_journal().size(), journal_before, "no new journal entries")


## CLK-04: closed at T, opened at T - 1 h, closed, opened at T + 2 h: 2 h simulated in total.
func test_clk_04_back_then_forward_counts_once() -> void:
	if not _ready_for_sessions():
		return
	var clock: FakeClock = FakeClock.new(T)
	_close(_launch(_dir, clock))
	clock.set_now(T - HOUR)
	var early: GameSession = _launch(_dir, clock)
	var total: int = early.get_last_catch_up().simulated_s
	_close(early)
	clock.set_now(T + 2 * HOUR)
	var s: GameSession = _launch(_dir, clock)
	total += s.get_last_catch_up().simulated_s
	check_eq(total, 2 * HOUR, "simulated across both launches")
	check_eq(s.get_starter().sim_time_unix, T + 2 * HOUR, "sim_time_unix")


## CLK-05: a 5-year jump forward (capped at 14 d), then the clock is corrected (re-anchor once),
## then a launch 1 h later simulates exactly 1 h.
func test_clk_05_jump_ahead_then_corrected() -> void:
	if not _ready_for_sessions():
		return
	var clock: FakeClock = FakeClock.new(T)
	_close(_launch(_dir, clock))
	clock.set_now(T + 5 * 365 * DAY)
	var future: GameSession = _launch(_dir, clock)
	check(future.get_last_catch_up().capped, "5 years: capped")
	_close(future)
	clock.set_now(T + HOUR)
	var corrected: GameSession = _launch(_dir, clock)
	check(corrected.get_last_catch_up().reanchored, "corrected clock: re-anchored")
	check_eq(corrected.get_last_catch_up().steps, 0, "corrected clock: nothing simulated")
	_close(corrected)
	clock.set_now(T + 2 * HOUR)
	var s: GameSession = _launch(_dir, clock)
	check_eq(s.get_last_catch_up().simulated_s, HOUR, "1 h later: 1 h simulated")
	check(not s.get_last_catch_up().reanchored, "1 h later: no second re-anchor")
	check_eq(_meta(s).get("clock_reanchors"), 1.0, "meta.clock_reanchors")


## CLK-08: 14 d - 60 s, exactly 14 d, and 14 d + 60 s away. simulated_s = min(elapsed, 14 d).
func test_clk_08_cap_boundary() -> void:
	if not _ready_for_sessions():
		return
	for elapsed: int in [CAP - 60, CAP, CAP + 60]:
		var dir: String = _dir.path_join(str(elapsed))
		var clock: FakeClock = FakeClock.new(T)
		_close(_launch(dir, clock))
		clock.set_now(T + elapsed)
		var r: CatchUpResult = _launch(dir, clock).get_last_catch_up()
		check_eq(r.simulated_s, mini(elapsed, CAP), "simulated_s for %d s away" % elapsed)
		if elapsed != CAP:
			check_eq(r.capped, elapsed > CAP, "capped for %d s away" % elapsed)


## CLK-11: 20 background and foreground cycles within 2 s simulate nothing extra and add no
## journal entries. on_background() twice in a row changes nothing the second time.
func test_clk_11_rapid_background_cycles() -> void:
	if not _ready_for_sessions():
		return
	var clock: FakeClock = FakeClock.new(T)
	var s: GameSession = _launch(_dir, clock)
	var starter_before: Dictionary = s.get_starter().to_dict()
	var journal_before: int = s.get_journal().size()
	for i: int in 20:
		s.on_background()
		s.on_background()
		if i % 10 == 9:
			clock.advance(1)
		s.on_resume()
	check_eq(s.get_starter().to_dict(), starter_before, "no grid step in 2 s")
	check_eq(s.get_journal().size(), journal_before, "no journal entries")
	clock.advance(58)
	s.tick()
	check_eq(s.get_starter().sim_time_unix, T + 60, "exactly one step once a minute has passed")


## CLK-12: the clock reads 1970. Re-anchor with the state unchanged. Correcting the clock later
## credits the gap, capped at 14 d (the accepted limit, ADR-006).
func test_clk_12_clock_reads_1970() -> void:
	if not _ready_for_sessions():
		return
	var clock: FakeClock = FakeClock.new(T)
	_close(_launch(_dir, clock))
	var before: Dictionary = _saved_starter(_dir)
	clock.set_now(0)
	var s: GameSession = _launch(_dir, clock)
	check(s.get_last_catch_up().reanchored, "re-anchored")
	var after: Dictionary = s.get_starter().to_dict()
	check_eq(after.get("sim_time_unix"), 0, "anchor = grid(0)")
	before.erase("sim_time_unix")
	after.erase("sim_time_unix")
	check_eq(after, before, "state otherwise unchanged")
	_close(s)
	clock.set_now(T + 60)
	var r: CatchUpResult = _launch(_dir, clock).get_last_catch_up()
	check(r.capped, "the corrected clock credits the gap, capped")
	check_eq(r.simulated_s, CAP, "at 14 d")


## CLK-14: 3 h with the app open equals 3 h closed. Compares the sim state (starter and
## environment). Events and journal may differ by design: a peak seen in the foreground is
## peak_now, one that happened while closed is peaked_while_away (AC-10.12).
func test_clk_14_open_equals_closed() -> void:
	if not _ready_for_sessions():
		return
	var base: String = _dir.path_join("base")
	_close(_launch(base, FakeClock.new(T)))
	var open_dir: String = _dir.path_join("open")
	var closed_dir: String = _dir.path_join("closed")
	QaTemp.copy_files(base, open_dir)
	QaTemp.copy_files(base, closed_dir)
	var open_clock: FakeClock = FakeClock.new(T)
	var open: GameSession = _launch(open_dir, open_clock)
	for minute: int in 180:
		open_clock.advance(60)
		open.tick()
	var closed: GameSession = _launch(closed_dir, FakeClock.new(T + 3 * HOUR))
	check_eq(open.get_starter().sim_time_unix, T + 3 * HOUR, "open: sim_time_unix")
	check_eq(open.get_starter().to_dict(), closed.get_starter().to_dict(), "starter, open vs closed")
	check_eq(open.get_environment().to_dict(), closed.get_environment().to_dict(), "environment")


## CLK-16 through Session: back exactly 6 h holds, back 6 h and 1 s re-anchors.
func test_clk_16_session_boundary() -> void:
	if not _ready_for_sessions():
		return
	for back: int in [21600, 21601]:
		var dir: String = _dir.path_join(str(back))
		var clock: FakeClock = FakeClock.new(T)
		_close(_launch(dir, clock))
		clock.set_now(T - back)
		var s: GameSession = _launch(dir, clock)
		check_eq(s.get_last_catch_up().reanchored, back > 21600, "re-anchored when back %d s" % back)
		check_eq(s.get_starter().sim_time_unix, T if back == 21600 else Sim.grid(T - back), "anchor, back %d s" % back)


## CLK-17, the accepted limit (ADR-006): the clock goes back 2 d (re-anchor), the player plays
## 1 h, then the clock is corrected. The next launch credits the 2 d gap, never more than 14 d.
func test_clk_17_corrected_backwards_jump_credits_the_gap() -> void:
	if not _ready_for_sessions():
		return
	var clock: FakeClock = FakeClock.new(T)
	_close(_launch(_dir, clock))
	clock.set_now(T - 2 * DAY)
	var s: GameSession = _launch(_dir, clock)
	check(s.get_last_catch_up().reanchored, "re-anchored at T - 2 d")
	for minute: int in 60:
		clock.advance(60)
		s.tick()
	_close(s)
	clock.set_now(T + HOUR)
	var r: CatchUpResult = _launch(_dir, clock).get_last_catch_up()
	check_eq(r.simulated_s, 2 * DAY, "credits the 2 d gap")
	check(r.simulated_s <= CAP and not r.capped, "within the cap")


# ------------------------------------------------------------------ helpers

func _ready_for_sessions() -> bool:
	return require(&"m4_save") and require(&"m5_catchup")


## A launch: a new Session on `dir`, booted against `clock`.
func _launch(dir: String, clock: FakeClock) -> GameSession:
	DirAccess.make_dir_recursive_absolute(dir)
	var s: GameSession = GameSession.new()
	_sessions.append(s)
	s.setup(clock, SaveStore.new(dir))
	s.boot()
	return s


## Closing the app: background (advance and save). The session object is then unused.
func _close(s: GameSession) -> void:
	s.on_background()


func _meta(s: GameSession) -> Dictionary:
	return s.build_payload().get("meta", {})


## The starter as a fresh launch reads it from `dir`'s save. "State unchanged" compares against
## this, not the in-memory starter, because in 4.7.2 a JSON save round trip can move a double by
## 1 ulp (see test_save_engine_facts.gd). That is SAVE-01's concern, not the clock rule's.
func _saved_starter(dir: String) -> Dictionary:
	var payload: Dictionary = SaveStore.new(dir).load_latest().payload
	var starter: StarterState = StarterState.from_dict(payload.get("starter", {}))
	return {} if starter == null else starter.to_dict()
