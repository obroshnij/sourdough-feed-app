extends CoreCase
## The F3 dev overlay drives the debug time scale and jumps, through the time-travel sandbox. Owner: T1.


func test_overlay_drives_debug_time_through_the_sandbox() -> void:
	if not require(&"p3_rules"):
		return
	var dir: String = fresh_dir("overlay")
	_dirs.append(dir + GameSession.TIME_TRAVEL_SUFFIX)
	var s := GameSession.new()
	s.setup(DebugClock.new(1.0), SaveStore.new(dir))
	s.boot()
	s.apply(AdoptStarterAction.new("Bramble"))
	var o := DevOverlay.new()
	o.session = s
	o._ready()
	check(not o.visible, "hidden until F3")
	check(o.set_scale_to(600.0) and s.get_debug_time_scale() == 600.0, "600x")
	check(s.is_time_traveling(), "time travel saves to the sandbox")
	var r: CatchUpResult = o.jump(86400)
	check(r.simulated_s >= 86400 - 60 and s.get_return_summary().show, "+1 d plays the return flow")
	check(o.set_scale_to(1.0) and s.is_time_traveling(), "back to 1x, still in the sandbox for this run")
	check(InputMap.has_action(&"dev_overlay"), "F3 is mapped")
	o.free()
	s.free()


## D-063: a phone has no F3 key, so a three-finger hold toggles the overlay. QA's frame-time line.
func test_three_finger_hold_toggles_and_frame_times_are_reported() -> void:
	if not require(&"p4_contracts"):
		return
	var o := DevOverlay.new()
	o.visible = false  # as _ready() leaves it; _ready() needs the scene tree for the Session autoload
	o.note_touch(0, true)
	o.note_touch(1, true)
	check(not o.advance_hold(2.0), "two fingers do nothing")
	o.note_touch(2, true)
	check(not o.advance_hold(DevOverlay.HOLD_S * 0.5), "not yet")
	check(o.advance_hold(DevOverlay.HOLD_S * 0.6) and o.visible, "a held three-finger touch shows it")
	check(not o.advance_hold(5.0) and o.visible, "once per hold")
	o.note_touch(2, false)
	o.note_touch(2, true)
	check(not o.advance_hold(5.0), "still the same hold until every finger lifts")
	for i: int in 3:
		o.note_touch(i, false)
	for i: int in 3:
		o.note_touch(i, true)
	check(o.advance_hold(DevOverlay.HOLD_S) and not o.visible, "a new hold hides it")
	check_eq(o.frame_stats(), Vector2.ZERO, "no frames yet")
	for i: int in 1200:
		o.record_frame(1.0 / 60.0 if i % 10 != 0 else 0.05)
	var f: Vector2 = o.frame_stats()
	check_close(f.x, 1000.0 / 60.0, 0.01, 0.0, "p50 about 16.7 ms")
	check_close(f.y, 50.0, 0.01, 0.0, "p95 catches the 1-in-10 slow frames")
	o.free()
