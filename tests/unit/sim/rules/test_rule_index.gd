extends RulesCase
## RuleIndex (the list T1's EventRules.registry() returns): the catalog's ids, tiers, cooldowns and copy
## keys, and that rules are pure and deterministic (architecture.md §7). Owner: T4.

## id -> [tier, cooldown_s] (events-catalog §2 and §3, game-mechanics §7.4). One-time and per-cycle
## limits are in the rules themselves (per starter or per cycle), so no rule uses the per-save one_time.
const CATALOG: Dictionary = {
	&"mold_found": [&"attention", 0],
	&"warning_signs": [&"attention", 0],
	&"first_rise": [&"info", 0],
	&"peak_now": [&"info", 0],
	&"peaked_while_away": [&"info", 0],
	&"hungry_again": [&"nudge", 12 * 3600],
	&"hooch_forming": [&"info", 24 * 3600],
	&"back_to_strength": [&"info", 24 * 3600],
}

## The copy each event needs (events-catalog §1 and §3, narrative §9 for the mold sheet).
const KEYS: Dictionary = {
	&"first_rise": ["TOAST", "AWAY", "JOURNAL_TITLE", "JOURNAL_BODY"],
	&"peak_now": ["TOAST", "JOURNAL_TITLE", "JOURNAL_BODY"],
	&"peaked_while_away": ["AWAY_SMALL", "AWAY_NEAR", "AWAY_DOUBLE", "AWAY_BIG", "JOURNAL_TITLE", "JOURNAL_BODY"],
	&"hungry_again": ["TITLE", "BODY", "BTN", "DISMISS", "AWAY", "JOURNAL_TITLE", "JOURNAL_BODY"],
	&"hooch_forming": ["TOAST", "AWAY", "JOURNAL_TITLE", "JOURNAL_BODY"],
	&"back_to_strength": ["TOAST", "AWAY", "JOURNAL_TITLE", "JOURNAL_BODY"],
	&"warning_signs": ["TITLE", "BODY", "BTN_FEED", "BTN_LOOK", "OUTCOME_FED", "AWAY_HOURS", "AWAY_DAYS",
		"JOURNAL_TITLE", "JOURNAL_BODY"],
	&"mold_found": ["AWAY", "JOURNAL_TITLE", "JOURNAL_BODY"],
}
const MOLD_SHEET_KEYS: Array[String] = ["MOLD_SHEET_TITLE", "MOLD_SHEET_BODY", "MOLD_CONFIRM_TITLE",
	"MOLD_CONFIRM_BODY", "MOLD_CONFIRM_YES", "MOLD_CONFIRM_NO"]


func test_ids_tiers_and_cooldowns_match_the_catalog() -> void:
	var rules: Array[EventRule] = RuleIndex.all()
	var seen: Dictionary = {}
	for r: EventRule in rules:
		check(CATALOG.has(r.id), "%s is a catalog id" % r.id)
		check(not seen.has(r.id), "%s is listed once" % r.id)
		seen[r.id] = true
		if CATALOG.has(r.id):
			var row: Array = CATALOG[r.id]
			check_eq(r.tier, row[0], "%s tier" % r.id)
			check_eq(r.cooldown_s, row[1], "%s cooldown" % r.id)
		check(not r.one_time, "%s doesn't use the per-save one_time flag" % r.id)
		check(SimConstants.TIERS.has(r.tier), "%s tier is canonical" % r.id)
	check_eq(seen.size(), CATALOG.size(), "all 8 slice rules are listed (D-017)")
	check_eq(rules[0].id, &"mold_found", "attention first: the order is the tie-break")
	check(RuleIndex.all()[0] != rules[0], "each call returns fresh instances")


func test_every_copy_key_exists() -> void:
	var text: String = FileAccess.get_file_as_string("res://src/i18n/en.csv")
	check(not text.is_empty(), "en.csv is readable")
	var keys: Dictionary = {}
	for line: String in text.split("\n"):
		keys[line.get_slice(",", 0)] = true
	for id: StringName in KEYS:
		for part: String in KEYS[id]:
			var key: String = "EVENT_%s_%s" % [String(id).to_upper(), part]
			check(keys.has(key), "%s is in en.csv" % key)
	for key: String in MOLD_SHEET_KEYS:
		check(keys.has(key), "%s is in en.csv" % key)


func test_rules_are_pure_and_deterministic() -> void:
	if not require(&"m5_catchup"):
		return
	# Contexts from real runs at the steps where each rule fires, then every rule evaluated twice.
	var probe: World = new_game(T0 + 7 * H)
	probe.feed()
	probe.away_to(T0 + 7 * H + 10 * DAY)
	var times: Array[int] = []
	for e: SimEvent in probe.events:
		if not times.has(e.created_unix):
			times.append(e.created_unix)
	check(times.size() >= 6, "the probe run fires at %d distinct steps" % times.size())
	var w: World = new_game(T0 + 7 * H)
	w.feed()
	for t: int in times:
		w.away_to(t - SimConstants.GRID_S)
		var prev: StarterState = w.state.copy()
		var prev_d: DerivedState = w.derived()
		w.rules = []
		w.away_to(t)
		w.rules = RuleIndex.all()
		var ctx := EventContext.new()
		ctx.prev_state = prev
		ctx.prev_derived = prev_d
		ctx.state = w.state
		ctx.derived = w.derived()
		ctx.env = w.env
		ctx.history = w.history
		ctx.ledger = w.ledger
		ctx.now_unix = t
		ctx.local_minute_of_day = LocalDay.minute_of_day(t, 0)
		ctx.app_foreground = false
		ctx.catalog = w.catalog
		var before: String = _snapshot(ctx)
		var first: Array = _evaluate_all(ctx)
		var second: Array = _evaluate_all(ctx)
		check(not first.is_empty(), "something fires at %s" % hours(t))
		check_eq(second, first, "same context, same events at %s" % hours(t))
		check_eq(_snapshot(ctx), before, "evaluating changes nothing at %s" % hours(t))
		# Admit what fired, as the engine would, so the next context sees the same ledger as the probe.
		EventRules.process(ctx, w.rules)


func test_payloads_hold_only_primitives_and_round_trip_through_the_ledger() -> void:
	if not require(&"m5_catchup"):
		return
	var w: World = new_game(T0 + 7 * H)
	w.feed()
	w.away_to(T0 + 7 * H + 10 * DAY)
	check(w.events.size() >= 6, "a 10-day neglect raises at least 6 events, got %d" % w.events.size())
	for e: SimEvent in w.events:
		for k: Variant in e.payload:
			check(typeof(k) == TYPE_STRING, "%s payload key %s is a String" % [e.id, str(k)])
			check(typeof(e.payload[k]) in [TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_BOOL],
				"%s payload %s is a primitive" % [e.id, str(k)])
	var text: String = JSON.stringify(w.ledger.to_dict(), "", true, true)
	var back: EventLedger = EventLedger.from_dict(JSON.parse_string(text))
	check(back != null, "the ledger with these events parses back")
	if back != null:
		check_eq(JSON.stringify(back.to_dict(), "", true, true), text, "and round-trips exactly")


static func _evaluate_all(ctx: EventContext) -> Array:
	var out: Array = []
	for r: EventRule in RuleIndex.all():
		var e: SimEvent = r.evaluate(ctx)
		if e != null:
			out.append(JSON.stringify(e.to_dict(), "", true, true))
	return out


static func _snapshot(ctx: EventContext) -> String:
	return JSON.stringify([ctx.prev_state.to_dict(), ctx.state.to_dict(), ctx.env.to_dict(),
		ctx.history.to_dict(), ctx.ledger.to_dict()], "", true, true)
