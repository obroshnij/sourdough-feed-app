class_name FlowSheet
extends Sheet
## The one sheet for flows that must be finished (ux-design §12 and §14, narrative §6 and §9, D-047):
## - new game: M.'s note, then naming, then AdoptStarterAction
## - attention events: warning_signs ("Look first" primary, "Feed it now" secondary) and mold_found
##   ("Discard it", "Not yet"), with the away rows on top when the event waits on return (ux §12)
## - the discard: confirm (replacing the sheet's content, no stack), the memorial page, the restart page,
##   then naming with "Pick for me", then DiscardStarterAction (memorial plus new starter, atomic)
## Pages replace each other's content. Every text comes from tr() keys or Session.format_text().
## Not dismissable: a kill partway through leaves the game where the Session says (D-047: back to the
## moldy jar, or to naming on the next launch).

signal look_first()
signal feed_now()
## The flow ended: &"adopted", &"discarded", &"deferred" (Not yet) or &"acked".
signal finished(outcome: StringName)
signal camera_focus(target: StringName)
signal camera_release()

const NAME_MAX: int = 16

var page: StringName = &""
var event: SimEvent = null
var name_field: LineEdit = null
var restart: bool = false

var _secondary: SdButton = null
var _tertiary: SdButton = null
var _reason: Label = null
var _presses: int = 0
var _mold_focus: bool = false


func _init() -> void:
	sheet_id = &"flow"
	title_key = &""
	height_kind = Sheet.Height.FULL
	done_primary = true
	dismissable = false


func _build_content(_box: VBoxContainer) -> void:
	var footer: Node = done_button.get_parent()
	_secondary = SdButton.new(&"", SdButton.Variant.SECONDARY)
	_secondary.name = "Secondary"
	_secondary.pressed.connect(_on_secondary)
	footer.add_child(_secondary)
	footer.move_child(_secondary, done_button.get_index())
	_tertiary = SdButton.new(&"", SdButton.Variant.TEXT)
	_tertiary.name = "Tertiary"
	_tertiary.pressed.connect(_on_tertiary)
	footer.add_child(_tertiary)
	footer.move_child(_tertiary, _secondary.get_index())
	dismissable = false
	_buttons(&"", &"", &"")


# ------------------------------------------------------------------ entry points
func start_new_game() -> void:
	restart = false
	event = null
	_show(&"note")


func show_event(e: SimEvent, away_lines: Array[String] = []) -> void:
	event = e
	_show(&"event", away_lines)
	if e.id == &"mold_found" and not _mold_focus:
		_mold_focus = true
		camera_focus.emit(&"mold")


## From the discard card ("Discard it" after "Not yet"): straight to the confirm page.
func start_discard() -> void:
	event = null
	_show(&"confirm")


func close() -> void:
	if _mold_focus:
		_mold_focus = false
		camera_release.emit()
	super.close()


# ------------------------------------------------------------------ pages
func _show(next: StringName, away_lines: Array[String] = []) -> void:
	page = next
	clear_content()
	_reason = null
	name_field = null
	_buttons(&"", &"", &"")
	match next:
		&"note":
			_title(&"ONBOARD_NOTE_TITLE")
			add_label(&"BodyLabel", tr(&"ONBOARD_NOTE_BODY"))
			_buttons(&"ONBOARD_NOTE_BTN_TOUR", &"ONBOARD_NOTE_BTN_SKIP", &"")
		&"naming":
			_title(&"NAME_TITLE")
			add_label(&"BodyLabel", tr(&"NAME_BODY"))
			name_field = LineEdit.new()
			name_field.name = "NameField"
			name_field.max_length = NAME_MAX
			name_field.custom_minimum_size = Vector2(0, 52)
			name_field.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			name_field.accessibility_name = tr(&"NAME_FIELD_A11Y")
			name_field.text = _suggestion()
			name_field.text_submitted.connect(func(_t: String) -> void: _on_done())
			content.add_child(name_field)
			_reason = add_label(&"ReasonLabel", "")
			_reason.visible = false
			_buttons(&"NAME_BTN_CONFIRM", &"NAME_BTN_PICK" if restart else &"", &"NAME_BTN_SUGGEST")
		&"event":
			var mold: bool = event != null and event.id == &"mold_found"
			_title(&"MOLD_SHEET_TITLE" if mold else event.key_for("TITLE"))
			for line: String in away_lines:
				add_label(&"HintLabel", line)
			add_label(&"BodyLabel", tr(&"MOLD_SHEET_BODY") if mold else session.format_text(event.key_for("BODY"), event.payload))
			if mold:
				_buttons(&"MOLD_BTN_DISCARD", &"MOLD_BTN_LATER", &"")
			else:
				_buttons(event.key_for("BTN_LOOK"), event.key_for("BTN_FEED"), &"")
		&"confirm":
			_title_text(session.format_text(&"MOLD_CONFIRM_TITLE", {"name": session.get_starter().name}))
			add_label(&"BodyLabel", tr(&"MOLD_CONFIRM_BODY"))
			# The destructive choice isn't the primary, preselected one (ux §14).
			_buttons(&"MOLD_CONFIRM_NO", &"MOLD_CONFIRM_YES", &"")
		&"memorial":
			_memorial_page()
			_buttons(&"MEMORIAL_BTN_NEXT", &"", &"")
		&"restart":
			_title(&"RESTART_TITLE")
			var body: StringName = &"RESTART_BODY_FIRST" if session.restart_preset() == &"first_restart" else &"RESTART_BODY_LATER"
			add_label(&"BodyLabel", tr(body))
			# D-047: no empty jar in the slice, so "Start again" is the only way on.
			_buttons(&"RESTART_BTN_YES", &"", &"")
	if not is_open():
		open()


func _memorial_page() -> void:
	var m: Memorial = session.preview_memorial()
	if m == null:
		return
	_title_text(session.format_text(&"MEMORIAL_TITLE", {"name": m.name}))
	add_label(&"HintLabel", session.format_text(&"MEMORIAL_DATES", m.dates_args()))
	add_label(&"BodyLabel", tr(m.epitaph_key()))
	add_label(&"BodyLabel", session.format_text(m.cause_key(), m.cause_args()))
	var stats := GridContainer.new()
	stats.name = "Stats"
	stats.columns = 2
	stats.add_theme_constant_override(&"h_separation", 16)
	content.add_child(stats)
	for row: Array in [[&"MEMORIAL_STAT_DAYS", m.days_together()], [&"MEMORIAL_STAT_FEEDS", m.feeds_count],
			[&"MEMORIAL_STAT_PEAKS", m.peaks_count]]:
		var key: StringName = row[0]
		var value: int = row[1]
		var name_label := Label.new()
		name_label.theme_type_variation = &"HintLabel"
		name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		name_label.text = tr(key)
		stats.add_child(name_label)
		var value_label := Label.new()
		value_label.theme_type_variation = &"SectionLabel"
		value_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		value_label.text = str(value)
		stats.add_child(value_label)
	add_label(&"HintLabel", tr(&"MEMORIAL_TIP"))


# ------------------------------------------------------------------ buttons
## Primary (pinned at the bottom), secondary above it, tertiary (a text button) above that.
func _buttons(primary: StringName, secondary: StringName, tertiary: StringName) -> void:
	done_button.text_key = primary
	done_button.visible = primary != &""
	_secondary.text_key = secondary
	_secondary.visible = secondary != &""
	_tertiary.text_key = tertiary
	_tertiary.visible = tertiary != &""
	done_button.disabled = false


func _on_done() -> void:
	match page:
		&"note":
			_show(&"naming")
		&"naming":
			_commit_name(name_field.text)
		&"event":
			if event.id == &"mold_found":
				_show(&"confirm")
			else:
				_ack(&"look")
				close()
				look_first.emit()
				finished.emit(&"acked")
		&"confirm":
			_defer()
		&"memorial":
			_show(&"restart")
		&"restart":
			restart = true
			_presses = 0
			_show(&"naming")


func _on_secondary() -> void:
	match page:
		&"note":
			_show(&"naming")
		&"naming":
			# "Pick for me" (D-047): one tap names it with the current suggestion.
			_commit_name(_suggestion())
		&"event":
			if event.id == &"mold_found":
				_defer()
			else:
				_ack(&"feed")
				close()
				feed_now.emit()
				finished.emit(&"acked")
		&"confirm":
			_ack(&"discard")
			_show(&"memorial")


func _on_tertiary() -> void:
	if page == &"naming":
		_presses += 1
		name_field.text = _suggestion()


func _suggestion() -> String:
	return tr(session.name_suggestion_key(_presses)) if session != null else ""


func _commit_name(raw: String) -> void:
	var starter_name: String = raw.strip_edges()
	var action: GameAction = DiscardStarterAction.new(starter_name) if restart else AdoptStarterAction.new(starter_name, &"skip")
	var result: ActionResult = session.apply(action)
	if not result.ok:
		if _reason != null:
			_reason.text = tr(result.reason_key)
			_reason.visible = true
		return
	restart = false
	close()
	finished.emit(&"discarded" if action is DiscardStarterAction else &"adopted")


## "Not yet" on the mold sheet or the confirm page: the event is acknowledged, the discard card takes over.
func _defer() -> void:
	_ack(&"later")
	close()
	finished.emit(&"deferred")


func _ack(choice: StringName) -> void:
	if event != null and event.presentation() != SimEvent.PRESENT_TOAST:
		session.apply(AckEventAction.new(event.uid, choice))
	event = null


func _title(key: StringName) -> void:
	_title_text(tr(key))


func _title_text(text: String) -> void:
	title_key = &""
	title_label.text = text
