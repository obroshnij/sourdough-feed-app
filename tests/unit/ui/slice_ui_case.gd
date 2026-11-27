class_name SliceUiCase
extends TestCase
## Shared setup for the Phase 3 UI tests: a real GameSession (FakeClock, temp saves) booted from one of
## the sim-made fixtures, the real UI mounted at 390 x 844 and bound to it, and a recorder on the Bus.
## Moments run at 5% speed (UiMotion.time_scale), so a test never waits seconds.

const H := preload("res://tests/unit/ui/ui_harness.gd")
const FIXTURES: String = "res://tests/unit/ui/fixtures"
const TMP: String = "user://test_tmp/ui_slice"

var tree: SceneTree = null
var ui: UiRoot = null
var session: GameSession = null
var clock: FakeClock = null
## [signal name, arg] in order.
var bus_heard: Array[Array] = []

var _links: Array[Array] = []


func before_each() -> void:
	I18nLoader.load_all()
	UiMotion.reduce = true
	UiMotion.time_scale = 0.05
	tree = Engine.get_main_loop() as SceneTree
	await tree.process_frame
	bus_heard.clear()
	var bus: Node = tree.root.get_node_or_null(^"Bus")
	if bus != null:
		var script: Script = bus.get_script() as Script
		for sig: Dictionary in script.get_script_signal_list():
			var sig_name: StringName = sig["name"]
			var argc: int = (sig["args"] as Array).size()
			var cb: Callable = _record0.bind(sig_name) if argc == 0 else _record1.bind(sig_name)
			bus.connect(sig_name, cb)
			_links.append([bus, sig_name, cb])


func after_each() -> void:
	UiMotion.reduce = false
	UiMotion.time_scale = 1.0
	Toast.keep_messages = false
	for link: Array in _links:
		var node: Node = link[0]
		var sig_name: StringName = link[1]
		var cb: Callable = link[2]
		if node.is_connected(sig_name, cb):
			node.disconnect(sig_name, cb)
	_links.clear()
	if ui != null:
		ui.get_parent().queue_free()
		ui = null
	if session != null:
		session.queue_free()
		session = null
	await tree.process_frame


## Boots a Session from tests/unit/ui/fixtures/<fixture>.json and mounts the UI bound to it.
func boot(fixture: String, device: String = "iphone_17e_390x844") -> void:
	var dir: String = "%s/%s_%d" % [TMP, fixture, Time.get_ticks_usec()]
	clock = FakeClock.new()
	session = GameSession.new()
	tree.root.add_child(session)
	session.setup(clock, SaveStore.new(dir), SettingsStore.new(dir + "/settings.cfg"))
	session.boot_from_fixture("%s/%s.json" % [FIXTURES, fixture])
	ui = H.mount(tree.root, device)
	ui.bind_session(session)
	await H.settle(tree, 3)


## A first launch: no save, so the Session starts the gifted starter with no name (is_first_run()).
func boot_new(device: String = "iphone_17e_390x844") -> void:
	var dir: String = "%s/new_%d" % [TMP, Time.get_ticks_usec()]
	clock = FakeClock.new()
	session = GameSession.new()
	tree.root.add_child(session)
	session.setup(clock, SaveStore.new(dir), SettingsStore.new(dir + "/settings.cfg"))
	ui = H.mount(tree.root, device)
	ui.bind_session(session)
	session.boot()
	await H.settle(tree, 3)


## A synthetic event for presenter tests (not in the Session's ledger, so an ack is refused harmlessly).
static func event(id: StringName, tier: StringName, uid: int) -> SimEvent:
	var e := SimEvent.new()
	e.id = id
	e.tier = tier
	e.uid = uid
	return e


func wait(seconds: float) -> void:
	await tree.create_timer(seconds).timeout


## A tap on an action bar button, the way a finger does it (press, release, pressed).
func tap_action(id: StringName) -> void:
	var b: ActionBarButton = ui.hud.bar_button(id)
	b.button_down.emit()
	b.button_up.emit()
	b.pressed.emit()
	await wait(0.4)


func heard(signal_name: StringName) -> Array:
	var out: Array = []
	for row: Array in bus_heard:
		if row[0] == signal_name:
			out.append(row[1])
	return out


func _record0(signal_name: StringName) -> void:
	bus_heard.append([signal_name, null])


func _record1(arg: Variant, signal_name: StringName) -> void:
	bus_heard.append([signal_name, arg])
