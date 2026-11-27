extends TestCase
## Places (art-direction.md §19): presets, the 18 mm lift and its five conditions (§19.4).

const U := preload("res://tests/unit/view/view_test_util.gd")
const DT: float = 1.0 / 60.0

var world: WorldView


func before_each() -> void:
	await U.tree_ready()
	world = (load("res://src/view/world.tscn") as PackedScene).instantiate() as WorldView
	world.follow_session = false
	(Engine.get_main_loop() as SceneTree).root.add_child(world)
	world.set_process(false)


func after_each() -> void:
	world.queue_free()


func _run(seconds: float) -> void:
	for i: int in int(ceil(seconds / DT)):
		world._process(DT)


func test_unknown_place_falls_back_to_counter_and_presets_differ() -> void:
	check_eq(PlacePresets.resolve(&""), &"counter", "empty id")
	check_eq(PlacePresets.resolve(&"attic"), &"counter", "unknown id")
	check_eq(float(PlacePresets.preset(&"window_sill")["window_set"]), 1.0, "window sill shows the bay")
	check_eq(float(PlacePresets.preset(&"proofing_box")["box"]), 1.0, "the box shows in the proofing box")
	check_eq(float(PlacePresets.preset(&"fridge")["fog"]), 0.3, "fridge glass fog")
	check_eq(PlacePresets.preset(&"window_sill")["night_floor"], Color("#15181C"), "cool night floor at the window")


func test_lift_peaks_at_18_mm_and_ends_at_exactly_zero() -> void:
	var peak: float = 0.0
	var t: float = 0.0
	while t < 1.4:
		peak = maxf(peak, PlacePresets.lift_offset(t, false))
		t += 0.01
	check_close(peak, 0.018, 0.0, 1e-4, "lifts 18 mm")
	check_eq(PlacePresets.lift_offset(PlacePresets.MOVE_S, false), 0.0, "back at the origin at 1.30 s")
	check_eq(PlacePresets.lift_offset(0.5, true), 0.0, "reduce motion: no lift")


func test_move_ends_with_the_jar_root_at_the_origin() -> void:
	world.set_place(&"proofing_box", true)
	check(world.is_moving(), "a move starts")
	_run(0.5)
	check(world.jar.position.y > 0.01, "lifted mid-move, got %s" % world.jar.position.y)
	_run(1.0)
	check(not world.is_moving(), "the move ends by 1.3 s")
	check_eq(world.jar.position, Vector3.ZERO, "root snapped to (0, 0, 0)")
	check(world.jar.box.visible, "the box shows")
	check_eq(float(world._place_now["box"]), 1.0, "the counter shade is on")


func test_second_move_retargets_without_stacking() -> void:
	world.set_place(&"window_sill", true)
	_run(0.4)
	world.set_place(&"proofing_box", true)
	var highest: float = 0.0
	for i: int in 100:
		world._process(DT)
		highest = maxf(highest, world.jar.position.y)
	check(highest <= PlacePresets.LIFT_M + 1e-6, "offsets never stack, max %s" % highest)
	check_eq(world.place, &"proofing_box", "retargeted")
	check_eq(world.jar.position, Vector3.ZERO, "ends at the origin")


func test_focus_waits_for_the_lift() -> void:
	world.set_place(&"window_sill", true)
	world._on_focus_requested(&"bubbles")
	check_eq(world.rig.focus_target, &"", "no focus during the lift")
	_run(1.4)
	check_eq(world.rig.focus_target, &"bubbles", "focus applied when the lift ends")


func test_reduce_motion_is_a_short_crossfade_without_lift() -> void:
	world.set_reduce_motion(true)
	world.set_place(&"window_sill", true)
	var highest: float = 0.0
	for i: int in 30:
		world._process(DT)
		highest = maxf(highest, world.jar.position.y)
	check_eq(highest, 0.0, "no lift")
	check(not world.is_moving(), "done in 0.4 s")
