extends TestCase
## The HUD driven end to end by the Session API and the fixture saves in tests/unit/ui/fixtures/ (made by
## tools/make_fixtures.gd from the real sim): boot_from_fixture(), then UiRoot.bind_session() reads
## Session.get_snapshot() and state_changed. The pill and hint must show the state the sim derived.

const H := preload("res://tests/unit/ui/ui_harness.gd")
const FIXTURES: String = "res://tests/unit/ui/fixtures"
const TMP: String = "user://test_tmp/ui_session"

var _tree: SceneTree = null
var _ui: UiRoot = null
var _session: GameSession = null


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
	if _session != null:
		_session.queue_free()
		_session = null
	await _tree.process_frame


func test_every_fixture_drives_the_pill_and_hint() -> void:
	if not require(&"m2_sim"):
		return
	var files: PackedStringArray = DirAccess.get_files_at(FIXTURES)
	var seen: Dictionary[StringName, bool] = {}
	for file: String in files:
		if not file.ends_with(".json"):
			continue
		_session = GameSession.new()
		_tree.root.add_child(_session)
		_session.setup(FakeClock.new(), SaveStore.new(TMP), SettingsStore.new(TMP + "/settings.cfg"))
		_session.boot_from_fixture("%s/%s" % [FIXTURES, file])
		check(_session.is_booted(), file + " boots")
		_ui = H.mount(_tree.root, "iphone_17e_390x844")
		_ui.bind_session(_session)
		await H.settle(_tree)
		var snap: StarterSnapshot = _session.get_snapshot()
		var expected: String = file.trim_suffix(".json")
		var shown: String = String(snap.state)
		if snap.state == &"dormant":
			shown += "_" + String(snap.dormant_cause)
		check_eq(shown, expected, file + " sim state matches the fixture name")
		check_eq(_ui.hud.status_pill.state_id, snap.state, file + " pill shows the session state")
		check_eq(_ui.hud.status_pill.text, tr(Keys.status_word(snap.state, snap.dormant_cause)), file + " pill word")
		var hint: String = _ui._forecast_hint(snap)
		if hint == "":
			hint = tr(Keys.status_hint(snap.state, snap.dormant_cause))
		check_eq(_ui.hud.hint_label.text, hint, file + " hint (the forecast right after a feed, ux §8)")
		check_eq(_ui.hud.name_label.text, "Bramble", file + " name")
		check_eq(_ui.hud.bar_button(&"feed").locked_reason_key != &"", snap.state == &"moldy", file + " feed lock")
		seen[snap.state] = true
		await after_each()
	check_eq(seen.size(), StatusStyle.STATES.size(), "fixtures cover all 11 states")


func test_settings_from_the_session_apply() -> void:
	if not require(&"m2_sim"):
		return
	_session = GameSession.new()
	_tree.root.add_child(_session)
	var store := SettingsStore.new(TMP + "/settings_apply.cfg")
	store.text_scale = 1.5
	store.reduce_motion = true
	_session.setup(FakeClock.new(), SaveStore.new(TMP), store)
	_session.boot_from_fixture(FIXTURES + "/hungry.json")
	UiMotion.reduce = false
	_ui = H.mount(_tree.root, "iphone_se_375x667")
	_ui.bind_session(_session)
	await H.settle(_tree)
	check_eq(_ui.text_scale, 1.5, "text size comes from the stored settings")
	check(UiMotion.reduce, "reduce motion comes from the stored settings")
	check_eq(_ui.hud.hint_label.get_theme_font_size(&"font_size"), 24, "hint at 150% is 24 pt")
	check(_ui.settings_sheet.size_chips[2].button_pressed, "the Largest chip shows as selected")
	check(_ui.settings_sheet.reduce_motion_row.button_pressed, "the reduce motion row shows on")
	_ui.set_text_scale(1.0)
