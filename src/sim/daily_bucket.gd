class_name DailyBucket
extends RefCounted
## One local day of trait inputs (data-models.md §5, progression.md §5). Ring of 14 in PlayerHistory.daily.
## PlayerHistory.record_step() fills the hours; record_action() fills feeds, ratios, changes and comebacks.

var day_key: String = ""
## Hours with the place (EnvironmentState.temperature_c) at 24 C or warmer. Not the starter's temp_c, which
## lags and never quite reaches the place's temperature in doubles (spec §14.2).
var hours_warm: float = 0.0
## Hours with the place at 18 C or cooler.
var hours_cool: float = 0.0
## Every hour this day held a starter (the denominator for the warm and cool shares). Phase 4, optional on load.
var hours: float = 0.0
var feeds: int = 0
## Sum of each feed's flour parts per kept part (1 for 1:1:1, 5 for 1:5:5).
var ratio_sum: float = 0.0
## Moves to another place, and feeds that changed the flour or the ratio from the feed before.
var changes: int = 0
## Feeds from unhealthy (rescued) or after 24 or more weighted starved hours (a comeback).
var comebacks: int = 0


func to_dict() -> Dictionary:
	return {
		"day_key": day_key, "hours_warm": hours_warm, "hours_cool": hours_cool, "hours": hours, "feeds": feeds,
		"ratio_sum": ratio_sum, "changes": changes, "comebacks": comebacks,
	}


static func from_dict(d: Dictionary) -> DailyBucket:
	var r := DictReader.new(d)
	var b := DailyBucket.new()
	b.day_key = r.text("day_key")
	b.hours_warm = r.num("hours_warm")
	b.hours_cool = r.num("hours_cool")
	b.hours = r.num_or("hours", 0.0)
	b.feeds = r.integer("feeds")
	b.ratio_sum = r.num("ratio_sum")
	b.changes = r.integer("changes")
	b.comebacks = r.integer("comebacks")
	return b if r.ok else null
