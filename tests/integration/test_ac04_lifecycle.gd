extends SliceCase
## AC-04 (starter lifecycle) through the real Session: a feed applied with Session.apply(), then the
## app open (live grid ticks) or closed (catch-up on the next launch). Asserts on Session state, the
## state_changed signal, the journal and the save. The pure sim is covered by T1's unit tests and the
## golden vectors (AC-04.1); this suite proves the same lifecycle survives the Session pipeline.
## Also: AC-02.2 (the jar follows the sim, no pops), EC-07 and EC-25 (a moldy starter, then discard).

## test-plan §4.3: each check time sits at least 0.3 h inside its spec §12.2 window (22 °C, 1:1:1).
const RISE_CHECKS: Array[Array] = [
	[0.1, &"freshly_fed"], [0.65, &"developing"], [3.0, &"active"], [5.5, &"near_peak"],
	[6.8, &"at_peak"], [10.0, &"collapsing"], [14.0, &"hungry"],
]
const RISE_ORDER: Array[StringName] = [
	&"freshly_fed", &"developing", &"active", &"near_peak", &"at_peak", &"collapsing", &"hungry",
]
## V9 (spec §18): unfed at the counter after a 1:1:1 feed on MATURE. Onset windows in hours.
const V9_ONSETS: Dictionary[StringName, Vector2] = {
	&"hungry": Vector2(12.4, 12.8), &"dormant": Vector2(74.0, 77.0),
	&"unhealthy": Vector2(104.0, 111.0), &"moldy": Vector2(207.0, 219.0),
}


## AC-04.2 and AC-02.2: a 1:1:1 feed at the counter with the app open for 14 h. Every rise phase is
## reached at its §4.3 check time, the pill never flickers back to an earlier phase, the journal logs
## each change once, and the jar (VisualParams) is exactly the mapper's output with no pop.
func test_ac_04_2_rise_cycle_with_the_app_open() -> void:
	if not ready_for_integration():
		return
	var h: SliceHarness = mature_phone("rise_open", SliceHarness.seed_for_draw(0.5))
	var fed: ActionResult = h.apply(feed_111())
	check(fed.ok, "the feed is accepted")
	var fed_at: int = h.session.get_starter().sim_time_unix
	h.forget()
	var next_check: int = 0
	var mapper_misses: int = 0
	for minute: int in range(1, 14 * 60 + 1):
		h.play(MIN)
		var expected: VisualParams = VisualMapper.from_state(h.session.get_starter(), h.session.get_environment())
		if h.session.get_visuals().to_dict() != expected.to_dict():
			mapper_misses += 1
		if next_check < RISE_CHECKS.size():
			var at_h: float = RISE_CHECKS[next_check][0]
			if minute == roundi(at_h * 60.0):
				var want: StringName = RISE_CHECKS[next_check][1]
				check_eq(h.state(), want, "state at %.2f h after the feed" % at_h)
				next_check += 1
	check_eq(next_check, RISE_CHECKS.size(), "every checkpoint was visited")
	check_eq(mapper_misses, 0, "rule 2: Session visuals equal VisualMapper.from_state at every tick")
	var seen: Array[StringName] = _distinct_states(h)
	seen.push_front(&"freshly_fed")
	check_eq(_dedupe(seen), RISE_ORDER, "state_changed walks the rise phases in order, with no flicker")
	var logged: Array[StringName] = []
	for e: JournalEntry in h.journal_of(&"state_change"):
		if e.at_unix > fed_at:
			logged.append(e.state_id)
	check_eq(logged, RISE_ORDER.slice(1), "the journal logs each change once, in order")
	_check_no_pops(h)


## AC-04.2 through catch-up (V9 via the Session): fed, closed, opened 225 h later. The launch's
## catch-up passes hungry, dormant, unhealthy and moldy at the V9 onsets, the journal keeps each
## change at the time it happened, and the warning comes at least 72 h before mold (L-6, AC-10.10).
func test_ac_04_2_neglect_states_through_catch_up() -> void:
	if not ready_for_integration():
		return
	var h: SliceHarness = mature_phone("neglect", SliceHarness.seed_for_draw(0.5))
	check(h.apply(feed_111()).ok, "the feed is accepted")
	var fed_at: int = h.session.get_starter().sim_time_unix
	h.reopen_at(T0 + 225 * HOUR)
	var r: CatchUpResult = h.session.get_last_catch_up()
	check_eq(r.simulated_s, 225 * HOUR, "225 h simulated")
	var onset: Dictionary[StringName, int] = {}
	for t: Dictionary in r.transitions:
		var to_state: StringName = StringName(String(t.get("to", "")))
		var at: int = t.get("at_unix", 0)
		if not onset.has(to_state):
			onset[to_state] = at
	for state_id: StringName in V9_ONSETS:
		var window: Vector2 = V9_ONSETS[state_id]
		if not check(onset.has(state_id), "%s reached during the catch-up" % state_id):
			continue
		check_between(float(onset[state_id] - fed_at) / HOUR, window.x - TOL_H, window.y + TOL_H,
			"%s onset (h after the feed)" % state_id)
	if onset.has(&"unhealthy") and onset.has(&"moldy"):
		check(onset[&"moldy"] - onset[&"unhealthy"] >= 72 * HOUR, "L-6: warning to mold is at least 72 h at the counter")
	check_eq(h.state(), &"moldy", "moldy at 225 h")
	check(not h.session.get_snapshot().can_feed, "a moldy snapshot says it can't be fed")
	var journaled: Dictionary[StringName, int] = {}
	for e: JournalEntry in h.journal_of(&"state_change"):
		if not journaled.has(e.state_id):
			journaled[e.state_id] = e.at_unix
	for state_id: StringName in V9_ONSETS:
		check_eq(journaled.get(state_id, -1), onset.get(state_id, -2),
			"the journal logs %s at the time it happened" % state_id)


## AC-09.6 and AC-09.5 (sim side): the time-lapse frames for a return to moldy run past the warning
## stage: at most 30 frames, some show the dull warning look with no mold, and only the last ones
## show mold. Mold never appears before the starter is moldy (PROP-16 through Session).
func test_ac_09_6_time_lapse_frames_pass_the_warning_stage() -> void:
	if not ready_for_integration():
		return
	var h: SliceHarness = mature_phone("timelapse_mold", SliceHarness.seed_for_draw(0.5))
	h.apply(feed_111())
	h.reopen_at(T0 + 225 * HOUR)
	var frames: Array[VisualParams] = h.session.get_last_catch_up().snapshots
	check_between(frames.size(), 1, CatchUpResult.MAX_SNAPSHOTS, "time-lapse frame count")
	var warning_frames: int = 0
	var first_mold: int = -1
	var mold_then_clean: bool = false
	for i: int in frames.size():
		var v: VisualParams = frames[i]
		if v.mold > 0.0 and first_mold < 0:
			first_mold = i
		elif v.mold == 0.0 and first_mold >= 0:
			mold_then_clean = true
		if v.mold == 0.0 and v.dullness >= 1.0:
			warning_frames += 1
	check(warning_frames >= 3, "at least 3 frames show the warning stage before mold (got %d)" % warning_frames)
	check(first_mold > 0, "mold appears only after earlier frames (first at %d)" % first_mold)
	check(not mold_then_clean, "mold never disappears again (it is latched)")
	check_eq(frames[frames.size() - 1].to_dict(), h.session.get_visuals().to_dict(),
		"the last frame is the jar the player sees")


## EC-07 and AC-08.5 (sim side): a moldy starter can't be fed or moved, and a refused action changes
## nothing, not even the save file (INT-07). Inspect still works and its surface reading is the
## fuzz. Falling back to save.prev (which still holds the starter from before the absence),
## relaunching and setting the clock back all give moldy again.
func test_ec_07_moldy_stays_moldy_whatever_the_player_tries() -> void:
	if not ready_for_integration():
		return
	var h: SliceHarness = mature_phone("moldy", SliceHarness.seed_for_draw(0.5))
	h.apply(feed_111())
	h.reopen_at(T0 + 225 * HOUR)
	if not check_eq(h.state(), &"moldy", "moldy at 225 h"):
		return
	check(not h.disk_starter(SaveStore.FILE_PREV).moldy, "save.prev still holds the starter from before")
	h.kill()
	var corrupt: PackedByteArray = h.bytes_of(SaveStore.FILE_MAIN)
	corrupt[corrupt.size() - 2] = corrupt[corrupt.size() - 2] ^ 0x01
	QaTemp.write(h.path(SaveStore.FILE_MAIN), corrupt)
	h.launch()
	check_eq(h.quarantined().size(), 1, "the corrupt save.json is quarantined")
	check_eq(h.state(), &"moldy", "save.prev plus a fresh catch-up is moldy again")
	var text_before: String = SliceHarness.payload_text(h.session.build_payload())
	var bytes_before: PackedByteArray = h.bytes_of(SaveStore.FILE_MAIN)
	var feed: ActionResult = h.apply(feed_111())
	check(not feed.ok, "a feed is refused")
	check_eq(feed.reason_key, GameAction.REASON_MOLDY, "with the MOLD_FEED_BLOCKED reason")
	var move: ActionResult = h.apply(SetEnvironmentAction.to_location(&"fridge"))
	check(not move.ok, "a move is refused")
	check_eq(move.reason_key, GameAction.REASON_MOLDY_LOCKED, "with the REASON_MOLDY_LOCKED reason")
	check_eq(SliceHarness.payload_text(h.session.build_payload()), text_before, "refused actions change no state")
	check_eq(h.bytes_of(SaveStore.FILE_MAIN), bytes_before, "refused actions write no save")
	var look: ActionResult = h.apply(InspectAction.new(&"surface"))
	check(look.ok, "inspect still works")
	var readout: InspectionReadout = look.readout as InspectionReadout
	check(readout != null and readout.observations.has(&"fuzzy_spots"), "the surface shows the fuzz")
	check(readout != null and readout.is_warning, "the surface reading is a warning")
	var sniff: ActionResult = h.apply(SmellAction.new())
	var smell: SmellReadout = sniff.readout as SmellReadout
	check(smell != null and smell.primary == &"musty" and smell.secondary.is_empty(),
		"the sim's smell of a moldy starter is musty only (the UI locks Smell, D-043)")
	h.reopen_at(T0 + 226 * HOUR)
	check_eq(h.state(), &"moldy", "still moldy after a relaunch")
	h.reopen_at(T0 + 224 * HOUR - 2 * DAY)
	check(h.session.get_last_catch_up().reanchored, "the clock 2 days back re-anchors")
	check_eq(h.state(), &"moldy", "still moldy with the clock set back")


## EC-25 and INT-06: discarding a moldy starter leaves one memorial and a clean new starter, and a
## kill right after the discard (before any background save) loses neither.
func test_ec_25_discard_survives_a_kill_and_leaves_one_memorial() -> void:
	if not ready_for_integration():
		return
	var h: SliceHarness = mature_phone("discard", SliceHarness.seed_for_draw(0.5))
	h.apply(feed_111())
	h.reopen_at(T0 + 225 * HOUR)
	var old_id: String = h.session.get_starter().id
	var old_entries: int = _entries_of(h, old_id)
	check(not h.apply(DiscardStarterAction.new("   ")).ok, "a blank new name is refused")
	var r: ActionResult = h.apply(DiscardStarterAction.new("Juniper"))
	check(r.ok, "discard is accepted")
	check_eq(r.journal_entry.kind if r.journal_entry != null else &"", &"memorial", "it writes a memorial entry")
	h.kill()
	h.launch()
	var s: StarterState = h.session.get_starter()
	check_ne(s.id, old_id, "a new starter id")
	check_eq(s.name, "Juniper", "the new name")
	check(not s.moldy and h.state() != &"moldy", "the new starter is not moldy")
	check_eq(h.session.get_memorials().size(), 1, "exactly one memorial after the relaunch")
	check_eq(h.journal_of(&"memorial").size(), 1, "exactly one memorial journal entry")
	check(old_entries >= 4, "the old starter had a journal (%d entries)" % old_entries)
	check_eq(_entries_of(h, old_id), old_entries + 1, "the old journal is kept under the old id, plus its memorial")
	var fed: ActionResult = h.apply(feed_111())
	check(fed.ok, "the new starter can be fed")
	check_eq(fed.journal_entry.starter_id if fed.journal_entry != null else "", s.id, "new entries use the new id")


# ------------------------------------------------------------------ helpers

## The snapshot states carried by every state_changed, in order.
func _distinct_states(h: SliceHarness) -> Array[StringName]:
	var out: Array[StringName] = []
	for e: Dictionary in h.heard_of(&"state_changed"):
		var args: Array = e["args"]
		var snap: StarterSnapshot = args[0] as StarterSnapshot
		out.append(snap.state)
	return out


func _entries_of(h: SliceHarness, starter_id: String) -> int:
	var n: int = 0
	for e: JournalEntry in h.session.get_journal():
		if e.starter_id == starter_id:
			n += 1
	return n


static func _dedupe(list: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for s: StringName in list:
		if out.is_empty() or out[out.size() - 1] != s:
			out.append(s)
	return out


## PROP-10 through Session: consecutive state_changed visuals move by at most max_delta, and the
## peak line never drops within the cycle.
func _check_no_pops(h: SliceHarness) -> void:
	var prev: VisualParams = null
	var pops: PackedStringArray = PackedStringArray()
	for e: Dictionary in h.heard_of(&"state_changed"):
		var args: Array = e["args"]
		var v: VisualParams = args[1] as VisualParams
		if prev != null:
			for p: String in pops_between(prev, v):
				pops.append("%s at %s" % [p, hours(int(e["at_unix"]))])
		prev = v
	check(pops.is_empty(), "AC-02.2: no visual pop between ticks: " + ", ".join(pops.slice(0, 8)))
