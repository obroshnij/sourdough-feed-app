extends TestCase
## LINT-04 (AC-12.14) and LINT-10 (CLK-13's automatable part), static checks over src/.
## - LINT-04: in every .tscn, text, placeholder_text, tooltip_text and accessibility_name are empty or an
##   UPPER_SNAKE key; every literal tr("KEY") in every script is in en.csv or a pending_*.csv.
## - LINT-10: DebugClock is built only behind OS.is_debug_build() or inside a dev/ tool folder; the dev
##   flags parse to nothing in release; Main adds the F3 overlay only in debug builds. A release-export
##   run of the same rule waits for Phase 5 (D-052 does not waive it; it is the export check).
## Dev tools under src/**/dev/ show developer text and are never player-facing.

const SRC: String = "res://src"
const CATALOGS: PackedStringArray = [
	"res://src/i18n/en.csv", "res://src/i18n/pending_core.csv", "res://src/i18n/pending_ui.csv",
	"res://src/i18n/pending_view.csv",
]
const SCENE_PROPS: PackedStringArray = ["text", "placeholder_text", "tooltip_text", "accessibility_name"]


func test_lint_04_scene_text_is_keys_and_every_tr_key_exists() -> void:
	var keys: Dictionary[String, bool] = _catalog_keys()
	check(keys.size() > 600, "the catalog loaded (%d keys)" % keys.size())
	var key_re := RegEx.create_from_string("^[A-Z][A-Z0-9_]*$")
	var prop_re := RegEx.create_from_string("^(%s) = \"(.*)\"$" % "|".join(SCENE_PROPS))
	var bad: PackedStringArray = PackedStringArray()
	var scenes: PackedStringArray = QaFiles.find(SRC, ".tscn")
	for path: String in scenes:
		if path.contains("/dev/"):
			continue
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			var m: RegExMatch = prop_re.search(line.strip_edges())
			if m == null:
				continue
			var value: String = m.get_string(2)
			if value != "" and (key_re.search(value) == null or not keys.has(value)):
				bad.append("%s: %s = \"%s\"" % [path, m.get_string(1), value])
	var tr_re := RegEx.create_from_string("\\btr\\(\\s*&?\"([^\"]+)\"")
	var used: int = 0
	for path: String in QaFiles.find(SRC, ".gd"):
		if path.contains("/dev/"):
			continue
		for m: RegExMatch in tr_re.search_all(FileAccess.get_file_as_string(path)):
			used += 1
			var key: String = m.get_string(1)
			if key_re.search(key) == null or not keys.has(key):
				bad.append("%s: tr(\"%s\") is not a catalog key" % [path, key])
	check(scenes.size() >= 3, "scanned %d scenes and %d tr() literals" % [scenes.size(), used])
	check(bad.is_empty(), "LINT-04:\n    " + "\n    ".join(bad.slice(0, 12)))


func test_lint_10_time_controls_are_debug_only() -> void:
	var bad: PackedStringArray = PackedStringArray()
	for path: String in QaFiles.find(SRC, ".gd"):
		if path.ends_with("/debug_clock.gd") or path.contains("/dev/"):
			continue
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i: int in lines.size():
			if lines[i].contains("DebugClock.new(") or lines[i].contains("DevOverlay.new("):
				var guarded: bool = false
				for j: int in range(maxi(0, i - 3), i):
					guarded = guarded or lines[j].contains("OS.is_debug_build()")
				if not guarded:
					bad.append("%s:%d builds a debug time control outside OS.is_debug_build()" % [path, i + 1])
	check(bad.is_empty(), "LINT-10:\n    " + "\n    ".join(bad))
	var flags: String = FileAccess.get_file_as_string("res://src/core/dev/dev_flags.gd")
	check(flags.contains("if not OS.is_debug_build():"), "DevFlags.parse() returns nothing in release builds")
	var main: String = FileAccess.get_file_as_string("res://src/main/main.gd")
	check(main.contains("if OS.is_debug_build():\n\t\tadd_child(DevOverlay.new())"), "Main adds the F3 overlay only in debug builds")


static func _catalog_keys() -> Dictionary[String, bool]:
	var keys: Dictionary[String, bool] = {}
	for path: String in CATALOGS:
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i: int in range(1, lines.size()):
			var key: String = lines[i].get_slice(",", 0).strip_edges()
			if key != "":
				keys[key] = true
	return keys
