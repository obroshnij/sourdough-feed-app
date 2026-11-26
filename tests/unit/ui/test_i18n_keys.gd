extends TestCase
## Every tr() key the UI uses exists (architecture §10, CLAUDE.md rule 3): the key literals in src/ui/**
## (.gd and .tscn), plus the keys the UI builds from canonical ids. A key may live in the generated en.csv
## or in one of the pending_*.csv files. Also checks the slot limits the UI depends on.

const CATALOGS: Array[String] = [
	"res://src/i18n/en.csv", "res://src/i18n/pending_core.csv", "res://src/i18n/pending_view.csv",
	"res://src/i18n/pending_ui.csv",
]
const KEY_RE: String = "[\"']([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)[\"']"


func test_every_key_literal_in_src_ui_exists() -> void:
	var catalog: Dictionary[String, String] = _catalog()
	var re := RegEx.create_from_string(KEY_RE)
	var found: int = 0
	for path: String in _files("res://src/ui"):
		var text: String = FileAccess.get_file_as_string(path)
		for m: RegExMatch in re.search_all(text):
			var key: String = m.get_string(1)
			found += 1
			check(catalog.has(key) and catalog[key] != "", "%s uses %s, which is in a catalog" % [path, key])
	check(found >= 15, "found %d key literals in src/ui" % found)


func test_built_keys_exist() -> void:
	var catalog: Dictionary[String, String] = _catalog()
	for st: StringName in StatusStyle.STATES:
		var causes: Array[StringName] = [&""]
		if st == &"dormant":
			causes = [&"cold", &"starved"]
		for cause: StringName in causes:
			for key: StringName in [Keys.status_word(st, cause), Keys.status_hint(st, cause), Keys.status_tap(st, cause)]:
				check(catalog.has(String(key)), "status key %s exists" % key)
			var word: String = catalog.get(String(Keys.status_word(st, cause)), "")
			var hint: String = catalog.get(String(Keys.status_hint(st, cause)), "")
			check(word.length() <= 12, "%s word <= 12" % st)
			check(hint.length() <= 34, "%s hint <= 34" % st)
	for id: StringName in Hud.ACTIONS:
		var label: String = "ACTION_%s" % Keys.up(id)
		var text: String = catalog.get(label, "")
		var a11y: String = catalog.get(label + "_A11Y", "")
		check(catalog.has(label), label + " exists")
		check(text.length() <= 7, label + " <= 7 (bar slot)")
		check(catalog.has(label + "_A11Y"), label + "_A11Y exists")
		check(a11y.length() <= 40, label + "_A11Y <= 40")
	check(catalog.has("STATUS_A11Y"), "STATUS_A11Y exists")
	check(catalog.has(String(GameAction.REASON_MOLDY)), "the moldy feed reason exists")


func test_pending_ui_rows_are_well_formed() -> void:
	var f: FileAccess = FileAccess.open("res://src/i18n/pending_ui.csv", FileAccess.READ)
	check_eq(Array(f.get_csv_line()), ["keys", "en"], "header is keys,en")
	var en: Dictionary[String, String] = _read("res://src/i18n/en.csv")
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() < 2 or row[0].is_empty():
			continue
		check(RegEx.create_from_string("^[A-Z][A-Z0-9_]*$").search(row[0]) != null, row[0] + " key format")
		check(not en.has(row[0]), row[0] + " is not already in en.csv (delete the pending row once narrative moves it)")
		check(not row[1].contains("—"), row[0] + " has no em dash")


func _catalog() -> Dictionary[String, String]:
	var out: Dictionary[String, String] = {}
	for path: String in CATALOGS:
		out.merge(_read(path))
	return out


func _read(path: String) -> Dictionary[String, String]:
	var out: Dictionary[String, String] = {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var header: PackedStringArray = f.get_csv_line()
	var col: int = header.find("en")
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if col > 0 and row.size() > col and not row[0].is_empty():
			out[row[0]] = row[col]
	return out


func _files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			out.append(dir + "/" + f)
	for d: String in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir + "/" + d))
	return out
