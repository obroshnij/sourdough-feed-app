class_name Memorial
extends RefCounted
## A starter that was lost to mold (data-models.md §6, D-002). Saved list, never trimmed.
## The memorial page (narrative.md §9.2 step 5, §9.3) reads these fields: MEMORIAL_TITLE {name},
## MEMORIAL_DATES from `dates_args()`, the stats, `epitaph_key()`, `cause_key()` with `cause_args()`, and
## MEMORIAL_TIP. Fields added in Phase 3 are optional on load, so Phase 2 saves still load (0 for unknown).

var starter_id: String = ""
var name: String = ""
var born_unix: int = 0
var ended_unix: int = 0
var feeds_count: int = 0
## &"mold" is the only cause.
var cause: StringName = &"mold"
## Times it reached its peak (MEMORIAL_STAT_PEAKS).
var peaks_count: int = 0
## The tallest rise, as a ratio of the fed level such as 2.3 (MEMORIAL_STAT_BEST, shown as "2.3×").
var best_rise: float = 0.0
## Whole days since the last feed spent at 11 C or warmer before mold ({days} in MEMORIAL_CAUSE_UNFED).
## Fridge days don't count (narrative §9.3).
var unfed_days: int = 0


## MEMORIAL_STAT_DAYS: whole days from adoption to the discard.
func days_together() -> int:
	@warning_ignore("integer_division")
	return maxi(ended_unix - born_unix, 0) / 86400


## narrative §9.3: the trait epitaph when a trait was revealed (P1), else MEMORIAL_EPITAPH_<1 + seed % 3>.
func epitaph_key() -> StringName:
	return StringName("MEMORIAL_EPITAPH_%d" % (1 + posmod(StarterState.seed_of(starter_id), 3)))


func cause_key() -> StringName:
	return &"MEMORIAL_CAUSE_UNFED"


func cause_args() -> Dictionary:
	return {"days": unfed_days}


## Args for MEMORIAL_DATES: Keys.format turns them into {start_date} and {end_date}.
func dates_args() -> Dictionary:
	return {"start_unix": born_unix, "end_unix": ended_unix}


func to_dict() -> Dictionary:
	return {
		"starter_id": starter_id, "name": name, "born_unix": born_unix, "ended_unix": ended_unix,
		"feeds_count": feeds_count, "cause": String(cause), "peaks_count": peaks_count, "best_rise": best_rise,
		"unfed_days": unfed_days,
	}


static func from_dict(d: Dictionary) -> Memorial:
	var r := DictReader.new(d)
	var m := Memorial.new()
	m.starter_id = r.text("starter_id")
	m.name = r.text("name")
	m.born_unix = r.integer("born_unix")
	m.ended_unix = r.integer("ended_unix")
	m.feeds_count = r.integer("feeds_count")
	m.cause = r.id("cause")
	m.peaks_count = r.integer_or("peaks_count", 0)
	m.best_rise = r.num_or("best_rise", 0.0)
	m.unfed_days = r.integer_or("unfed_days", 0)
	return m if r.ok else null
