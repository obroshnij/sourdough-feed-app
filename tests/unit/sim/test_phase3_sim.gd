extends TestCase
## Phase 3 contracts on the pure sim side: the feed planner, forecast words, the return summary, the
## time-lapse keyframes, the history fields the event rules read, and the memorial. Owner: T1.

const T0: int = 1795651200
const H: int = 3600


func _counter() -> EnvironmentState:
	return EnvironmentState.at_location(&"counter")


## A mature starter at its peak at the counter, timestamped T0: the BT-17 setup.
func _mature_at_peak() -> StarterState:
	var s: StarterState = SimFixtures.mature()
	SimFixtures.feed_ratio(s)
	s.sim_time_unix = T0
	return Demo.run_to_peak(s, _counter())


func _event(id: StringName, tier: StringName, at: int, uid: int, payload: Dictionary = {}) -> SimEvent:
	var e := SimEvent.new()
	e.id = id
	e.tier = tier
	e.created_unix = at
	e.uid = uid
	e.payload = payload
	return e


func test_schedule_question_picks_one_preset_per_answer_at_the_counter() -> void:
	if not require(&"p3_contracts"):
		return
	var s: StarterState = _mature_at_peak()
	var expect: Dictionary = {&"soon": "1:1:1", &"later": "1:2:2", &"tomorrow": "1:5:5"}
	for answer: StringName in FeedPlanner.ANSWERS:
		var p: FeedPreview = FeedPlanner.plan(s, _counter(), PlayerHistory.new(), answer, &"white_bread",
			&"pour_off", T0, 0)
		check_eq(p.ratio_text, expect[answer], "BT-17 %s picks %s" % [answer, expect[answer]])
		check(p.fits_window and p.fit_key == &"", "%s fits its window" % answer)
		check_eq(p.discard_g, roundi(s.mass_g - p.action.kept_g), "%s discard in grams" % answer)
		check(p.forecast.has_window and p.window_key.begins_with("WINDOW_"), "%s has forecast words" % answer)
		check_eq(p.reason_key, &"", "%s would be accepted" % answer)
		check_eq(p.timing, &"on_time", "%s is on time at the peak" % answer)
	var fridge: FeedPreview = FeedPlanner.plan(s, EnvironmentState.at_location(&"fridge"), PlayerHistory.new(),
		&"later", &"whole_wheat", &"pour_off", T0, 0)
	check(not fridge.fits_window and fridge.fit_key == &"FEED_FIT_FRIDGE", "the fridge says so, never blocks")
	check_eq(fridge.ratio_text, "1:2:2", "the answer's own preset when nothing fits")
	var moldy: StarterState = s.copy()
	moldy.moldy = true
	var blocked: FeedPreview = FeedPlanner.preview(moldy, _counter(), PlayerHistory.new(),
		FeedAction.from_ratio(1.0, 1.0, &"white_bread"), &"", T0, 0)
	check_eq(blocked.reason_key, GameAction.REASON_MOLDY, "a moldy preview carries the refusal")
	var hoochy: StarterState = s.copy()
	hoochy.hooch = CatchUp.HOOCH_VISIBLE
	check(FeedPlanner.preview(hoochy, _counter(), null, FeedAction.from_ratio(1.0, 1.0, &"white_bread"), &"", T0,
		0).hooch_step, "hooch at 0.10 opens the hooch step")
	hoochy.hooch = CatchUp.HOOCH_VISIBLE - 0.001
	check(not FeedPlanner.preview(hoochy, _counter(), null, FeedAction.from_ratio(1.0, 1.0, &"white_bread"), &"",
		T0, 0).hooch_step, "just under 0.10 has no hooch step")


func test_routine_hint_needs_three_far_apart_feeds_and_a_quick_peak() -> void:
	if not require(&"p3_contracts"):
		return
	var h := PlayerHistory.new()
	var quick := PeakForecast.new()
	quick.has_window = true
	quick.peak_min_s = 6.0 * H
	quick.peak_max_s = 6.5 * H
	h.recent_feed_unix = [T0, T0 + 20 * H, T0 + 44 * H]
	check(FeedPlanner.routine_hint(h, quick, T0 + 60 * H), "3 feeds 20 h or more apart, peak under 10 h")
	h.recent_feed_unix = [T0, T0 + 19 * H, T0 + 44 * H]
	check(not FeedPlanner.routine_hint(h, quick, T0 + 60 * H), "a 19 h gap: no hint")
	h.recent_feed_unix = [T0, T0 + 20 * H, T0 + 44 * H]
	h.routine_hint_unix = T0 + 60 * H - 86400
	check(not FeedPlanner.routine_hint(h, quick, T0 + 60 * H), "shown a day ago: not again this week")
	var slow := PeakForecast.new()
	slow.has_window = true
	slow.peak_min_s = 11.0 * H
	slow.peak_max_s = 11.5 * H
	h.routine_hint_unix = 0
	check(not FeedPlanner.routine_hint(h, slow, T0 + 60 * H), "a peak after 10 h fits the rhythm")


func test_forecast_window_words() -> void:
	if not require(&"p3_contracts"):
		return
	var morning: int = T0 + 8 * H
	check_eq(ForecastWindow.key(morning, morning + H, 0), &"WINDOW_SOON", "within 90 min")
	check_eq(ForecastWindow.key(morning, morning + 3 * H, 0), &"WINDOW_LUNCHTIME", "11:00 today")
	check_eq(ForecastWindow.key(morning, T0 + 19 * H, 0), &"WINDOW_THIS_EVENING", "19:00 today")
	check_eq(ForecastWindow.key(morning, T0 + 22 * H, 0), &"WINDOW_TONIGHT", "22:00 today")
	check_eq(ForecastWindow.key(morning, T0 + 24 * H + 2 * H, 0), &"WINDOW_OVERNIGHT", "02:00 tomorrow")
	check_eq(ForecastWindow.key(morning, T0 + 24 * H + 7 * H, 0), &"WINDOW_TOMORROW_MORNING", "07:00 tomorrow")
	check_eq(ForecastWindow.key(morning, T0 + 24 * H + 18 * H, 0), &"WINDOW_TOMORROW_EVENING", "18:00 tomorrow")
	check_eq(ForecastWindow.key(morning, T0 + 72 * H, 0), &"WINDOW_LATER", "in 3 days")
	check_eq(ForecastWindow.key(morning, T0 + 19 * H, -3 * H), &"WINDOW_THIS_AFTERNOON", "the offset moves it")


func test_return_summary_keeps_three_rows_and_one_prompt() -> void:
	if not require(&"p3_contracts"):
		return
	var r := CatchUpResult.new()
	r.from_unix = T0
	r.to_unix = T0 + 7 * 86400
	r.simulated_s = 7 * 86400
	r.events = [
		_event(&"first_rise", &"info", T0 + 2 * H, 1),
		_event(&"peaked_while_away", &"info", T0 + 7 * H, 2,
			{"time_unix": T0 + 6 * H, "peak_rise": 2.1, "rise_word": "DOUBLE"}),
		_event(&"hooch_forming", &"info", T0 + 17 * H, 3),
		_event(&"hungry_again", &"nudge", T0 + 18 * H, 4),
		_event(&"big_bubble", &"info", T0 + 20 * H, 5),
		_event(&"warning_signs", &"attention", T0 + 108 * H, 6, {"began_unix": T0 + 108 * H}),
	]
	r.transitions = [{"at_unix": T0 + 30 * H, "from": "hungry", "to": "dormant", "cause": "starved"}]
	var s: ReturnSummary = ReturnSummary.build(r)
	check(s.show and not s.first_launch, "a week away with events shows")
	check_eq(s.title_key, &"AWAY_TITLE_LONG", "3 days or more: Welcome back")
	check_eq(s.lines.size(), 3, "at most 3 rows")
	check_eq(s.prompt.id, &"warning_signs", "the attention is the prompt")
	var keys: Array[StringName] = []
	for line: ReturnLine in s.lines:
		keys.append(line.text_key)
	check(keys.has(&"EVENT_WARNING_SIGNS_AWAY_DAYS"), "the warning row is always kept: %s" % [keys])
	check_eq(s.lines[s.lines.size() - 1].args, {"days": 2}, "warnings began 60 h before the return: 2 days")
	check(keys.has(&"EVENT_FIRST_RISE_AWAY") and keys.has(&"EVENT_PEAKED_WHILE_AWAY_AWAY_DOUBLE"),
		"milestone and peak beat hunger, other info and ambient: %s" % [keys])
	for i: int in range(1, s.lines.size()):
		check(s.lines[i - 1].at_unix <= s.lines[i].at_unix, "rows oldest first")
	var dropped_ids: Array[StringName] = []
	for e: SimEvent in s.dropped:
		dropped_ids.append(e.id)
	check(dropped_ids.has(&"big_bubble") and dropped_ids.has(&"hooch_forming") and dropped_ids.has(&"hungry_again"),
		"everything without a row (and not the prompt) is listed as dropped: %s" % [dropped_ids])
	check(not dropped_ids.has(&"warning_signs"), "the prompt is never dropped")


func test_return_summary_cap_hours_boundary_and_fridge_rest() -> void:
	if not require(&"p3_contracts"):
		return
	var r := CatchUpResult.new()
	r.from_unix = T0
	r.to_unix = T0 + 30 * H
	r.simulated_s = 30 * H
	r.events = [_event(&"warning_signs", &"attention", T0, 1, {"began_unix": T0})]
	var s: ReturnSummary = ReturnSummary.build(r)
	check_eq(s.lines[0].text_key, &"EVENT_WARNING_SIGNS_AWAY_HOURS", "30 h uses the hours line")
	check_eq(s.lines[0].args, {"hours": 30}, "{hours}")
	check_eq(s.title_key, &"AWAY_TITLE", "under 3 days: While you were away")
	var capped := CatchUpResult.new()
	capped.from_unix = T0
	capped.to_unix = T0 + 14 * 86400
	capped.simulated_s = SimConstants.CATCH_UP_CAP_S
	capped.capped = true
	capped.transitions = [
		{"at_unix": T0 + H, "from": "at_peak", "to": "collapsing", "cause": ""},
		{"at_unix": T0 + 9 * H, "from": "collapsing", "to": "hungry", "cause": ""},
		{"at_unix": T0 + 60 * H, "from": "hungry", "to": "dormant", "cause": "starved"},
		{"at_unix": T0 + 99 * H, "from": "dormant", "to": "unhealthy", "cause": ""},
	]
	capped.events = [
		_event(&"warning_signs", &"attention", T0 + 99 * H, 7, {"began_unix": T0 + 99 * H}),
		_event(&"mold_found", &"attention", T0 + 210 * H, 8),
	]
	var c: ReturnSummary = ReturnSummary.build(capped)
	check(c.capped and c.lines.size() == 3, "capped: still 3 rows")
	check_eq(c.lines[2].text_key, &"AWAY_CAPPED", "AWAY_CAPPED is last")
	check(c.lines[0].text_key == &"EVENT_WARNING_SIGNS_AWAY_DAYS" and c.lines[1].text_key == &"EVENT_MOLD_FOUND_AWAY",
		"return to moldy: the warning row, then the mold row (events-catalog §5)")
	check_eq(c.prompt.id, &"mold_found", "mold_found is the prompt")
	var fridge := CatchUpResult.new()
	fridge.from_unix = T0
	fridge.to_unix = T0 + 4 * 86400
	fridge.simulated_s = 4 * 86400
	fridge.transitions = [{"at_unix": T0 + 2 * H, "from": "active", "to": "dormant", "cause": "cold"}]
	check_eq(ReturnSummary.build(fridge).lines[0].text_key, &"AWAY_LONG_REST", "days in the fridge: a long rest")
	var short := CatchUpResult.new()
	short.simulated_s = SimConstants.AWAY_SUMMARY_MIN_S - 60
	short.transitions = fridge.transitions
	check(not ReturnSummary.build(short).show, "under the 3,600 s threshold it doesn't show")
	short.simulated_s = SimConstants.AWAY_SUMMARY_MIN_S
	check(ReturnSummary.build(short).show, "at 3,600 s with a change it shows")
	var stale_nudge := CatchUpResult.new()
	stale_nudge.simulated_s = 8 * H
	stale_nudge.events = [_event(&"hungry_again", &"nudge", T0, 9)]
	stale_nudge.events[0].expires_if = &"state_not_hungry"
	var fed := DerivedState.new()
	fed.state = &"developing"
	check(ReturnSummary.build(stale_nudge, fed).prompt == null, "a stale nudge is never the prompt")
	check(ReturnSummary.for_first_launch(T0).first_launch and not ReturnSummary.for_first_launch(T0).show,
		"the first launch shows nothing")


func test_time_lapse_keyframes_are_bounded_and_keep_every_transition() -> void:
	if not require(&"p3_contracts"):
		return
	var s: StarterState = SimFixtures.mature()
	SimFixtures.feed_ratio(s)
	s.sim_time_unix = T0
	var env: EnvironmentState = _counter()
	var no_rules: Array[EventRule] = []
	var r: CatchUpResult = CatchUp.run_with_rules(s, env, PlayerHistory.new(), EventLedger.new(),
		SimCatalog.builtin(), T0 + 10 * 86400, 0, false, no_rules)
	check(r.keyframes.size() >= 2 and r.keyframes.size() <= CatchUpResult.MAX_KEYFRAMES,
		"at most 30 frames, got %d" % r.keyframes.size())
	check_eq(r.keyframes[0].at_unix, r.from_unix, "the first frame is the state before the first step")
	check_eq(r.keyframes[-1].at_unix, r.to_unix, "the last frame is the state at the return")
	check_eq(r.keyframes[0].state, &"freshly_fed", "the first frame shows the fed starter")
	for i: int in range(1, r.keyframes.size()):
		check(r.keyframes[i - 1].at_unix < r.keyframes[i].at_unix, "frames strictly in time order")
	var frame_at: Dictionary = {}
	for k: TimeLapseKeyframe in r.keyframes:
		frame_at[k.at_unix] = k
	check(r.transitions.size() >= 6, "10 days unfed walks the state chain, %d transitions" % r.transitions.size())
	for t: Dictionary in r.transitions:
		var at: int = t["at_unix"]
		if not check(frame_at.has(at), "a frame at %d for %s" % [at, t["to"]]):
			continue
		var k: TimeLapseKeyframe = frame_at[at]
		check(k.transition and String(k.state) == t["to"], "a transition frame at %d for %s" % [at, t["to"]])
	check_between(r.time_lapse_duration_s(), 6.0, 6.0, "10 days plays for the full 6 s")
	# finish_keyframes never drops a transition frame, so the 30-frame cap (AC-09.5) holds only while the
	# collector's transition cap plus the first and last frames fit in it (QA's finding).
	check(CatchUpResult.MAX_TRANSITION_FRAMES + 2 <= CatchUpResult.MAX_KEYFRAMES,
		"16 transitions + first + last fit in 30")
	var one_hour := CatchUpResult.new()
	one_hour.simulated_s = SimConstants.AWAY_SUMMARY_MIN_S
	check_between(one_hour.time_lapse_duration_s(), 3.0, 3.0, "a 1 h return plays for 3 s")


func test_history_fields_for_the_event_rules() -> void:
	if not require(&"p3_contracts"):
		return
	var h := PlayerHistory.new()
	var env: EnvironmentState = _counter()
	var s: StarterState = SimFixtures.mature()
	s.sim_time_unix = T0
	var prev: DerivedState = StateDeriver.derive(s, env)
	var feed: FeedAction = FeedAction.from_ratio(1.0, 1.0, &"white_bread")
	feed.at_unix = T0 + 17
	h.record_action(feed, s, prev)
	check(h.real_feeds == 1 and h.last_feed_unix == T0, "real_feeds and the feed's grid time")
	check_eq(h.last_feed, feed.to_dict(), "the last feed for feed-like-last-time")
	SimFixtures.feed_ratio(s)
	var entered: bool = false
	for i: int in 12 * 60:
		Sim.step(s, env)
		var d: DerivedState = StateDeriver.derive(s, env)
		h.record_step(s, d, prev, false)
		if d.rise_phase == &"at_peak" and prev.rise_phase != &"at_peak":
			entered = true
			check(not h.peak_seen_foreground, "reset on the at_peak entry step (background)")
		prev = d
	check(entered and h.peaks == 1, "one peak counted, got %d" % h.peaks)
	check(h.cycle_peak_unix > T0 and h.cycle_peak_unix % 60 == 0, "the cycle's peak time on the grid")
	check(h.best_rise >= 2.0, "the tallest rise, %s" % h.best_rise)
	check_eq(h.warm_unfed_s, 12 * H, "12 h unfed at 22 C")
	var unhealthy := DerivedState.new()
	unhealthy.state = &"unhealthy"
	h.record_action(feed, s, unhealthy)
	check(h.unhealthy_left_unix == s.sim_time_unix and h.last_very_late_feed_unix == s.sim_time_unix,
		"a rescue feed leaves unhealthy and arms back_to_strength")
	check_eq(h.warm_unfed_s, 0, "a feed resets the unfed clock")
	var cold := DerivedState.new()
	cold.state = &"dormant"
	cold.dormant_cause = &"cold"
	h.record_action(SetEnvironmentAction.to_location(&"counter"), s, cold, EnvironmentState.at_location(&"fridge"))
	check_eq(h.fridge_left_unix, s.sim_time_unix, "leaving the fridge cold-dormant is a fridge wake")
	h.fridge_left_unix = 0
	h.record_action(SetEnvironmentAction.to_location(&"counter"), s, prev, EnvironmentState.at_location(&"fridge"))
	check_eq(h.fridge_left_unix, 0, "a short fridge visit that never got cold doesn't count")
	var back: PlayerHistory = PlayerHistory.from_dict(h.to_dict())
	check_eq(back.to_dict(), h.to_dict(), "round trip")
	var old: Dictionary = h.to_dict()
	for k: String in ["real_feeds", "last_feed", "peaks", "onboarding_path", "peak_seen_foreground"]:
		old.erase(k)
	check(PlayerHistory.from_dict(old) != null, "a Phase 2 history without the new fields still loads")
	h.reset_for_new_starter()
	check(h.real_feeds == 0 and h.peaks == 0 and not h.last_feed.is_empty(), "a new starter keeps only the habit")


func test_memorial_page_values() -> void:
	if not require(&"p3_contracts"):
		return
	var m := Memorial.new()
	m.starter_id = "000002a000000000"
	m.born_unix = T0
	m.ended_unix = T0 + 9 * 86400 + 5 * H
	m.unfed_days = 8
	check_eq(m.days_together(), 9, "whole days together")
	check_eq(m.epitaph_key(), &"MEMORIAL_EPITAPH_1", "1 + seed % 3, seed 42")
	check_eq(m.cause_args(), {"days": 8}, "{days}")
	check_eq(m.dates_args(), {"start_unix": T0, "end_unix": m.ended_unix}, "dates for Keys.format")
	var old: Dictionary = m.to_dict()
	old.erase("peaks_count")
	old.erase("best_rise")
	old.erase("unfed_days")
	check(Memorial.from_dict(old) != null, "a Phase 2 memorial still loads")
	check_eq(StarterState.seed_of("not hex!"), 0, "a non-hex id gives seed 0")


func test_flour_profiles_match_sim_constants() -> void:
	if not require(&"m2_sim"):
		return
	var catalog: SimCatalog = SimCatalog.builtin()
	check_eq(catalog.flours.size(), SimConstants.FLOUR_IDS.size(), "one profile per flour id")
	for id: StringName in SimConstants.FLOUR_IDS:
		var f: FlourProfile = catalog.flours[id]
		var row: Array = SimConstants.FLOURS[id]
		check_eq(f.id, id, "%s id" % id)
		check_eq([f.speed_mult, f.acid_mult, f.water_absorption, f.gas_retention], row.slice(0, 4),
			"%s mirrors SimConstants.FLOURS (the comment in flour_profile.gd)" % id)


func test_smell_and_adoption_validation() -> void:
	if not require(&"p3_contracts"):
		return
	var s: StarterState = SimFixtures.mature()
	check_eq(SmellAction.new().validate(s, _counter(), null), &"", "smell is fine")
	s.moldy = true
	check_eq(SmellAction.new().validate(s, _counter(), null), GameAction.REASON_MOLDY_LOCKED, "D-043 no smell when moldy")
	var unnamed := StarterState.new()
	check_eq(AdoptStarterAction.new("Bramble").validate(unnamed, _counter(), null), &"", "adopting an unnamed starter")
	check_eq(AdoptStarterAction.new("  ").validate(unnamed, _counter(), null), GameAction.REASON_NAME, "a name is needed")
	check_eq(AdoptStarterAction.new("Bramble", &"wander").validate(unnamed, _counter(), null), GameAction.REASON_ADOPT,
		"only tour or skip")
	unnamed.name = "Bramble"
	check_eq(AdoptStarterAction.new("Other").validate(unnamed, _counter(), null), GameAction.REASON_ADOPT,
		"a named starter can't be adopted again")
	var a: FeedAction = FeedAction.from_ratio(5.0, 5.0, &"whole_wheat")
	a.hooch_choice = &"stir_in"
	var b: FeedAction = FeedAction.from_dict(a.to_dict())
	check(b != null and b.to_dict() == a.to_dict(), "FeedAction round-trips through to_dict")
	check_eq(a.copy().to_dict(), a.to_dict(), "copy is field by field")
	check(FeedAction.from_dict({"kept_g": 50}) == null, "a malformed feed gives null")
