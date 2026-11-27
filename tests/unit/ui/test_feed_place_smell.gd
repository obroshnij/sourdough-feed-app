extends SliceUiCase
## Phase 3 items 1 to 3 through the real UI and a real Session: the feed sheet (AC-05.2, 05.3, 05.5,
## 05.7, 05.9), the place sheet (AC-06.1, 06.6, 06.7), the smell moment and card (AC-07.2, 07.6) and the
## inspect chips (AC-08.4), plus the moldy locks (AC-08.5) and the jar region while a sheet is open.

const DIGITS: String = "[0-9]"


func test_feed_like_last_time_is_two_taps() -> void:
	await boot("at_peak")
	var before: Dictionary = session.last_feed_action().to_dict()
	var feeds: int = session.get_history().real_feeds
	await tap_action(&"feed")
	var sheet: FeedSheet = ui.feed_sheet
	check(sheet.is_open(), "tap 1 opens the feed sheet")
	check_eq(sheet.answer, &"soon", "last time's ratio (1:1:1) is preselected")
	check(sheet.rows[&"soon"].button_pressed, "its row shows selected")
	check(sheet.flour_chips[&"white_bread"].button_pressed, "last time's flour is preselected")
	check(sheet.same_as_last, "'Same as last time' shows")
	check(sheet.preview != null and sheet.preview.discard_g >= 0, "the discard comes from the preview")
	check_eq(sheet.done_button.text, tr(&"FEED_MIX_BTN"), "the footer is Mix")
	sheet.done_button.pressed.emit()
	await wait(0.6)
	check_eq(session.get_history().real_feeds, feeds + 1, "tap 2 (Mix) feeds once")
	var after: Dictionary = session.last_feed_action().to_dict()
	after.erase("at_unix")
	before.erase("at_unix")
	check_eq(after, before, "the stored feed equals last time's, field by field (AC-05.3)")
	check_eq(session.get_snapshot().state, &"freshly_fed", "the starter is freshly fed")


func test_mix_spam_feeds_once() -> void:
	await boot("at_peak")
	var feeds: int = session.get_history().real_feeds
	await tap_action(&"feed")
	for i: int in 20:
		ui.feed_sheet.done_button.pressed.emit()
	await wait(0.6)
	check_eq(session.get_history().real_feeds, feeds + 1, "20 taps on Mix give exactly 1 feed (AC-05.9)")


func test_answer_and_flour_change_the_preview() -> void:
	await boot("at_peak")
	await tap_action(&"feed")
	var sheet: FeedSheet = ui.feed_sheet
	sheet.rows[&"tomorrow"].button_pressed = true
	await tree.process_frame
	check_eq(sheet.answer, &"tomorrow", "picking an answer selects it")
	check(not sheet.same_as_last, "'Same as last time' hides once anything changes")
	check_eq(sheet.preview.answer, &"tomorrow", "the preview is planned for that answer")
	sheet.flour_chips[&"whole_wheat"].button_pressed = true
	await tree.process_frame
	check_eq(sheet.preview.action.main_flour(), &"whole_wheat", "the flour chip changes the planned feed")
	check(sheet.rows[&"tomorrow"].text_fits(), "the row's title and sub-line fit")
	var forecast: Label = sheet.content.get_node(^"Forecast") as Label
	check(not RegEx.create_from_string(DIGITS).search(forecast.text), "the forecast line has no digits: " + forecast.text)


func test_hooch_step_and_choice() -> void:
	await boot("dormant_starved")
	await tap_action(&"feed")
	var sheet: FeedSheet = ui.feed_sheet
	check(sheet.preview.hooch_step, "hooch is visible in this fixture")
	check(sheet.hooch_chips[&"pour_off"].button_pressed, "Pour off is preselected (AC-05.5)")
	sheet.hooch_chips[&"stir_in"].button_pressed = true
	await tree.process_frame
	sheet.done_button.pressed.emit()
	await wait(0.6)
	check_eq(session.last_feed_action().hooch_choice, &"stir_in", "Stir in reached the applied feed")


func test_feed_sequence_beats_skip_and_result() -> void:
	UiMotion.reduce = false
	await boot("at_peak")
	await tap_action(&"feed")
	ui.feed_sheet.done_button.pressed.emit()
	await tree.process_frame
	check(ui.feed_running, "the sequence runs after Mix")
	check(not ui.skip_pill.visible, "the first feed has no Skip")
	await ui.feed_sequence_finished
	check_eq(heard(&"feed_moment"), [&"discard", &"scoop", &"pour", &"stir"], "Bus.feed_moment at each beat")
	check(ui.card.is_shown() and ui.card.kind == &"feed_result", "the result card follows")
	check(not RegEx.create_from_string(DIGITS).search(ui.card.body_label.text), "the forecast card has no digits")
	# Second feed: Skip shows and jumps to the end.
	ui.card.dismiss()
	bus_heard.clear()
	await tap_action(&"feed")
	ui.feed_sheet.done_button.pressed.emit()
	await tree.process_frame
	check(ui.skip_pill.visible, "from the second feed on, Skip shows")
	ui.skip_pill.pressed.emit()
	await ui.feed_sequence_finished
	check(heard(&"feed_moment").size() < 4, "Skip ends the beats early")
	check(not ui.skip_pill.visible, "Skip hides at the end")


func test_place_sheet_applies_at_once() -> void:
	await boot("at_peak")
	await tap_action(&"environment")
	var sheet: PlaceSheet = ui.place_sheet
	check(sheet.is_open(), "Place opens the place sheet")
	check_close(sheet.sheet_height(), 844.0 * 0.45, 0.0, 0.51, "the place sheet is 45% of the screen")
	check_eq(sheet.cards.keys(), [&"counter", &"warm_spot", &"fridge"], "the slice's three places, no cover or container")
	check(sheet.cards[&"counter"].button_pressed, "the current place is selected")
	var region: Rect2 = ui.jar_region()
	check_close(region.end.y, sheet.open_top(), 0.0, 0.51, "the jar region ends at the sheet's top while it's open")
	sheet.cards[&"fridge"].button_pressed = true
	await tree.process_frame
	check_eq(session.get_environment().location, &"fridge", "a tap applies at once, with no confirm")
	sheet.close()
	await wait(0.4)
	check_close(ui.jar_region().end.y, ui.hud.bar_top(), 0.0, 0.51, "the region goes back to the bar when it closes")
	var regions: Array = heard(&"jar_region_changed")
	check(regions.size() >= 2, "jar_region_changed fired on open and on close")


func test_smell_moment_and_card() -> void:
	await boot("at_peak")
	await tap_action(&"smell")
	await wait(0.3)
	check_eq(heard(&"smell_moment_started").size(), 1, "the moment starts")
	check_eq(heard(&"smell_moment_finished").size(), 1, "and finishes")
	check(ui.card.is_shown() and ui.card.kind == &"smell", "the smell card shows")
	var readout: SmellReadout = SmellModel.read(session.get_starter(), session.get_environment())
	var text: SmellCardText = SmellCardText.build(readout, false, session.get_history().real_feeds, 1)
	check_eq(ui.card.title_label.text, tr(text.title_key), "the title is the sim's primary descriptor")
	check(not RegEx.create_from_string(DIGITS).search(ui.card.title_label.text + ui.card.body_label.text),
		"no digits on the card (AC-07.6)")
	var first_title: String = ui.card.title_label.text
	var first_body: String = ui.card.body_label.text
	ui.card.dismiss()
	await tap_action(&"smell")
	await wait(0.3)
	check_eq(ui.card.body_label.text, first_body, "smelling again in the same cycle gives the same line (AC-07.2)")
	check_eq(ui.card.title_label.text, first_title, "and the same title")


func test_inspect_chip_moves_the_camera_and_reads_the_sim() -> void:
	await boot("active")
	await tap_action(&"inspect")
	var sheet: InspectSheet = ui.inspect_sheet
	check_eq(sheet.chips.keys(), [&"bubbles", &"height", &"surface"], "the P0 chips only (AC-08.4)")
	sheet.chips[&"bubbles"].pressed.emit()
	await wait(0.3)
	var targets: Array = heard(&"camera_focus_requested")
	check_eq(targets, [sheet.readout.camera_target], "the chip asks the camera for the readout's target")
	var obs: String = session.format_text(sheet.readout.text_key)
	check_eq((sheet.content.get_node(^"Result").get_child(1) as Label).text, obs, "the observation is the readout's text")
	sheet.close()
	await wait(0.3)
	check(heard(&"camera_focus_released").size() >= 1, "closing releases the camera")


func test_moldy_locks_feed_smell_and_place() -> void:
	await boot("moldy")
	for id: StringName in [&"feed", &"smell", &"environment"]:
		check(ui.hud.bar_button(id).locked_reason_key != &"", "%s is locked while moldy" % id)
	for id: StringName in [&"inspect", &"journal"]:
		check_eq(ui.hud.bar_button(id).locked_reason_key, &"", "%s still works" % id)
	await tap_action(&"feed")
	check(not ui.sheets.has_open_sheet(), "a locked Feed opens nothing")
	check_eq(ui.toast.label.text, tr(&"MOLD_FEED_BLOCKED"), "Feed shows its reason")
	await tap_action(&"smell")
	check(ui.card.is_shown() and ui.card.title_label.text == tr(&"SMELL_MOLDY_TITLE"), "Smell shows the 'Best not' card")
	check_eq(heard(&"smell_moment_started").size(), 0, "with no smell moment")
	await tap_action(&"environment")
	check_eq(ui.toast.label.text, tr(&"REASON_MOLDY_LOCKED"), "Place shows its reason")
	await tap_action(&"inspect")
	check(ui.inspect_sheet.is_open(), "Inspect opens")
