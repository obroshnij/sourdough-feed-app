extends TestCase
## LINT-01 (test-plan §2.7, architecture §1 rule 4, CLAUDE.md hard rule 1): src/sim/** stays
## pure. No Nodes, scenes or engine singletons, no global RNG, no loading, no tr().
## Comments are stripped before matching, so "never touches Time." in a doc line is fine.
## Methods on a passed-in RNG (`rng.randi()`) are allowed. Global `randi()` is not.

const SIM_DIR := "res://src/sim"

## [pattern, what it forbids]. Patterns run on code with comments removed.
const RULES: Array[Array] = [
	["\\bextends\\s+Node", "extends Node"],
	["\\bNode\\.new\\b", "Node.new"],
	["\\bget_tree\\s*\\(", "get_tree("],
	["\\bTime\\.", "Time."],
	["\\bOS\\.", "OS."],
	["\\bEngine\\.", "Engine."],
	["\\bInput\\.", "Input."],
	["\\bDisplayServer\\.", "DisplayServer."],
	["\\bFileAccess\\b", "FileAccess"],
	["\\bDirAccess\\b", "DirAccess"],
	["\\bload\\s*\\(", "load("],
	["\\bpreload\\s*\\(", "preload("],
	["\\bResource(Loader|Saver)\\b", "ResourceLoader or ResourceSaver"],
	["(?<![\\w.])randi\\s*\\(", "global randi("],
	["(?<![\\w.])randf\\s*\\(", "global randf("],
	["(?<![\\w.])(randi_range|randf_range|randfn|seed)\\s*\\(", "global RNG function"],
	["\\brandomize\\s*\\(", "randomize("],
	["\\btr(_n)?\\s*\\(", "tr("],
]


func test_lint_01_sim_has_no_forbidden_tokens() -> void:
	var files: PackedStringArray = _sim_files()
	if files.is_empty():
		return
	var compiled: Array[RegEx] = []
	for rule: Array in RULES:
		compiled.append(RegEx.create_from_string(String(rule[0])))
	var hits: PackedStringArray = PackedStringArray()
	for path: String in files:
		var lines: PackedStringArray = strip_comments(FileAccess.get_file_as_string(path)).split("\n")
		for n: int in lines.size():
			for i: int in compiled.size():
				if compiled[i].search(lines[n]) != null:
					hits.append("%s:%d uses %s: %s" % [path, n + 1, String(RULES[i][1]), lines[n].strip_edges()])
	check(hits.is_empty(), "src/sim must stay pure (architecture §1), %d files scanned:\n%s"
			% [files.size(), "\n".join(hits)])


func test_lint_01_sim_scripts_are_not_nodes() -> void:
	var files: PackedStringArray = _sim_files()
	if files.is_empty():
		return
	var nodes: PackedStringArray = PackedStringArray()
	for path: String in files:
		var script: GDScript = load(path) as GDScript
		if script == null or not script.can_instantiate():
			continue  # LINT-03 reports scripts that don't compile.
		var base: StringName = script.get_instance_base_type()
		if base == &"Node" or ClassDB.is_parent_class(base, &"Node"):
			nodes.append("%s extends %s, a Node" % [path, base])
	check(nodes.is_empty(), "sim classes are RefCounted or Resource data:\n" + "\n".join(nodes))


func _sim_files() -> PackedStringArray:
	var files: PackedStringArray = QaFiles.find(SIM_DIR, ".gd")
	if files.is_empty():
		skip("no .gd files under src/sim yet (they arrive with T1's contracts commit)")
	return files


## Removes `#` comments, keeping string contents (a forbidden token inside a string still
## counts). Handles "..." and '...' with escapes, and triple-quoted strings across lines.
static func strip_comments(source: String) -> String:
	var out: PackedStringArray = PackedStringArray()
	var quote: String = ""  # "", "\"", "'", "\"\"\"" or "'''"
	var i: int = 0
	var n: int = source.length()
	var start: int = 0
	while i < n:
		var c: String = source[i]
		if quote.is_empty():
			if c == "#":
				out.append(source.substr(start, i - start))
				while i < n and source[i] != "\n":
					i += 1
				start = i
				continue
			if c == "\"" or c == "'":
				quote = c.repeat(3) if source.substr(i, 3) == c.repeat(3) else c
				i += quote.length()
				continue
		else:
			if c == "\\":
				i += 2
				continue
			if source.substr(i, quote.length()) == quote:
				i += quote.length()
				quote = ""
				continue
			if c == "\n" and quote.length() == 1:
				quote = ""  # an unterminated one-line string ends at the line break
		i += 1
	out.append(source.substr(start))
	return "".join(out)
