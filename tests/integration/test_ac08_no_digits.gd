extends SliceCase
## AC-08.3 (UX §4): no digit on the main screen, its toasts or its cards, other than in the name the player
## typed. The real UiRoot (mounted by T3's harness at the 17e size) is bound to a real Session for each of
## T3's 12 state fixtures, then scanned. One fixture is also fed and played through its first rise, so the
## forecast hint and an info toast are on screen for the scan. Sheets that legitimately show numbers
## (the place cards' °C, the feed grams) are not part of the main screen.

const H := preload("res://tests/unit/ui/ui_harness.gd")
const FIXTURES: String = "res://tests/unit/ui/fixtures"
const NAME: String = "Bramble"

var _ui: UiRoot = null


func before_each() -> void:
	await super.before_each()
	UiMotion.reduce = true


func after_each() -> void:
	if _ui != null and is_instance_valid(_ui):
		_ui.get_parent().free()
	_ui = null
	UiMotion.reduce = false
	super.after_each()


func test_ac_08_3_no_digits_on_the_main_screen_toasts_or_cards() -> void:
	if not (ready_for_integration() and require(&"p3_contracts") and require(&"p3_rules")):
		return
	var tree := Engine.get_main_loop() as SceneTree
	var scanned: int = 0
	var found: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(FIXTURES):
		if not file.ends_with(".json"):
			continue
		var h: SliceHarness = phone("digits_" + file.get_basename())
		h.launch_fixture(FIXTURES.path_join(file))
		_mount(h)
		await H.settle(tree)
		scanned += _scan(file, found)
		if file == "at_peak.json":
			h.apply(feed_111())
			await H.settle(tree)
			scanned += _scan(file + " after a feed", found)
			h.play(2 * HOUR)
			await H.settle(tree)
			scanned += _scan(file + " at the first rise", found)
		_ui.get_parent().free()
		_ui = null
		h.dispose()
	# 14 scans (12 fixtures, plus a feed and a first rise); each main screen shows at least the name, the
	# status word and the hint.
	check(scanned >= 14 * 3, "scanned %d visible texts in 14 scans" % scanned)
	check(found.is_empty(), "digits on the main screen:\n    " + "\n    ".join(found.slice(0, 10)))


func _mount(h: SliceHarness) -> void:
	_ui = H.mount((Engine.get_main_loop() as SceneTree).root, "iphone_17e_390x844")
	_ui.bind_session(h.session)


## Adds "where: text" for every visible text with a digit outside the player's name. Returns how many
## texts it read.
func _scan(where: String, found: PackedStringArray) -> int:
	var digit := RegEx.create_from_string("[0-9]")
	var n: int = 0
	for c: Control in H.visible_controls(_ui):
		var text: String = ""
		if c is Label:
			text = (c as Label).text
		elif c is Button:
			text = (c as Button).text
		elif c is RichTextLabel:
			text = (c as RichTextLabel).get_parsed_text()
		if text.is_empty():
			continue
		n += 1
		if digit.search(text.replace(NAME, "")) != null:
			found.append("%s: %s \"%s\"" % [where, c.name, text])
	return n
