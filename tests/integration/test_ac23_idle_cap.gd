extends TestCase
## Phase 4, AC-23.1 (PERF-02): the idle frame cap, through the real Session autoload and the Bus. 3 s
## (IDLE_AFTER_S) after `interaction_ended` with no input, Engine.max_fps drops to 30; `interaction_started`
## brings 60 back at once. Waits about 3.4 s of real time. AC-23.2 (60 during every non-camera animation)
## waits for T2's battery work (OD-27): today only OrbitCamera emits these signals.

var _fps_before: int = 0


func before_each() -> void:
	_fps_before = Engine.max_fps
	await (Engine.get_main_loop() as SceneTree).process_frame


func after_each() -> void:
	var bus: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Bus")
	if bus != null:
		bus.emit_signal(&"interaction_started")  # stops the Session's idle timer
	Engine.max_fps = _fps_before


func test_ac_23_1_idle_cap_after_three_seconds_and_back_at_once() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var bus: Node = tree.root.get_node_or_null("Bus")
	var session: Node = tree.root.get_node_or_null("Session")
	if not check(bus != null and session != null, "the Bus and Session autoloads are running"):
		return
	check_eq(GameSession.ACTIVE_FPS, 60, "active cap 60 (architecture §11)")
	check_eq(GameSession.IDLE_FPS, 30, "idle cap 30 (PERF-02)")
	check_eq(GameSession.IDLE_AFTER_S, 3.0, "idle after 3 s")
	bus.emit_signal(&"interaction_started")
	check_eq(Engine.max_fps, GameSession.ACTIVE_FPS, "60 while interacting")
	bus.emit_signal(&"interaction_ended")
	check_eq(Engine.max_fps, GameSession.ACTIVE_FPS, "still 60 right after the interaction ends")
	await tree.create_timer(GameSession.IDLE_AFTER_S - 1.0).timeout
	check_eq(Engine.max_fps, GameSession.ACTIVE_FPS, "still 60 at 2 s")
	await tree.create_timer(1.4).timeout
	check_eq(Engine.max_fps, GameSession.IDLE_FPS, "30 once 3 s pass with no input")
	bus.emit_signal(&"interaction_started")
	check_eq(Engine.max_fps, GameSession.ACTIVE_FPS, "60 again the moment an interaction starts")
