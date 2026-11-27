extends SliceUiCase
## The T3 rows QA's traceability (test-plan §3.13) lists as planned and buildable now. Each test names its
## AC row. Taps are counted the way a finger makes them (press, release, pressed) through _tap().

const DIGITS: String = "[0-9]"

var taps: int = 0


func _tap(b: BaseButton) -> void:
	taps += 1
	b.button_down.emit()
	b.button_up.emit()
	if b.toggle_mode:
		# A finger on a toggle (a radio choice in a group) turns it on, which emits toggled.
		b.button_pressed = true
	b.pressed.emit()
	await wait(0.4)


## Waits for the feed sequence and the smell moment to end (at most 10 s). Polling, not a signal await,
## because a short moment can finish before the await starts.
func _until_idle() -> void:
	var end_ms: int = Time.get_ticks_msec() + 10000
	while (ui.feed_running or ui.smell_running) and Time.get_ticks_msec() < end_ms:
		await tree.process_frame


func _tap_bar(id: StringName) -> void:
	await _tap(ui.hud.bar_button(id))


## Boots `fixture` with some starter fields changed (a synthetic edge case, written to a temp file).
func _boot_with(fixture: String, changes: Dictionary) -> void:
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("%s/%s.json" % [FIXTURES, fixture]))
	var starter: Dictionary = payload["starter"]
	starter.merge(changes, true)
	var path: String = "user://test_tmp/ui_backfill_%d.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://test_tmp"))
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(payload))
	f.close()
	var dir: String = "%s/edge_%d" % [TMP, Time.get_ticks_usec()]
	clock = FakeClock.new()
	session = GameSession.new()
	tree.root.add_child(session)
	session.setup(clock, SaveStore.new(dir), SettingsStore.new(dir + "/settings.cfg"))
	session.boot_from_fixture(path)
	ui = H.mount(tree.root, "iphone_17e_390x844")
	ui.bind_session(session)
	await H.settle(tree, 3)


func _feeds() -> int:
	return session.get_history().real_feeds


func _smell_once() -> void:
	ui.card.dismiss(true)
	await _tap_bar(&"smell")
	await wait(0.2)


# ------------------------------------------------------------------ AC-03.9
func test_ac03_9_bar_press_dragged_away_never_acts() -> void:
	await boot("active")
	var b: ActionBarButton = ui.hud.bar_button(&"smell")
	check_eq(ui.hud.action_bar.mouse_filter, Control.MOUSE_FILTER_STOP, "the bar plate consumes the press, so the camera never sees it")
	check_eq(b.mouse_filter, Control.MOUSE_FILTER_STOP, "and so does the button")
	b.button_down.emit()
	var drag := InputEventScreenDrag.new()
	drag.position = Vector2(0, -40)
	b._gui_input(drag)
	await wait(0.7)
	check(not b.is_popup_visible(), "a drag past the 10 pt slop cancels the long-press")
	b.button_up.emit()


# ------------------------------------------------------------------ AC-05.2
func test_ac05_2_feed_sheet_has_no_free_inputs() -> void:
	await boot("at_peak")
	await _tap_bar(&"feed")
	var free: Array[String] = []
	for c: Control in H.visible_controls(ui.feed_sheet.panel):
		if c is LineEdit or c is TextEdit or c is Range or c is Stepper:
			free.append(String(c.name))
	check_eq(free, [] as Array[String], "no free keep, hydration or ratio input in the slice")
	check(not ui.feed_sheet.done_button.disabled, "Mix is enabled when not moldy")


# ------------------------------------------------------------------ AC-05.4 and AC-12.7 (return, nudge)
func test_ac05_4_feed_from_a_return_in_three_taps() -> void:
	await boot("active")
	session.on_background()
	clock.advance(6 * 3600)
	session.on_resume()
	await wait(0.1)
	var feeds: int = _feeds()
	taps = 0
	if ui.return_running:
		await _tap(ui.skip_pill)
		var bus: Node = tree.root.get_node_or_null(^"Bus")
		if bus != null:
			bus.emit_signal(&"time_lapse_finished")
		await wait(0.3)
	await _tap_bar(&"feed")
	await _tap(ui.feed_sheet.done_button)
	check_eq(_feeds(), feeds + 1, "fed")
	check(taps <= 3, "a return, then fed in %d taps (budget 3)" % taps)


func test_ac05_4_feed_from_the_nudge_in_three_taps() -> void:
	await boot("hungry")
	ui.presenter.enqueue(event(&"hungry_again", &"nudge", 9601))
	await wait(0.4)
	var feeds: int = _feeds()
	taps = 1  # the time-lapse skip on a return
	await _tap(ui.card.buttons.get_node(^"EventAct") as Button)
	await _tap(ui.feed_sheet.done_button)
	check_eq(_feeds(), feeds + 1, "fed")
	check(taps <= 3, "Skip, Feed it, Mix: %d taps (budget 3)" % taps)


# ------------------------------------------------------------------ AC-05.4b
func test_ac05_4b_warning_safe_path_in_four_taps() -> void:
	await boot("unhealthy")
	ui.presenter.enqueue(event(&"warning_signs", &"attention", 9701))
	await wait(0.4)
	var feeds: int = _feeds()
	taps = 1  # the time-lapse skip on a return
	await _tap(ui.flow_sheet.done_button)
	await wait(0.2)
	check_eq(ui.inspect_sheet.current_kind, &"surface", "'Look first' runs the surface check")
	await _tap(ui.inspect_sheet.get_node(^"Panel/Body/Scroll/Content/Result/FeedNow") as Button)
	check(ui.feed_sheet.is_open(), "'Feed now' opens the feed sheet")
	await _tap(ui.feed_sheet.done_button)
	check_eq(_feeds(), feeds + 1, "fed")
	check(taps <= 4, "Skip, Look first, Feed now, Mix: %d taps (budget 4)" % taps)


func test_ac05_4_warning_quick_path_in_three_taps() -> void:
	await boot("unhealthy")
	ui.presenter.enqueue(event(&"warning_signs", &"attention", 9702))
	await wait(0.4)
	var feeds: int = _feeds()
	taps = 1
	await _tap(ui.flow_sheet._secondary)
	await _tap(ui.feed_sheet.done_button)
	check_eq(_feeds(), feeds + 1, "fed")
	check(taps <= 3, "Skip, Feed it now, Mix: %d taps (budget 3)" % taps)


# ------------------------------------------------------------------ AC-05.5
func test_ac05_5_no_hooch_step_below_the_threshold() -> void:
	await _boot_with("hungry", {"hooch": 0.0999})
	await _tap_bar(&"feed")
	check(not ui.feed_sheet.preview.hooch_step, "hooch 0.0999: no hooch step")
	check(not (ui.feed_sheet.content.get_node(^"Hooch") as Control).visible, "and the hooch rows are hidden")
	await after_each()
	await before_each()
	await _boot_with("hungry", {"hooch": 0.1})
	await _tap_bar(&"feed")
	check(ui.feed_sheet.preview.hooch_step, "hooch 0.1: the hooch step shows")
	check((ui.feed_sheet.content.get_node(^"Hooch") as Control).visible, "first in the sheet")


# ------------------------------------------------------------------ AC-05.6
func test_ac05_6_early_feed_shows_the_note_and_still_mixes() -> void:
	await boot("active")
	await _tap_bar(&"feed")
	var sheet: FeedSheet = ui.feed_sheet
	check_eq(sheet.preview.timing, &"early", "an active starter is fed early")
	check_eq((sheet.content.get_node(^"Note") as Label).text, tr(&"FEED_EARLY_NOTE"), "the non-blocking early line shows")
	check(not sheet.done_button.disabled, "Mix stays enabled")
	var feeds: int = _feeds()
	await _tap(sheet.done_button)
	check_eq(_feeds(), feeds + 1, "and it feeds")


# ------------------------------------------------------------------ AC-06.7 and AC-12.7 (fridge)
func test_ac06_7_fridge_in_three_taps() -> void:
	await boot("active")
	taps = 0
	await _tap_bar(&"environment")
	await _tap(ui.place_sheet.cards[&"fridge"])
	await _tap(ui.place_sheet.done_button)
	check_eq(session.get_environment().location, &"fridge", "moved to the fridge")
	check(not ui.place_sheet.is_open(), "the sheet closed")
	check_eq(taps, 3, "Place, Fridge, Done: 3 taps (budget 3)")


# ------------------------------------------------------------------ AC-07.3, 07.4, 07.5, 07.6
func test_ac07_3_musty_meaning_shows_every_time() -> void:
	await boot("unhealthy")
	var r: SmellReadout = SmellModel.read(session.get_starter(), session.get_environment())
	check(r.intensities.get(&"musty", 0.0) > 0.0, "the unhealthy fixture smells musty")
	for i: int in 5:
		await _smell_once()
		check(ui.card.extra_label.visible and ui.card.extra_label.text == tr(&"SMELL_MUSTY_MEANING"),
			"smell %d: the musty meaning shows (never fades)" % (i + 1))


func test_ac07_4_hunger_smell_meaning_says_normal() -> void:
	await boot("hungry")
	session.on_background()
	clock.advance(8 * 3600)
	session.on_resume()
	# Let the return flow (time-lapse wait, then the away card) finish before smelling.
	while ui.return_running:
		await tree.process_frame
	await wait(0.2)
	ui.card.dismiss(true)
	check_eq(session.get_snapshot().state, &"hungry", "still hungry 8 h later")
	await _smell_once()
	check(ui.card.extra_label.text.to_lower().contains("normal"),
		"the hungry smell's meaning says normal: '%s'" % ui.card.extra_label.text)


func test_ac07_5_meaning_three_times_then_one_tap_away() -> void:
	await boot("at_peak")
	for i: int in 3:
		await _smell_once()
		check(ui.card.extra_label.visible and ui.card.extra_label.text != "", "smell %d: the meaning shows" % (i + 1))
	await _smell_once()
	check(not ui.card.extra_label.visible, "smell 4: the meaning is hidden")
	var why: Button = ui.card.buttons.get_node_or_null(^"ShowMeaning") as Button
	check(why != null and why.visible, "behind one tap")
	if why != null:
		check_eq(why.text, tr(&"SMELL_MEANING_BTN"), "labeled from its key")
		await _tap(why)
		check(ui.card.extra_label.visible and ui.card.extra_label.text != "", "the tap shows it")


func test_ac07_6_smell_moment_lasts_about_1_2_s() -> void:
	await boot("at_peak")
	UiMotion.time_scale = 1.0
	UiMotion.reduce = false
	var started: int = Time.get_ticks_msec()
	ui.start_smell()
	await ui.smell_finished
	var took: float = (Time.get_ticks_msec() - started) / 1000.0
	check_between(took, 1.15, 1.45, "the moment lasts about 1.2 s (%.2f s)" % took)
	check(not RegEx.create_from_string(DIGITS).search(ui.card.title_label.text + ui.card.body_label.text + ui.card.extra_label.text),
		"no digits on the smell card")


# ------------------------------------------------------------------ AC-08.2 and AC-12.8 (pill)
func test_ac08_2_pill_crossfade_and_pulse() -> void:
	await boot("active")
	UiMotion.time_scale = 1.0
	var pill: StatusPill = ui.hud.status_pill
	UiMotion.reduce = false
	pill.set_status(&"near_peak")
	await wait(0.08)
	check(pill.modulate.a < 1.0, "the word crossfades in")
	check(pill.scale.x > 1.0, "with a pulse")
	await wait(0.35)
	check_close(pill.modulate.a, 1.0, 0.0, 0.001, "and ends opaque")
	check_close(pill.scale.x, 1.0, 0.0, 0.001, "at its size, within 250 ms")
	UiMotion.reduce = true
	pill.set_status(&"at_peak")
	await wait(0.08)
	check(pill.modulate.a < 1.0, "reduce motion: still a crossfade")
	check_close(pill.scale.x, 1.0, 0.0, 0.001, "reduce motion: no pulse")


# ------------------------------------------------------------------ AC-08.8
func test_ac08_8_show_me_moves_the_camera_to_the_cue() -> void:
	await boot("active")
	await _tap(ui.hud.status_pill)
	check(ui.card.is_shown() and ui.card.kind == &"explainer", "the explainer shows")
	await _tap(ui.card.buttons.get_node(^"ShowMe") as Button)
	check_eq(heard(&"camera_focus_requested"), [StatusStyle.show_me_target(&"active")], "'Show me' asks for the state's main cue")


# ------------------------------------------------------------------ AC-09.4
func test_ac09_4_attention_on_return_has_no_away_card() -> void:
	await boot("dormant_starved")
	session.on_background()
	clock.advance(40 * 3600)
	session.on_resume()
	await wait(0.6)
	var rs: ReturnSummary = session.get_return_summary()
	check(rs.show and rs.prompt != null, "40 h more unfed brings warning signs pending on return")
	if rs.prompt == null:
		return
	check(not (ui.card.is_shown() and ui.card.kind == &"away"), "no away summary card")
	var flow: FlowSheet = ui.flow_sheet
	check(flow.is_open() and flow.page == &"event", "the attention sheet shows")
	var top: Array[String] = []
	for c: Node in flow.content.get_children():
		var l: Label = c as Label
		if l != null and l.theme_type_variation == &"HintLabel":
			top.append(l.text)
	var lines: Array[String] = []
	for line: ReturnLine in rs.lines:
		lines.append(session.format_text(line.text_key, line.args))
	check_eq(top, lines, "its rows sit on top of the attention sheet")


# ------------------------------------------------------------------ AC-10.8
func test_ac10_8_events_wait_for_the_feed_sequence_and_inspection() -> void:
	await boot("at_peak")
	await _tap_bar(&"feed")
	UiMotion.time_scale = 0.3
	ui.feed_sheet.done_button.pressed.emit()
	await wait(0.1)
	ui.presenter.enqueue(event(&"first_rise", &"info", 9801))
	await wait(0.3)
	check(ui.feed_running and not ui.toast.is_shown(), "nothing interrupts the feed sequence")
	await _until_idle()
	UiMotion.time_scale = 0.05
	await wait(0.3)
	check(ui.toast.is_shown(), "the toast follows it")
	ui.toast.dismiss()
	ui.card.dismiss(true)
	await _tap_bar(&"inspect")
	ui.presenter.enqueue(event(&"peak_now", &"info", 9802))
	await wait(0.4)
	check(not ui.toast.is_shown(), "nothing interrupts an inspection")
	ui.inspect_sheet.close()
	await wait(0.5)
	check(ui.toast.is_shown(), "then it shows")


# ------------------------------------------------------------------ AC-12.1 and AC-12.2 (cards, toasts)
func test_ac12_1_and_12_2_cards_and_toasts_at_small_sizes() -> void:
	for device: String in ["iphone_se_375x667", "android_360x640"]:
		for scale: float in [1.0, 1.5]:
			await boot("moldy", device)
			ui.set_text_scale(scale)
			var tag: String = "%s @%d%%" % [device, roundi(scale * 100)]
			for kind: String in ["nudge", "discard", "toast"]:
				match kind:
					"nudge":
						ui._present_event_card(event(&"hungry_again", &"nudge", 9900))
					"discard":
						ui._show_discard_card_if_moldy()
					"toast":
						ui.toast.show_text("x".repeat(0) + tr(&"EVENT_HUNGRY_AGAIN_BODY").substr(0, 60), &"", true)
				await wait(0.5)
				var root: Control = ui.toast if kind == "toast" else ui.card
				_check_overlay("%s %s" % [tag, kind], root, H.device_size(device))
				ui.card.dismiss(true)
				ui.toast.dismiss()
				await wait(0.3)
			await after_each()
			await before_each()


func _check_overlay(tag: String, root: Control, screen: Vector2) -> void:
	var targets: Array[Control] = []
	for c: Control in H.visible_controls(root):
		var r: Rect2 = c.get_global_rect()
		check(Rect2(Vector2.ZERO, screen).grow(0.5).encloses(r), "%s %s on screen" % [tag, c.name])
		var l: Label = c as Label
		if l != null and l.text != "":
			check(l.get_line_count() <= l.get_visible_line_count(), "%s %s shows all its lines" % [tag, l.name])
		if c is BaseButton:
			targets.append(c)
			check(r.size.x >= 43.5 and r.size.y >= 43.5, "%s %s target %s >= 44" % [tag, c.name, r.size])
			check(c.accessibility_name != "", "%s %s has a name" % [tag, c.name])
	for i: int in targets.size():
		for j: int in range(i + 1, targets.size()):
			check(not targets[i].get_global_rect().grow(-0.5).intersects(targets[j].get_global_rect().grow(-0.5)),
				"%s %s and %s don't overlap" % [tag, targets[i].name, targets[j].name])


# ------------------------------------------------------------------ AC-12.7 (the other tap paths)
func test_ac12_7_tap_budgets() -> void:
	await boot("active")
	check(ui.hud.status_pill.text != "" and ui.hud.hint_label.text != "", "check the starter: 0 taps")
	taps = 0
	await _tap(ui.hud.status_pill)
	check(ui.card.kind == &"explainer" and taps == 1, "understand the status: 1 tap")
	ui.card.dismiss(true)
	var feeds: int = _feeds()
	taps = 0
	await _tap_bar(&"feed")
	await _tap(ui.feed_sheet.rows[&"tomorrow"])
	await _tap(ui.feed_sheet.done_button)
	check(_feeds() == feeds + 1 and taps == 3, "a different ratio: 3 taps (budget 4)")
	await _until_idle()
	ui.card.dismiss(true)
	taps = 0
	await _tap_bar(&"feed")
	await _tap(ui.feed_sheet.rows[&"later"])
	await _tap(ui.feed_sheet.flour_chips[&"whole_wheat"])
	await _tap(ui.feed_sheet.done_button)
	check(_feeds() == feeds + 2 and taps == 4, "a different ratio and flour: 4 taps (budget 4)")
	await _until_idle()
	ui.card.dismiss(true)
	taps = 0
	await _tap_bar(&"smell")
	await wait(0.2)
	check(ui.card.kind == &"smell" and taps == 1, "smell: 1 tap")
	ui.card.dismiss(true)
	taps = 0
	await _tap_bar(&"inspect")
	await _tap(ui.inspect_sheet.chips[&"height"])
	await wait(0.2)
	check(ui.inspect_sheet.current_kind == &"height" and taps == 2, "inspect one kind: 2 taps")
	ui.inspect_sheet.close()
	await wait(0.3)
	taps = 0
	await _tap_bar(&"journal")
	check(ui.journal_sheet.is_open() and taps == 1, "read the journal: 1 tap")
	ui.journal_sheet.close()
	await wait(0.3)
	taps = 0
	await _tap(ui.hud.settings_button)
	await _tap(ui.settings_sheet.size_chips[1])
	check(is_equal_approx(ui.text_scale, 1.25) and taps == 2, "change text size: 2 taps")
	ui.set_text_scale(1.0)


# ------------------------------------------------------------------ AC-12.8 (cards and toasts)
func test_ac12_8_card_and_toast_motion() -> void:
	await boot("active")
	UiMotion.time_scale = 1.0
	UiMotion.reduce = false
	ui.card.present(&"notice", "T", "B")
	await tree.process_frame
	check(ui.card.offset_bottom > 0.0 and ui.card.modulate.a < 1.0, "a card slides up and fades in")
	await wait(UiMotion.CARD_IN + 0.1)
	check(is_zero_approx(ui.card.offset_bottom) and is_equal_approx(ui.card.modulate.a, 1.0), "in 280 ms")
	ui.toast.show_text("T")
	await tree.process_frame
	check(ui.toast.offset_top < 0.0 and ui.toast.modulate.a < 1.0, "a toast slides down and fades in")
	await wait(UiMotion.TOAST_IN + 0.1)
	check(is_zero_approx(ui.toast.offset_top), "in 220 ms")
	ui.card.dismiss(true)
	ui.toast.dismiss()
	await wait(0.4)
	UiMotion.reduce = true
	ui.card.present(&"notice", "T", "B")
	ui.toast.show_text("T")
	await tree.process_frame
	check(is_zero_approx(ui.card.offset_bottom) and ui.card.modulate.a < 1.0, "reduce motion: the card only fades")
	check(is_zero_approx(ui.toast.offset_top) and ui.toast.modulate.a < 1.0, "reduce motion: the toast only fades")


# ------------------------------------------------------------------ AC-12.11
func test_ac12_11_android_back_closes_the_top_sheet() -> void:
	await boot("active")
	await _tap_bar(&"environment")
	ui.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await wait(0.4)
	check(not ui.sheets.has_open_sheet(), "back closes the open sheet")
	ui.presenter.enqueue(event(&"warning_signs", &"attention", 9990))
	await wait(0.4)
	ui.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await wait(0.4)
	check(ui.flow_sheet.is_open(), "back never dismisses an attention sheet that must be acted on")
