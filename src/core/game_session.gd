class_name GameSession
extends Node
## Autoload `Session` (architecture.md §3.1). Owns the game state, the clock, the save store and sim_rng.
## The only mutator: UI builds a GameAction and calls apply(). Signatures are frozen from §3.3 and §4.
## Tests never use the autoload: `GameSession.new()` plus `setup(FakeClock.new(), SaveStore.new(dir))`,
## then `boot()`.
##
## Boot is started by Main (`Session.start()`), not by `_ready`, so a `-s` test run never touches
## user://saves, and World and UI have connected their signals before session_ready fires.

## After launch load and catch-up. `summary` may be empty.
signal session_ready(summary: CatchUpResult)
## After returning from the background.
signal resumed(summary: CatchUpResult)
## Every grid step that changes the state, and after every action.
signal state_changed(snapshot: StarterSnapshot, visuals: VisualParams)
## After apply(): ok, or rejected with a reason key.
signal action_applied(result: ActionResult)
## One event released for display.
signal event_raised(event: SimEvent)
## After the journal grows.
signal journal_appended(entry: JournalEntry)
## A save failed; UI shows a calm notice. Fires once per run of failures.
signal save_failed(reason_key: StringName)

const APP_VERSION: String = "0.2.0"
const SAVE_DIR: String = "user://saves"
const FIXTURE_SAVE_DIR: String = "user://fixture_saves"
const AUTOSAVE_INTERVAL_S: int = 600
const SAVE_FAILED_KEY: StringName = &"REASON_SAVE_FAILED"
const NOT_READY_KEY: StringName = &"REASON_NOT_READY"
## Frame cap (architecture.md §11): 60 while interacting, 30 after 3 s with no interaction.
const ACTIVE_FPS: int = 60
const IDLE_FPS: int = 30
const IDLE_AFTER_S: float = 3.0
const PAYLOAD_SECTIONS: Array[String] = [
	"environment", "events", "history", "journal", "memorials", "meta", "rng", "starter",
]


## The decoded payload, before it is applied.
class Parts:
	var starter: StarterState = null
	var env: EnvironmentState = null
	var history: PlayerHistory = PlayerHistory.new()
	var ledger: EventLedger = EventLedger.new()
	var journal: Array[JournalEntry] = []
	var memorials: Array[Memorial] = []
	var meta: SaveMeta = SaveMeta.new()
	var has_rng: bool = false
	var rng_seed: int = 0
	var rng_state: int = 0


var _clock: Clock = null
var _store: SaveStore = null
var _settings: SettingsStore = null
var _catalog: SimCatalog = SimCatalog.builtin()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _rng_seed: int = 0
var _starter: StarterState = StarterState.new()
var _env: EnvironmentState = EnvironmentState.new()
var _history: PlayerHistory = PlayerHistory.new()
var _ledger: EventLedger = EventLedger.new()
var _journal: Array[JournalEntry] = []
var _memorials: Array[Memorial] = []
var _meta: SaveMeta = SaveMeta.new()
var _derived: DerivedState = DerivedState.new()
var _visuals: VisualParams = VisualParams.new()
var _last_summary: CatchUpResult = CatchUpResult.new()
var _journal_uid: int = 0
var _booted: bool = false
var _first_run: bool = false
var _foreground: bool = true
var _session_now: int = 0
var _last_wall: int = 0
var _last_mono_ms: int = 0
var _last_save_wall: int = 0
var _save_failing: bool = false
var _timer: Timer = null
var _idle_timer: Timer = null
var _flags: DevFlags = DevFlags.new()


func _ready() -> void:
	_flags = DevFlags.parse()
	I18nLoader.load_all()
	_wire_bus()


# ------------------------------------------------------------------ lifecycle
## Injects the seams. Tests call this with a FakeClock and a temp SaveStore.
func setup(clock: Clock, store: SaveStore, settings: SettingsStore = null) -> void:
	_clock = clock
	_store = store
	_settings = settings if settings != null else SettingsStore.new()
	if _store.clock == null:
		_store.clock = clock


## The game's entry point, called once by Main. Builds the real seams unless setup() already ran.
func start() -> void:
	if _booted:
		return
	if _clock == null:
		var clock: Clock = SystemClock.new()
		if OS.is_debug_build():
			clock = DebugClock.new(_flags.time_scale)
		var dir: String = FIXTURE_SAVE_DIR if _flags.fixture != "" else SAVE_DIR
		setup(clock, SaveStore.new(dir), SettingsStore.new())
		_settings.load_settings()
	if _flags.fixture != "":
		boot_from_fixture(_flags.fixture)
	else:
		boot()
	_start_timer()
	_on_interaction_ended()


## Launch (architecture.md §6.1): load (or start new), clock rules, catch-up, save, session_ready.
func boot() -> CatchUpResult:
	var now: int = _clock.now_unix()
	var report: SaveLoadReport = _store.load_latest(_is_payload_valid)
	var parts: Parts = _decode_payload(report.payload, false) if report.ok else null
	if parts != null:
		_apply_parts(parts)
		_first_run = false
	else:
		_begin_new_game(now, &"new_game")
		_first_run = report.first_run
		if not report.first_run:
			_meta.recovered_from = "quarantine"
	var summary: CatchUpResult = _sync_to_clock()
	_finish_boot(summary)
	return summary


## Dev and test entry: a full save file or a bare payload, shown as of now (no catch-up). Falls back to
## boot() if the file can't be read.
func boot_from_fixture(path: String) -> CatchUpResult:
	var parts: Parts = _decode_payload(_store.load_from_path(path), true)
	if parts == null:
		push_warning("Fixture not loaded, booting normally: " + path)
		return boot()
	_apply_parts(parts)
	_first_run = false
	var now: int = _clock.now_unix()
	_starter.sim_time_unix = Sim.grid(now)
	_reset_session_clock(now)
	_refresh()
	var summary: CatchUpResult = CatchUpResult.empty(_starter.sim_time_unix)
	_last_summary = summary
	_finish_boot(summary)
	return summary


## One foreground grid tick (the 60 s timer calls it; tests call it directly).
func tick() -> void:
	if not _booted:
		return
	var prev_state: StringName = _derived.state
	var res: CatchUpResult = _live_sync(true)
	_journal_transitions(res)
	if res.steps > 0:
		_emit_state()
	_emit_events(res.events)
	var now: int = _clock.now_unix()
	if _derived.state != prev_state or now - _last_save_wall >= AUTOSAVE_INTERVAL_S:
		_save()


## Backgrounding (APPLICATION_PAUSED, FOCUS_OUT, close): advance to now and save. Idempotent.
func on_background() -> void:
	if not _booted:
		return
	var res: CatchUpResult = _live_sync(true)
	_journal_transitions(res)
	_foreground = false
	_save()


## Returning (APPLICATION_RESUMED): clock rules, catch-up, save, resumed(summary).
func on_resume() -> CatchUpResult:
	if not _booted:
		return CatchUpResult.empty(0)
	_foreground = true
	var summary: CatchUpResult = _sync_to_clock()
	_journal_transitions(summary)
	_save()
	_emit_state()
	resumed.emit(summary)
	_emit_events(summary.events)
	return summary


## Android back with no sheet open (T3 decides): save, then quit.
func save_and_quit() -> void:
	on_background()
	get_tree().quit()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			on_background()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			if _booted and not _foreground:
				on_resume()


# ------------------------------------------------------------------ the action pipeline (architecture §4)
func apply(action: GameAction) -> ActionResult:
	if not _booted:
		var not_ready: ActionResult = ActionResult.rejected(action.kind, NOT_READY_KEY)
		action_applied.emit(not_ready)
		return not_ready
	# 1. sync to grid(now)
	var sync: CatchUpResult = _live_sync(true)
	_journal_transitions(sync)
	action.at_unix = _clock.now_unix()
	# 2. validate
	var reason: StringName = action.validate(_starter, _env, _catalog)
	if reason == &"" and action is AckEventAction:
		var ack_check: AckEventAction = action
		if _ledger.find_pending(ack_check.event_uid) == null:
			reason = GameAction.REASON_EVENT
	if reason != &"":
		var rejected: ActionResult = ActionResult.rejected(action.kind, reason)
		if sync.steps > 0:
			_emit_state()
		_emit_events(sync.events)
		action_applied.emit(rejected)
		return rejected
	# 3. mutate
	var before: StarterState = _starter.copy()
	var derived_before: DerivedState = _derived
	var result: ActionResult = ActionResult.accepted(action.kind)
	var entry: JournalEntry = null
	match action.kind:
		&"feed":
			var feed: FeedAction = action
			Sim.apply_feed(_starter, feed, _rng)
			entry = _feed_entry(feed, before, derived_before)
		&"environment":
			var move: SetEnvironmentAction = action
			var e: EnvironmentState = move.env.copy()
			var row: Array = SimConstants.LOCATIONS[e.location]
			e.humidity_pct = row[1]
			e.changed_unix = _starter.sim_time_unix
			_env = e
			entry = _make_entry(&"environment", StringName("JOURNAL_LOG_MOVE_%s" % Keys.up(e.location)), move.to_dict())
		&"smell":
			var smell: SmellReadout = SmellModel.read(_starter, _env)
			result.readout = smell
			if smell.primary != &"" and not _seen_this_cycle(&"smell", "primary", String(smell.primary)):
				entry = _make_entry(&"smell", &"JOURNAL_LOG_SMELL", {"primary": String(smell.primary)})
				entry.args = {"descriptor": String(smell.primary)}
		&"inspect":
			var inspect: InspectAction = action
			var look: InspectionReadout = Inspection.read(_starter, _env, inspect.inspect_kind)
			result.readout = look
			if not _seen_this_cycle(&"inspect", "text_key", String(look.text_key)):
				entry = _make_entry(&"inspect", look.text_key, {"inspect_kind": String(look.inspect_kind), "text_key": String(look.text_key)})
		&"rename":
			var rename: RenameAction = action
			_starter.name = rename.new_name.strip_edges()
			entry = _make_entry(&"rename", &"", rename.to_dict())
		&"ack_event":
			var ack: AckEventAction = action
			_ledger.remove_pending(ack.event_uid)
		&"discard_starter":
			var discard: DiscardStarterAction = action
			entry = _discard_starter(discard)
	# 4. derive
	_refresh()
	# 5. history
	_history.record_action(action, before, derived_before)
	if result.readout is SmellReadout:
		var sm: SmellReadout = result.readout
		for d: StringName in [sm.primary] + sm.secondary:
			if d != &"":
				_history.smelled_descriptors[d] = true
		if sm.primary != &"":
			_history.record_seen(StringName("smell.%s" % sm.primary))
	elif result.readout is InspectionReadout:
		var ir: InspectionReadout = result.readout
		_history.record_seen(StringName("inspect.%s.level_%d" % [ir.inspect_kind, ir.level]))
	# 6. events
	var rules: Array[EventRule] = EventRules.registry()
	if not rules.is_empty():
		var ctx: EventContext = _context(before, derived_before, action)
		result.events = EventRules.process(ctx, rules)
	# 7. journal
	if entry != null:
		_append_journal(entry)
		result.journal_entry = entry
	# 8. save
	_save()
	# 9. signals
	action_applied.emit(result)
	_emit_state()
	if entry != null:
		journal_appended.emit(entry)
	_emit_events(sync.events)
	_emit_events(result.events)
	return result


## After the B6 demo or its skip: the real save is made from the demo's state (architecture §5.5).
func adopt_starter(state: StarterState, starter_name: String) -> void:
	var now: int = _clock.now_unix()
	_starter = state.copy()
	_starter.name = starter_name.strip_edges()
	if _starter.id == "":
		_starter.id = _new_id()
	_starter.rebase_to(now)
	_history.recent_feed_unix.clear()
	_first_run = false
	_reset_session_clock(now)
	_refresh()
	_save()
	_emit_state()


# ------------------------------------------------------------------ getters (read-only copies)
func is_booted() -> bool:
	return _booted


## No save existed at launch: the UI runs onboarding and the B6 demo, then calls adopt_starter().
func is_first_run() -> bool:
	return _first_run


func get_snapshot() -> StarterSnapshot:
	return StarterSnapshot.make(_starter, _derived, _env)


func get_visuals() -> VisualParams:
	return _visuals.copy()


func get_derived() -> DerivedState:
	return _derived


func get_starter() -> StarterState:
	return _starter.copy()


func get_environment() -> EnvironmentState:
	return _env.copy()


func get_history() -> PlayerHistory:
	return _history.copy()


func get_journal() -> Array[JournalEntry]:
	return _journal.duplicate()


func get_memorials() -> Array[Memorial]:
	return _memorials.duplicate()


func get_pending_events() -> Array[SimEvent]:
	return _ledger.pending.duplicate()


func get_catalog() -> SimCatalog:
	return _catalog


func get_settings() -> SettingsStore:
	return _settings


func get_last_catch_up() -> CatchUpResult:
	return _last_summary


## The current cycle's forecast (status tap during a rise phase).
func get_forecast() -> PeakForecast:
	return Forecast.peak_window(_starter, _env)


## What a feed would do, for the feed sheet's schedule question. Changes nothing.
func forecast_feed(feed: FeedAction) -> PeakForecast:
	return Forecast.peak_window(_starter, _env, feed)


func now_unix() -> int:
	return _clock.now_unix() if _clock != null else 0


func local_utc_offset_s() -> int:
	return _clock.local_utc_offset_s() if _clock != null else 0


## Writes the payload as pretty JSON, for fixtures and bug reports (debug).
func dump_state(path: String) -> Error:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(build_payload(), "\t", true, true))
	f.close()
	return OK


func build_payload() -> Dictionary:
	var journal: Array = []
	for e: JournalEntry in _journal:
		journal.append(e.to_dict())
	var memorials: Array = []
	for m: Memorial in _memorials:
		memorials.append(m.to_dict())
	return {
		"environment": _env.to_dict(),
		"events": _ledger.to_dict(),
		"history": _history.to_dict(),
		"journal": journal,
		"memorials": memorials,
		"meta": _meta.to_dict(),
		"rng": {"sim_seed": str(_rng_seed), "sim_state": str(_rng.state)},
		"starter": _starter.to_dict(),
	}


# ------------------------------------------------------------------ internals
func _finish_boot(summary: CatchUpResult) -> void:
	_booted = true
	_foreground = true
	_journal_transitions(summary)
	_save()
	_emit_state()
	session_ready.emit(summary)
	_emit_events(summary.events)


## Launch and resume: TimePolicy, then catch-up (app in the background for the whole window).
func _sync_to_clock() -> CatchUpResult:
	var now: int = _clock.now_unix()
	var decision: TimeResolution = TimePolicy.resolve(_starter.sim_time_unix, now)
	var summary: CatchUpResult
	if decision.action == &"reanchor":
		summary = CatchUpResult.empty(_starter.sim_time_unix)
		_starter.sim_time_unix = decision.target_unix
		summary.to_unix = decision.target_unix
		summary.reanchored = true
		_meta.clock_reanchors += 1
	elif decision.action == &"hold":
		summary = CatchUpResult.empty(_starter.sim_time_unix)
	else:
		summary = CatchUp.run(_starter, _env, _history, _ledger, _catalog, now, _clock.local_utc_offset_s(), false)
	_reset_session_clock(now)
	_refresh()
	_last_summary = summary
	return summary


## In session: advance by the guarded elapsed time (architecture §5.3, last row).
func _live_sync(foreground: bool) -> CatchUpResult:
	var now: int = _clock.now_unix()
	var mono: int = _clock.monotonic_msec()
	@warning_ignore("integer_division")
	var mono_delta_s: int = (mono - _last_mono_ms) / 1000
	var elapsed: int = TimePolicy.foreground_elapsed_s(now - _last_wall, mono_delta_s)
	_session_now += maxi(elapsed, 0)
	_last_wall = now
	_last_mono_ms += mono_delta_s * 1000
	var res: CatchUpResult = CatchUp.run(_starter, _env, _history, _ledger, _catalog, _session_now,
		_clock.local_utc_offset_s(), foreground)
	_refresh()
	return res


func _reset_session_clock(now: int) -> void:
	_session_now = now
	_last_wall = now
	_last_mono_ms = _clock.monotonic_msec()


func _refresh() -> void:
	_derived = StateDeriver.derive(_starter, _env)
	_visuals = VisualMapper.from_derived(_starter, _env, _derived)


func _emit_state() -> void:
	state_changed.emit(get_snapshot(), _visuals.copy())


func _emit_events(events: Array[SimEvent]) -> void:
	for e: SimEvent in events:
		var entry: JournalEntry = _make_entry(&"event", StringName("EVENT_%s_JOURNAL_TITLE" % Keys.up(e.id)),
			{"event_id": String(e.id), "event_uid": e.uid})
		entry.at_unix = e.created_unix
		_append_journal(entry)
		journal_appended.emit(entry)
		event_raised.emit(e)


func _context(prev: StarterState, prev_derived: DerivedState, action: GameAction) -> EventContext:
	var ctx := EventContext.new()
	ctx.prev_state = prev
	ctx.prev_derived = prev_derived
	ctx.state = _starter
	ctx.derived = _derived
	ctx.env = _env
	ctx.history = _history
	ctx.ledger = _ledger
	ctx.now_unix = _starter.sim_time_unix
	ctx.utc_offset_s = _clock.local_utc_offset_s()
	ctx.local_minute_of_day = LocalDay.minute_of_day(_starter.sim_time_unix, ctx.utc_offset_s)
	ctx.app_foreground = _foreground
	ctx.last_action = action
	ctx.catalog = _catalog
	return ctx


func _save() -> Error:
	if _store == null:
		return ERR_UNCONFIGURED
	var now: int = _clock.now_unix()
	_meta.save_count += 1
	_meta.saved_unix = now
	_meta.app_version = APP_VERSION
	var err: Error = _store.save(build_payload())
	if err != OK:
		_meta.save_count -= 1
		if not _save_failing:
			save_failed.emit(SAVE_FAILED_KEY)
		_save_failing = true
	else:
		_save_failing = false
		_last_save_wall = now
	return err


func _begin_new_game(now: int, preset: StringName) -> void:
	_starter = StarterPresets.make(preset, now)
	_starter.id = _new_id()
	_env = StarterPresets.environment_for(preset, now)
	_history = PlayerHistory.new()
	_ledger = EventLedger.new()
	_journal.clear()
	_memorials.clear()
	_journal_uid = 0
	_meta = SaveMeta.new()
	_meta.created_unix = now
	_meta.app_version = APP_VERSION
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(8)
	_rng_seed = bytes.decode_s64(0)
	_rng = RandomNumberGenerator.new()
	_rng.seed = _rng_seed
	_reset_session_clock(now)
	_refresh()


func _discard_starter(action: DiscardStarterAction) -> JournalEntry:
	var now: int = action.at_unix
	var m := Memorial.new()
	m.starter_id = _starter.id
	m.name = _starter.name
	m.born_unix = _starter.born_unix
	m.ended_unix = now
	m.cause = &"mold"
	for e: JournalEntry in _journal:
		if e.starter_id == _starter.id and e.kind == &"feed":
			m.feeds_count += 1
	var entry: JournalEntry = _make_entry(&"memorial", &"MEMORIAL_TITLE", m.to_dict())
	var preset: StringName = &"first_restart" if _memorials.is_empty() else &"restart"
	_memorials.append(m)
	_starter = StarterPresets.make(preset, now)
	_starter.id = _new_id()
	_starter.name = action.new_name.strip_edges()
	_env = StarterPresets.environment_for(preset, now)
	_history.consecutive_early_feeds = 0
	_history.last_strong_peak_rise = 0.0
	_history.recent_feed_unix.clear()
	return entry


func _feed_entry(feed: FeedAction, before: StarterState, derived_before: DerivedState) -> JournalEntry:
	var timing: StringName = PlayerHistory.feed_timing_class(derived_before)
	var key: StringName = &"JOURNAL_LOG_FEED"
	if timing == &"on_time":
		key = &"JOURNAL_LOG_FEED_AT_PEAK"
	elif timing == &"rescue":
		key = &"JOURNAL_LOG_FEED_RESCUE"
	var data: Dictionary = feed.to_dict()
	data["timing"] = String(timing)
	data["had_hooch"] = before.hooch >= CatchUp.HOOCH_VISIBLE
	data["feed_u"] = _starter.feed_u
	var entry: JournalEntry = _make_entry(&"feed", key, data)
	var r: Vector2 = feed.ratio()
	entry.args = {"ratio": "1:%d:%d" % [roundi(r.x), roundi(r.y)], "flour_g": roundi(feed.flour_total_g())}
	return entry


func _make_entry(kind: StringName, key: StringName, data: Dictionary) -> JournalEntry:
	var e := JournalEntry.new()
	_journal_uid += 1
	e.uid = _journal_uid
	e.starter_id = _starter.id
	e.at_unix = _clock.now_unix()
	e.kind = kind
	e.state_id = _derived.state
	e.text_key = key
	e.data = data
	return e


func _append_journal(entry: JournalEntry) -> void:
	JournalEntry.append_capped(_journal, entry)


func _journal_transitions(res: CatchUpResult) -> void:
	for t: Dictionary in res.transitions:
		var to_state: String = t.get("to", "")
		var at: int = t.get("at_unix", 0)
		var e: JournalEntry = _make_entry(&"state_change", Keys.status_word(StringName(to_state)), t.duplicate())
		e.at_unix = at
		e.state_id = StringName(to_state)
		_append_journal(e)


## Smell and inspect journal at most once per value per rise cycle (game-mechanics §4).
func _seen_this_cycle(kind: StringName, field: String, value: String) -> bool:
	for i: int in range(_journal.size() - 1, -1, -1):
		var e: JournalEntry = _journal[i]
		if e.starter_id != _starter.id or e.kind == &"feed":
			return false
		if e.kind == kind and str(e.data.get(field, "")) == value:
			return true
	return false


func _new_id() -> String:
	return Crypto.new().generate_random_bytes(8).hex_encode()


func _is_payload_valid(payload: Dictionary) -> bool:
	return _decode_payload(payload, false) != null


## Strict for saves (every section required). Lenient for fixtures: only starter and environment are
## required, the rest default.
func _decode_payload(p: Dictionary, lenient: bool) -> Parts:
	if p.is_empty():
		return null
	var r := DictReader.new(p)
	if not lenient:
		for section: String in PAYLOAD_SECTIONS:
			if not p.has(section):
				return null
	var parts := Parts.new()
	parts.starter = StarterState.from_dict(r.dict("starter"))
	parts.env = EnvironmentState.from_dict(r.dict("environment"))
	if parts.starter == null or parts.env == null or not r.ok:
		return null
	if p.has("history"):
		parts.history = PlayerHistory.from_dict(r.dict("history"))
	if p.has("events"):
		parts.ledger = EventLedger.from_dict(r.dict("events"))
	if p.has("meta"):
		parts.meta = SaveMeta.from_dict(r.dict("meta"))
	if parts.history == null or parts.ledger == null or parts.meta == null:
		return null
	if p.has("journal"):
		for item: Variant in r.list("journal"):
			if typeof(item) != TYPE_DICTIONARY:
				return null
			var e: JournalEntry = JournalEntry.from_dict(item)
			if e == null:
				return null
			parts.journal.append(e)
	if p.has("memorials"):
		for item: Variant in r.list("memorials"):
			if typeof(item) != TYPE_DICTIONARY:
				return null
			var m: Memorial = Memorial.from_dict(item)
			if m == null:
				return null
			parts.memorials.append(m)
	if p.has("rng"):
		var rr := DictReader.new(r.dict("rng"))
		var seed_text: String = rr.text("sim_seed")
		var state_text: String = rr.text("sim_state")
		if not rr.ok or not seed_text.is_valid_int() or not state_text.is_valid_int():
			return null
		parts.has_rng = true
		parts.rng_seed = seed_text.to_int()
		parts.rng_state = state_text.to_int()
	if not r.ok:
		return null
	return parts


func _apply_parts(parts: Parts) -> void:
	_starter = parts.starter
	_env = parts.env
	_history = parts.history
	_ledger = parts.ledger
	_journal = parts.journal
	_memorials = parts.memorials
	_meta = parts.meta
	_journal_uid = 0
	for e: JournalEntry in _journal:
		_journal_uid = maxi(_journal_uid, e.uid)
	_rng = RandomNumberGenerator.new()
	if parts.has_rng:
		_rng_seed = parts.rng_seed
		_rng.seed = parts.rng_seed
		# Never set seed after state: that resets the stream (architecture §6.1).
		_rng.state = parts.rng_state
	else:
		var bytes: PackedByteArray = Crypto.new().generate_random_bytes(8)
		_rng_seed = bytes.decode_s64(0)
		_rng.seed = _rng_seed
	_refresh()


func _start_timer() -> void:
	if _timer != null:
		return
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer)
	add_child(_timer)
	_schedule_timer()


func _schedule_timer() -> void:
	var secs: float = float(SimConstants.GRID_S - posmod(_clock.now_unix(), SimConstants.GRID_S))
	if _clock is DebugClock:
		var dc: DebugClock = _clock
		secs /= maxf(dc.get_time_scale(), 0.001)
	_timer.start(maxf(secs + 0.05, 0.05))


func _on_timer() -> void:
	tick()
	_schedule_timer()


## The autoload listens to Bus for the frame cap. A poke (starter_tapped) never changes the sim.
func _wire_bus() -> void:
	var bus: Node = get_node_or_null("/root/Bus")
	if bus == null:
		return
	bus.connect(&"interaction_started", _on_interaction_started)
	bus.connect(&"interaction_ended", _on_interaction_ended)


func _on_interaction_started() -> void:
	Engine.max_fps = ACTIVE_FPS
	if _idle_timer != null:
		_idle_timer.stop()


func _on_interaction_ended() -> void:
	if _idle_timer == null:
		_idle_timer = Timer.new()
		_idle_timer.one_shot = true
		_idle_timer.timeout.connect(_on_idle)
		add_child(_idle_timer)
	if _idle_timer.is_inside_tree():
		_idle_timer.start(IDLE_AFTER_S)


func _on_idle() -> void:
	Engine.max_fps = IDLE_FPS
