class_name JournalSheet
extends Sheet
## The minimal journal (ux-design §14, game-copy §11, D-017): feeds, peaks, events, Day one and the memorial
## pages, newest first. Order is the journal's uid order (Session.get_journal()), never at_unix, which can
## run backwards across a clock hold (architecture §5.3). Every line renders through Session.format_text(),
## so the save holds keys and args, never text. Digits are fine here (a dedicated screen, ux §4).

## What the slice's journal shows. Smell, inspect, place and state-change lines stay in the save for later.
const SHOWN_KINDS: Array[StringName] = [&"feed", &"event", &"milestone", &"memorial", &"rename"]

var rows: int = 0


func _init() -> void:
	sheet_id = &"journal"
	title_key = &"JOURNAL_SCREEN_TITLE"
	height_kind = Sheet.Height.FULL


func _on_open() -> void:
	rebuild()


func rebuild() -> void:
	clear_content()
	rows = 0
	if session == null:
		return
	var entries: Array[JournalEntry] = session.get_journal()
	var offset: int = session.local_utc_offset_s()
	var last_day: String = ""
	for i: int in range(entries.size() - 1, -1, -1):
		var e: JournalEntry = entries[i]
		if not SHOWN_KINDS.has(e.kind):
			continue
		var day: String = Keys.format_date(e.at_unix, offset)
		if day != last_day:
			last_day = day
			add_label(&"HintLabel", day)
		if e.kind == &"memorial":
			_memorial(e)
		else:
			_entry(e)
		rows += 1
	if rows == 0:
		add_label(&"SectionLabel", tr(&"JOURNAL_EMPTY_TITLE"))
		add_label(&"BodyLabel", tr(&"JOURNAL_EMPTY_BODY"))


func _entry(e: JournalEntry) -> void:
	add_label(&"SectionLabel", session.format_text(e.text_key, _args(e)))
	var body: StringName = e.body_key()
	if body != &"":
		add_label(&"BodyLabel", session.format_text(body, _args(e)))


## A memorial page inside the journal (narrative §9.3): the name, the dates, the epitaph and the cause.
func _memorial(e: JournalEntry) -> void:
	var m: Memorial = Memorial.from_dict(e.data)
	if m == null:
		return
	add_label(&"TitleLabel", session.format_text(&"MEMORIAL_TITLE", {"name": m.name}))
	add_label(&"HintLabel", session.format_text(&"MEMORIAL_DATES", m.dates_args()))
	add_label(&"BodyLabel", tr(m.epitaph_key()))
	add_label(&"BodyLabel", session.format_text(m.cause_key(), m.cause_args()))


## The entry's args plus the fields its keys use from data ({name} on Day one and renames).
func _args(e: JournalEntry) -> Dictionary:
	var args: Dictionary = e.data.duplicate()
	args.merge(e.args, true)
	return args
