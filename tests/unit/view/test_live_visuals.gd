extends TestCase
## Phase 3 live visuals: VisualParams easing (art-direction.md §8), the feed sequence, bubble pops.

const U := preload("res://tests/unit/view/view_test_util.gd")
const DT: float = 1.0 / 60.0


func before_each() -> void:
	await U.tree_ready()


func _params(rise: float, dome: float, density: float) -> VisualParams:
	var p := VisualParams.new()
	p.rise = rise
	p.dome = dome
	p.bubble_density = density
	p.activity = 0.8
	p.bubble_size = 0.5
	return p


func test_easing_never_snaps_and_settles_in_about_1_5_s() -> void:
	var e := VisualEaser.new()
	e.set_goal(_params(1.0, 0.1, 0.1))
	e.snap()
	e.set_goal(_params(2.3, 0.8, 0.65))
	var prev: float = e.shown.rise
	var max_step: float = 0.0
	for i: int in 30:
		e.step(DT)
		max_step = maxf(max_step, absf(e.shown.rise - prev))
		prev = e.shown.rise
	check(max_step < 0.1, "a 1.3 rise jump moves at most 0.1 per frame, got %s" % max_step)
	check(e.shown.rise < 2.3 - 0.1, "not there after 0.5 s")
	for i: int in 90:
		e.step(DT)
	check_close(e.shown.rise, 2.3, 0.0, 0.07, "within 5%% of the step after 1.5 s")
	for i: int in 240:
		e.step(DT)
	check(e.is_settled(), "settled after 5.5 s")
	check(e.shown.rise <= 2.3 + 1e-6, "critically damped: no overshoot")


func test_easing_moves_tint_and_copies_cover() -> void:
	var e := VisualEaser.new()
	e.set_goal(VisualParams.new())
	e.snap()
	var g := VisualParams.new()
	g.tint = Color(0.84, 0.72, 0.56)
	g.cover = &"cloth"
	e.set_goal(g)
	e.step(DT)
	check_eq(e.shown.cover, &"cloth", "cover follows at once")
	check(e.shown.tint.r < 1.0 and e.shown.tint.r > 0.84, "tint eases")


func test_snap_fields_only_jumps_those_fields() -> void:
	var e := VisualEaser.new()
	e.set_goal(_params(2.3, 0.8, 0.65))
	e.snap()
	e.set_goal(_params(1.0, 0.1, 0.1))
	e.snap_fields([&"rise"])
	check_eq(e.shown.rise, 1.0, "rise jumped")
	check_close(e.shown.dome, 0.8, 0.0, 1e-6, "dome still eases")


func test_feed_discard_then_settle_band_overshoots_six_percent() -> void:
	var f := FeedMoment.new()
	f.begin(&"discard")
	for i: int in 36:
		f.step(DT)
	check_close(f.rise_mul, FeedMoment.DISCARD_TO, 0.0, 0.01, "level drops over 0.6 s")
	f.begin(&"scoop")
	var dust_at: float = -1.0
	for i: int in 60:
		f.step(DT)
		if f.dust and dust_at < 0.0:
			dust_at = float(i + 1) * DT
	check_close(dust_at, 0.45, 0.0, 0.02, "flour dust lands at scoop + 0.45 s")
	f.begin(&"pour")
	f.begin(&"settle")
	var peak: float = 0.0
	for i: int in 60:
		f.step(DT)
		peak = maxf(peak, f.band_t)
	check_close(peak, 1.06, 0.0, 0.01, "band snap overshoots about 6%%")
	for i: int in 120:
		f.step(DT)
	check(not f.active(), "the feed sequence ends")
	check_eq(f.rise_mul, 1.0, "level back to the sim's")
	check_eq(f.lid, 0.0, "lid back on")


func test_feed_without_a_state_times_out() -> void:
	var f := FeedMoment.new()
	f.begin(&"discard")
	for i: int in int(11.0 / DT):
		f.step(DT)
	check(not f.active(), "eases back after the timeout")
	check_eq(f.rise_mul, 1.0, "no stuck level")


func test_pops_are_deterministic_and_come_only_from_params() -> void:
	check_eq(BubblePops.pop_spot(7), BubblePops.pop_spot(7), "same serial, same spot")
	check_ne(BubblePops.pop_spot(7), BubblePops.pop_spot(8), "different serials differ")
	var p := _params(2.3, 0.8, 0.65)
	check_close(BubblePops.pop_rate(p), 0.8 * 0.4 * (0.3 + 0.7 * 0.65), 0.0, 1e-6, "activity x 0.4 per s, scaled by density")
	p.hooch_depth = 0.35
	check_eq(BubblePops.pop_rate(p), 0.0, "no pops under hooch")
	p.hooch_depth = 0.0
	p.mold = 0.75
	check_eq(BubblePops.pop_rate(p), 0.0, "no pops on a moldy starter")
	var small: VisualParams = _params(2.3, 0.8, 0.65)
	small.bubble_size = 0.0
	var big: VisualParams = _params(2.3, 0.8, 0.65)
	big.bubble_size = 1.0
	check(BubblePops.pop_radius_m(big, 0.5) > BubblePops.pop_radius_m(small, 0.5), "bubble_size sets the pop size")
	for n: int in 200:
		var s: Vector3 = BubblePops.pop_spot(n)
		check(s.x >= 0.0 and s.x <= 0.85, "spot %d inside the cap" % n)


func test_pops_spawn_on_the_surface_and_stop_with_reduce_motion() -> void:
	var pops := BubblePops.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(pops)
	pops.set_process(false)
	pops.set_params(_params(2.3, 0.8, 0.65))
	for i: int in 600:
		pops.advance(DT)
	check(pops.serial >= 2, "pops happen at an active peak, got %d" % pops.serial)
	check(pops.live_count() <= BubblePops.MAX_POPS, "bounded")
	if pops.live_count() > 0:
		var y: float = pops.multimesh.get_instance_transform(0).origin.y
		var top: float = BubblePops.surface_y(pops.params, 0.0, JarGeometry.FLOOR_Y_M)
		check(y > JarGeometry.FLOOR_Y_M + 0.06 and y <= top + 0.001, "pop sits on the top surface, y=%s" % y)
	var before: int = pops.serial
	pops.motion_on = false
	for i: int in 600:
		pops.advance(DT)
	check_eq(pops.serial, before, "reduce motion: no new pops")
	pops.queue_free()


func test_smell_wisp_tints_never_use_reserved_hues() -> void:
	for fam: StringName in [&"fresh_yeasty", &"mildly_fruity", &"yogurt", &"wet_flour", &"pleasantly_tangy",
			&"strongly_acidic", &"alcohol", &"acetone", &"musty", &"cheesy"]:
		var c: Color = SmellWisps.tint_for(fam)
		var reserved: bool = c.s > 0.3 and (c.h * 360.0 < 25.0 or c.h * 360.0 > 330.0)
		check(not reserved, "%s tint %s is not pink, orange or red" % [fam, c.to_html(false)])
