extends TestCase
## Headless layout of the HUD shell at fixed root sizes (AC-12.1, AC-12.2, AC-12.6, ux-design §2 and §16):
## every device profile x every text size x every status, with the longest copy the pill and hint show.

const H := preload("res://tests/unit/ui/ui_harness.gd")
const MIN_TARGET: float = 44.0
const BAR_SLOT: float = 64.0
const EPS: float = 0.51

var _tree: SceneTree = null
var _ui: UiRoot = null


func before_each() -> void:
	I18nLoader.load_all()
	# No press or pulse scaling, so rects are the laid-out rects.
	UiMotion.reduce = true
	_tree = Engine.get_main_loop() as SceneTree
	# The root only takes children once the first frame has run.
	await _tree.process_frame


func after_each() -> void:
	UiMotion.reduce = false
	if _ui != null:
		_ui.get_parent().queue_free()
		_ui = null
	await _tree.process_frame


func test_insets_gutters_and_jar_region() -> void:
	for device: String in H.DEVICES:
		for scale: float in TypeScale.SCALES:
			await _mount(device, scale)
			_ui.apply_snapshot(H.snapshot(&"at_peak"))
			await H.settle(_tree)
			var insets: SafeInsets = H.device_insets(device)
			var size: Vector2 = H.device_size(device)
			var plate: Rect2 = _ui.hud.top_plate.get_global_rect()
			var bar: Rect2 = _ui.hud.action_bar.get_global_rect()
			var tag: String = "%s @%d%%" % [device, roundi(scale * 100)]
			check_close(plate.position.y, insets.top + 8.0, 0.0, EPS, tag + " plate top = safe top + 8")
			check_close(size.y - bar.end.y, insets.bottom + 8.0, 0.0, EPS, tag + " bar bottom = safe bottom + 8")
			check(plate.position.x >= 16.0 - EPS and size.x - plate.end.x >= 16.0 - EPS, tag + " plate gutters >= 16")
			check(bar.position.x >= 16.0 - EPS and size.x - bar.end.x >= 16.0 - EPS, tag + " bar gutters >= 16")
			if device.begins_with("android"):
				check(size.y - bar.end.y >= 56.0 - EPS, tag + " Android bar gap >= 56 dp")
			var region: Rect2 = _ui.jar_region()
			check_close(region.position.y, plate.end.y, 0.0, EPS, tag + " jar region starts under the plate")
			check_close(region.end.y, bar.position.y, 0.0, EPS, tag + " jar region ends at the bar")
			if not device.begins_with("android"):
				check(region.size.y >= 0.55 * size.y, "%s jar region %.0f pt is >= 55%% of %.0f" % [tag, region.size.y, size.y])
			await after_each()


func test_targets_text_and_names_for_every_status() -> void:
	for device: String in H.DEVICES:
		for scale: float in TypeScale.SCALES:
			await _mount(device, scale)
			for snap: StarterSnapshot in H.all_snapshots("Gluten Morgen"):
				_ui.apply_snapshot(snap)
				await H.settle(_tree, 2)
				var tag: String = "%s @%d%% %s/%s" % [device, roundi(scale * 100), snap.state, snap.dormant_cause]
				_check_hud(tag)
			await after_each()


func test_routing_filters_on_the_top_plate() -> void:
	await _mount("iphone_17e_390x844", 1.0)
	_ui.apply_snapshot(H.snapshot(&"active"))
	await H.settle(_tree)
	var stops: Array[String] = []
	for c: Control in H.visible_controls(_ui.hud.top_plate):
		if c.mouse_filter == Control.MOUSE_FILTER_STOP:
			stops.append(String(c.name))
	stops.sort()
	check_eq(stops, ["Settings", "Status"], "only the pill and settings stop touches on the top plate")
	check_eq(_ui.hud.mouse_filter, Control.MOUSE_FILTER_IGNORE, "HUD layer ignores touches")
	check_eq(_ui.mouse_filter, Control.MOUSE_FILTER_IGNORE, "UI root ignores touches")
	check_eq(_ui.hud.action_bar.mouse_filter, Control.MOUSE_FILTER_STOP, "the whole bar plate stops touches")


func test_feed_emphasis_and_moldy_lock() -> void:
	await _mount("iphone_se_375x667", 1.0)
	var feed: ActionBarButton = _ui.hud.bar_button(&"feed")
	_ui.apply_snapshot(H.snapshot(&"hungry"))
	check(feed.emphasized, "hungry: Feed gets the halo and dot")
	_ui.apply_snapshot(H.snapshot(&"collapsing"))
	check(feed.emphasized, "collapsing: Feed gets the halo and dot")
	_ui.apply_snapshot(H.snapshot(&"at_peak"))
	check(not feed.emphasized, "at_peak: no emphasis")
	var others: int = 0
	for b: ActionBarButton in _ui.hud.bar_buttons():
		if b != feed and b.emphasized:
			others += 1
	check_eq(others, 0, "no other button ever gets a badge")
	_ui.apply_snapshot(H.snapshot(&"moldy"))
	await H.settle(_tree)
	check_eq(feed.locked_reason_key, &"MOLD_FEED_BLOCKED", "moldy: Feed is locked with a reason")
	check(not feed.emphasized, "moldy: no feed emphasis")
	var reasons: Array[StringName] = []
	feed.locked_pressed.connect(func(k: StringName) -> void: reasons.append(k))
	feed.pressed.emit()
	await H.settle(_tree)
	check_eq(reasons, [&"MOLD_FEED_BLOCKED"], "a tap on locked Feed reports the reason")
	check(_ui.toast.is_shown(), "the reason is shown in a toast")
	check_eq(_ui.toast.label.text, tr(&"MOLD_FEED_BLOCKED"), "toast shows the reason text")
	check(not _ui.sheets.has_open_sheet(), "a locked Feed opens no sheet")


func _mount(device: String, scale: float) -> void:
	_ui = H.mount(_tree.root, device, scale)
	await H.settle(_tree)


func _check_hud(tag: String) -> void:
	var root_rect: Rect2 = _ui.get_global_rect()
	var targets: Array[Control] = []
	for c: Control in H.visible_controls(_ui.hud):
		var r: Rect2 = c.get_global_rect()
		if c is BaseButton:
			targets.append(c)
			check(r.size.x >= MIN_TARGET - EPS and r.size.y >= MIN_TARGET - EPS,
				"%s %s target %s >= 44 x 44" % [tag, c.name, r.size])
			check(c.accessibility_name.length() > 0 and c.accessibility_name.length() <= 40,
				"%s %s accessibility_name 1..40 chars: '%s'" % [tag, c.name, c.accessibility_name])
		if c is ActionBarButton:
			check(r.size.x >= BAR_SLOT - EPS and r.size.y >= BAR_SLOT - EPS, "%s %s bar slot %s >= 64 x 64" % [tag, c.name, r.size])
		check(root_rect.encloses(r.grow(-EPS)), "%s %s %s stays on screen" % [tag, c.name, r])
		var label: Label = c as Label
		if label != null and label.text != "":
			_check_label(tag, label)
		var button: Button = c as Button
		if button != null and button.text != "":
			_check_button_text(tag, button)
	for i: int in targets.size():
		for j: int in range(i + 1, targets.size()):
			var a: Rect2 = targets[i].get_global_rect().grow(-EPS)
			var b: Rect2 = targets[j].get_global_rect().grow(-EPS)
			check(not a.intersects(b), "%s hit areas %s and %s don't overlap" % [tag, targets[i].name, targets[j].name])


func _check_label(tag: String, label: Label) -> void:
	var font: Font = label.get_theme_font(&"font")
	var fsize: int = label.get_theme_font_size(&"font_size")
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var w: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		var fits: bool = w <= label.size.x + EPS
		if label is FitLabel:
			check(fits, "%s name '%s' fits at %d pt (%.1f of %.1f)" % [tag, label.text, fsize, w, label.size.x])
		else:
			check(fits, "%s label %s '%s' fits on one line" % [tag, label.name, label.text])
	else:
		check(label.get_line_count() <= label.get_visible_line_count(),
			"%s label %s shows all %d lines" % [tag, label.name, label.get_line_count()])
		check(label.size.y >= label.get_minimum_size().y - EPS, "%s label %s is as tall as its text" % [tag, label.name])


func _check_button_text(tag: String, b: Button) -> void:
	var font: Font = b.get_theme_font(&"font")
	var fsize: int = b.get_theme_font_size(&"font_size")
	var box: StyleBox = b.get_theme_stylebox(&"normal")
	var w: float = font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var room: float = b.size.x - box.get_margin(SIDE_LEFT) - box.get_margin(SIDE_RIGHT)
	if b.icon != null and b.vertical_icon_alignment != VERTICAL_ALIGNMENT_TOP:
		room -= b.get_theme_constant(&"icon_max_width") + b.get_theme_constant(&"h_separation")
	check(w <= room + EPS, "%s button %s text '%s' fits (%.1f of %.1f)" % [tag, b.name, b.text, w, room])
