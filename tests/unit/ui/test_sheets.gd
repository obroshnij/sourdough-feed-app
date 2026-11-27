extends TestCase
## Sheets and overlays (ux-design §3, §6, §15, §17; AC-12.1, AC-12.2, AC-12.8, AC-12.11): every sheet at
## every device and text size keeps targets >= 44, text unclipped and on screen, one sheet at a time, the
## scrim blocks the 3D view, and the motion matches the spec with its reduce-motion fallbacks.

const H := preload("res://tests/unit/ui/ui_harness.gd")
const EPS: float = 0.51

var _tree: SceneTree = null
var _ui: UiRoot = null


func before_each() -> void:
	I18nLoader.load_all()
	UiMotion.reduce = true
	_tree = Engine.get_main_loop() as SceneTree
	# The root only takes children once the first frame has run.
	await _tree.process_frame


func after_each() -> void:
	UiMotion.reduce = false
	if _ui != null:
		_ui.set_text_scale(1.0)
		_ui.get_parent().queue_free()
		_ui = null
	await _tree.process_frame


func test_every_sheet_fits_at_every_size() -> void:
	for device: String in H.DEVICES:
		for scale: float in TypeScale.SCALES:
			_ui = H.mount(_tree.root, device, scale)
			_ui.apply_snapshot(H.snapshot(&"active"))
			await H.settle(_tree)
			for s: Sheet in _ui.sheets.sheets():
				_ui.sheets.open(s.sheet_id)
				# Poll for the end of the open animation instead of a fixed wait, so a loaded machine
				# can't fail it (the 360 x 640 @ 125% flake).
				await _until(func() -> bool: return absf(s.panel.get_global_rect().position.y - s.open_top()) < 0.5, 2.0)
				await _tree.process_frame
				var tag: String = "%s @%d%% %s" % [device, roundi(scale * 100), s.sheet_id]
				check_eq(_ui.sheets.current_id(), s.sheet_id, tag + " is the open sheet")
				_check_sheet(tag, s, H.device_size(device), H.device_insets(device))
				s.close()
				await _until(func() -> bool: return not s.visible, 2.0)
				check(not s.visible, tag + " hides after closing")
			await after_each()


func test_one_sheet_at_a_time_and_bus_signals() -> void:
	_ui = H.mount(_tree.root, "iphone_17e_390x844")
	await H.settle(_tree)
	var events: Array[String] = []
	var bus: Node = _tree.root.get_node_or_null(^"Bus")
	if bus != null:
		bus.connect(&"sheet_opened", func(id: StringName) -> void: events.append("open:" + id))
		bus.connect(&"sheet_closed", func(id: StringName) -> void: events.append("close:" + id))
	_ui.hud.bar_button(&"feed").activated.emit(&"feed")
	await _wait(0.35)
	check_eq(_ui.sheets.current_id(), &"feed", "Feed opens the feed sheet")
	check(_ui.hud.bar_button(&"feed").is_open, "the Feed button shows open")
	_ui.hud.settings_button.pressed.emit()
	await _wait(0.35)
	check_eq(_ui.sheets.current_id(), &"settings", "settings replaced the feed sheet")
	check(not _ui.sheets.sheet(&"feed").is_open(), "the feed sheet closed first (no stacks)")
	check(not _ui.hud.bar_button(&"feed").is_open, "no bar button shows open under settings")
	var settings: Sheet = _ui.sheets.sheet(&"settings")
	check_eq(settings.scrim.mouse_filter, Control.MOUSE_FILTER_STOP, "the scrim blocks the 3D view")
	check_close(settings.scrim.get_global_rect().size.y, 844.0, 0.0, EPS, "the scrim covers the screen")
	_ui.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _wait(0.35)
	check(not _ui.sheets.has_open_sheet(), "Android back closes the open sheet")
	if bus != null:
		check_eq(events, ["open:feed", "close:feed", "open:settings", "close:settings"], "Bus sheet signals in order")
	else:
		check(true, "no Bus autoload in this run")


func test_scrim_tap_closes_unless_disabled() -> void:
	_ui = H.mount(_tree.root, "iphone_se_375x667")
	await H.settle(_tree)
	var s: Sheet = _ui.sheets.sheet(&"inspect")
	_ui.sheets.open(&"inspect")
	await _wait(0.35)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	s.dismiss_on_scrim = false
	s.scrim.gui_input.emit(release)
	await _wait(0.1)
	check(s.is_open(), "a scrim tap is ignored when the sheet can't be dismissed that way")
	s.dismiss_on_scrim = true
	s.scrim.gui_input.emit(release)
	await _wait(0.35)
	check(not s.is_open(), "a scrim tap closes the sheet")


func test_sheet_motion_and_reduce_motion() -> void:
	check_close(UiMotion.SHEET_OPEN, 0.30, 0.0, 0.0001, "sheet open 300 ms")
	check_close(UiMotion.SHEET_CLOSE, 0.22, 0.0, 0.0001, "sheet close 220 ms")
	check_close(UiMotion.CARD_IN, 0.28, 0.0, 0.0001, "card in 280 ms")
	check_close(UiMotion.CARD_OUT, 0.20, 0.0, 0.0001, "card out 200 ms")
	check_close(UiMotion.TOAST_IN, 0.22, 0.0, 0.0001, "toast in 220 ms")
	check_close(UiMotion.TOAST_OUT, 0.18, 0.0, 0.0001, "toast out 180 ms")
	check_close(UiMotion.toast_duration("x".repeat(60)), 6.7, 0.0, 0.0001, "toast 2.5 s + 70 ms per char")
	check_close(UiMotion.toast_duration("x".repeat(200)), 7.0, 0.0, 0.0001, "toast at most 7 s")
	UiMotion.reduce = false
	check_close(UiMotion.sheet_open(), 0.30, 0.0, 0.0001, "full motion open")
	UiMotion.reduce = true
	check_close(UiMotion.sheet_open(), 0.15, 0.0, 0.0001, "reduce motion: 150 ms fade in")
	check_close(UiMotion.sheet_close(), 0.12, 0.0, 0.0001, "reduce motion: 120 ms fade out")
	# Reduce motion: the panel never slides; it sits at its final place and fades.
	_ui = H.mount(_tree.root, "iphone_17e_390x844")
	await H.settle(_tree)
	var s: Sheet = _ui.sheets.sheet(&"feed")
	_ui.sheets.open(&"feed")
	await _tree.process_frame
	var final_top: float = 844.0 - s.sheet_height()
	check_close(s.panel.get_global_rect().position.y, final_top, 0.0, EPS, "reduce motion: no slide")
	check(s.panel.modulate.a < 1.0, "reduce motion: the panel is fading in")
	await _wait(0.3)
	check_close(s.panel.modulate.a, 1.0, 0.0, 0.001, "faded in")
	# Full motion: the panel starts below its final place.
	s.close()
	await _wait(0.3)
	UiMotion.reduce = false
	_ui.sheets.open(&"feed")
	await _tree.process_frame
	check(s.panel.get_global_rect().position.y > final_top + 1.0, "full motion: the sheet slides up")
	await _wait(0.45)
	check_close(s.panel.get_global_rect().position.y, final_top, 0.0, EPS, "the sheet ends at its height")


func test_sheet_heights_follow_the_spec() -> void:
	_ui = H.mount(_tree.root, "iphone_17e_390x844")
	await H.settle(_tree)
	var insets: SafeInsets = H.device_insets("iphone_17e_390x844")
	check_close(_ui.sheets.sheet(&"inspect").sheet_height(), 844.0 * 0.42, 0.0, EPS, "peek 42%")
	check_close(_ui.sheets.sheet(&"feed").sheet_height(), 844.0 * 0.60, 0.0, EPS, "half 60%")
	check_close(_ui.sheets.sheet(&"journal").sheet_height(), 844.0 - insets.top - 12.0, 0.0, EPS, "full")
	check(844.0 - _ui.sheets.sheet(&"feed").sheet_height() >= 0.40 * 844.0 - EPS, "a half sheet's top stays below 40%")


## Waits until `cond` is true, at most `max_s` seconds.
func _until(cond: Callable, max_s: float) -> void:
	var end_ms: int = Time.get_ticks_msec() + int(max_s * 1000.0)
	while not cond.call() and Time.get_ticks_msec() < end_ms:
		await _tree.process_frame


func _wait(seconds: float) -> void:
	await _tree.create_timer(seconds).timeout


func _check_sheet(tag: String, s: Sheet, screen: Vector2, insets: SafeInsets) -> void:
	var panel: Rect2 = s.panel.get_global_rect()
	check(panel.end.y <= screen.y + EPS, tag + " panel ends at the screen bottom")
	var done: Rect2 = s.done_button.get_global_rect()
	check(screen.y - done.end.y >= insets.bottom + 8.0 - EPS, tag + " Done sits above the bottom inset")
	var targets: Array[Control] = []
	for c: Control in H.visible_controls(s.panel):
		var r: Rect2 = c.get_global_rect()
		var label: Label = c as Label
		if label != null and label.text != "":
			check(label.get_line_count() <= label.get_visible_line_count(), "%s label %s shows all lines" % [tag, label.name])
			if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
				var w: float = label.get_theme_font(&"font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
					label.get_theme_font_size(&"font_size")).x
				check(w <= r.size.x + EPS, "%s label %s fits" % [tag, label.name])
		if c is BaseButton:
			targets.append(c)
			check(r.size.x >= 44.0 - EPS and r.size.y >= 44.0 - EPS, "%s %s target %s >= 44" % [tag, c.name, r.size])
			check(c.accessibility_name.length() > 0 and c.accessibility_name.length() <= 40,
				"%s %s accessibility_name '%s'" % [tag, c.name, c.accessibility_name])
			var b: Button = c as Button
			if b.text != "" and b.autowrap_mode == TextServer.AUTOWRAP_OFF:
				var font: Font = b.get_theme_font(&"font")
				var w2: float = font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size(&"font_size")).x
				var box: StyleBox = b.get_theme_stylebox(&"normal")
				var room: float = r.size.x - box.get_margin(SIDE_LEFT) - box.get_margin(SIDE_RIGHT)
				if b.icon != null:
					room -= b.get_theme_constant(&"icon_max_width") + b.get_theme_constant(&"h_separation")
				check(w2 <= room + EPS, "%s %s text '%s' fits (%.1f of %.1f)" % [tag, c.name, b.text, w2, room])
			# Rows below the fold scroll; they must fit the sheet's width, and the footer must stay inside.
			check(r.position.x >= panel.position.x - EPS and r.end.x <= panel.end.x + EPS,
				"%s %s %s inside the sheet's width %s" % [tag, c.name, r, panel])
			if not s.content.is_ancestor_of(c):
				check(panel.grow(EPS).encloses(r), "%s %s %s inside the sheet %s" % [tag, c.name, r, panel])
	# Scrolled rows are clipped to the scroll area, so compare the parts a finger can reach.
	var scroll_rect: Rect2 = (s.content.get_parent() as Control).get_global_rect()
	for i: int in targets.size():
		for j: int in range(i + 1, targets.size()):
			var a: Rect2 = _reachable(s, targets[i], scroll_rect)
			var b2: Rect2 = _reachable(s, targets[j], scroll_rect)
			if a.size.x <= 2.0 * EPS or a.size.y <= 2.0 * EPS or b2.size.x <= 2.0 * EPS or b2.size.y <= 2.0 * EPS:
				continue
			check(not a.grow(-EPS).intersects(b2.grow(-EPS)), "%s %s and %s don't overlap" % [tag, targets[i].name, targets[j].name])


func _reachable(s: Sheet, c: Control, scroll_rect: Rect2) -> Rect2:
	var r: Rect2 = c.get_global_rect()
	if not s.content.is_ancestor_of(c):
		return r
	return r.intersection(scroll_rect) if r.intersects(scroll_rect) else Rect2()
