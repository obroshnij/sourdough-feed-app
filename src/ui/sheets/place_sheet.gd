class_name PlaceSheet
extends Sheet
## "Where it lives" (ux-design §13, game-copy §13, D-018): a 45% peek sheet with the P0 places as option
## cards, 3 across (2 across at the largest text). A choice applies at once through
## Session.apply(SetEnvironmentAction), with no confirmation. Selected: 3 pt accent border and a check badge.

signal refused(reason_key: StringName)

const PLACES: Array[StringName] = [&"counter", &"warm_spot", &"fridge"]
const SHARE: float = 0.45

var cards: Dictionary[StringName, ChoiceButton] = {}
var _grid: GridContainer = null
var _group := ButtonGroup.new()
var _syncing: bool = false


func _init() -> void:
	sheet_id = &"environment"
	title_key = &"PLACE_TITLE"
	height_kind = Sheet.Height.PEEK
	custom_share = SHARE


func _build_content(box: VBoxContainer) -> void:
	_grid = GridContainer.new()
	_grid.name = "Places"
	_grid.columns = 3
	_grid.add_theme_constant_override(&"h_separation", 8)
	_grid.add_theme_constant_override(&"v_separation", 8)
	box.add_child(_grid)
	for p: StringName in PLACES:
		var card := ChoiceButton.new(p, ChoiceButton.Style.CARD)
		card.name = "Place_" + String(p)
		card.button_group = _group
		card.toggled.connect(func(on: bool) -> void:
			if on and not _syncing:
				choose(p))
		_grid.add_child(card)
		cards[p] = card


func _refresh_text() -> void:
	super._refresh_text()
	for p: StringName in cards:
		cards[p].set_texts(tr(Keys.location(p)), tr(StringName("%s_SUB" % Keys.location(p))))
		# AC-06.4's temperature line waits for a {temp} placeholder in narrative's copy checker.


func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_THEME_CHANGED and _grid != null:
		# Two across at the largest text, so the labels never clip (ux-design §13).
		_grid.columns = 2 if get_theme_font_size(&"font_size", &"BodyLabel") >= 24 else 3


func _on_open() -> void:
	_select(session.get_environment().location if session != null else &"counter")


func choose(place: StringName) -> void:
	if session == null:
		return
	var result: ActionResult = session.apply(SetEnvironmentAction.to_location(place))
	if result.ok:
		_select(place)
	else:
		_select(session.get_environment().location)
		refused.emit(result.reason_key)


func _select(place: StringName) -> void:
	_syncing = true
	for p: StringName in cards:
		cards[p].set_pressed_no_signal(p == place)
		cards[p].queue_redraw()
	_syncing = false
