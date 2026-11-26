class_name I18nLoader
extends RefCounted
## Registers the string catalogs at runtime (architecture.md §10), so a fresh checkout imports cleanly:
## - The generated catalog src/i18n/en.csv is imported by Godot (csv_translation) and added here once its
##   .translation exists. Listing it in project.godot made a fresh `--import` log "Cannot open file",
##   because the editor loads project translations before the first import has produced them.
## - The three pending_*.csv files use the `keep` importer and are parsed here directly. A header-only CSV
##   given to the CSV importer logs "Locale 'en' does not contain any translation".
## Session calls load_all() from _ready. Tests may call it too; it is idempotent.

const CATALOG: String = "res://src/i18n/en.en.translation"
const PENDING_CSVS: Array[String] = [
	"res://src/i18n/pending_core.csv",
	"res://src/i18n/pending_view.csv",
	"res://src/i18n/pending_ui.csv",
]
const LOCALE: String = "en"

static var _loaded: bool = false


static func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	if ResourceLoader.exists(CATALOG):
		var res: Resource = load(CATALOG)
		var catalog: Translation = res as Translation
		if catalog != null:
			TranslationServer.add_translation(catalog)
	for path: String in PENDING_CSVS:
		var t: Translation = translation_from_csv(path)
		if t != null:
			TranslationServer.add_translation(t)


## Parses a `keys,en` CSV (RFC 4180 quoting). Null when the file is missing or has no rows.
static func translation_from_csv(path: String) -> Translation:
	if not FileAccess.file_exists(path):
		return null
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var header: PackedStringArray = f.get_csv_line()
	var col: int = header.find(LOCALE)
	if col < 1:
		return null
	var t := Translation.new()
	t.locale = LOCALE
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() > col and not row[0].strip_edges().is_empty():
			t.add_message(StringName(row[0].strip_edges()), StringName(row[col]))
	return t if t.get_message_count() > 0 else null
