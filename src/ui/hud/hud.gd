class_name Hud
extends Control
## The main-screen HUD (ux-design §4): the top plate (name, status pill, hint, settings) and the bottom
## action bar in the thumb zone. Reads StarterSnapshot only (CLAUDE.md rule 2): no digits, no meters.
## Touch routing (ux-design §6): the top plate and every layout node IGNORE touches, so a drag that starts
## on the plate still orbits the jar. Only the pill and the settings button inside it STOP. The action bar
## plate STOPs across its whole area.

signal action_requested(action_id: StringName)
signal locked_pressed(action_id: StringName, reason_key: StringName)
signal status_pressed()
signal settings_pressed()
## The plate or the bar changed size or place.
signal layout_changed()

const ACTIONS: Array[StringName] = [&"feed", &"smell", &"inspect", &"environment", &"journal"]
const BAR_HEIGHT: float = 72.0
## D-043 and narrative §9.2: what a locked button says. Smell shows the "Best not" card instead of a toast.
const MOLDY_LOCKS: Dictionary[StringName, StringName] = {
	&"feed": &"MOLD_FEED_BLOCKED", &"smell": &"SMELL_MOLDY_BODY", &"environment": &"REASON_MOLDY_LOCKED",
}

@onready var top_plate: PanelContainer = $TopPlate
@onready var name_label: FitLabel = $TopPlate/Rows/NameRow/Name
@onready var settings_button: IconButton = $TopPlate/Rows/NameRow/Settings
@onready var status_pill: StatusPill = $TopPlate/Rows/Status
@onready var hint_label: Label = $TopPlate/Rows/Hint
@onready var action_bar: PanelContainer = $ActionBar

var snapshot: StarterSnapshot = null
var _insets: SafeInsets = SafeInsets.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	status_pill.pressed.connect(_on_status_pressed)
	for b: ActionBarButton in bar_buttons():
		b.activated.connect(func(id: StringName) -> void: action_requested.emit(id))
		b.locked_pressed.connect(func(id: StringName, key: StringName) -> void: locked_pressed.emit(id, key))
	top_plate.resized.connect(func() -> void: layout_changed.emit())
	action_bar.resized.connect(func() -> void: layout_changed.emit())
	apply_insets(_insets)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and snapshot != null:
		_apply_hint()


func bar_buttons() -> Array[ActionBarButton]:
	var out: Array[ActionBarButton] = []
	for id: StringName in ACTIONS:
		out.append(bar_button(id))
	return out


func bar_button(action_id: StringName) -> ActionBarButton:
	return action_bar.get_node("Slots/%s" % String(action_id).capitalize().replace(" ", "")) as ActionBarButton


func apply_insets(insets: SafeInsets) -> void:
	_insets = insets
	top_plate.anchor_left = 0.0
	top_plate.anchor_right = 1.0
	top_plate.anchor_top = 0.0
	top_plate.anchor_bottom = 0.0
	top_plate.grow_vertical = Control.GROW_DIRECTION_END
	top_plate.offset_left = insets.gutter_left()
	top_plate.offset_right = -insets.gutter_right()
	top_plate.offset_top = insets.hud_top()
	top_plate.offset_bottom = insets.hud_top()
	action_bar.anchor_left = 0.0
	action_bar.anchor_right = 1.0
	action_bar.anchor_top = 1.0
	action_bar.anchor_bottom = 1.0
	action_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	action_bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	action_bar.offset_left = insets.gutter_left()
	action_bar.offset_right = -insets.gutter_right()
	action_bar.offset_bottom = -insets.bar_gap()
	action_bar.offset_top = -insets.bar_gap() - BAR_HEIGHT
	layout_changed.emit()


## The bottom of the top plate, in this control's coordinates.
func plate_bottom() -> float:
	return top_plate.position.y + top_plate.size.y


func bar_top() -> float:
	return action_bar.position.y


func set_snapshot(snap: StarterSnapshot) -> void:
	snapshot = snap
	name_label.set_fit_text(snap.name)
	status_pill.set_status(snap.state, snap.dormant_cause)
	_apply_hint()
	var feed: ActionBarButton = bar_button(&"feed")
	feed.emphasized = StatusStyle.FEED_EMPHASIS.has(snap.state) and snap.can_feed
	# D-043: while moldy, Feed, Smell and Place are locked, each with its reason. Inspect and Journal work.
	for id: StringName in MOLDY_LOCKS:
		bar_button(id).locked_reason_key = &"" if snap.can_feed else MOLDY_LOCKS[id]


## D-050: disabled and quiet while the Session catches up on a worker thread.
func set_actions_enabled(on: bool) -> void:
	for b: ActionBarButton in bar_buttons():
		if b.disabled == on:
			b.disabled = not on
			b.queue_redraw()


## Marks the button whose sheet is open (filled icon and the accent pill), or none.
func set_open_action(action_id: StringName) -> void:
	for b: ActionBarButton in bar_buttons():
		b.is_open = b.action_id == action_id


func _apply_hint() -> void:
	hint_label.text = tr(Keys.status_hint(snapshot.state, snapshot.dormant_cause))


func _on_status_pressed() -> void:
	status_pill.show_new_dot = false
	status_pressed.emit()
