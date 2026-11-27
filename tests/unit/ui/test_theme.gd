extends TestCase
## The one Theme (architecture §9.1, AC-12.3 to AC-12.5, ux-design §16.1 and §17): fresh against its
## builder, the palette and type scale from the docs, WCAG contrast computed (not eyeballed), and no
## Control in the UI resolving to Godot's default theme.

const H := preload("res://tests/unit/ui/ui_harness.gd")

## ux-design §16.1 / art-direction §2.2.
const HEX: Dictionary[StringName, String] = {
	&"surface": "#FBF6EC", &"surface_alt": "#F1E7D6", &"ink": "#33241A", &"ink_muted": "#6A5444",
	&"accent": "#4F6B47", &"on_accent": "#FFFCF5", &"outline": "#8A7461", &"disabled": "#8F7D6E",
	&"tone_good": "#4F7A45", &"tone_watch": "#8A6414", &"tone_care": "#6E4F12", &"tone_stop": "#8E2B22",
	&"tone_rest": "#4E6A80", &"care_fill": "#F4E4BE",
}


func test_theme_file_is_fresh() -> void:
	var saved: Theme = load(ThemeBuilder.THEME_PATH) as Theme
	check(saved != null, "sourdough_theme.tres loads as a Theme")
	if saved == null:
		return
	# A UiRoot elsewhere may have merged runtime values into the cached copy; read the file itself.
	var disk: Theme = ResourceLoader.load(ThemeBuilder.THEME_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	var fresh: Theme = ThemeBuilder.build(UiPalette.new(0.0), 1.0)
	var diffs: PackedStringArray = _diff(disk, fresh)
	check(diffs.is_empty(), "the .tres matches ThemeBuilder (run tests/unit/ui/tools/build_theme.gd): %s" % ", ".join(diffs.slice(0, 8)))
	check(disk.default_font is FontVariation, "the default font is our Figtree face")


func test_palette_matches_the_docs() -> void:
	var t: Theme = ThemeBuilder.build(UiPalette.new(0.0), 1.0)
	for role: StringName in HEX:
		check_eq(t.get_color(role, ThemeBuilder.PALETTE_TYPE).to_html(false).to_upper(), HEX[role].trim_prefix("#"), String(role))
	var night: Theme = ThemeBuilder.build(UiPalette.new(1.0), 1.0)
	check_eq(night.get_color(&"surface", ThemeBuilder.PALETTE_TYPE).to_html(false).to_upper(), "EDE3D2", "surface_night")
	check_close(night.get_color(&"plate", ThemeBuilder.PALETTE_TYPE).a, 0.94, 0.0, 0.001, "night plate alpha 0.94")
	check_close(t.get_color(&"plate", ThemeBuilder.PALETTE_TYPE).a, 0.88, 0.0, 0.001, "day plate alpha 0.88")
	check_close(UiPalette.new(0.5).plate().a, 0.91, 0.0, 0.001, "mid fade plate alpha follows the night factor")


func test_type_scale_matches_ux_17() -> void:
	var expect: Dictionary[float, Array] = {1.0: [20, 17, 16, 14], 1.25: [25, 21, 20, 16], 1.5: [30, 26, 24, 16]}
	for scale: float in expect:
		var t: Theme = ThemeBuilder.build(UiPalette.new(0.0), scale)
		var row: Array = expect[scale]
		var tag: String = "@%d%%" % roundi(scale * 100)
		check_eq(t.get_font_size(&"font_size", &"TitleLabel"), row[0], tag + " title")
		check_eq(t.get_font_size(&"font_size", &"NameLabel"), row[0], tag + " name")
		check_eq(t.get_font_size(&"font_size", &"StatusPill"), row[1], tag + " status word")
		check_eq(t.get_font_size(&"font_size", &"PrimaryButton"), row[1], tag + " button")
		check_eq(t.get_font_size(&"font_size", &"Label"), row[2], tag + " body")
		check_eq(t.get_font_size(&"font_size", &"HintLabel"), row[2], tag + " hint")
		check_eq(t.get_font_size(&"font_size", &"ChipButton"), row[2], tag + " chip")
		check_eq(t.get_font_size(&"font_size", &"ToastLabel"), row[2], tag + " toast")
		check_eq(t.get_font_size(&"font_size", &"ActionBarButton"), row[3], tag + " bar label (capped at 16)")
		check(t.get_font_size(&"font_size", &"BodyLabel") >= 16, tag + " body >= 16 pt")
		check_eq(t.get_font_size(&"font_size", &"BarPopupLabel"), 28, tag + " long-press label 28")


func test_contrast_day_and_night() -> void:
	for night: float in [0.0, 1.0]:
		var p := UiPalette.new(night)
		var tag: String = "night" if night > 0.0 else "day"
		var surf: Color = p.surface()
		_text(UiPalette.INK, surf, tag + " ink on surface")
		_text(UiPalette.INK_MUTED, surf, tag + " ink_muted on surface")
		_text(UiPalette.INK, UiPalette.SURFACE_ALT, tag + " ink on surface_alt (pill, chip)")
		_text(UiPalette.ON_ACCENT, UiPalette.ACCENT, tag + " on_accent on accent")
		_text(surf, UiPalette.INK, tag + " toast text on ink")
		_text(UiPalette.ON_ACCENT, UiPalette.TONE_STOP, tag + " moldy pill word")
		_text(UiPalette.INK, UiPalette.CARE_FILL, tag + " ink on care fill")
		_graphic(UiPalette.ACCENT, surf, tag + " accent on surface")
		_graphic(UiPalette.OUTLINE, surf, tag + " outline on surface")
		_graphic(UiPalette.OUTLINE, UiPalette.SURFACE_ALT, tag + " outline on surface_alt")
		_graphic(UiPalette.TONE_CARE, UiPalette.CARE_FILL, tag + " care icon on care fill")
		for tone: StringName in UiPalette.TONES:
			_graphic(UiPalette.TONES[tone], surf, "%s tone %s on surface" % [tag, tone])
			if tone != &"stop" and tone != &"care":
				_graphic(UiPalette.TONES[tone], UiPalette.SURFACE_ALT, "%s tone %s on the pill fill" % [tag, tone])
		# AC-12.4: plates over the scene, worst case pure black and pure white behind.
		var plate: Color = p.plate()
		check(plate.a >= 0.88 - 0.0001, tag + " plate alpha >= 0.88")
		for behind: Color in [Color.BLACK, Color.WHITE]:
			var shown: Color = behind.lerp(Color(plate, 1.0), plate.a)
			_text(UiPalette.INK, shown, "%s ink on plate over %s" % [tag, behind.to_html(false)])
			_text(UiPalette.INK_MUTED, shown, "%s ink_muted on plate over %s" % [tag, behind.to_html(false)])


func test_no_control_uses_the_default_theme() -> void:
	I18nLoader.load_all()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var ui: UiRoot = H.mount(tree.root, "iphone_17e_390x844")
	ui.apply_snapshot(H.snapshot(&"at_peak"))
	ui.sheets.open(&"settings")
	await H.settle(tree, 12)
	var default_theme: Theme = ThemeDB.get_default_theme()
	var checked: int = 0
	for c: Control in H.visible_controls(ui):
		var font: Font = c.get_theme_font(&"font")
		check(font != default_theme.default_font and font != ThemeDB.fallback_font,
			"%s (%s) resolves its font from our Theme" % [c.name, c.get_class()])
		var b: Button = c as Button
		if b != null:
			for slot: StringName in [&"normal", &"pressed", &"focus"]:
				var mine: StyleBox = b.get_theme_stylebox(slot)
				check(mine != default_theme.get_stylebox(slot, &"Button"), "%s %s stylebox is ours" % [c.name, slot])
		checked += 1
	check(checked > 30, "walked %d controls" % checked)
	check_eq((ui.theme as Theme).resource_path, ThemeBuilder.THEME_PATH, "one Theme: the UI root uses sourdough_theme.tres")
	ui.get_parent().queue_free()
	await tree.process_frame


static func luminance(c: Color) -> float:
	var ch: Array[float] = []
	for v: float in [c.r, c.g, c.b]:
		ch.append(v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2]


static func ratio(a: Color, b: Color) -> float:
	var la: float = luminance(a)
	var lb: float = luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _text(fg: Color, bg: Color, what: String) -> void:
	var r: float = ratio(fg, bg)
	check(r >= 4.5, "%s: %.2f >= 4.5" % [what, r])


func _graphic(fg: Color, bg: Color, what: String) -> void:
	var r: float = ratio(fg, bg)
	check(r >= 3.0, "%s: %.2f >= 3" % [what, r])


func _diff(a: Theme, b: Theme) -> PackedStringArray:
	var out := PackedStringArray()
	if a.default_font_size != b.default_font_size:
		out.append("default_font_size")
	var kinds: Array[int] = [Theme.DATA_TYPE_COLOR, Theme.DATA_TYPE_CONSTANT, Theme.DATA_TYPE_FONT_SIZE,
		Theme.DATA_TYPE_STYLEBOX, Theme.DATA_TYPE_FONT]
	var types_a: PackedStringArray = a.get_type_list()
	var types_b: PackedStringArray = b.get_type_list()
	types_a.sort()
	types_b.sort()
	if types_a != types_b:
		out.append("type list")
		return out
	for type: String in types_b:
		if a.get_type_variation_base(type) != b.get_type_variation_base(type):
			out.append(type + " base")
		for kind: int in kinds:
			var names_a: PackedStringArray = a.get_theme_item_list(kind, type)
			var names_b: PackedStringArray = b.get_theme_item_list(kind, type)
			names_a.sort()
			names_b.sort()
			if names_a != names_b:
				out.append("%s items %d" % [type, kind])
				continue
			for item: String in names_b:
				var va: Variant = a.get_theme_item(kind, item, type)
				var vb: Variant = b.get_theme_item(kind, item, type)
				if not _same(va, vb):
					out.append("%s.%s" % [type, item])
	return out


func _same(x: Variant, y: Variant) -> bool:
	if typeof(x) != typeof(y):
		return false
	if typeof(x) != TYPE_OBJECT:
		return x == y
	var ox: Object = x
	var oy: Object = y
	if ox == null or oy == null:
		return ox == oy
	if ox.get_class() != oy.get_class():
		return false
	for prop: Dictionary in oy.get_property_list():
		var usage: int = prop.get("usage", 0)
		if usage & PROPERTY_USAGE_STORAGE == 0:
			continue
		var pname: StringName = prop.get("name", &"")
		var px: Variant = ox.get(pname)
		var py: Variant = oy.get(pname)
		if typeof(px) == TYPE_OBJECT and typeof(py) == TYPE_OBJECT:
			var rx: Resource = px as Resource
			var ry: Resource = py as Resource
			if rx != null and ry != null and rx.resource_path != "" and rx.resource_path == ry.resource_path:
				continue
			if not _same(px, py):
				return false
		elif typeof(px) == TYPE_FLOAT and typeof(py) == TYPE_FLOAT:
			if not is_equal_approx(float(px), float(py)):
				return false
		elif px != py:
			return false
	return true
