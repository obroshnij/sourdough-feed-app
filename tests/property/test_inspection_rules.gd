extends TestCase
## AC-08.4's parts not covered by T3's chips-and-card tests: the readouts follow spec §14 at its thresholds
## (value - ε and value), fuzz shows only on a moldy starter, and the camera reaches an inspection's framing
## in 500 ms (at once with reduce motion). Numbers are spec §14's, written out here.

const EPS: float = 1e-6
## Spec §14 height levels: [lower bound, observation].
const HEIGHT_LEVELS: Array[Array] = [
	[1.1, &"a_little"], [1.5, &"nearly_doubled"], [1.85, &"doubled"], [2.4, &"more_than_doubled"],
]


func test_ac_08_4_height_and_surface_follow_spec_14_at_their_thresholds() -> void:
	if not require(&"m2_sim"):
		return
	var env: EnvironmentState = EnvironmentState.at_location(&"counter")
	var base: StarterState = SimFixtures.mature()
	var below: StringName = &"at_mark"
	for row: Array in HEIGHT_LEVELS:
		var edge: float = row[0]
		var s: StarterState = base.copy()
		s.peak_rise = 2.9
		s.rise = edge - EPS
		check_eq(_obs(s, env, &"height")[0], below, "rise %s" % show(s.rise))
		s.rise = edge
		check_eq(_obs(s, env, &"height")[0], row[1], "rise %s" % show(edge))
		below = row[1]
	var streak: StarterState = base.copy()
	streak.rise = 1.8
	streak.peak_rise = 1.8 + 0.2 - EPS
	check(not _obs(streak, env, &"height").has(&"streak_line"), "no streak line just under 0.2 below the peak")
	streak.peak_rise = 1.8 + 0.2 + 1e-12  # 2.0 - 1.8 is 0.19999999999999996 in doubles
	check(_obs(streak, env, &"height").has(&"streak_line"), "a streak line at 0.2 below the peak")
	# Surface: hooch bands 0.1, 0.4, 0.8; dark from 0.1 once mold risk reaches 0.3; skin 0.3, crust 0.7.
	var hooch_rows: Array[Array] = [[0.1 - EPS, &""], [0.1, &"hooch_thin"], [0.4 - EPS, &"hooch_thin"],
		[0.4, &"hooch_layer"], [0.8 - EPS, &"hooch_layer"], [0.8, &"hooch_dark"]]
	for row: Array in hooch_rows:
		var s: StarterState = base.copy()
		s.mold_risk = 0.0
		s.hooch = row[0]
		var obs: Array[StringName] = _obs(s, env, &"surface")
		var want: StringName = row[1]
		for line: StringName in [&"hooch_thin", &"hooch_layer", &"hooch_dark"]:
			check_eq(obs.has(line), line == want, "hooch %s: %s" % [show(s.hooch), line])
	var watch: StarterState = base.copy()
	watch.hooch = 0.1
	watch.mold_risk = 0.3
	check(_obs(watch, env, &"surface").has(&"hooch_dark"), "hooch at 0.1 reads dark once mold risk is 0.3")
	for row: Array in [[0.3 - EPS, &""], [0.3, &"skin"], [0.7 - EPS, &"skin"], [0.7, &"crust"]]:
		var s: StarterState = base.copy()
		s.dryness = row[0]
		var obs: Array[StringName] = _obs(s, env, &"surface")
		check_eq(obs.has(&"skin"), row[1] == &"skin", "dryness %s: skin" % show(s.dryness))
		check_eq(obs.has(&"crust"), row[1] == &"crust", "dryness %s: crust" % show(s.dryness))
	# Fuzz only when moldy, through a whole neglect run (PROP-16's surface part).
	var run: StarterState = SimFixtures.mature()
	SimFixtures.feed_ratio(run)
	var wrong: int = 0
	for minute: int in 240 * 60:
		Sim.step(run, env)
		if minute % 30 == 0 and _obs(run, env, &"surface").has(&"fuzzy_spots") != run.moldy:
			wrong += 1
	check(run.moldy, "the run reached mold")
	check_eq(wrong, 0, "fuzzy spots show exactly when moldy")


func test_ac_08_4_the_camera_reaches_an_inspection_in_500_ms() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	await tree.process_frame
	for reduce: bool in [false, true]:
		var rig := OrbitCamera.new()
		tree.root.add_child(rig)
		rig.set_process(false)
		rig.reduce_motion = reduce
		rig.focus(&"surface")
		var dt: float = 1.0 / 60.0
		if not reduce:
			for i: int in 24:  # 0.4 s
				rig._process(dt)
			check(absf(rig.pitch - 76.0) > 0.5, "not there yet at 0.4 s (pitch %.2f)" % rig.pitch)
			for i: int in 7:  # to 0.5 s and one frame
				rig._process(dt)
		else:
			rig._process(dt)
		check_close(rig.pitch, 76.0, 0.0, 0.1, "reduce motion %s: at the surface framing by 0.5 s" % reduce)
		rig.free()


static func _obs(s: StarterState, env: EnvironmentState, kind: StringName) -> Array[StringName]:
	return Inspection.read(s, env, kind).observations
