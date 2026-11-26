class_name SheetHost
extends Control
## Holds every sheet and keeps at most one open (ux-design §1.4: no modal stacks). Opening another sheet
## closes the current one first.

signal sheet_opened(sheet_id: StringName)
signal sheet_closed(sheet_id: StringName)

var _current: Sheet = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s: Sheet in sheets():
		s.opened.connect(_on_opened.bind(s))
		s.closed.connect(_on_closed.bind(s))


func sheets() -> Array[Sheet]:
	var out: Array[Sheet] = []
	for child: Node in get_children():
		var s: Sheet = child as Sheet
		if s != null:
			out.append(s)
	return out


func sheet(sheet_id: StringName) -> Sheet:
	for s: Sheet in sheets():
		if s.sheet_id == sheet_id:
			return s
	return null


func current_id() -> StringName:
	return _current.sheet_id if _current != null else &""


func has_open_sheet() -> bool:
	return _current != null


func open(sheet_id: StringName) -> void:
	var target: Sheet = sheet(sheet_id)
	if target == null or target == _current:
		return
	if _current != null:
		_current.close()
	target.open()


func close_current() -> void:
	if _current != null:
		_current.close()


func set_insets(insets: SafeInsets) -> void:
	for s: Sheet in sheets():
		s.set_insets(insets)


func _on_opened(_id: StringName, s: Sheet) -> void:
	_current = s
	sheet_opened.emit(s.sheet_id)


func _on_closed(_id: StringName, s: Sheet) -> void:
	if _current == s:
		_current = null
	sheet_closed.emit(s.sheet_id)
