class_name DailyBucket
extends RefCounted
## One local day of trait inputs (data-models.md §5, P1 traits). Ring of 14 in PlayerHistory.daily.

var day_key: String = ""
## Hours at temp_c >= 24 C.
var hours_warm: float = 0.0
## Hours at temp_c <= 18 C.
var hours_cool: float = 0.0
var feeds: int = 0
var ratio_sum: float = 0.0
var changes: int = 0
var comebacks: int = 0


func to_dict() -> Dictionary:
	return {
		"day_key": day_key, "hours_warm": hours_warm, "hours_cool": hours_cool, "feeds": feeds,
		"ratio_sum": ratio_sum, "changes": changes, "comebacks": comebacks,
	}


static func from_dict(d: Dictionary) -> DailyBucket:
	var r := DictReader.new(d)
	var b := DailyBucket.new()
	b.day_key = r.text("day_key")
	b.hours_warm = r.num("hours_warm")
	b.hours_cool = r.num("hours_cool")
	b.feeds = r.integer("feeds")
	b.ratio_sum = r.num("ratio_sum")
	b.changes = r.integer("changes")
	b.comebacks = r.integer("comebacks")
	return b if r.ok else null
