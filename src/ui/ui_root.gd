class_name UiRoot
extends Control
## The UI layer (architecture.md §3.2 and §9.1). Owns the one Theme, the safe areas, text size, reduce
## motion and the night palette, and wires the HUD, overlays and sheets to the Session and the Bus.
## It reads Session outputs only and changes the game only through Session.apply() (CLAUDE.md rule 2).
## Moments it runs itself: the smell moment (ux §9) and the feed sequence (ux §8). The one card above the
## bar (`card`) carries the explainer, smell, feed result, nudge, away summary and discard cards.
## Tests drive it without a Session: apply_snapshot(), set_insets_override(), set_text_scale(),
## set_night_blend(); with one, bind_session().

signal smell_finished(card: SmellCardText)
signal feed_sequence_finished()

const SHEET_FOR_ACTION: Dictionary[StringName, StringName] = {
	&"feed": &"feed", &"inspect": &"inspect", &"environment": &"environment", &"journal": &"journal",
}
const CARD_GAP: float = 12.0
const TOAST_GAP: float = 8.0
## The night palette follows the shared night factor; checked once a minute.
const CLOCK_CHECK_S: float = 60.0
## ux §9: the smell moment is 1.2 s (600 ms with reduce motion); the HUD dims to 60% during it.
const SMELL_S: float = 1.2
const SMELL_REDUCED_S: float = 0.6
const SMELL_HUD_DIM: float = 0.6
## Result cards auto-hide after 8 s unless "keep messages on screen" is on (ux §9).
const CARD_HOLD_S: float = 8.0
## ux §8 beats after Mix (s). The first feed runs about 6 s (D-023), later ones about 4.2 s.
const FEED_BEATS: Array[Array] = [[&"discard", 0.8], [&"scoop", 0.9], [&"pour", 0.8], [&"stir", 1.2]]
const FEED_HOOCH_S: float = 0.6
const FEED_SETTLE_S: float = 0.5
const FEED_REDUCED_S: float = 0.6
const FIRST_FEED_STRETCH: float = 6.0 / 4.2

@onready var hud: Hud = $Hud
@onready var card_slot: Control = $Overlays/CardSlot
@onready var card: Card = $Overlays/CardSlot/Explainer
@onready var explainer: Card = $Overlays/CardSlot/Explainer
@onready var toast_slot: Control = $Overlays/ToastSlot
@onready var toast: Toast = $Overlays/ToastSlot/Toast
@onready var skip_pill: SdButton = $Overlays/SkipPill
@onready var sheets: SheetHost = $Sheets
@onready var settings_sheet: SettingsSheet = $Sheets/Settings
@onready var feed_sheet: FeedSheet = $Sheets/Feed
@onready var inspect_sheet: InspectSheet = $Sheets/Inspect
@onready var place_sheet: PlaceSheet = $Sheets/Environment
@onready var journal_sheet: JournalSheet = $Sheets/Journal
@onready var flow_sheet: FlowSheet = $Sheets/Flow

var session: GameSession = null
var settings: SettingsStore = SettingsStore.new("")
var palette: UiPalette = UiPalette.new()
var text_scale: float = 1.0
var smell_running: bool = false
var feed_running: bool = false
## The return flow (time-lapse, then the away card) holds events until it's done (ux §12).
var return_running: bool = false
var presenter: EventPresenter = null
## Safety net if the view never reports the time-lapse's end (T2 owns playback).
const TIME_LAPSE_WAIT_MAX_S: float = 12.0
const READY_POLL_S: float = 0.1

var _insets: SafeInsets = SafeInsets.new()
var _insets_override: SafeInsets = null
var _night_override: float = -1.0
var _region: Rect2 = Rect2()
var _base_region: Rect2 = Rect2()
var _clock: Timer = null
var _feed_skipped: bool = false
var _ready_poll: Timer = null
var _nudge_uid: int = 0
var _prompt_uid: int = 0
var _prompt_lines: Array[String] = []
var _time_lapse_done: bool = false
## During the time-lapse a tap anywhere skips it (ux §12), so a full-screen catcher sits under the pill.
var _tap_catcher: Control = null


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if theme == null:
		theme = load(ThemeBuilder.THEME_PATH) as Theme
	hud.action_requested.connect(_on_action)
	hud.locked_pressed.connect(_on_locked)
	hud.status_pressed.connect(_on_status_pressed)
	hud.settings_pressed.connect(func() -> void: open_sheet(&"settings"))
	hud.layout_changed.connect(_place_overlays)
	sheets.sheet_opened.connect(_on_sheet_opened)
	sheets.sheet_closed.connect(_on_sheet_closed)
	settings_sheet.text_scale_chosen.connect(_on_text_scale_chosen)
	settings_sheet.reduce_motion_toggled.connect(_on_reduce_motion_toggled)
	settings_sheet.toggle_changed.connect(_on_setting_toggled)
	feed_sheet.mixed.connect(func(_r: ActionResult, p: FeedPreview) -> void: play_feed_sequence(p))
	inspect_sheet.camera_focus.connect(func(t: StringName) -> void: _bus_emit(&"camera_focus_requested", t))
	inspect_sheet.camera_release.connect(func() -> void: _bus_emit(&"camera_focus_released"))
	inspect_sheet.feed_requested.connect(func() -> void: open_sheet(&"feed"))
	place_sheet.refused.connect(func(k: StringName) -> void: toast.show_key(k))
	card.dismissed.connect(_on_card_dismissed)
	flow_sheet.look_first.connect(func() -> void: inspect_sheet.open_to(&"surface", true))
	flow_sheet.feed_now.connect(func() -> void: open_sheet(&"feed"))
	flow_sheet.finished.connect(_on_flow_finished)
	flow_sheet.camera_focus.connect(func(t: StringName) -> void: _bus_emit(&"camera_focus_requested", t))
	flow_sheet.camera_release.connect(func() -> void: _bus_emit(&"camera_focus_released"))
	presenter = EventPresenter.new()
	presenter.name = "EventPresenter"
	presenter.is_busy = func() -> bool: return not is_idle()
	presenter.card_up = func() -> bool: return card.is_shown()
	presenter.sheet_up = func() -> bool: return sheets.has_open_sheet()
	presenter.toast_up = func() -> bool: return toast.is_shown()
	presenter.present_toast.connect(_present_event_toast)
	presenter.present_card.connect(_present_event_card)
	presenter.present_sheet.connect(_present_event_sheet)
	presenter.withdraw_shown.connect(_on_event_withdrawn)
	add_child(presenter)
	_ready_poll = Timer.new()
	_ready_poll.wait_time = READY_POLL_S
	_ready_poll.timeout.connect(_refresh_ready)
	add_child(_ready_poll)
	skip_pill.pressed.connect(_on_skip)
	toast.link_opened.connect(func() -> void: open_sheet(&"journal"))
	_tap_catcher = Control.new()
	_tap_catcher.name = "TimeLapseTapCatcher"
	_tap_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tap_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_tap_catcher.visible = false
	_tap_catcher.gui_input.connect(func(ev: InputEvent) -> void:
		var mb: InputEventMouseButton = ev as InputEventMouseButton
		if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_on_skip())
	skip_pill.get_parent().add_child(_tap_catcher)
	skip_pill.get_parent().move_child(_tap_catcher, skip_pill.get_index())
	skip_pill.visible = false
	resized.connect(_relayout)
	settings_sheet.sync_from(text_scale, UiMotion.reduce)
	_clock = Timer.new()
	_clock.wait_time = CLOCK_CHECK_S
	_clock.timeout.connect(_refresh_night)
	add_child(_clock)
	var bus: Node = get_node_or_null(^"/root/Bus")
	if bus != null and bus.has_signal(&"starter_tapped"):
		bus.connect(&"starter_tapped", func(_where: StringName) -> void: _dismiss_card_on_action())
	if bus != null and bus.has_signal(&"time_lapse_finished"):
		bus.connect(&"time_lapse_finished", func() -> void: _time_lapse_done = true)
	var s: GameSession = get_node_or_null(^"/root/Session") as GameSession
	if s != null:
		bind_session(s)
	_relayout()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_RESUMED:
			if is_node_ready():
				_relayout()
				_refresh_night()
				_refresh_ready.call_deferred()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Android back: closes the open sheet first; with none open, save and quit (AC-12.11).
			if sheets.has_open_sheet():
				var current: Sheet = sheets.sheet(sheets.current_id())
				if current != null and current.dismissable:
					sheets.close_current()
			elif session != null and session.is_booted():
				session.save_and_quit()


# ------------------------------------------------------------------ session
func bind_session(s: GameSession) -> void:
	session = s
	for sh: Sheet in sheets.sheets():
		sh.session = s
	s.state_changed.connect(_on_state_changed)
	s.session_ready.connect(_on_session_ready)
	s.resumed.connect(_on_session_ready)
	s.save_failed.connect(func(reason: StringName) -> void: toast.show_key(reason))
	presenter.bind(s)
	if s.is_booted():
		_on_session_ready(s.get_last_catch_up())


func _on_session_ready(summary: CatchUpResult) -> void:
	var store: SettingsStore = session.get_settings()
	if store != null:
		settings = store
	apply_settings()
	apply_snapshot(session.get_snapshot())
	_refresh_night()
	_refresh_ready()
	_clock.start()
	_start_return_flow(summary)


func _on_state_changed(snapshot: StarterSnapshot, _visuals: VisualParams) -> void:
	apply_snapshot(snapshot)
	_refresh_ready()


## True when nothing holds the screen: no sheet, no smell moment, no feed sequence, no return flow
## (ux §12 queue rule).
func is_idle() -> bool:
	return not sheets.has_open_sheet() and not smell_running and not feed_running and not return_running


## D-050: while a long catch-up runs on its worker thread, the saved state shows and apply() would refuse.
## The action bar stays disabled and quiet (no toast) until the Session is ready.
func _refresh_ready() -> void:
	var ready: bool = session == null or (session.is_booted() and not session.is_catching_up())
	hud.set_actions_enabled(ready)
	if ready:
		_ready_poll.stop()
	elif _ready_poll.is_stopped():
		_ready_poll.start()


# ------------------------------------------------------------------ launch and return (ux §12, §14)
func _start_return_flow(result: CatchUpResult) -> void:
	if session.recovered_this_launch():
		card.present(&"notice", tr(&"RECOVERED_TITLE"), tr(&"RECOVERED_BODY"), "", [], true, CARD_HOLD_S)
	if session.is_first_run():
		flow_sheet.start_new_game()
		return
	var rs: ReturnSummary = session.get_return_summary()
	if rs.show and rs.prompt != null:
		# A pending attention event: no away card; its rows go on top of the attention sheet (ux §12).
		_prompt_uid = rs.prompt.uid
		_prompt_lines = _away_lines(rs)
	elif rs.show:
		if result != null and result.play_time_lapse and settings.show_time_lapse:
			await _wait_for_time_lapse()
		_present_away(rs)
	_show_discard_card_if_moldy()


## The time-lapse is T2's: hide the HUD, offer Skip, wait for Bus.time_lapse_finished.
func _wait_for_time_lapse() -> void:
	return_running = true
	_time_lapse_done = false
	hud.visible = false
	skip_pill.visible = true
	_tap_catcher.visible = true
	var end_ms: int = Time.get_ticks_msec() + int(TIME_LAPSE_WAIT_MAX_S * 1000.0 * UiMotion.time_scale)
	while not _time_lapse_done and Time.get_ticks_msec() < end_ms:
		await get_tree().process_frame
	skip_pill.visible = false
	_tap_catcher.visible = false
	hud.visible = true
	return_running = false


func _away_lines(rs: ReturnSummary) -> Array[String]:
	var lines: Array[String] = []
	for line: ReturnLine in rs.lines:
		lines.append(session.format_text(line.text_key, line.args))
	return lines


func _present_away(rs: ReturnSummary) -> void:
	var snap: StarterSnapshot = session.get_snapshot()
	var now: String = session.format_text(&"STATUS_A11Y", {
		"word": String(Keys.status_word(snap.state, snap.dormant_cause)),
		"hint": String(Keys.status_hint(snap.state, snap.dormant_cause))})
	card.present(&"away", tr(rs.title_key), "\n".join(_away_lines(rs)), now)


## After "Not yet" (or on a launch while moldy, with no mold sheet waiting): a card that stays above the bar
## until the discard starts (narrative §9.2).
func _show_discard_card_if_moldy() -> void:
	if session == null or session.get_snapshot().can_feed:
		return
	for e: SimEvent in session.get_pending_events():
		if e.id == &"mold_found":
			return
	var discard := SdButton.new(&"MOLD_BTN_DISCARD", SdButton.Variant.PRIMARY)
	discard.name = "DiscardIt"
	discard.pressed.connect(func() -> void:
		card.dismiss(true)
		flow_sheet.start_discard())
	card.present(&"discard", tr(&"STATUS_MOLDY_WORD"), tr(&"STATUS_MOLDY_HINT"), "", [discard], false)


func _on_flow_finished(outcome: StringName) -> void:
	match outcome:
		&"adopted":
			toast.show_text(session.format_text(&"NAME_DONE_TOAST", {"name": session.get_starter().name}))
		&"discarded":
			card.dismiss(true)
			toast.show_key(&"MOLD_DONE_TOAST")
		&"deferred":
			_show_discard_card_if_moldy()


# ------------------------------------------------------------------ events (ux §12)
func _present_event_toast(e: SimEvent) -> void:
	# Every info event is journaled, so its toast links to the journal (ux §12).
	toast.show_text(session.format_text(e.key_for("TOAST"), e.payload), &"", true)


func _present_event_card(e: SimEvent) -> void:
	_nudge_uid = e.uid
	var act := SdButton.new(e.key_for("BTN"), SdButton.Variant.PRIMARY)
	act.name = "EventAct"
	act.pressed.connect(func() -> void:
		_ack_nudge(&"act")
		card.dismiss(true)
		if e.id == &"hungry_again":
			open_sheet(&"feed"))
	var later := SdButton.new(e.key_for("DISMISS"), SdButton.Variant.TEXT)
	later.name = "EventLater"
	later.pressed.connect(func() -> void:
		_ack_nudge(&"dismiss")
		card.dismiss(true))
	card.present(&"nudge", tr(e.key_for("TITLE")), session.format_text(e.key_for("BODY"), e.payload), "",
		[later, act], true)


func _ack_nudge(choice: StringName) -> void:
	if _nudge_uid > 0 and session != null:
		session.apply(AckEventAction.new(_nudge_uid, choice))
	_nudge_uid = 0


func _present_event_sheet(e: SimEvent) -> void:
	var lines: Array[String] = []
	if e.uid == _prompt_uid:
		lines = _prompt_lines
	_prompt_uid = 0
	_prompt_lines = []
	card.dismiss(true)
	flow_sheet.show_event(e, lines)


func _on_event_withdrawn(uid: int) -> void:
	if card.is_shown() and card.kind == &"nudge" and _nudge_uid == uid:
		_nudge_uid = 0
		card.dismiss(true)


# ------------------------------------------------------------------ test and driver seams
func apply_snapshot(snapshot: StarterSnapshot) -> void:
	hud.set_snapshot(snapshot)
	hud.set_hint_override(_forecast_hint(snapshot))
	hud.status_pill.show_new_dot = _is_state_new(snapshot.state)
	if card.is_shown() and card.kind == &"explainer":
		_show_explainer()


func set_insets_override(insets: SafeInsets) -> void:
	_insets_override = insets
	_relayout()


func set_text_scale(value: float) -> void:
	text_scale = TypeScale.SCALES[TypeScale.index_of(value)]
	settings_sheet.sync_from(text_scale, UiMotion.reduce)
	_rebuild_theme()


## 0 day to 1 night. A negative value goes back to following the Session's night factor.
func set_night_blend(value: float) -> void:
	_night_override = value
	_refresh_night()


func set_reduce_motion(on: bool) -> void:
	UiMotion.reduce = on
	settings_sheet.sync_from(text_scale, on)


func insets() -> SafeInsets:
	return _insets


## The space between the HUD plate and the action bar (or the open sheet's top edge), where the camera
## frames the jar (ux-design §2).
func jar_region() -> Rect2:
	return _region


func apply_settings() -> void:
	UiMotion.reduce = settings.reduce_motion
	Toast.keep_messages = settings.keep_messages
	settings_sheet.sync_toggles(settings)
	set_text_scale(settings.text_scale)


func open_sheet(sheet_id: StringName) -> void:
	card.dismiss()
	toast.dismiss()
	sheets.open(sheet_id)


# ------------------------------------------------------------------ layout
func _relayout() -> void:
	if not is_node_ready():
		return
	if _insets_override != null:
		_insets = _insets_override
	else:
		_insets = SafeInsets.from_display(get_window().content_scale_factor)
	hud.apply_insets(_insets)
	sheets.set_insets(_insets)
	_place_overlays()


func _place_overlays() -> void:
	if not is_node_ready():
		return
	var top: float = hud.plate_bottom()
	var bottom: float = hud.bar_top()
	toast_slot.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_slot.offset_left = _insets.gutter_left()
	toast_slot.offset_right = -_insets.gutter_right()
	toast_slot.offset_top = top + TOAST_GAP
	toast_slot.offset_bottom = top + TOAST_GAP
	card_slot.set_anchors_preset(Control.PRESET_TOP_WIDE)
	card_slot.offset_left = _insets.gutter_left()
	card_slot.offset_right = -_insets.gutter_right()
	card_slot.offset_top = top + CARD_GAP
	card_slot.offset_bottom = bottom - CARD_GAP
	skip_pill.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	skip_pill.offset_bottom = -(size.y - bottom) - CARD_GAP
	skip_pill.offset_top = skip_pill.offset_bottom - skip_pill.custom_minimum_size.y
	skip_pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_base_region = Rect2(Vector2(0.0, top), Vector2(size.x, maxf(bottom - top, 0.0)))
	if not sheets.has_open_sheet():
		_emit_region(_base_region)


func _emit_region(region: Rect2) -> void:
	if region != _region:
		_region = region
		_bus_emit(&"jar_region_changed", region)


# ------------------------------------------------------------------ theme
func _rebuild_theme() -> void:
	var t: Theme = theme
	if t == null:
		return
	t.merge_with(ThemeBuilder.build(palette, text_scale))


## D-043 and D-049: the palette follows Session.get_night_factor(), the same curve the lights use.
func _refresh_night() -> void:
	var blend: float = _night_override
	if blend < 0.0:
		blend = session.get_night_factor() if session != null and session.is_booted() else 0.0
	if is_equal_approx(blend, palette.night):
		return
	palette = UiPalette.new(blend)
	_rebuild_theme()


# ------------------------------------------------------------------ actions and sheets
func _on_action(action_id: StringName) -> void:
	if feed_running or smell_running:
		return
	_dismiss_card_on_action()
	if action_id == &"smell":
		start_smell()
	elif SHEET_FOR_ACTION.has(action_id):
		open_sheet(SHEET_FOR_ACTION[action_id])


## D-043: a locked button shows its reason. Smell shows the "Best not" card, the others a toast.
func _on_locked(action_id: StringName, reason_key: StringName) -> void:
	if action_id == &"smell":
		card.present(&"smell", tr(&"SMELL_MOLDY_TITLE"), tr(&"SMELL_MOLDY_BODY"), "", [], true, CARD_HOLD_S)
	else:
		toast.show_key(reason_key)


func _dismiss_card_on_action() -> void:
	if card.is_shown() and card.dismissable:
		card.dismiss()


func _on_card_dismissed(kind: StringName) -> void:
	if kind == &"explainer":
		_bus_emit(&"camera_focus_released")
	elif kind == &"nudge":
		# A swipe or tap away counts as "Later" (ux §12).
		_ack_nudge(&"dismiss")


func _on_sheet_opened(sheet_id: StringName) -> void:
	hud.set_open_action(sheet_id if SHEET_FOR_ACTION.values().has(sheet_id) else &"")
	_bus_emit(&"sheet_opened", sheet_id)
	var s: Sheet = sheets.sheet(sheet_id)
	if s != null and s.height_kind != Sheet.Height.FULL:
		var top: float = _base_region.position.y
		_emit_region(Rect2(Vector2(0.0, top), Vector2(size.x, maxf(s.open_top() - top, 0.0))))


func _on_sheet_closed(sheet_id: StringName) -> void:
	if not sheets.has_open_sheet():
		hud.set_open_action(&"")
		_emit_region(_base_region)
	_bus_emit(&"sheet_closed", sheet_id)


# ------------------------------------------------------------------ status explainer
## ux §8: after a feed, the forecast becomes the hint until the starter peaks ({window} words, no digits).
const FORECAST_HINT_STATES: Array[StringName] = [&"freshly_fed", &"developing", &"active", &"near_peak"]


func _forecast_hint(snapshot: StarterSnapshot) -> String:
	if session == null or not session.is_booted() or not FORECAST_HINT_STATES.has(snapshot.state):
		return ""
	var window: StringName = session.get_forecast_window_key()
	return session.format_text(&"FORECAST_LINE", {"window": String(window)}) if window != &"" else ""


## AC-08.7: the pill's "new" dot, the first time a state shows, until tapped. Uses the Session's saved
## seen-state record when T1's API is there; without it, no dot (never guessed).
func _is_state_new(state_id: StringName) -> bool:
	if session == null or not session.has_method(&"is_state_new"):
		return false
	return session.call(&"is_state_new", state_id) == true


func _on_status_pressed() -> void:
	# The HUD already hid the dot on tap; the Session records it so it never comes back for this state.
	if _is_state_new(hud.status_pill.state_id) and session.has_method(&"mark_state_seen"):
		session.call(&"mark_state_seen", hud.status_pill.state_id)
	if card.is_shown() and card.kind == &"explainer":
		card.dismiss()
		return
	_show_explainer()


func _show_explainer() -> void:
	var snap: StarterSnapshot = hud.snapshot
	if snap == null:
		return
	var show_me := SdButton.new(&"STATUS_SHOW_ME_BTN", SdButton.Variant.TEXT)
	show_me.name = "ShowMe"
	show_me.pressed.connect(func() -> void:
		_bus_emit(&"camera_focus_requested", StatusStyle.show_me_target(snap.state)))
	var body: String = tr(Keys.status_tap(snap.state, snap.dormant_cause))
	var forecast: String = ""
	if session != null and session.is_booted():
		var window: StringName = session.get_forecast_window_key()
		if window != &"":
			forecast = session.format_text(&"FORECAST_LINE", {"window": String(window)})
	card.present(&"explainer", tr(Keys.status_word(snap.state, snap.dormant_cause)), body, forecast, [show_me])


# ------------------------------------------------------------------ smell moment (ux §9)
## The smell moment, then the card. The card's text comes from the sim's readout (CLAUDE.md rule 2).
func start_smell() -> void:
	if smell_running or session == null:
		return
	var result: ActionResult = session.apply(SmellAction.new())
	if not result.ok:
		_on_locked(&"smell", result.reason_key)
		return
	var readout: SmellReadout = result.readout as SmellReadout
	smell_running = true
	_bus_emit(&"smell_moment_started")
	var dim: Tween = create_tween()
	dim.tween_property(hud, "modulate:a", SMELL_HUD_DIM, 0.2)
	await _sleep(SMELL_REDUCED_S if UiMotion.reduce else SMELL_S)
	var back: Tween = create_tween()
	back.tween_property(hud, "modulate:a", 1.0, 0.2)
	_bus_emit(&"smell_moment_finished")
	smell_running = false
	var h: PlayerHistory = session.get_history()
	var primary: StringName = readout.primary if readout != null else &""
	var seen: int = h.seen_counts.get(StringName("smell.%s" % primary), 1)
	var text: SmellCardText = SmellCardText.build(readout if readout != null else SmellReadout.new(),
		false, h.real_feeds, seen)
	var ambiguous: bool = readout != null and readout.get(&"ambiguous") == true
	_present_smell(text, seen <= 1 and primary != &"", ambiguous)
	smell_finished.emit(text)


func _present_smell(text: SmellCardText, first_time: bool, ambiguous: bool = false) -> void:
	var body: String = tr(text.body_key)
	if text.note_key != &"":
		body += " " + session.format_text(text.note_key, text.note_args)
	var meaning: String = tr(text.meaning_key) if text.meaning_key != &"" else ""
	var buttons: Array[Button] = []
	if ambiguous:
		# ux §9: when the sim says the smell can't tell the state apart, offer the surface check.
		meaning = (meaning + "\n" if meaning != "" else "") + tr(&"SMELL_TRY_INSPECT")
		var look := SdButton.new(&"SMELL_TRY_INSPECT_BTN", SdButton.Variant.TEXT)
		look.name = "TryInspect"
		look.pressed.connect(func() -> void:
			card.dismiss(true)
			inspect_sheet.open_to(&"surface"))
		buttons.append(look)
	card.present(&"smell", tr(text.title_key), body, meaning, buttons, true, CARD_HOLD_S,
		tr(&"SMELL_NEW_RIBBON") if first_time else "")


# ------------------------------------------------------------------ feed sequence (ux §8)
## Runs after Mix: Bus.feed_moment at each beat, a Skip pill from the second feed on, then the result card.
## The sim has already changed (Session.apply ran at Mix); this is presentation only.
func play_feed_sequence(preview: FeedPreview) -> void:
	feed_running = true
	_feed_skipped = false
	var first: bool = session == null or session.get_history().real_feeds <= 1
	var stretch: float = FIRST_FEED_STRETCH if first else 1.0
	skip_pill.visible = not first
	if UiMotion.reduce:
		await _sleep(FEED_REDUCED_S)
	else:
		if preview != null and preview.hooch_step:
			await _sleep(FEED_HOOCH_S * stretch)
		for beat: Array in FEED_BEATS:
			if _feed_skipped:
				break
			var step: StringName = beat[0]
			var secs: float = beat[1]
			_bus_emit(&"feed_moment", step)
			await _sleep(secs * stretch)
		if not _feed_skipped:
			await _sleep(FEED_SETTLE_S * stretch)
	skip_pill.visible = false
	feed_running = false
	_present_feed_result(preview)
	feed_sequence_finished.emit()


func _present_feed_result(preview: FeedPreview) -> void:
	var body: String = ""
	if preview != null and preview.window_key != &"":
		body = session.format_text(&"FORECAST_LINE", {"window": String(preview.window_key)})
	elif preview != null and preview.fit_key != &"":
		body = tr(preview.fit_key)
	card.present(&"feed_result", tr(&"FEED_DONE_TITLE"), body, "", [], true, CARD_HOLD_S)


## Waits `seconds`, returning early when the feed sequence is skipped.
func _sleep(seconds: float) -> void:
	var end_ms: int = Time.get_ticks_msec() + int(seconds * UiMotion.time_scale * 1000.0)
	while Time.get_ticks_msec() < end_ms and not (feed_running and _feed_skipped):
		await get_tree().process_frame


## Skip ends the feed sequence, or asks the view to end the time-lapse (it then sends time_lapse_finished).
func _on_skip() -> void:
	if feed_running:
		_feed_skipped = true
	elif return_running:
		# The view ends playback and then sends time_lapse_finished; the away card waits for that.
		_bus_emit(&"time_lapse_skip_requested")


# ------------------------------------------------------------------ settings
func _on_text_scale_chosen(value: float) -> void:
	settings.text_scale = TypeScale.SCALES[TypeScale.index_of(value)]
	_save_settings()
	set_text_scale(value)


func _on_reduce_motion_toggled(on: bool) -> void:
	settings.reduce_motion = on
	_save_settings()
	set_reduce_motion(on)


func _on_setting_toggled(setting: StringName, on: bool) -> void:
	match setting:
		&"haptics":
			settings.haptics = on
		&"keep_messages":
			settings.keep_messages = on
			Toast.keep_messages = on
	_save_settings()


## Through Session.save_settings(), which also emits Bus.settings_changed for the view.
func _save_settings() -> void:
	if session != null and session.get_settings() == settings:
		session.save_settings()
	elif settings.path != "":
		settings.save_settings()


func _bus_emit(signal_name: StringName, arg: Variant = null) -> void:
	var bus: Node = get_node_or_null(^"/root/Bus")
	if bus == null or not bus.has_signal(signal_name):
		return
	if arg == null:
		bus.emit_signal(signal_name)
	else:
		bus.emit_signal(signal_name, arg)
