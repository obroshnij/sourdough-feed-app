extends SliceCase
## AC-10 (contextual events) through the real Session with T4's slice rules live (p3_rules). Events are
## observed as the Session gives them: admitted events in CatchUpResult.events and ActionResult.events,
## every admitted event journaled once, and event_raised / event_withdrawn on the Session.
## T0 is 00:00 UTC, so each test picks a UTC offset that puts its moments in the day it needs.

const OFFSET_08: int = 8 * 3600  # T0 is 08:00 local
const OFFSET_10: int = 10 * 3600  # T0 is 10:00 local
const OFFSET_07: int = 7 * 3600  # T0 is 07:00 local
## Timed cooldowns (game-mechanics §7.3), checked over the random months.
const COOLDOWNS: Dictionary[StringName, int] = {
	&"hungry_again": 12 * 3600, &"hooch_forming": 24 * 3600, &"back_to_strength": 24 * 3600,
}
const ONCE_PER_STARTER: Array[StringName] = [&"first_rise", &"mold_found"]
## The published numbers, written out here so a wrong constant in the code can't pass by comparing
## with itself: spec §14.1 (rise 1.25, 85%), game-mechanics §7.3 (quiet 22:00 to 08:00, daily caps).
const SPEC_RISE_NOTICEABLE: float = 1.25
const SPEC_STRENGTH_SHARE: float = 0.85
const QUIET_FROM_MIN: int = 22 * 60
const QUIET_UNTIL_MIN: int = 8 * 60
const CAPS: Dictionary[StringName, int] = {&"info": 4, &"nudge": 2, &"attention": 1}
const POSITIVE: Array[StringName] = [
	&"first_rise", &"peaked_while_away", &"peak_now", &"hooch_forming", &"back_to_strength",
]


func ready_for_rules() -> bool:
	return ready_for_integration() and require(&"p3_contracts") and require(&"p3_rules")


## AC-10.1 first_rise: fires once per starter, at the exact step the rise first reaches 1.25 after a
## feed (spec §14.1 RISE_NOTICEABLE), as an info event that is shown at once and journaled. A second
## feed's rise doesn't repeat it, and an unfed starter never gets it.
func test_ac_10_1_first_rise_at_its_crossing_once_per_starter() -> void:
	if not ready_for_rules():
		return
	var h: SliceHarness = _mature("first_rise", OFFSET_08)
	h.apply(feed_111())
	var crossed: int = -1
	for minute: int in 3 * 60:
		h.play(MIN)
		if crossed < 0 and h.session.get_starter().rise >= SPEC_RISE_NOTICEABLE:
			crossed = h.clock.now_unix()
	var raised: Array[SimEvent] = _raised(h, &"first_rise")
	if check_eq(raised.size(), 1, "first_rise raised once"):
		check_eq(raised[0].created_unix, crossed, "at the step the rise reached 1.25 (%s)" % hours(crossed))
		check_eq(raised[0].tier, &"info", "info tier")
	check_eq(_journaled(h, &"first_rise"), 1, "journaled once")
	h.apply(feed_111())
	h.play(3 * HOUR)
	check_eq(_raised(h, &"first_rise").size(), 1, "a second feed's rise doesn't repeat it")
	var unfed: SliceHarness = _mature("first_rise_unfed", OFFSET_08)
	unfed.play(3 * HOUR)
	check_eq(_journaled(unfed, &"first_rise"), 0, "an unfed starter never gets it")


## AC-10.1 hungry_again and hooch_forming: while away, hungry_again (nudge) is created at the step the
## state turns hungry, and hooch_forming (info) at the step hooch reaches 0.10. Fed before either
## moment, neither fires. AC-10.3: a second hooch crossing 18 h after the first is held by the 24 h
## cooldown, while a second hunger 18 h later passes the 12 h one.
func test_ac_10_1_hunger_and_hooch_at_their_crossings_and_cooldowns() -> void:
	if not ready_for_rules():
		return
	var h: SliceHarness = _mature("hunger", OFFSET_08)
	h.apply(feed_111())
	h.reopen_at(T0 + 18 * HOUR)
	var r: CatchUpResult = h.session.get_last_catch_up()
	var hungry_at: int = _transition_to(r, &"hungry")
	var hunger: Array[SimEvent] = _of(r.events, &"hungry_again")
	var hooch: Array[SimEvent] = _of(r.events, &"hooch_forming")
	if check_eq(hunger.size(), 1, "hungry_again created while away"):
		check_eq(hunger[0].created_unix, hungry_at, "at the step it turned hungry (%s)" % hours(hungry_at))
		check_eq(hunger[0].tier, &"nudge", "nudge tier")
	if check_eq(hooch.size(), 1, "hooch_forming created while away"):
		check_eq(hooch[0].created_unix, int(r.notable.get("hooch_first_unix", -1)), "at the step hooch reached 0.10")
		check_eq(hooch[0].tier, &"info", "info tier")
	h.apply(feed_111())
	h.reopen_at(T0 + 36 * HOUR)
	var second: CatchUpResult = h.session.get_last_catch_up()
	check_eq(_of(second.events, &"hungry_again").size(), 1, "a second hunger 18 h later passes the 12 h cooldown")
	check(second.notable.has("hooch_first_unix"), "hooch crossed 0.10 again")
	check_eq(_of(second.events, &"hooch_forming").size(), 0, "the second hooch crossing is held by the 24 h cooldown")
	var early: SliceHarness = _mature("hunger_fed_early", OFFSET_08)
	early.apply(feed_111())
	early.reopen_at(T0 + 11 * HOUR)
	early.apply(feed_111())
	early.reopen_at(T0 + 20 * HOUR)
	var none: CatchUpResult = early.session.get_last_catch_up()
	check(_of(none.events, &"hungry_again").is_empty() and _of(none.events, &"hooch_forming").is_empty(),
		"fed before either moment: neither fires")


## AC-10.1, 10.6 and 10.10 at the counter: left 225 h after a feed. warning_signs (attention) is
## created at the step the state turns unhealthy, with began_unix at that moment; mold_found
## (attention) at the step it turns moldy, at least 72 h later. The unacknowledged warning is replaced
## by mold_found, so exactly one attention waits, and it is the summary's prompt. No positive event is
## created after the warning began, and the stale hunger nudge is gone.
func test_ac_10_6_and_10_10_warning_then_mold_at_the_counter() -> void:
	if not ready_for_rules():
		return
	var h: SliceHarness = _mature("warning_counter", OFFSET_08)
	h.apply(feed_111())
	h.reopen_at(T0 + 225 * HOUR)
	var r: CatchUpResult = h.session.get_last_catch_up()
	var warn: Array[SimEvent] = _of(r.events, &"warning_signs")
	var mold: Array[SimEvent] = _of(r.events, &"mold_found")
	var unhealthy_at: int = _transition_to(r, &"unhealthy")
	var moldy_at: int = _transition_to(r, &"moldy")
	if not (check_eq(warn.size(), 1, "one warning_signs") and check_eq(mold.size(), 1, "one mold_found")):
		return
	check_eq(warn[0].created_unix, unhealthy_at, "warning_signs at the unhealthy onset")
	check_eq(int(DictReader.float_of(warn[0].payload.get("began_unix", -1))), unhealthy_at, "began_unix is the onset")
	check_eq(mold[0].created_unix, moldy_at, "mold_found at the step it turned moldy")
	check(warn[0].tier == &"attention" and mold[0].tier == &"attention", "both attention")
	var gap_h: float = float(mold[0].created_unix - warn[0].created_unix) / HOUR
	check(gap_h >= 72.0, "AC-10.10: warning to mold is at least 72 h at the counter (%.1f h)" % gap_h)
	var waiting: Array[SimEvent] = []
	for e: SimEvent in h.session.get_pending_events():
		if e.tier == &"attention":
			waiting.append(e)
	check_eq(waiting.size(), 1, "exactly one attention waits")
	check(not waiting.is_empty() and waiting[0].id == &"mold_found", "mold_found replaced the unacknowledged warning")
	var prompt: SimEvent = h.session.get_return_summary().prompt
	check(prompt != null and prompt.id == &"mold_found", "mold_found is the summary's prompt")
	for e: SimEvent in r.events:
		if POSITIVE.has(e.id):
			check(e.created_unix < unhealthy_at, "%s is not created after the warning began" % e.id)
	for e: SimEvent in h.session.get_pending_events():
		check(e.id != &"hungry_again", "the stale hunger nudge is gone")


## AC-10.6: a second attention is held while the first waits, and admitted once the first is
## acknowledged. The first warning_signs is left unacknowledged; a rescue feed ends the episode; a second
## neglect re-arms the rule (24 h out of unhealthy) and makes it unhealthy again, but nothing new is
## admitted while the first card waits. Acknowledging it lets the second warning in at once.
func test_ac_10_6_a_second_attention_waits_for_the_first_ack() -> void:
	if not ready_for_rules():
		return
	var h: SliceHarness = _mature("attention_hold", OFFSET_08)
	h.apply(feed_111())
	h.reopen_at(T0 + 115 * HOUR)
	var first: Array[SimEvent] = _of(h.session.get_last_catch_up().events, &"warning_signs")
	if not check_eq(first.size(), 1, "the first warning_signs"):
		return
	check(h.apply(feed_111()).ok, "a rescue feed")
	check(h.state() != &"unhealthy", "out of unhealthy after the rescue")
	h.reopen_at(T0 + 115 * HOUR + 130 * HOUR)
	var r: CatchUpResult = h.session.get_last_catch_up()
	check(_transition_to(r, &"unhealthy") > 0, "unhealthy again in the second neglect")
	check(_of(r.events, &"warning_signs").is_empty(), "the second warning is held while the first waits")
	var waiting: Array[SimEvent] = _waiting_attention(h)
	check(waiting.size() == 1 and waiting[0].uid == first[0].uid, "only the first warning waits")
	if h.state() != &"unhealthy":
		fail("still unhealthy at the ack (got %s), so the held warning can be admitted" % h.state())
		return
	var ack: ActionResult = h.apply(AckEventAction.new(first[0].uid))
	check(ack.ok, "the first warning is acknowledged")
	var second: Array[SimEvent] = _of(ack.events, &"warning_signs")
	if second.is_empty():
		h.play(MIN)
		second = _waiting_attention(h)
	check(second.size() == 1 and second[0].uid != first[0].uid, "the second warning is admitted after the ack")


## AC-10.10 at warm_spot (26 °C): warning to mold is at least 59 h (the spec's floor anywhere; v1 is
## about 86 h here).
func test_ac_10_10_warning_gap_at_the_warm_spot() -> void:
	if not ready_for_rules():
		return
	var starter: StarterState = SliceHarness.mature()
	starter.temp_c = 26.0
	var h: SliceHarness = phone("warning_warm", T0, OFFSET_08)
	h.seed_save(starter, EnvironmentState.at_location(&"warm_spot"), SliceHarness.seed_for_draw(0.5))
	h.launch()
	h.apply(feed_111())
	h.reopen_at(T0 + 13 * DAY)
	var r: CatchUpResult = h.session.get_last_catch_up()
	var warn: Array[SimEvent] = _of(r.events, &"warning_signs")
	var mold: Array[SimEvent] = _of(r.events, &"mold_found")
	if check(warn.size() == 1 and mold.size() == 1, "warning_signs and mold_found both fired"):
		var gap_h: float = float(mold[0].created_unix - warn[0].created_unix) / HOUR
		check(gap_h >= 59.0, "warning to mold at warm_spot is at least 59 h (%.1f h)" % gap_h)


## AC-10.12: a peak passed while the app was closed gives peaked_while_away once, with the peak's time;
## a peak watched with the app open gives peak_now once, at the first at_peak step, and never both.
func test_ac_10_12_peak_closed_versus_open() -> void:
	if not ready_for_rules():
		return
	var shut: SliceHarness = _mature("peak_closed", OFFSET_08)
	shut.apply(feed_111())
	shut.reopen_at(T0 + 12 * HOUR)
	var r: CatchUpResult = shut.session.get_last_catch_up()
	var away: Array[SimEvent] = _of(r.events, &"peaked_while_away")
	check(_of(r.events, &"peak_now").is_empty(), "closed: no peak_now")
	if check_eq(away.size(), 1, "closed: peaked_while_away once"):
		check_eq(int(DictReader.float_of(away[0].payload.get("time_unix", -1))), int(r.notable.get("peak_unix", -2)),
			"its time is the peak's (the highest rise)")
	var open: SliceHarness = _mature("peak_open", OFFSET_08)
	open.apply(feed_111())
	var first_at_peak: int = -1
	for minute: int in 12 * 60:
		open.play(MIN)
		if first_at_peak < 0 and open.session.get_snapshot().rise_phase == &"at_peak":
			first_at_peak = open.clock.now_unix()
	var now_events: Array[SimEvent] = _raised(open, &"peak_now")
	if check_eq(now_events.size(), 1, "open: peak_now once in the cycle"):
		check_eq(now_events[0].created_unix, first_at_peak, "at the first at_peak step")
	check_eq(_journaled(open, &"peaked_while_away"), 0, "open: no peaked_while_away")


## AC-10.11: after three days in the fridge, the first strong counter cycle whose peak reaches 85% of
## the last strong peak gives back_to_strength. At that moment the rise is at least 0.85 of the
## reference. A starter that was never neglected never gets it.
func test_ac_10_11_back_to_strength_after_the_fridge() -> void:
	if not ready_for_rules():
		return
	var h: SliceHarness = _mature("strength", OFFSET_08)
	h.apply(feed_111())
	h.play(HOUR)
	h.apply(SetEnvironmentAction.to_location(&"fridge"))
	h.reopen_at(T0 + HOUR + 3 * DAY)
	h.apply(SetEnvironmentAction.to_location(&"counter"))
	h.apply(feed_111())
	var reference: float = h.session.get_history().last_strong_peak_rise
	var at_event: float = -1.0
	for minute: int in 16 * 60:
		h.play(MIN)
		if at_event < 0.0 and not _raised(h, &"back_to_strength").is_empty():
			at_event = h.session.get_starter().peak_rise
	check(reference > 0.0, "a strong reference peak exists (%.3f)" % reference)
	if check(at_event > 0.0, "back_to_strength fired in the first counter cycle after the fridge"):
		check(at_event >= SPEC_STRENGTH_SHARE * reference - 1e-9,
			"at that moment the peak (%.3f) is at least 85%% of the reference (%.3f)" % [at_event, reference])
	var steady: SliceHarness = _mature("strength_never", OFFSET_08)
	for i: int in 4:
		steady.apply(feed_111())
		steady.reopen_at(T0 + (i + 1) * 12 * HOUR)
	check_eq(_journaled(steady, &"back_to_strength"), 0, "never neglected: no back_to_strength")


## AC-10.4 and 10.5: hunger that begins at 22:36 local is created as a nudge held until 08:00. The player
## feeds at 02:00, so at 08:00 the nudge is stale and is never shown. A nudge that was shown and then
## fed is withdrawn (event_withdrawn with its uid).
func test_ac_10_4_and_10_5_quiet_hours_and_stale_nudges() -> void:
	if not ready_for_rules():
		return
	var night: SliceHarness = _mature("nudge_night", OFFSET_10)
	night.apply(feed_111())
	night.reopen_at(T0 + 16 * HOUR)
	var hunger: Array[SimEvent] = _of(night.session.get_last_catch_up().events, &"hungry_again")
	if check_eq(hunger.size(), 1, "the hunger nudge was created overnight"):
		var minute: int = LocalDay.minute_of_day(hunger[0].created_unix, OFFSET_10)
		check(_quiet(minute), "created in quiet hours (minute %d)" % minute)
		check_eq(hunger[0].not_before_unix, hunger[0].created_unix + _to_eight(minute), "held until 08:00 local")
	check(_raised(night, &"hungry_again").is_empty(), "not shown during quiet hours")
	check(night.apply(feed_111()).ok, "fed at 02:00")
	night.reopen_at(T0 + 23 * HOUR)
	check(_raised(night, &"hungry_again").is_empty(), "never shown: it went stale before 08:00")
	for e: SimEvent in night.session.get_pending_events():
		check(e.id != &"hungry_again", "and it is no longer pending")
	var day: SliceHarness = _mature("nudge_day", OFFSET_08)
	day.apply(feed_111())
	day.reopen_at(T0 + 13 * HOUR)
	var shown: Array[SimEvent] = _raised(day, &"hungry_again")
	if check_eq(shown.size(), 1, "a daytime hunger nudge is shown on return"):
		day.forget()
		day.apply(feed_111())
		var withdrawn: Array[int] = []
		for e: Dictionary in day.heard_of(&"event_withdrawn"):
			var args: Array = e["args"]
			withdrawn.append(int(args[0]))
		check(withdrawn.has(shown[0].uid), "feeding withdraws the shown nudge (uid %d)" % shown[0].uid)


## AC-10.9 (BT-1, BT-9): 1:2:2 fed at 08:00 and 20:00 for 30 days. No attention event at all, at most
## 2 nudges a local day, never unhealthy, mold risk under 0.3, at least one at_peak each day, and at
## most 4 h hungry a day.
func test_ac_10_9_twice_daily_for_a_month_needs_no_attention() -> void:
	if not ready_for_rules():
		return
	var h: SliceHarness = _mature("bt9", OFFSET_08)
	var feed: FeedAction = FeedAction.from_ratio(2.0, 2.0, &"white_bread")
	var events: Array[SimEvent] = h.apply(feed).events.duplicate()
	var peaks: Dictionary[String, int] = {}
	var hungry_s: Dictionary[String, int] = {}
	var unhealthy: bool = false
	var max_mold: float = 0.0
	for k: int in range(1, 60):
		h.reopen_at(T0 + k * 12 * HOUR)
		var r: CatchUpResult = h.session.get_last_catch_up()
		events.append_array(r.events)
		_tally_states(r, OFFSET_08, peaks, hungry_s)
		for t: Dictionary in r.transitions:
			unhealthy = unhealthy or String(t.get("to", "")) == "unhealthy"
		max_mold = maxf(max_mold, h.session.get_starter().mold_risk)
		events.append_array(h.apply(feed).events)
	var per_day: Dictionary[String, int] = {}
	var attention: int = 0
	for e: SimEvent in events:
		if e.tier == &"attention":
			attention += 1
		elif e.tier == &"nudge":
			var key: String = LocalDay.day_key(e.created_unix, OFFSET_08)
			per_day[key] = per_day.get(key, 0) + 1
	check_eq(attention, 0, "no attention event in 30 days")
	check(per_day.values().all(func(n: int) -> bool: return n <= 2), "at most 2 nudges a day: %s" % str(per_day))
	check(not unhealthy, "never unhealthy")
	check(max_mold < 0.3, "mold risk stays under 0.3 (max %.4f)" % max_mold)
	var short_days: PackedStringArray = PackedStringArray()
	for d: int in range(1, 30):
		var key: String = LocalDay.day_key(T0 + d * DAY, OFFSET_08)
		if peaks.get(key, 0) < 1:
			short_days.append(key)
		if hungry_s.get(key, 0) > 4 * HOUR:
			short_days.append(key + " hungry %d s" % hungry_s[key])
	check(short_days.is_empty(), "every day has an at_peak and at most 4 h hungry: " + ", ".join(short_days))


## AC-10.9 (BT-2): 1:5:5 fed once a day at 19:00 for 14 days. No attention event, never unhealthy, mold
## risk under 0.3, and at_peak starts 9 to 13 h after each feed.
func test_ac_10_9_bt_2_once_daily_one_to_five() -> void:
	if not ready_for_rules():
		return
	var offset_19: int = 19 * 3600  # T0 is 19:00 local
	var h: SliceHarness = _mature("bt2", offset_19)
	var feed: FeedAction = FeedAction.from_ratio(5.0, 5.0, &"white_bread")
	var events: Array[SimEvent] = h.apply(feed).events.duplicate()
	var late: PackedStringArray = PackedStringArray()
	var unhealthy: bool = false
	var max_mold: float = 0.0
	for d: int in range(1, 15):
		h.reopen_at(T0 + d * DAY)
		var r: CatchUpResult = h.session.get_last_catch_up()
		events.append_array(r.events)
		var peak_at: int = _transition_to(r, &"at_peak")
		var after_h: float = float(peak_at - (T0 + (d - 1) * DAY)) / HOUR
		if peak_at < 0 or after_h < 9.0 or after_h > 13.0:
			late.append("day %d: %.2f h" % [d, after_h])
		for t: Dictionary in r.transitions:
			unhealthy = unhealthy or String(t.get("to", "")) == "unhealthy"
		max_mold = maxf(max_mold, h.session.get_starter().mold_risk)
		events.append_array(h.apply(feed).events)
	check(events.all(func(e: SimEvent) -> bool: return e.tier != &"attention"), "no attention event in 14 days")
	check(not unhealthy, "never unhealthy")
	check(max_mold < 0.3, "mold risk under 0.3 (max %.4f)" % max_mold)
	check(late.is_empty(), "at_peak starts 9 to 13 h after each feed: " + ", ".join(late))


## BT-3: 1:2:2 fed at 07:00 and 22:00 for 14 days. No nudge is ever created in quiet hours.
func test_bt_3_late_evening_feeds_create_no_night_nudges() -> void:
	if not ready_for_rules():
		return
	var h: SliceHarness = _mature("bt3", OFFSET_07)
	var feed: FeedAction = FeedAction.from_ratio(2.0, 2.0, &"white_bread")
	var events: Array[SimEvent] = h.apply(feed).events.duplicate()
	var t: int = T0
	for k: int in 27:
		t += 15 * HOUR if k % 2 == 0 else 9 * HOUR
		h.reopen_at(t)
		events.append_array(h.session.get_last_catch_up().events)
		events.append_array(h.apply(feed).events)
	for e: SimEvent in events:
		if e.tier == &"nudge":
			var minute: int = LocalDay.minute_of_day(e.created_unix, OFFSET_07)
			check(not _quiet(minute), "%s created at minute %d, in quiet hours" % [e.id, minute])
	check_eq(h.journal_of(&"feed").size(), 28, "28 feeds over 14 days")


## AC-10.2, 10.3, 10.4 and PROP-12 over random months: random feeds, moves, absences of 2 h to 9 days,
## acknowledgements and discards at four UTC offsets. Per local date at most 4 info, 2 nudges and 1
## attention are created; never more than one attention waits; each timed cooldown holds; first_rise
## and mold_found come at most once per starter; nudges in quiet hours wait until 08:00 and nothing
## else waits. The same seed gives the same events (id, time, tier).
func test_ac_10_2_caps_cooldowns_and_quiet_hours_over_random_months() -> void:
	if not ready_for_rules():
		return
	var offsets: Array[int] = [-5 * 3600, 0, 3 * 3600, 9 * 3600]
	var problems: PackedStringArray = PackedStringArray()
	var total: int = 0
	var schedules: int = maxi(3, seeds() / 20)
	for i: int in schedules:
		var offset: int = offsets[i % offsets.size()]
		var out: Dictionary = _random_month("month_%d" % i, 9100 + i, offset)
		var events: Array[SimEvent] = []
		events.assign(out["events"])
		var found: PackedStringArray = out["problems"]
		problems.append_array(found)
		total += events.size()
		problems.append_array(_judge_month(events, out["discards"], offset, i))
		if i == 0:
			var again: Dictionary = _random_month("month_0_again", 9100, offset)
			var replay: Array[SimEvent] = []
			replay.assign(again["events"])
			check_eq(_signature(replay), _signature(events), "PROP-12: the same seed gives the same events")
	check(total >= schedules * 10, "the months produced events (%d)" % total)
	check(problems.is_empty(), "%d problems:\n    %s" % [problems.size(), "\n    ".join(problems.slice(0, 12))])


# ------------------------------------------------------------------ helpers

func _mature(label: String, offset: int) -> SliceHarness:
	var h: SliceHarness = phone(label, T0, offset)
	check_eq(h.seed_save(SliceHarness.mature(), null, SliceHarness.seed_for_draw(0.5)), OK, label + ": seeded")
	h.launch()
	return h


## Events raised on the Session (shown), by id, oldest first.
func _raised(h: SliceHarness, id: StringName) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e: Dictionary in h.heard_of(&"event_raised"):
		var args: Array = e["args"]
		var ev: SimEvent = args[0] as SimEvent
		if ev != null and ev.id == id:
			out.append(ev)
	return out


func _journaled(h: SliceHarness, id: StringName) -> int:
	var n: int = 0
	for e: JournalEntry in h.journal_of(&"event"):
		if String(e.data.get("event_id", "")) == String(id):
			n += 1
	return n


static func _waiting_attention(h: SliceHarness) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e: SimEvent in h.session.get_pending_events():
		if e.tier == &"attention":
			out.append(e)
	return out


static func _of(events: Array[SimEvent], id: StringName) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e: SimEvent in events:
		if e.id == id:
			out.append(e)
	return out


## The time of the first transition to `state` in a catch-up, or -1.
static func _transition_to(r: CatchUpResult, state: StringName) -> int:
	for t: Dictionary in r.transitions:
		if String(t.get("to", "")) == String(state):
			return int(t.get("at_unix", -1))
	return -1


## Counts at_peak entries and hungry seconds per local day from a catch-up's transitions.
static func _tally_states(r: CatchUpResult, offset: int, peaks: Dictionary[String, int],
		hungry_s: Dictionary[String, int]) -> void:
	for i: int in r.transitions.size():
		var t: Dictionary = r.transitions[i]
		var at: int = int(t.get("at_unix", 0))
		var to_state: String = String(t.get("to", ""))
		var key: String = LocalDay.day_key(at, offset)
		if to_state == "at_peak":
			peaks[key] = peaks.get(key, 0) + 1
		if to_state == "hungry":
			var until: int = int(r.transitions[i + 1].get("at_unix", r.to_unix)) if i + 1 < r.transitions.size() else r.to_unix
			hungry_s[key] = hungry_s.get(key, 0) + (until - at)


## One random month on a new phone. Returns {"events", "discards", "problems"}.
func _random_month(label: String, schedule_seed: int, offset: int) -> Dictionary:
	var gen := RandomNumberGenerator.new()
	gen.seed = schedule_seed
	var h: SliceHarness = _mature(label, offset)
	var events: Array[SimEvent] = []
	var discards: Array[int] = []
	var problems: PackedStringArray = PackedStringArray()
	var presets: Array[Vector2] = [Vector2(1, 1), Vector2(2, 2), Vector2(5, 5)]
	var places: Array[StringName] = [&"counter", &"warm_spot", &"fridge"]
	var t: int = T0
	var end: int = T0 + 30 * DAY
	while t < end:
		var gap: int = gen.randi_range(2 * HOUR, 30 * HOUR) + gen.randi_range(0, 59) * MIN
		if gen.randf() < 0.08:
			gap = gen.randi_range(3 * DAY, 9 * DAY)
		t = mini(t + gap, end)
		h.reopen_at(t)
		events.append_array(h.session.get_last_catch_up().events)
		_check_waiting(h, problems, "%s after the launch at %s" % [label, hours(t)])
		if h.state() == &"moldy":
			var d: ActionResult = h.apply(DiscardStarterAction.new("Fern"))
			if d.ok:
				discards.append(t)
				events.append_array(d.events)
			continue
		var roll: float = gen.randf()
		if roll < 0.7:
			var p: Vector2 = presets[gen.randi_range(0, presets.size() - 1)]
			var flour: StringName = &"whole_wheat" if gen.randf() < 0.3 else &"white_bread"
			events.append_array(h.apply(FeedAction.from_ratio(p.x, p.y, flour)).events)
		elif roll < 0.85:
			events.append_array(h.apply(SetEnvironmentAction.to_location(places[gen.randi_range(0, 2)])).events)
		for e: SimEvent in h.session.get_pending_events():
			if e.tier == &"attention" and gen.randf() < 0.5:
				events.append_array(h.apply(AckEventAction.new(e.uid)).events)
		_check_waiting(h, problems, "%s after the actions at %s" % [label, hours(t)])
	h.kill()
	return {"events": events, "discards": discards, "problems": problems}


func _check_waiting(h: SliceHarness, problems: PackedStringArray, where: String) -> void:
	var n: int = 0
	for e: SimEvent in h.session.get_pending_events():
		if e.tier == &"attention":
			n += 1
	if n > 1:
		problems.append("%d attention events waiting %s" % [n, where])


func _judge_month(events: Array[SimEvent], discards: Array[int], offset: int, i: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var per_day: Dictionary[String, int] = {}
	var last: Dictionary[StringName, int] = {}
	var per_starter: Dictionary[String, int] = {}
	for e: SimEvent in events:
		var day: String = LocalDay.day_key(e.created_unix, offset)
		var cap_key: String = "%s %s" % [day, e.tier]
		per_day[cap_key] = per_day.get(cap_key, 0) + 1
		if per_day[cap_key] > CAPS.get(e.tier, 0):
			out.append("month %d: %d %s events on %s" % [i, per_day[cap_key], e.tier, day])
		if COOLDOWNS.has(e.id) and last.has(e.id) and e.created_unix - last[e.id] < COOLDOWNS[e.id]:
			out.append("month %d: %s %d s after the last one" % [i, e.id, e.created_unix - last[e.id]])
		last[e.id] = e.created_unix
		if ONCE_PER_STARTER.has(e.id):
			var epoch: int = 0
			for d: int in discards:
				if e.created_unix >= d:
					epoch += 1
			var once_key: String = "%s %d" % [e.id, epoch]
			per_starter[once_key] = per_starter.get(once_key, 0) + 1
			if per_starter[once_key] > 1:
				out.append("month %d: %s twice for starter %d" % [i, e.id, epoch])
		var minute: int = LocalDay.minute_of_day(e.created_unix, offset)
		var want_hold: int = 0
		if e.tier == &"nudge" and _quiet(minute):
			want_hold = e.created_unix + _to_eight(minute)
		if e.not_before_unix != want_hold:
			out.append("month %d: %s (%s) at minute %d waits until %d, expected %d" % [i, e.id, e.tier,
				minute, e.not_before_unix, want_hold])
	return out


static func _quiet(minute: int) -> bool:
	return minute >= QUIET_FROM_MIN or minute < QUIET_UNTIL_MIN


## Seconds from local `minute` (inside quiet hours) to the next 08:00.
static func _to_eight(minute: int) -> int:
	var minutes: int = QUIET_UNTIL_MIN - minute if minute < QUIET_UNTIL_MIN else 24 * 60 - minute + QUIET_UNTIL_MIN
	return minutes * 60


static func _signature(events: Array[SimEvent]) -> Array:
	var out: Array = []
	for e: SimEvent in events:
		out.append([String(e.id), e.created_unix, String(e.tier)])
	return out
