class_name EventScheduler
extends RefCounted
## Admission rules (architecture.md §7, game-mechanics.md §7.2 and §7.3). Pure: same inputs, same answer.
## The ledger is the only thing it writes, and only when it admits.

const DAILY_CAPS: Dictionary = {&"info": 4, &"nudge": 2, &"attention": 1}
const QUIET_START_MIN: int = 22 * 60
const QUIET_END_MIN: int = 8 * 60
## The only attention event that may replace a waiting one.
const ATTENTION_OVERRIDE: StringName = &"mold_found"


static func in_quiet_hours(local_minute_of_day: int) -> bool:
	return local_minute_of_day >= QUIET_START_MIN or local_minute_of_day < QUIET_END_MIN


## Seconds from local_minute_of_day to the next 08:00 local.
static func seconds_to_quiet_end(local_minute_of_day: int) -> int:
	var minutes: int = posmod(QUIET_END_MIN - local_minute_of_day, 1440)
	return minutes * 60


## Admits `event` into `ledger.pending` and returns true, or returns false and changes nothing.
## The caller rolls the ledger's day first (EventRules.process does).
static func admit(event: SimEvent, ledger: EventLedger, local_minute_of_day: int,
		cooldown_s: int = 0, one_time: bool = false) -> bool:
	if one_time and ledger.once_flags.get(event.id, false):
		return false
	if cooldown_s > 0 and ledger.last_fired_unix.has(event.id):
		if event.created_unix - ledger.last_fired_unix[event.id] < cooldown_s:
			return false
	var cap: int = DAILY_CAPS.get(event.tier, 0)
	if ledger.count_today(event.tier) >= cap:
		return false
	if event.tier == &"attention":
		var waiting: SimEvent = ledger.pending_attention()
		if waiting != null:
			if event.id != ATTENTION_OVERRIDE:
				return false
			ledger.remove_pending(waiting.uid)
	if event.tier == &"nudge" and in_quiet_hours(local_minute_of_day):
		event.not_before_unix = event.created_unix + seconds_to_quiet_end(local_minute_of_day)
	event.local_minute_of_day = local_minute_of_day
	event.uid = ledger.take_uid()
	event.status = &"pending"
	ledger.last_fired_unix[event.id] = event.created_unix
	if one_time:
		ledger.once_flags[event.id] = true
	ledger.day_counts[event.tier] = ledger.count_today(event.tier) + 1
	ledger.add_pending(event)
	return true
