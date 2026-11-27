extends SliceUiCase
## Phase 3 items 4 to 7 and D-050 through the real UI and a real Session: event presentation and holding
## (ux §12), the away summary (events-catalog §5), the journal order, the new game (M.'s note, naming,
## AdoptStarterAction), the mold flow to the memorial and the restart (D-047), and the quiet not-ready bar.


func test_new_game_note_then_naming_adopts() -> void:
	await boot_new()
	check(session.is_first_run(), "a first launch has an unnamed starter")
	var flow: FlowSheet = ui.flow_sheet
	check(flow.is_open() and flow.page == &"note", "M.'s note shows first")
	check(not flow.dismissable and not flow.close_button.visible, "the note can't be dismissed")
	flow.done_button.pressed.emit()
	await wait(0.2)
	check_eq(flow.page, &"naming", "then naming")
	var first: String = flow.name_field.text
	check_eq(first, tr(session.name_suggestion_key(0)), "the field opens on a suggestion")
	flow._tertiary.pressed.emit()
	check_ne(flow.name_field.text, first, "'Suggest another' changes it")
	flow.name_field.text = "Bramble"
	flow.done_button.pressed.emit()
	await wait(0.3)
	check_eq(session.get_starter().name, "Bramble", "AdoptStarterAction named it")
	check(not session.is_first_run(), "the new game is done")
	check(not flow.is_open(), "the flow closes")
	check_eq(ui.toast.label.text, session.format_text(&"NAME_DONE_TOAST", {"name": "Bramble"}), "'Bramble it is.'")


func test_events_wait_for_sheets_then_show_by_priority() -> void:
	await boot("at_peak")
	ui.open_sheet(&"journal")
	await wait(0.2)
	ui.presenter.enqueue(event(&"first_rise", &"info", 9001))
	ui.presenter.enqueue(event(&"hungry_again", &"nudge", 9002))
	await wait(0.3)
	check(not ui.toast.is_shown() and not ui.card.is_shown(), "nothing interrupts an open sheet")
	ui.sheets.close_current()
	await wait(0.5)
	check(ui.card.is_shown() and ui.card.kind == &"nudge", "the nudge (higher tier) shows first")
	check_eq(ui.card.title_label.text, tr(&"EVENT_HUNGRY_AGAIN_TITLE"), "with its title")
	await wait(0.3)
	check(ui.toast.is_shown(), "a toast may show while a card is up")
	check_eq(ui.toast.label.text, tr(&"EVENT_FIRST_RISE_TOAST"), "the info toast")
	var act: Button = ui.card.buttons.get_node(^"EventAct") as Button
	act.pressed.emit()
	await wait(0.4)
	check(ui.feed_sheet.is_open(), "'Feed it' opens the feed sheet")


func test_withdrawn_card_hides() -> void:
	await boot("hungry")
	ui.presenter.enqueue(event(&"hungry_again", &"nudge", 9101))
	await wait(0.4)
	check(ui.card.is_shown() and ui.card.kind == &"nudge", "the nudge shows")
	ui.presenter.withdraw(9101)
	await wait(0.3)
	check(not ui.card.is_shown(), "event_withdrawn hides it")


func test_smell_moment_holds_events() -> void:
	await boot("at_peak")
	UiMotion.time_scale = 0.5
	ui.start_smell()
	ui.presenter.enqueue(event(&"first_rise", &"info", 9201))
	await wait(0.2)
	check(ui.smell_running, "the smell moment runs")
	check(not ui.toast.is_shown(), "an event waits during the smell moment (AC-07.7)")
	await ui.smell_finished
	UiMotion.time_scale = 0.05
	await wait(0.3)
	check(ui.toast.is_shown(), "then it shows")


func test_warning_signs_look_first() -> void:
	await boot("unhealthy")
	ui.presenter.enqueue(event(&"warning_signs", &"attention", 9301))
	await wait(0.4)
	var flow: FlowSheet = ui.flow_sheet
	check(flow.is_open() and flow.page == &"event", "the attention sheet shows")
	check_eq(flow.done_button.text, tr(&"EVENT_WARNING_SIGNS_BTN_LOOK"), "'Look first' is the bottom, primary button")
	check_eq(flow._secondary.text, tr(&"EVENT_WARNING_SIGNS_BTN_FEED"), "'Feed it now' is secondary")
	flow.done_button.pressed.emit()
	await wait(0.6)
	check(ui.inspect_sheet.is_open() and ui.inspect_sheet.current_kind == &"surface", "it runs the surface check")
	check(ui.inspect_sheet.from_warning, "opened from the warning")


func test_mold_flow_to_memorial_and_restart() -> void:
	await boot("moldy")
	var flow: FlowSheet = ui.flow_sheet
	ui.presenter.enqueue(event(&"mold_found", &"attention", 9401))
	await wait(0.4)
	check(flow.is_open() and flow.page == &"event", "the mold sheet shows")
	check(heard(&"camera_focus_requested").has(&"mold"), "the camera goes to the colony")
	check(not flow.close_button.visible, "no Close X on the mold sheet")
	flow._secondary.pressed.emit()
	await wait(0.4)
	check(not flow.is_open(), "'Not yet' closes it")
	check(heard(&"camera_focus_released").size() >= 1, "and releases the camera")
	check(ui.card.is_shown() and ui.card.kind == &"discard", "the discard card stays above the bar")
	ui.card.dismiss()
	check(ui.card.is_shown(), "a tap can't dismiss it")
	(ui.card.buttons.get_node(^"DiscardIt") as Button).pressed.emit()
	await wait(0.3)
	check_eq(flow.page, &"confirm", "'Discard it' asks to confirm")
	flow._secondary.pressed.emit()
	await wait(0.2)
	check_eq(flow.page, &"memorial", "then the memorial page")
	check_eq(flow.title_label.text, session.format_text(&"MEMORIAL_TITLE", {"name": "Bramble"}), "named for the starter")
	flow.done_button.pressed.emit()
	await wait(0.2)
	check_eq(flow.page, &"restart", "then the restart page")
	check(not flow._secondary.visible, "only 'Start again' (D-047)")
	flow.done_button.pressed.emit()
	await wait(0.2)
	check_eq(flow.page, &"naming", "then naming")
	check(flow._secondary.visible, "with 'Pick for me'")
	var pick: String = flow._suggestion()
	flow._secondary.pressed.emit()
	await wait(0.4)
	check(not session.get_starter().moldy, "a new starter")
	check_eq(session.get_starter().name, pick, "named in one tap")
	check_eq(session.get_memorials().size(), 1, "the memorial is kept")
	check_eq(ui.toast.label.text, tr(&"MOLD_DONE_TOAST"), "the jar is washed")
	check(not ui.card.is_shown(), "the discard card is gone")


func test_away_summary_after_the_time_lapse() -> void:
	await boot("active")
	session.on_background()
	clock.advance(6 * 3600)
	session.on_resume()
	await wait(0.1)
	var rs: ReturnSummary = session.get_return_summary()
	check(rs.show, "six hours away gives a summary")
	if rs.prompt != null:
		check(not ui.card.is_shown() or ui.card.kind != &"away", "with an attention waiting, no away card")
		return
	if session.get_last_catch_up().play_time_lapse:
		check(ui.return_running, "the UI waits for the view's time-lapse")
		check(ui.skip_pill.visible and not ui.hud.visible, "Skip shows and the HUD hides")
		ui.skip_pill.pressed.emit()
		await wait(0.1)
		check(heard(&"time_lapse_skip_requested").size() == 1 or not _bus_has(&"time_lapse_skip_requested"),
			"Skip asks the view to end the time-lapse")
		var bus: Node = tree.root.get_node_or_null(^"Bus")
		if bus != null and bus.has_signal(&"time_lapse_finished"):
			bus.emit_signal(&"time_lapse_finished")
	await wait(0.4)
	check(not ui.return_running and ui.hud.visible, "back to the main screen")
	check(ui.card.is_shown() and ui.card.kind == &"away", "the away card shows")
	check_eq(ui.card.title_label.text, tr(rs.title_key), "with the summary's title")
	check(ui.card.body_label.text.split("\n").size() <= ReturnSummary.MAX_LINES, "at most 3 rows")


func _bus_has(sig: StringName) -> bool:
	var bus: Node = tree.root.get_node_or_null(^"Bus")
	return bus != null and bus.has_signal(sig)


func test_journal_keeps_uid_order() -> void:
	await boot("at_peak")
	await tap_action(&"feed")
	ui.feed_sheet.done_button.pressed.emit()
	await ui.feed_sequence_finished
	ui.card.dismiss()
	await tap_action(&"journal")
	var sheet: JournalSheet = ui.journal_sheet
	check(sheet.is_open(), "Journal opens")
	check(sheet.rows >= 1, "the feed is in the journal")
	var expected: Array[String] = []
	var entries: Array[JournalEntry] = session.get_journal()
	for i: int in range(entries.size() - 1, -1, -1):
		if JournalSheet.SHOWN_KINDS.has(entries[i].kind) and entries[i].kind != &"memorial":
			expected.append(session.format_text(entries[i].text_key, sheet._args(entries[i])))
	var shown: Array[String] = []
	for c: Node in sheet.content.get_children():
		var l: Label = c as Label
		if l != null and l.theme_type_variation == &"SectionLabel":
			shown.append(l.text)
	check_eq(shown, expected, "newest first, in uid order, never sorted by at_unix")


func test_forecast_becomes_the_hint_after_a_feed() -> void:
	await boot("at_peak")
	check_eq(ui.hud.hint_label.text, tr(&"STATUS_AT_PEAK_HINT"), "at peak, the state's own hint")
	await tap_action(&"feed")
	ui.feed_sheet.done_button.pressed.emit()
	await ui.feed_sequence_finished
	var window: StringName = session.get_forecast_window_key()
	if window == &"":
		skip("no forecast window right after this feed")
		return
	check_eq(ui.hud.hint_label.text, session.format_text(&"FORECAST_LINE", {"window": String(window)}),
		"after a feed, the forecast is the hint (ux §8)")
	check(not RegEx.create_from_string("[0-9]").search(ui.hud.hint_label.text), "with no digits")


func test_info_toast_links_to_the_journal() -> void:
	await boot("active")
	ui.presenter.enqueue(event(&"first_rise", &"info", 9501))
	await wait(0.4)
	check(ui.toast.is_shown(), "the toast shows")
	check((ui.toast.get_node(^"Row/Chevron") as Control).visible, "with a › chevron")
	check_eq(ui.toast.accessibility_description, tr(&"TOAST_A11Y_MORE"), "and says it opens the entry")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	ui.toast._gui_input(release)
	await wait(0.4)
	check(ui.journal_sheet.is_open(), "a tap opens the journal")


func test_place_cards_show_the_temperature() -> void:
	await boot("active")
	await tap_action(&"environment")
	for p: StringName in ui.place_sheet.cards:
		var row: Array = SimConstants.LOCATIONS[p]
		var temp: float = row[0]
		check_eq(ui.place_sheet.cards[p].detail_text, tr(&"PLACE_TEMP_C").format({"temp": str(roundi(temp))}),
			"%s shows its temperature in °C (AC-06.4)" % p)
		check(ui.place_sheet.cards[p].text_fits(), "%s card text fits" % p)


func test_new_state_dot_when_the_api_exists() -> void:
	await boot("active")
	var pill: StatusPill = ui.hud.status_pill
	var was_new: bool = session.is_state_new(&"active")
	check_eq(pill.show_new_dot, was_new, "the dot follows the Session's seen-state record")
	if was_new:
		check(pill.accessibility_description.ends_with(tr(&"STATUS_NEW_A11Y")), "and the description says so")
		pill.pressed.emit()
		await wait(0.2)
		check(not pill.show_new_dot, "a tap clears it")
		check(not session.is_state_new(&"active"), "once per state")


## D-043: the palette and the lights share one curve, NightFade, through Session.get_night_factor().
func test_palette_follows_night_fade() -> void:
	await boot("active")
	# The harness pins day for layout tests; the game follows the Session (override < 0).
	ui.set_night_blend(-1.0)
	var day0: int = clock.now_unix() - posmod(clock.now_unix(), 86400)
	for minutes: int in [12 * 60, 16 * 60 + 55, 17 * 60 + 5, 17 * 60 + 10, 17 * 60 + 25, 23 * 60, 6 * 60 + 10]:
		clock.set_now(day0 + minutes * 60)
		ui._refresh_night()
		var expected: float = NightFade.at_unix(float(clock.now_unix()), clock.local_utc_offset_s())
		check_close(ui.palette.night, expected, 0.0, 0.0001, "palette night factor at %02d:%02d" % [minutes / 60, minutes % 60])
		check_close(ui.palette.night, session.get_night_factor(), 0.0, 0.0001, "same as Session.get_night_factor()")


func test_bar_is_quiet_while_catching_up() -> void:
	await boot("active")
	session.on_background()
	clock.advance(5 * 3600)
	session.resume_async()
	ui._refresh_ready()
	if not session.is_catching_up():
		skip("the catch-up finished before the check (fast machine)")
		session.wait_for_catch_up()
		return
	for b: ActionBarButton in ui.hud.bar_buttons():
		check(b.disabled, "%s is disabled while catching up (D-050)" % b.action_id)
	check(not ui.toast.is_shown(), "with no toast")
	session.wait_for_catch_up()
	await wait(0.3)
	for b: ActionBarButton in ui.hud.bar_buttons():
		check(not b.disabled, "%s is back once ready" % b.action_id)
