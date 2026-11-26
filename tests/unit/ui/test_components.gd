extends TestCase
## Component behavior (ux-design §11, §16, §17): status never by color alone, care and stop pills, safe-area
## floors, the long-press label, the stepper limits and the toggle.

const H := preload("res://tests/unit/ui/ui_harness.gd")

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
		_ui.get_parent().queue_free()
		_ui = null
	await _tree.process_frame


func test_status_pill_icon_word_and_kind() -> void:
	_ui = H.mount(_tree.root, "iphone_17e_390x844")
	await H.settle(_tree)
	var pill: StatusPill = _ui.hud.status_pill
	var icons: Dictionary[String, StringName] = {}
	for snap: StarterSnapshot in H.all_snapshots():
		_ui.apply_snapshot(snap)
		await _tree.process_frame
		var tag: String = "%s/%s" % [snap.state, snap.dormant_cause]
		check(pill.icon != null, tag + " has an icon")
		check(pill.text != "" and pill.text != String(Keys.status_word(snap.state, snap.dormant_cause)), tag + " has a translated word")
		check(pill.accessibility_description.contains(pill.text), tag + " a11y description reads the word")
		if pill.icon != null:
			icons[pill.icon.resource_path] = snap.state
		var box: StyleBoxFlat = pill.get_theme_stylebox(&"normal") as StyleBoxFlat
		match StatusStyle.kind(snap.state):
			StatusStyle.Kind.CARE:
				check_eq(box.border_width_left, 3, tag + " care: 3 pt border")
				check_eq(box.bg_color, UiPalette.CARE_FILL, tag + " care: honey fill")
				check(pill.icon.resource_path.ends_with("_filled.svg"), tag + " care: filled icon")
			StatusStyle.Kind.STOP:
				check_eq(box.bg_color, UiPalette.TONE_STOP, tag + " stop: filled pill")
				check_eq(pill.get_theme_color(&"font_color"), UiPalette.ON_ACCENT, tag + " stop: cream word")
				check(pill.icon.resource_path.ends_with("_filled.svg"), tag + " stop: filled icon")
			StatusStyle.Kind.PEAK:
				check(box.shadow_size > 0, tag + " peak: glow")
			_:
				check_eq(box.border_width_left, 2, tag + " 2 pt tone border")
				check_eq(pill.get_theme_color(&"font_color"), UiPalette.INK, tag + " word in ink, not the tone")
				check(pill.icon.resource_path.ends_with("_outline.svg"), tag + " outline icon")
	check_eq(icons.size(), StatusStyle.STATES.size(), "each of the 11 states has its own icon shape")


func test_no_red_outside_moldy() -> void:
	for st: StringName in StatusStyle.STATES:
		var stop: bool = StatusStyle.tone(st) == &"stop"
		check_eq(stop, st == &"moldy", "%s uses the stop tone only if moldy" % st)


func test_safe_inset_floors() -> void:
	check_eq(SafeInsets.make(20, 0).with_floors("iOS").bar_gap(), 8.0, "iPhone SE bar gap 8")
	check_eq(SafeInsets.make(47, 34).with_floors("iOS").bar_gap(), 42.0, "iPhone 17e bar gap 42")
	check_eq(SafeInsets.make(24, 0).with_floors("Android").bar_gap(), 56.0, "Android bar gap floor 56")
	check_eq(SafeInsets.make(24, 63).with_floors("Android").bar_gap(), 71.0, "Android keeps a larger reported inset")
	check_eq(SafeInsets.make(62, 34).hud_top(), 70.0, "HUD top = safe top + 8")
	check_eq(SafeInsets.make(0, 0, 12, 0).gutter_left(), 28.0, "gutter 16 + side inset")
	check_eq(SafeInsets.from_display(2.0).top, 0.0, "desktop runs get no insets")


func test_long_press_shows_the_large_label() -> void:
	_ui = H.mount(_tree.root, "iphone_se_375x667")
	await H.settle(_tree)
	var smell: ActionBarButton = _ui.hud.bar_button(&"smell")
	var acted: Array[StringName] = []
	smell.activated.connect(func(id: StringName) -> void: acted.append(id))
	smell.button_down.emit()
	await _tree.create_timer(0.6).timeout
	check(smell.is_popup_visible(), "after 500 ms the label popup shows")
	var popup_label: Label = smell.get_node(^"LabelPopup").get_child(0) as Label
	check_eq(popup_label.get_theme_font_size(&"font_size"), 28, "the popup label is 28 pt (200%)")
	check_eq(popup_label.text, smell.text, "the popup shows the button label")
	smell.button_up.emit()
	smell.pressed.emit()
	check(not smell.is_popup_visible(), "release hides it")
	check(acted.is_empty(), "a long-press doesn't act")
	smell.button_down.emit()
	smell.button_up.emit()
	smell.pressed.emit()
	check_eq(acted, [&"smell"], "a tap acts")


func test_stepper_limits_and_toggle() -> void:
	var holder := Control.new()
	holder.theme = load(ThemeBuilder.THEME_PATH) as Theme
	_tree.root.add_child(holder)
	var st := Stepper.new()
	st.min_value = 24
	st.max_value = 30
	holder.add_child(st)
	st.value = 30
	await _tree.process_frame
	check(st.plus.disabled, "+ disables at the max")
	check(not st.minus.disabled, "- stays on")
	check(st.minus.size.x >= 48.0 and st.minus.size.y >= 48.0, "stepper buttons are 48")
	check(st.minus.accessibility_name != "" and st.plus.accessibility_name != "", "stepper buttons have names")
	st.step(-1)
	check_eq(st.value, 29, "step down")
	st.value = 10
	check_eq(st.value, 24, "clamped to min")
	check(st.minus.disabled, "- disables at the min")
	var row := ToggleRow.new(&"SETTINGS_REDUCE_MOTION")
	holder.add_child(row)
	await _tree.process_frame
	check(row.size.y >= 52.0, "toggle row >= 52 tall")
	check_eq(row.text, tr(&"SETTINGS_REDUCE_MOTION"), "toggle label from its key")
	holder.queue_free()
	await _tree.process_frame
