class_name SettingsSheet
extends Sheet
## Settings (ux-design §14), Phase 2 stubs: text size and reduce motion. Both are in-app settings because
## Godot 4.7.2 can't read the phone's text size or reduce-motion values. "Change text size" is 2 taps:
## the gear, then a size chip (ux-design §7).

signal text_scale_chosen(text_scale: float)
signal reduce_motion_toggled(on: bool)
## &"haptics" or &"keep_messages".
signal toggle_changed(setting: StringName, on: bool)

const SIZE_KEYS: Array[StringName] = [&"SETTINGS_TEXT_STANDARD", &"SETTINGS_TEXT_LARGE", &"SETTINGS_TEXT_LARGEST"]

var size_label: Label = null
var size_chips: Array[Chip] = []
var reduce_motion_row: ToggleRow = null
var haptics_row: ToggleRow = null
var keep_messages_row: ToggleRow = null
var _group := ButtonGroup.new()
var _syncing: bool = false


func _init() -> void:
	sheet_id = &"settings"
	title_key = &"SETTINGS_TITLE"
	height_kind = Sheet.Height.FULL


func _build_content(box: VBoxContainer) -> void:
	size_label = Label.new()
	size_label.name = "TextSizeLabel"
	size_label.theme_type_variation = &"SectionLabel"
	size_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	size_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(size_label)
	var flow := HFlowContainer.new()
	flow.name = "TextSizes"
	flow.add_theme_constant_override(&"h_separation", 8)
	flow.add_theme_constant_override(&"v_separation", 8)
	box.add_child(flow)
	for i: int in SIZE_KEYS.size():
		var chip := Chip.new(SIZE_KEYS[i])
		chip.name = "Size%d" % i
		chip.button_group = _group
		chip.toggled.connect(_on_size_toggled.bind(i))
		flow.add_child(chip)
		size_chips.append(chip)
	var sep := HSeparator.new()
	box.add_child(sep)
	reduce_motion_row = ToggleRow.new(&"SETTINGS_REDUCE_MOTION")
	reduce_motion_row.name = "ReduceMotion"
	reduce_motion_row.toggled.connect(func(on: bool) -> void:
		if not _syncing:
			reduce_motion_toggled.emit(on))
	box.add_child(reduce_motion_row)
	haptics_row = _toggle(box, &"SETTINGS_HAPTICS", &"haptics")
	keep_messages_row = _toggle(box, &"SETTINGS_KEEP_MESSAGES", &"keep_messages")


func _toggle(box: VBoxContainer, key: StringName, setting: StringName) -> ToggleRow:
	var row := ToggleRow.new(key)
	row.name = String(setting).capitalize().replace(" ", "")
	row.toggled.connect(func(on: bool) -> void:
		if not _syncing:
			toggle_changed.emit(setting, on))
	box.add_child(row)
	return row


## Shows the stored haptics and keep-messages values without emitting.
func sync_toggles(store: SettingsStore) -> void:
	_syncing = true
	haptics_row.set_pressed_no_signal(store.haptics)
	keep_messages_row.set_pressed_no_signal(store.keep_messages)
	haptics_row.queue_redraw()
	keep_messages_row.queue_redraw()
	_syncing = false


## Shows the stored values without emitting.
func sync_from(text_scale: float, reduce_motion: bool) -> void:
	_syncing = true
	var idx: int = TypeScale.index_of(text_scale)
	for i: int in size_chips.size():
		size_chips[i].set_pressed_no_signal(i == idx)
		size_chips[i].toggled.emit(i == idx)
	reduce_motion_row.set_pressed_no_signal(reduce_motion)
	reduce_motion_row.queue_redraw()
	_syncing = false


func _refresh_text() -> void:
	super._refresh_text()
	if size_label != null:
		size_label.text = tr(&"SETTINGS_TEXT_SIZE")


func _on_size_toggled(on: bool, index: int) -> void:
	if on and not _syncing:
		text_scale_chosen.emit(TypeScale.SCALES[index])
