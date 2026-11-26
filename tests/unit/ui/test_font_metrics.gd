extends TestCase
## Font widths against the 0.47 em rule the copy limits assume (ux-design §17 and §18, D-029).
## Average advance per character, spaces included, over every string in en.csv. The same method gives
## Figtree 0.432 (Regular) and 0.439 (SemiBold), within 0.005 em of ux-designer's CoreText figures (0.427,
## 0.435), so the numbers are comparable.
## Fraunces is the name and journal-title face, so it is also measured on the 24 name suggestions and
## checked where it is used: every suggestion fits the 240 pt name row at 150% (30 pt) without shrinking.

const RULE_EM: float = 0.47
const NAME_ROW_PT: float = 240.0


func test_figtree_weights_fit_the_rule() -> void:
	var text: String = _catalog_text(false)
	for w: int in [UiFonts.WEIGHT_REGULAR, UiFonts.WEIGHT_SEMIBOLD]:
		var em: float = avg_em(UiFonts.figtree(w), text)
		print("    Figtree wght %d: %.3f em over %d chars" % [w, em, text.length()])
		check(em < RULE_EM, "Figtree %d averages %.3f em < 0.47" % [w, em])


func test_fraunces_width_and_the_name_row() -> void:
	var face: FontVariation = UiFonts.fraunces(UiFonts.WEIGHT_SEMIBOLD)
	var all: float = avg_em(face, _catalog_text(false))
	var names: float = avg_em(face, _catalog_text(true))
	var fig_names: float = avg_em(UiFonts.figtree(UiFonts.WEIGHT_SEMIBOLD), _catalog_text(true))
	print("    Fraunces SemiBold opsz 20 SOFT 50 WONK 0: %.3f em (catalog), %.3f em (names; Figtree SemiBold %.3f)" % [all, names, fig_names])
	check(all < RULE_EM, "Fraunces SemiBold averages %.3f em < 0.47 on the catalog" % all)
	var widest: float = 0.0
	for n: String in _names():
		var w: float = face.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		widest = maxf(widest, w)
		check(w <= NAME_ROW_PT, "'%s' at 30 pt is %.1f pt, fits the 240 pt row" % [n, w])
	print("    widest suggested name at 30 pt: %.1f of 240 pt" % widest)
	# A 16-character name at the 0.47 rule needs 16 x 0.47 x 30 = 225.6 pt; at Fraunces' own name width:
	var sixteen: float = 16.0 * names * 30.0
	print("    16 chars at the measured name width: %.1f pt (auto-fit to 85%% covers up to %.1f pt)" % [sixteen, NAME_ROW_PT / 0.85])
	check(sixteen <= NAME_ROW_PT / 0.85, "a 16-character name fits after the 85% auto-fit")


static func avg_em(font: Font, text: String) -> float:
	var size: int = 100
	var total: float = 0.0
	var chars: int = 0
	var space: float = font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	for word: String in text.split(" ", false):
		total += font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + space
		chars += word.length() + 1
	return total / (float(maxi(chars, 1)) * size)


func _names() -> PackedStringArray:
	var out := PackedStringArray()
	var f: FileAccess = FileAccess.open("res://src/i18n/en.csv", FileAccess.READ)
	f.get_csv_line()
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() > 1 and row[0].begins_with("NAME_SUGGEST_"):
			out.append(row[1])
	return out


func _catalog_text(names_only: bool) -> String:
	if names_only:
		return " ".join(_names())
	var parts := PackedStringArray()
	var f: FileAccess = FileAccess.open("res://src/i18n/en.csv", FileAccess.READ)
	f.get_csv_line()
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() > 1:
			parts.append(row[1])
	return " ".join(parts)
