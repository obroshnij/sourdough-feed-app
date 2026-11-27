class_name ReturnLine
extends RefCounted
## One moment row of the "while you were away" card (game-copy §10, events-catalog §5). The UI renders it
## with Keys.format(text_key, args, utc_offset_s): `time_unix` becomes {time}; `hours` and `days` are ints.

## The keep class, highest first: attention, milestone, peak, hunger, info, moment, ambient, capped.
## `capped` is the AWAY_CAPPED row, always kept, always last.
var kind: StringName = &"info"
## EVENT_<ID>_AWAY (or one of its variants) for an event, AWAY_* for a moment that isn't an event.
var text_key: StringName = &""
var args: Dictionary = {}
## Sim time it happened. Rows show oldest first.
var at_unix: int = 0
## The event behind the row, or &"" and 0 for a moment row.
var event_id: StringName = &""
var event_uid: int = 0


static func make(kind_id: StringName, key: StringName, at: int, row_args: Dictionary = {}) -> ReturnLine:
	var l := ReturnLine.new()
	l.kind = kind_id
	l.text_key = key
	l.at_unix = at
	l.args = row_args
	return l
