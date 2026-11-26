extends TestCase
## The event engine skeleton (architecture.md §7, game-mechanics.md §7.3): scheduler admission, the ledger,
## and rule evaluation. No rules ship in Phase 2; these use test-only events. Owner: T1.

const T0: int = 1795651200


func _event(id: StringName, tier: StringName, at: int) -> SimEvent:
	var e := SimEvent.new()
	e.id = id
	e.tier = tier
	e.created_unix = at
	return e


func test_cooldown_and_one_time() -> void:
	if not require(&"m2_sim"):
		return
	var l := EventLedger.new()
	check(EventScheduler.admit(_event(&"a", &"info", T0), l, 600, 3600), "first admitted")
	check(not EventScheduler.admit(_event(&"a", &"info", T0 + 3599), l, 600, 3600), "inside the cooldown")
	check(EventScheduler.admit(_event(&"a", &"info", T0 + 3600), l, 600, 3600), "after the cooldown")
	check(EventScheduler.admit(_event(&"m", &"info", T0), l, 600, 0, true), "one-time fires once")
	check(not EventScheduler.admit(_event(&"m", &"info", T0 + 999999), l, 600, 0, true), "one-time never again")
	check_eq(l.pending[0].uid, 1, "uids from the ledger")
	check_eq(l.next_uid, 4, "next_uid advances")


func test_daily_caps_per_tier() -> void:
	if not require(&"m2_sim"):
		return
	var l := EventLedger.new()
	l.roll_day("2026-11-26")
	var admitted: Dictionary = {&"info": 0, &"nudge": 0, &"attention": 0}
	for tier: StringName in admitted:
		for i: int in 6:
			if EventScheduler.admit(_event(StringName("%s_%d" % [tier, i]), tier, T0 + i), l, 720):
				admitted[tier] = int(admitted[tier]) + 1
	check_eq(admitted, {&"info": 4, &"nudge": 2, &"attention": 1}, "caps 4 info, 2 nudge, 1 attention")
	l.roll_day("2026-11-27")
	check(EventScheduler.admit(_event(&"next_day", &"nudge", T0 + 86400), l, 720), "caps reset at local midnight")


func test_one_attention_waiting_and_the_mold_override() -> void:
	if not require(&"m2_sim"):
		return
	var l := EventLedger.new()
	check(EventScheduler.admit(_event(&"warning_signs", &"attention", T0), l, 720), "first attention")
	l.roll_day("next")
	check(not EventScheduler.admit(_event(&"other", &"attention", T0 + 86400), l, 720), "held while one is waiting")
	check(EventScheduler.admit(_event(&"mold_found", &"attention", T0 + 86400), l, 720), "mold_found replaces it")
	check(l.pending.size() == 1 and l.pending[0].id == &"mold_found", "never more than one waiting")


func test_quiet_hours_defer_nudges_to_8am() -> void:
	if not require(&"m2_sim"):
		return
	var l := EventLedger.new()
	var night: SimEvent = _event(&"hungry_again", &"nudge", T0)
	check(EventScheduler.admit(night, l, 23 * 60), "a nudge at 23:00 is admitted")
	check_eq(night.not_before_unix, T0 + 9 * 3600, "deferred to 08:00")
	var info: SimEvent = _event(&"hooch_forming", &"info", T0)
	EventScheduler.admit(info, l, 23 * 60)
	check_eq(info.not_before_unix, 0, "info is logged normally in quiet hours")
	check(EventScheduler.in_quiet_hours(22 * 60) and EventScheduler.in_quiet_hours(7 * 60 + 59), "22:00 to 07:59 is quiet")
	check(not EventScheduler.in_quiet_hours(8 * 60), "08:00 is not quiet")


func test_pending_cap_drops_oldest_info_first() -> void:
	if not require(&"m2_sim"):
		return
	var l := EventLedger.new()
	l.add_pending(_event(&"keep_me", &"nudge", T0))
	for i: int in 25:
		l.add_pending(_event(StringName("i%d" % i), &"info", T0 + i))
	check_eq(l.pending.size(), EventLedger.PENDING_CAP, "capped at 20")
	check_eq(l.pending[0].id, &"keep_me", "the nudge survives")
	check_eq(l.pending[1].id, &"i6", "the oldest infos went first")


func test_ledger_round_trip() -> void:
	if not require(&"m2_sim"):
		return
	var l := EventLedger.new()
	l.roll_day("2026-11-26")
	var e: SimEvent = _event(&"peak_now", &"info", T0)
	e.payload = {"peak_rise": 2.25, "peak_unix": T0}
	EventScheduler.admit(e, l, 600, 0, true)
	var text: String = JSON.stringify(l.to_dict(), "", true, true)
	var parsed: Dictionary = JSON.parse_string(text)
	var back: EventLedger = EventLedger.from_dict(parsed)
	check(back != null, "parses back")
	check_eq(JSON.stringify(back.to_dict(), "", true, true), text, "round-trips exactly")
	check(EventLedger.from_dict({"next_uid": "seven"}) == null, "a wrong type gives null, silently")
