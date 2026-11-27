extends CoreCase
## The D-042 fallback: launch and resume catch-ups on a WorkerThreadPool thread give exactly the synchronous
## result, show the saved state first, and refuse actions until done. Owner: T1.

const H: int = 3600
const DAY: int = 86400


## A named, fed starter saved at T0 in `dir`, then closed.
func _saved_game(dir: String) -> void:
	var s := GameSession.new()
	s.setup(FakeClock.new(T0), SaveStore.new(dir))
	s.boot()
	s.apply(AdoptStarterAction.new("Bramble"))
	s.apply(FeedAction.from_ratio(1.0, 1.0, &"white_bread"))
	s.on_background()
	s.free()


func _copy_dir(from: String, to: String) -> void:
	for f: String in DirAccess.get_files_at(from):
		copy_file(from + "/" + f, to + "/" + f)


func test_async_launch_equals_the_synchronous_launch() -> void:
	if not require(&"p3_contracts"):
		return
	var a_dir: String = fresh_dir("async_a")
	_saved_game(a_dir)
	var b_dir: String = fresh_dir("async_b")
	_copy_dir(a_dir, b_dir)
	var sync := GameSession.new()
	sync.setup(FakeClock.new(T0 + 3 * DAY), SaveStore.new(a_dir))
	var sync_result: CatchUpResult = sync.boot()
	var async := GameSession.new()
	async.setup(FakeClock.new(T0 + 3 * DAY), SaveStore.new(b_dir))
	var order: Array[String] = []
	var first_state: Array[StringName] = []
	async.state_changed.connect(func(snap: StarterSnapshot, _v: VisualParams) -> void:
		order.append("state")
		if first_state.is_empty():
			first_state.append(snap.state))
	async.session_ready.connect(func(_r: CatchUpResult) -> void: order.append("ready"))
	async.boot_async()
	check(async.is_catching_up() and not async.is_booted(), "a 3-day catch-up runs on a worker thread")
	check(order == ["state"] and first_state[0] == &"freshly_fed", "the saved state shows at once: %s" % [order])
	check_eq(async.apply(SmellAction.new()).reason_key, GameSession.NOT_READY_KEY, "actions wait")
	async.tick()
	async.wait_for_catch_up()
	check(async.is_booted() and not async.is_catching_up(), "done")
	check_eq(order, ["state", "state", "ready"], "then the caught-up state, then session_ready")
	check_eq(async.get_last_catch_up().steps, sync_result.steps, "same number of steps")
	check_eq(payload_text(async.build_payload()), payload_text(sync.build_payload()),
		"byte-equal to the synchronous launch (PROP-02 style)")
	check_eq(async.get_return_summary().lines.size(), sync.get_return_summary().lines.size(), "same summary")
	sync.free()
	async.free()


func test_async_resume_equals_on_resume_and_short_ones_stay_synchronous() -> void:
	if not require(&"p3_contracts"):
		return
	var a_dir: String = fresh_dir("resume_a")
	_saved_game(a_dir)
	var b_dir: String = fresh_dir("resume_b")
	_copy_dir(a_dir, b_dir)
	var a_clock := FakeClock.new(T0 + H)
	var b_clock := FakeClock.new(T0 + H)
	var sync := GameSession.new()
	sync.setup(a_clock, SaveStore.new(a_dir))
	sync.boot()
	var async := GameSession.new()
	async.setup(b_clock, SaveStore.new(b_dir))
	async.boot_async()
	check(not async.is_catching_up() and async.is_booted(), "a 1 h catch-up stays on the main thread")
	sync.on_background()
	async.on_background()
	a_clock.advance(2 * DAY)
	b_clock.advance(2 * DAY)
	sync.on_resume()
	async.resume_async()
	check(async.is_catching_up(), "a 2-day resume runs on a worker thread")
	check_eq(async.apply(FeedAction.from_ratio(1.0, 1.0, &"white_bread")).reason_key, GameSession.NOT_READY_KEY,
		"no feed until it's done")
	async.wait_for_catch_up()
	check_eq(payload_text(async.build_payload()), payload_text(sync.build_payload()), "byte-equal to on_resume()")
	sync.free()
	async.free()


func test_strong_peak_reference_needs_a_real_peak() -> void:
	if not require(&"p3_contracts"):
		return
	var h := PlayerHistory.new()
	var env := EnvironmentState.at_location(&"counter")
	var s: StarterState = StarterPresets.make(&"first_restart", T0)
	var d: DerivedState = StateDeriver.derive(s, env)
	var feed: FeedAction = FeedAction.from_ratio(1.0, 1.0, &"white_bread")
	s.vigor_at_feed = 1.0
	h.record_action(feed, s, d)
	check_eq(h.last_strong_peak_rise, 0.0, "M.'s spare never peaked: its %.3f is not a reference" % s.peak_rise)
	var fed: StarterState = SimFixtures.mature()
	SimFixtures.feed_ratio(fed)
	var prev: DerivedState = StateDeriver.derive(fed, env)
	for i: int in 9 * 60:
		Sim.step(fed, env)
		var now_d: DerivedState = StateDeriver.derive(fed, env)
		h.record_step(fed, now_d, prev, false)
		prev = now_d
	check(h.cycle_reached_peak, "a full cycle reached at_peak")
	h.record_action(feed, fed, prev)
	check(h.last_strong_peak_rise > 1.9, "a real peak becomes the reference: %.3f" % h.last_strong_peak_rise)
	check(not h.cycle_reached_peak, "the feed starts a new cycle")
