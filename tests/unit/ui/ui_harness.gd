extends RefCounted
## Mounts the real UI (src/ui/ui_root.tscn) under a fixed-size root Control, never anchored to the window:
## the headless window stays 64 x 64 (test-plan OD-11). Used by the tests in tests/unit/ui/ and by the
## capture tool. Not a test file (no test_ prefix).

const UI_SCENE: String = "res://src/ui/ui_root.tscn"

## Device profiles in pt: size, safe top, safe bottom, OS (ux-design §2). The Android compact profile uses
## a 24 pt status bar; its bottom comes from the 48 floor.
const DEVICES: Dictionary[String, Array] = {
	"android_360x640": [Vector2(360, 640), 24.0, 0.0, "Android"],
	"iphone_se_375x667": [Vector2(375, 667), 20.0, 0.0, "iOS"],
	"iphone_17e_390x844": [Vector2(390, 844), 47.0, 34.0, "iOS"],
	"iphone_17_pro_max_440x956": [Vector2(440, 956), 62.0, 34.0, "iOS"],
}


static func device_size(device: String) -> Vector2:
	var row: Array = DEVICES[device]
	var v: Vector2 = row[0]
	return v


static func device_insets(device: String) -> SafeInsets:
	var row: Array = DEVICES[device]
	var t: float = row[1]
	var b: float = row[2]
	var os_name: String = row[3]
	return SafeInsets.make(t, b).with_floors(os_name)


## Returns the UiRoot, already inside `holder` (a Control of the device size, added to `parent`).
static func mount(parent: Node, device: String, text_scale: float = 1.0, night: float = 0.0) -> UiRoot:
	var holder := Control.new()
	holder.name = "FixedRoot_" + device
	holder.size = device_size(device)
	holder.clip_contents = false
	parent.add_child(holder)
	var packed: PackedScene = load(UI_SCENE)
	var layer: Node = packed.instantiate()
	var ui: UiRoot = layer.get_node(^"Root") as UiRoot
	layer.remove_child(ui)
	_clear_owner(ui)
	layer.free()
	holder.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.set_insets_override(device_insets(device))
	ui.set_text_scale(text_scale)
	ui.set_night_blend(night)
	return ui


static func snapshot(state: StringName, starter_name: String = "Bramble", cause: StringName = &"") -> StarterSnapshot:
	var s := StarterSnapshot.new()
	s.name = starter_name
	s.state = state
	s.dormant_cause = cause
	s.rise_phase = state
	s.is_warning = state == &"unhealthy" or state == &"moldy"
	s.can_feed = state != &"moldy"
	return s


## Every (state, dormant cause) pair the pill can show: 12, because dormant has two versions.
static func all_snapshots(starter_name: String = "Bramble") -> Array[StarterSnapshot]:
	var out: Array[StarterSnapshot] = []
	for st: StringName in StatusStyle.STATES:
		if st == &"dormant":
			out.append(snapshot(st, starter_name, &"cold"))
			out.append(snapshot(st, starter_name, &"starved"))
		else:
			out.append(snapshot(st, starter_name))
	return out


static func settle(tree: SceneTree, frames: int = 3) -> void:
	for i: int in frames:
		await tree.process_frame


## Every visible Control under `node`, depth first.
static func visible_controls(node: Node) -> Array[Control]:
	var out: Array[Control] = []
	_collect(node, out)
	return out


static func _collect(node: Node, out: Array[Control]) -> void:
	var c: Control = node as Control
	if c != null:
		if not c.is_visible_in_tree():
			return
		out.append(c)
	for child: Node in node.get_children():
		_collect(child, out)


static func _clear_owner(node: Node) -> void:
	node.owner = null
	for child: Node in node.get_children():
		_clear_owner(child)
