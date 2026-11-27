class_name FeedSheet
extends Sheet
## The feed sheet (ux-design §8, game-copy §7, D-020). It opens on last time's choices, so "feed like last
## time" is Feed then Mix: 2 taps (AC-05.3). Everything shown comes from Session.preview_feed() or
## plan_feed(): the discard in grams, the forecast words, the notes, the hooch step. Mix applies
## preview.action through Session.apply(); nothing here does sim math.

signal mixed(result: ActionResult, preview: FeedPreview)

const ANSWERS: Array[StringName] = [&"soon", &"later", &"tomorrow"]
const HOOCH: Array[StringName] = [&"pour_off", &"stir_in"]
const HOOCH_KEYS: Dictionary[StringName, StringName] = {&"pour_off": &"FEED_HOOCH_POUR", &"stir_in": &"FEED_HOOCH_STIR"}

var preview: FeedPreview = null
var answer: StringName = &""
var flour: StringName = &"white_bread"
var hooch: StringName = &"pour_off"
var same_as_last: bool = true
var rows: Dictionary[StringName, ChoiceButton] = {}
var flour_chips: Dictionary[StringName, Chip] = {}
var hooch_chips: Dictionary[StringName, Chip] = {}

var _last: FeedAction = null
var _hooch_box: VBoxContainer = null
var _discard: Label = null
var _forecast: Label = null
var _note: Label = null
var _same_row: HBoxContainer = null
var _same_label: Label = null
var _labels: Dictionary[StringName, Label] = {}
var _answer_group := ButtonGroup.new()
var _flour_group := ButtonGroup.new()
var _hooch_group := ButtonGroup.new()
var _syncing: bool = false
## Mix applies once per opening, however fast it is tapped (AC-05.9).
var _mixing: bool = false


func _init() -> void:
	sheet_id = &"feed"
	title_key = &"FEED_SHEET_TITLE"
	height_kind = Sheet.Height.HALF
	done_key = &"FEED_MIX_BTN"
	done_primary = true


func _build_content(box: VBoxContainer) -> void:
	_hooch_box = VBoxContainer.new()
	_hooch_box.name = "Hooch"
	box.add_child(_hooch_box)
	_labels[&"FEED_HOOCH_PROMPT"] = _section(_hooch_box, &"SectionLabel")
	var hrow := HFlowContainer.new()
	hrow.add_theme_constant_override(&"h_separation", 8)
	hrow.add_theme_constant_override(&"v_separation", 8)
	_hooch_box.add_child(hrow)
	for h: StringName in HOOCH:
		var chip := Chip.new(HOOCH_KEYS[h])
		chip.name = "Hooch_" + String(h)
		chip.button_group = _hooch_group
		chip.toggled.connect(func(on: bool) -> void:
			if on and not _syncing:
				_choose_hooch(h))
		hrow.add_child(chip)
		hooch_chips[h] = chip
	_labels[&"FEED_HOOCH_NOTE"] = _section(_hooch_box, &"HintLabel")

	_labels[&"FEED_SCHEDULE_QUESTION"] = _section(box, &"SectionLabel")
	for a: StringName in ANSWERS:
		var row := ChoiceButton.new(a, ChoiceButton.Style.ROW)
		row.name = "Answer_" + String(a)
		row.button_group = _answer_group
		row.toggled.connect(func(on: bool) -> void:
			if on and not _syncing:
				_choose_answer(a))
		box.add_child(row)
		rows[a] = row

	_labels[&"FEED_STEP_FLOUR"] = _section(box, &"SectionLabel")
	var frow := HFlowContainer.new()
	frow.name = "Flours"
	frow.add_theme_constant_override(&"h_separation", 8)
	frow.add_theme_constant_override(&"v_separation", 8)
	box.add_child(frow)
	for f: StringName in FeedPlanner.SLICE_FLOURS:
		var chip := Chip.new(Keys.flour(f))
		chip.name = "Flour_" + String(f)
		chip.button_group = _flour_group
		chip.toggled.connect(func(on: bool) -> void:
			if on and not _syncing:
				_choose_flour(f))
		frow.add_child(chip)
		flour_chips[f] = chip

	_discard = _section(box, &"BodyLabel")
	_discard.name = "Discard"
	_forecast = _section(box, &"BodyLabel")
	_forecast.name = "Forecast"
	_note = _section(box, &"HintLabel")
	_note.name = "Note"
	_same_row = HBoxContainer.new()
	_same_row.name = "SameAsLast"
	_same_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var check := TextureRect.new()
	check.texture = UiIcon.texture(&"ui_check")
	check.custom_minimum_size = Vector2(20, 20)
	check.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	check.modulate = UiPalette.ACCENT
	_same_row.add_child(check)
	_same_label = Label.new()
	_same_label.theme_type_variation = &"HintLabel"
	_same_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_same_row.add_child(_same_label)
	box.add_child(_same_row)


func _refresh_text() -> void:
	super._refresh_text()
	for key: StringName in _labels:
		_labels[key].text = tr(key)
	if _same_label != null:
		_same_label.text = tr(&"FEED_SAME_AS_LAST")
	if preview != null:
		_refresh()


func _on_open() -> void:
	if session == null:
		return
	_mixing = false
	_last = session.last_feed_action()
	flour = _last.main_flour() if FeedPlanner.SLICE_FLOURS.has(_last.main_flour()) else FeedPlanner.SLICE_FLOURS[0]
	hooch = _last.hooch_choice if HOOCH.has(_last.hooch_choice) else &"pour_off"
	answer = answer_for(_last)
	same_as_last = true
	preview = session.preview_feed(_last.copy(), answer)
	_refresh()


## The schedule answer whose own preset matches `feed`'s ratio, or &"" (an exact ratio from elsewhere).
static func answer_for(feed: FeedAction) -> StringName:
	var r: Vector2 = feed.ratio()
	for a: StringName in ANSWERS:
		var p: Vector2 = FeedPlanner.ANSWER_RATIO[a]
		if absf(p.x - r.x) < 0.25 and absf(p.y - r.y) < 0.25:
			return a
	return &""


func _choose_answer(a: StringName) -> void:
	answer = a
	same_as_last = false
	preview = session.plan_feed(a, flour, hooch)
	_refresh()


func _choose_flour(f: StringName) -> void:
	flour = f
	same_as_last = false
	if answer != &"":
		preview = session.plan_feed(answer, flour, hooch)
	else:
		var r: Vector2 = _last.ratio()
		var feed: FeedAction = FeedAction.from_ratio(r.x, r.y, flour)
		feed.hooch_choice = hooch
		preview = session.preview_feed(feed)
	_refresh()


## The contract lets the UI change hooch_choice on the preview's action before Mix.
func _choose_hooch(h: StringName) -> void:
	hooch = h
	same_as_last = false
	preview.action.hooch_choice = h
	_refresh()


func _refresh() -> void:
	if preview == null or rows.is_empty():
		return
	_syncing = true
	for a: StringName in ANSWERS:
		var row: ChoiceButton = rows[a]
		var ratio_text: String
		var kept: int
		if a == answer:
			ratio_text = preview.ratio_text
			kept = preview.kept_g
		else:
			var p: Vector2 = FeedPlanner.ANSWER_RATIO[a]
			var f: FeedAction = FeedAction.from_ratio(p.x, p.y, flour)
			ratio_text = f.ratio_text()
			kept = roundi(f.kept_g)
		row.set_texts(tr(StringName("FEED_OPTION_%s_TITLE" % Keys.up(a))),
			_fmt(&"FEED_OPTION_SUB", {"ratio": ratio_text, "grams": kept}))
		row.set_pressed_no_signal(a == answer)
		row.queue_redraw()
	if answer == &"":
		for a: StringName in ANSWERS:
			rows[a].set_pressed_no_signal(false)
	for f: StringName in flour_chips:
		flour_chips[f].set_pressed_no_signal(f == flour)
		flour_chips[f].toggled.emit(f == flour)
	_hooch_box.visible = preview.hooch_step
	for h: StringName in hooch_chips:
		hooch_chips[h].set_pressed_no_signal(h == hooch)
		hooch_chips[h].toggled.emit(h == hooch)
	_discard.text = _fmt(&"FEED_DISCARD_LINE", {"grams": preview.discard_g})
	_forecast.visible = preview.window_key != &""
	if _forecast.visible:
		_forecast.text = _fmt(&"FORECAST_LINE", {"window": String(preview.window_key)})
	var note: StringName = _note_key()
	_note.visible = note != &""
	_note.text = tr(note) if note != &"" else ""
	_same_row.visible = same_as_last
	done_button.disabled = preview.reason_key != &""
	_syncing = false


## One non-blocking line at most: the refusal reason, then fit, then timing note, then the routine hint.
func _note_key() -> StringName:
	for k: StringName in [preview.reason_key, preview.fit_key, preview.note_key]:
		if k != &"":
			return k
	return &"FEED_ROUTINE_HINT" if preview.routine_hint else &""


## Mix: one plain tap (ux-design §8: never a hold).
func _on_done() -> void:
	if preview == null or session == null or _mixing:
		return
	_mixing = true
	var action: FeedAction = preview.action
	if preview.hooch_step:
		action.hooch_choice = hooch
	var result: ActionResult = session.apply(action)
	if result.ok:
		close()
		mixed.emit(result, preview)
	else:
		_mixing = false
		_note.visible = true
		_note.text = tr(result.reason_key)


func _fmt(key: StringName, args: Dictionary) -> String:
	return session.format_text(key, args) if session != null else tr(key).format(args)


func _section(parent: Control, type: StringName) -> Label:
	var l := Label.new()
	l.theme_type_variation = type
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l
