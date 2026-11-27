extends TestCase
## Slice scope in the UI (test-plan §3.13) and LINT-12. Static checks over src/ui (.gd and .tscn):
## - AC-06.1, D-018: humidity is never shown (the UI never reads it).
## - AC-06.6, D-018, D-019: no P1 place (window_sill, proofing_box) and no P2 cover or container is offered.
## - AC-08.4, D-021: no P1 inspection kind (consistency, development).
## - LINT-12: at the Phase 3 exit every pending_*.csv is header only, so no placeholder copy ships.
## When P1 lands, the owner removes the matching ids from OUT_OF_SLICE in the same commit.

const UI_DIR: String = "res://src/ui"
const OUT_OF_SLICE: PackedStringArray = [
	"humidity", "window_sill", "proofing_box", "tight_lid", "\"cloth\"", "wide_mouth_jar", "ceramic_crock",
	"fermentation_vessel", "&\"consistency\"", "&\"development\"",
]
const PENDING: PackedStringArray = [
	"res://src/i18n/pending_core.csv", "res://src/i18n/pending_ui.csv", "res://src/i18n/pending_view.csv",
]


func test_ui_offers_nothing_outside_the_slice() -> void:
	var files: PackedStringArray = QaFiles.find(UI_DIR, ".gd")
	files.append_array(QaFiles.find(UI_DIR, ".tscn"))
	check(files.size() >= 10, "src/ui has scripts and scenes to scan (%d)" % files.size())
	var hits: PackedStringArray = PackedStringArray()
	for path: String in files:
		var n: int = 0
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			n += 1
			if line.strip_edges().begins_with("#"):
				continue  # comments may name later features
			var low: String = line.to_lower()
			for token: String in OUT_OF_SLICE:
				if low.contains(token.to_lower()):
					hits.append("%s:%d mentions %s" % [path, n, token])
	check(hits.is_empty(), "out-of-slice ids in the UI:\n    " + "\n    ".join(hits))


func test_lint_12_pending_csvs_are_header_only() -> void:
	for path: String in PENDING:
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).strip_edges().split("\n", false)
		check(FileAccess.file_exists(path), path + " exists")
		check_eq(lines.size(), 1, path + " has only its header (no placeholder copy ships)")
