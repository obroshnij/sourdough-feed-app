extends TestCase
## LINT-03 and R-8 (test-plan §1, §2.7; CLAUDE.md hard rule 4: untyped declarations are errors).
## The engine does the type checking. This lint makes sure it is switched on and can't be
## bypassed: the warning levels from architecture §13, no directory rule over src/ or tests/,
## no @warning_ignore for the typing warnings, and every script under src/ and tests/ compiles.

## architecture §13: these must be 2 (error).
const ERROR_WARNINGS: PackedStringArray = [
	"untyped_declaration",
	"unsafe_property_access",
	"unsafe_method_access",
]
const SCANNED_DIRS: PackedStringArray = ["res://src", "res://tests"]


func test_typing_warnings_are_errors() -> void:
	check_eq(ProjectSettings.get_setting("debug/gdscript/warnings/enable", false), true,
			"debug/gdscript/warnings/enable")
	for warning: String in ERROR_WARNINGS:
		var key: String = "debug/gdscript/warnings/" + warning
		check_eq(ProjectSettings.get_setting(key, 0), 2, key + " (2 = error)")


func test_no_directory_rule_covers_src_or_tests() -> void:
	var rules: Variant = ProjectSettings.get_setting("debug/gdscript/warnings/directory_rules", {})
	if typeof(rules) != TYPE_DICTIONARY:
		check(false, "directory_rules is not a Dictionary: %s" % str(rules))
		return
	var covering: PackedStringArray = PackedStringArray()
	for rule_path: Variant in (rules as Dictionary).keys():
		var p: String = String(rule_path).trim_suffix("/")
		for dir: String in SCANNED_DIRS:
			if dir == p or dir.begins_with(p + "/") or p == "res:/":
				covering.append("%s covers %s" % [rule_path, dir])
	check(covering.is_empty(), "a warning directory rule could switch typing off. Ask qa-engineer first:\n"
			+ "\n".join(covering))


## R-8: every .gd under src/ loads and instantiates with the project's warning settings.
func test_every_src_script_compiles() -> void:
	var files: PackedStringArray = QaFiles.find("res://src", ".gd")
	if files.is_empty():
		skip("no .gd files under src/ yet (they arrive with T1's contracts commit)")
		return
	_check_compiles(files)


## Helpers and fixtures under tests/. The runner itself loads every test_*.gd.
func test_every_test_helper_compiles() -> void:
	var helpers: PackedStringArray = PackedStringArray()
	for path: String in QaFiles.find("res://tests", ".gd"):
		if not path.get_file().begins_with("test_"):
			helpers.append(path)
	_check_compiles(helpers)


func test_no_warning_ignore_for_typing() -> void:
	# Built from pieces so this file doesn't match its own scan.
	var annotation: String = "@" + "warning_ignore"
	var pattern: RegEx = RegEx.create_from_string(
			annotation + "(_start)?\\s*\\([^)]*\\b(" + "|".join(ERROR_WARNINGS) + ")\\b")
	var hits: PackedStringArray = PackedStringArray()
	var scanned: int = 0
	for dir: String in SCANNED_DIRS:
		for path: String in QaFiles.find(dir, ".gd"):
			scanned += 1
			var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
			for n: int in lines.size():
				if pattern.search(lines[n]) != null:
					hits.append("%s:%d %s" % [path, n + 1, lines[n].strip_edges()])
	check(scanned > 0, "scanned no .gd files")
	check(hits.is_empty(), "typing warnings may not be silenced (hard rule 4):\n" + "\n".join(hits))


func _check_compiles(files: PackedStringArray) -> void:
	var broken: PackedStringArray = PackedStringArray()
	for path: String in files:
		var script: GDScript = load(path) as GDScript
		if script == null or not script.can_instantiate():
			broken.append(path)  # The logged parse error is added to the failure by the runner.
	check(broken.is_empty(), "%d of %d scripts don't compile:\n%s"
			% [broken.size(), files.size(), "\n".join(broken)])
