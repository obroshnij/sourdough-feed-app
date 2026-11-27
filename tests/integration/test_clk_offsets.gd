extends SliceCase
## CLK-06, CLK-07 and CLK-15 (AC-09.8) and the daylight-saving and travel part of AC-10.4, with the live
## rules. The sim uses Unix time only, so offsets never change it. Quiet hours and day keys follow the
## local time of the moment in live play, and, in a catch-up, the offset read at resume (architecture
## §5.4, accepted limit). Quiet hours are 22:00 to 08:00 (game-mechanics §7.3), written out here.

const QUIET_FROM_MIN: int = 22 * 60
const QUIET_UNTIL_MIN: int = 8 * 60


func ready_for_rules() -> bool:
	return ready_for_integration() and require(&"p3_contracts") and require(&"p3_rules")


## CLK-06 and CLK-07: the same feeds and absences with the offset fixed at 0, with a daylight-saving
## shift (+1 h, then -1 h back), and with travel from UTC-5 to UTC+9 mid-day. The starter and
## environment are bit-identical in all three.
func test_clk_06_07_offsets_never_change_the_sim() -> void:
	if not ready_for_rules():
		return
	var plans: Dictionary[String, Array] = {
		"fixed": [0, 0, 0], "dst": [0, 3600, 0], "travel": [-5 * 3600, 9 * 3600, 9 * 3600],
	}
	var results: Dictionary[String, Dictionary] = {}
	for label: String in plans:
		var offsets: Array = plans[label]
		var h: SliceHarness = phone("offset_" + label, T0, int(offsets[0]))
		h.seed_save(SliceHarness.mature(), null, SliceHarness.seed_for_draw(0.5))
		h.launch()
		h.apply(feed_111())
		h.play(5 * HOUR)
		h.clock.set_offset(int(offsets[1]))
		h.play(3 * HOUR)
		h.reopen_at(T0 + 30 * HOUR)
		h.apply(feed_111())
		h.clock.set_offset(int(offsets[2]))
		h.play(6 * HOUR)
		results[label] = {"starter": h.session.get_starter().to_dict(), "env": h.session.get_environment().to_dict()}
	check_eq(results["dst"], results["fixed"], "daylight saving changes nothing in the sim")
	check_eq(results["travel"], results["fixed"], "travel from UTC-5 to UTC+9 changes nothing in the sim")


## AC-10.4 and CLK-07 in live play: fed at 07:00 UTC, hunger comes at about 19:36 UTC. Moving the offset
## to +3 h during play puts that moment at 22:36 local, so the nudge waits until 08:00 local, by the new
## offset. With the offset left at 0 it is shown at once.
func test_ac_10_4_quiet_hours_follow_the_new_offset_in_live_play() -> void:
	if not ready_for_rules():
		return
	for moved: bool in [false, true]:
		var label: String = "travel_live_%s" % moved
		var h: SliceHarness = phone(label, T0, 0)
		h.seed_save(SliceHarness.mature(), null, SliceHarness.seed_for_draw(0.5))
		h.launch()
		h.reopen_at(T0 + 7 * HOUR)
		h.apply(feed_111())
		h.play(8 * HOUR)
		if moved:
			h.clock.set_offset(3 * 3600)
		h.play(6 * HOUR)
		var nudge: SimEvent = _first_in_journal(h, &"hungry_again")
		if not check(nudge != null, "%s: the hunger nudge was created" % label):
			continue
		var offset: int = 3 * 3600 if moved else 0
		var minute: int = LocalDay.minute_of_day(nudge.created_unix, offset)
		check_eq(_quiet(minute), moved, "%s: created at local minute %d" % [label, minute])
		var want_hold: int = nudge.created_unix + _to_eight(minute) if moved else 0
		check_eq(nudge.not_before_unix, want_hold, "%s: held until 08:00 local only after the move" % label)


## The catch-up's accepted limit (architecture §5.4): the offset is read once at resume and applies to the
## whole window. Closed at 07:00 UTC with offset 0, the offset moves to +3 h while closed: the nudge created
## at about 19:36 UTC is judged at 22:36 local and waits until 08:00 local.
func test_clk_06_catch_up_uses_the_offset_read_at_resume() -> void:
	if not ready_for_rules():
		return
	var h: SliceHarness = phone("travel_closed", T0, 0)
	h.seed_save(SliceHarness.mature(), null, SliceHarness.seed_for_draw(0.5))
	h.launch()
	h.reopen_at(T0 + 7 * HOUR)
	h.apply(feed_111())
	h.close()
	h.clock.set_offset(3 * 3600)
	h.clock.set_now(T0 + 21 * HOUR)
	h.launch()
	var nudges: Array[SimEvent] = []
	for e: SimEvent in h.session.get_last_catch_up().events:
		if e.id == &"hungry_again":
			nudges.append(e)
	if check_eq(nudges.size(), 1, "one hunger nudge while away"):
		var minute: int = LocalDay.minute_of_day(nudges[0].created_unix, 3 * 3600)
		check(_quiet(minute), "judged by the resume offset: local minute %d is in quiet hours" % minute)
		check_eq(nudges[0].not_before_unix, nudges[0].created_unix + _to_eight(minute), "held until 08:00 local")


## CLK-15: the local date rolls at local midnight, across a year end and on 29 February, and the daily caps
## restart with it. The quiet window crosses midnight.
func test_clk_15_year_end_leap_day_and_the_midnight_quiet_window() -> void:
	if not ready_for_rules():
		return
	var new_year_utc: int = 1830297600  # 2028-01-01 00:00 UTC
	for offset: int in [0, 9 * 3600, -5 * 3600]:
		var midnight: int = new_year_utc - offset
		check_eq(LocalDay.day_key(midnight - 1, offset), "2027-12-31", "offset %d: last second of the year" % offset)
		check_eq(LocalDay.day_key(midnight, offset), "2028-01-01", "offset %d: first second of the next" % offset)
	var leap_noon: int = 1835438400  # 2028-02-29 12:00 UTC
	check_eq(LocalDay.day_key(leap_noon, 0), "2028-02-29", "29 February exists in 2028")
	check_eq(LocalDay.day_key(leap_noon + 86400, 0), "2028-03-01", "and is followed by 1 March")
	var ledger := EventLedger.new()
	ledger.roll_day("2027-12-31")
	ledger.day_counts[&"info"] = 4
	ledger.roll_day("2027-12-31")
	check_eq(ledger.count_today(&"info"), 4, "the same date keeps its count")
	ledger.roll_day("2028-01-01")
	check_eq(ledger.count_today(&"info"), 0, "a new local date restarts the caps")
	for m: Array in [[23 * 60 + 30, true], [30, true], [7 * 60 + 59, true], [8 * 60, false], [21 * 60 + 59, false], [22 * 60, true]]:
		check_eq(EventScheduler.in_quiet_hours(int(m[0])), bool(m[1]), "quiet at local minute %d" % int(m[0]))


# ------------------------------------------------------------------ helpers

## The first admitted event with `id`, found in the ledger history of the journal (live play has no
## CatchUpResult to read). Returns the pending event when it is still waiting, else a copy rebuilt from
## the journal entry.
func _first_in_journal(h: SliceHarness, id: StringName) -> SimEvent:
	for e: SimEvent in h.session.get_pending_events():
		if e.id == id:
			return e
	for e: Dictionary in h.heard_of(&"event_raised"):
		var args: Array = e["args"]
		var ev: SimEvent = args[0] as SimEvent
		if ev != null and ev.id == id:
			return ev
	return null


static func _quiet(minute: int) -> bool:
	return minute >= QUIET_FROM_MIN or minute < QUIET_UNTIL_MIN


static func _to_eight(minute: int) -> int:
	var minutes: int = QUIET_UNTIL_MIN - minute if minute < QUIET_UNTIL_MIN else 24 * 60 - minute + QUIET_UNTIL_MIN
	return minutes * 60
