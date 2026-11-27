class_name GameSession
extends Node
## Autoload `Session` (architecture.md §3.1). Owns the game state, the clock, the save store and sim_rng.
## The only mutator: UI builds a GameAction and calls apply(). Signatures are frozen from §3.3 and §4.
## Tests never use the autoload: `GameSession.new()` plus `setup(FakeClock.new(), SaveStore.new(dir))`,
## then `boot()`.
##
## Boot is started by Main (`Session.start()`), not by `_ready`, so a `-s` test run never touches
## user://saves, and World and UI have connected their signals before session_ready fires.
##
## Phase 3 call sequences for T3:
## - Launch: session_ready(result). If is_first_run(): M.'s note, then naming with name_suggestion_key(),
##   then apply(AdoptStarterAction.new(name, &"skip")), then the first feed (Day one goes to the journal).
##   Otherwise read get_return_summary(): when it shows, play the time-lapse (result.keyframes, if
##   result.play_time_lapse), then the summary card, then the prompt. resumed(result) works the same way.
## - Events: event_raised(event) fires once per run for each event when it is due. event.presentation() says
##   toast, card or sheet. Cards and sheets stay pending until apply(AckEventAction.new(uid, choice)).
##   Toasts need no acknowledgement. event_withdrawn(uid) means a raised card went stale: hide it.
## - Feed sheet: plan_feed(answer, flour, hooch) or preview_feed(last_feed_action()), then
##   apply(preview.action).
## - Mold: the mold_found sheet, confirm, then preview_memorial() and restart_preset() for the memorial and
##   restart pages, then naming, then apply(DiscardStarterAction.new(name)): memorial plus new starter at once.

## After launch load and catch-up. `summary` may be empty. Read get_return_summary() in the handler.
signal session_ready(summary: CatchUpResult)
## After returning from the background. Read get_return_summary() in the handler.
signal resumed(summary: CatchUpResult)
## Every grid step that changes the state, and after every action.
signal state_changed(snapshot: StarterSnapshot, visuals: VisualParams)
## After apply(): ok, or rejected with a reason key.
signal action_applied(result: ActionResult)
## One event released for display: once per run, when due (quiet-hours nudges wait until 08:00).
signal event_raised(event: SimEvent)
## A raised event went stale before it was acknowledged (for example hungry_again after a feed). Hide it.
signal event_withdrawn(uid: int)
## After the journal grows.
signal journal_appended(entry: JournalEntry)
## A save failed; UI shows a calm notice. Fires once per run of failures.
signal save_failed(reason_key: StringName)

const APP_VERSION: String = "0.2.0"
const SAVE_DIR: String = "user://saves"
const FIXTURE_SAVE_DIR: String = "user://fixture_saves"
## Debug time travel saves go to `<save dir>` plus this suffix, never to the real save (see
## set_debug_time_scale()).
const TIME_TRAVEL_SUFFIX: String = "_time_travel"
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
## D-042 fallback, in use since the slice rules landed: in the real app, a launch or resume catch-up of at
## least this many steps (2 h) runs on a WorkerThreadPool thread. A 14-day catch-up with the 8 slice rules took
## a median 259 ms on the Mac (estimate), over the 250 ms budget, and a phone is slower. Shorter ones take a
## few milliseconds and stay on the main thread.
const ASYNC_MIN_STEPS: int = 120


## A launch or resume catch-up running on a worker thread. It works on copies of the starter, environment,
## history and ledger; the main thread swaps them in once the task completes (architecture §11). CatchUp is
## pure, so no locks are needed.
class CatchUpJob:
	var kind: StringName = &"boot"
	var first_launch: bool = false
	var starter: StarterState = null
	var env: EnvironmentState = null
	var history: PlayerHistory = null
	var ledger: EventLedger = null
	var catalog: SimCatalog = null
	var to_unix: int = 0
	var utc_offset_s: int = 0
	var mono_ms: int = 0
	var result: CatchUpResult = null

	func run() -> void:
		result = CatchUp.run(starter, env, history, ledger, catalog, to_unix, utc_offset_s, false)


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
var _return: ReturnSummary = ReturnSummary.new()
var _journal_uid: int = 0
var _booted: bool = false
var _foreground: bool = true
var _session_now: int = 0
var _last_wall: int = 0
var _last_mono_ms: int = 0
var _last_save_wall: int = 0
var _save_failing: bool = false
var _time_travel: bool = false
var _recovered_this_launch: bool = false
## Event uids already raised this run (not saved: a relaunch raises pending cards and sheets again).
var _released: Dictionary[int, bool] = {}
var _to_raise: Array[SimEvent] = []
var _to_withdraw: Array[int] = []
var _job: CatchUpJob = null
var _job_id: int = -1
## The real app (start() and the resume notifications) catches up on a worker thread. Tests call boot() and
## on_resume(), which stay synchronous, or boot_async() plus wait_for_catch_up().
var async_catch_up: bool = true
var _timer: Timer = null
var _idle_timer: Timer = null
var _flags: DevFlags = DevFlags.new()


func _ready() -> void:
	_flags = DevFlags.parse()
	I18nLoader.load_all()
	_wire_bus()


## Polls the worker-thread catch-up while one runs. With no job it switches itself off, so the order of
## _ready() and boot_async() doesn't matter.
func _process(_delta: float) -> void:
	if _job == null:
		set_process(false)
	elif WorkerThreadPool.is_task_completed(_job_id):
		_finish_job()


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
		# A launch with --time-scale runs in the time-travel sandbox from the start, so scaled time never
		# reaches the real save (debug builds only; DevFlags is empty in release builds).
		if _flags.fixture == "" and not is_equal_approx(_flags.time_scale, 1.0):
			dir += TIME_TRAVEL_SUFFIX
			_time_travel = true
		setup(clock, SaveStore.new(dir), SettingsStore.new())
		_settings.load_settings()
	if _flags.fixture != "":
		boot_from_fixture(_flags.fixture)
	elif async_catch_up:
		boot_async()
	else:
		boot()
	_start_timer()
	_on_interaction_ended()


## Launch (architecture.md §6.1): load (or start new), clock rules, catch-up, save, session_ready.
## Synchronous: tests use it. The real app uses boot_async().
func boot() -> CatchUpResult:
	var first_launch: bool = _load_or_new()
	var summary: CatchUpResult = _sync_to_clock()
	_finish_boot(summary, first_launch)
	return summary


## The real app's launch (D-042): loads the save and shows it at once (state_changed with the saved state),
## then runs a long catch-up on a worker thread. Until it finishes, is_booted() is false and apply() refuses
## with REASON_NOT_READY; then everything continues exactly as boot() (same result, same signals, ending in
## session_ready). A short catch-up (under 2 h) just runs boot()'s way. wait_for_catch_up() blocks until done.
func boot_async() -> void:
	if _job != null:
		return
	var first_launch: bool = _load_or_new()
	if not _start_job(&"boot", first_launch):
		_finish_boot(_sync_to_clock(), first_launch)


## Coming back from the background in the real app: like on_resume(), with a long catch-up on a worker thread.
## While it runs, apply() refuses with REASON_NOT_READY and the jar keeps showing the state from before.
func resume_async() -> void:
	if not _booted or _job != null:
		return
	_foreground = true
	if not _start_job(&"resume", false):
		_finish_resume(_sync_to_clock())


## True while a worker-thread catch-up runs.
func is_catching_up() -> bool:
	return _job != null


## Blocks until a running worker-thread catch-up is done and applied (tests, and before a background save).
func wait_for_catch_up() -> void:
	if _job != null:
		_finish_job()


## Dev and test entry: a full save file or a bare payload, shown as of now (no catch-up). Falls back to
## boot() if the file can't be read.
func boot_from_fixture(path: String) -> CatchUpResult:
	var parts: Parts = _decode_payload(_store.load_from_path(path), true)
	if parts == null:
		push_warning("Fixture not loaded, booting normally: " + path)
		return boot()
	_apply_parts(parts)
	var now: int = _clock.now_unix()
	_starter.sim_time_unix = Sim.grid(now)
	_reset_session_clock(now)
	_refresh()
	var summary: CatchUpResult = CatchUpResult.empty(_starter.sim_time_unix)
	_last_summary = summary
	_finish_boot(summary, false)
	return summary


## One foreground grid tick (the 60 s timer calls it; tests call it directly).
func tick() -> void:
	if not _booted or _job != null:
		return
	var prev_state: StringName = _derived.state
	var res: CatchUpResult = _live_sync(true)
	_journal_transitions(res)
	var entries: Array[JournalEntry] = _record_events(res.events)
	var ledger_changed: bool = _collect_releases() or not res.events.is_empty()
	var now: int = _clock.now_unix()
	if _derived.state != prev_state or ledger_changed or now - _last_save_wall >= AUTOSAVE_INTERVAL_S:
		_save()
	if res.steps > 0:
		_emit_state()
	_emit_entries(entries)
	_emit_releases()


## Backgrounding (APPLICATION_PAUSED, FOCUS_OUT, close): advance to now and save. Idempotent.
## A worker-thread catch-up still running is finished first, so the save holds it.
func on_background() -> void:
	wait_for_catch_up()
	if not _booted:
		return
	var res: CatchUpResult = _live_sync(true)
	_journal_transitions(res)
	_record_events(res.events)
	_foreground = false
	_save()


## Returning (APPLICATION_RESUMED): clock rules, catch-up, save, resumed(summary). Synchronous: tests and
## debug_advance() use it. The real app uses resume_async().
func on_resume() -> CatchUpResult:
	wait_for_catch_up()
	if not _booted:
		return CatchUpResult.empty(0)
	_foreground = true
	var summary: CatchUpResult = _sync_to_clock()
	_finish_resume(summary)
	return summary


func _finish_resume(summary: CatchUpResult) -> void:
	_journal_transitions(summary)
	var entries: Array[JournalEntry] = _record_events(summary.events)
	_prepare_return(summary, false)
	_collect_releases()
	_save()
	_emit_state()
	resumed.emit(summary)
	_emit_entries(entries)
	_emit_releases()


## Android back with no sheet open (T3 decides): save, then quit.
func save_and_quit() -> void:
	on_background()
	get_tree().quit()


## Debug builds only (tests and the dev overlay): saves, stops the timers and drops every seam and all game
## state, so setup() and start() (or boot()) can run again in the same process. Does nothing in release.
func shutdown() -> void:
	if not OS.is_debug_build():
		return
	wait_for_catch_up()
	if _booted:
		on_background()
	for t: Timer in [_timer, _idle_timer]:
		if t != null:
			t.stop()
			if t.is_inside_tree():
				remove_child(t)
			t.free()
	_timer = null
	_idle_timer = null
	_clock = null
	_store = null
	_settings = null
	_booted = false
	_foreground = true
	_time_travel = false
	_recovered_this_launch = false
	_released.clear()
	_to_raise.clear()
	_to_withdraw.clear()
	_starter = StarterState.new()
	_env = EnvironmentState.new()
	_history = PlayerHistory.new()
	_ledger = EventLedger.new()
	_journal = []
	_memorials = []
	_meta = SaveMeta.new()
	_last_summary = CatchUpResult.new()
	_return = ReturnSummary.new()
	_journal_uid = 0
	_refresh()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			on_background()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			if _booted and not _foreground:
				if async_catch_up:
					resume_async()
				else:
					on_resume()


# ------------------------------------------------------------------ the action pipeline (architecture §4)
func apply(action: GameAction) -> ActionResult:
	if not _booted or _job != null:
		var not_ready: ActionResult = ActionResult.rejected(action.kind, NOT_READY_KEY)
		action_applied.emit(not_ready)
		return not_ready
	# 1. sync to grid(now)
	var sync: CatchUpResult = _live_sync(true)
	_journal_transitions(sync)
	var sync_entries: Array[JournalEntry] = _record_events(sync.events)
	action.at_unix = _clock.now_unix()
	# 2. validate
	var reason: StringName = action.validate(_starter, _env, _catalog)
	if reason == &"" and action is AckEventAction:
		var ack_check: AckEventAction = action
		if _ledger.find_pending(ack_check.event_uid) == null:
			reason = GameAction.REASON_EVENT
	if reason != &"":
		var rejected: ActionResult = ActionResult.rejected(action.kind, reason)
		_collect_releases()
		if sync.steps > 0:
			_emit_state()
		_emit_entries(sync_entries)
		action_applied.emit(rejected)
		_emit_releases()
		return rejected
	# 3. mutate
	var before: StarterState = _starter.copy()
	var derived_before: DerivedState = _derived
	var env_before: EnvironmentState = _env
	var result: ActionResult = ActionResult.accepted(action.kind)
	var entries: Array[JournalEntry] = []
	var main_entry: JournalEntry = null
	match action.kind:
		&"feed":
			var feed: FeedAction = action
			_note_routine_hint(feed, before)
			Sim.apply_feed(_starter, feed, _rng)
			if before.hooch >= CatchUp.HOOCH_VISIBLE:
				var poured: bool = feed.hooch_choice != &"stir_in"
				entries.append(_make_entry(&"hooch",
					&"JOURNAL_LOG_HOOCH_POURED" if poured else &"JOURNAL_LOG_HOOCH_STIRRED",
					{"hooch_choice": String(feed.hooch_choice), "hooch": before.hooch}))
			main_entry = _feed_entry(feed, before, derived_before)
		&"environment":
			var move: SetEnvironmentAction = action
			var e: EnvironmentState = move.env.copy()
			var row: Array = SimConstants.LOCATIONS[e.location]
			e.humidity_pct = row[1]
			e.changed_unix = _starter.sim_time_unix
			_env = e
			main_entry = _make_entry(&"environment", StringName("JOURNAL_LOG_MOVE_%s" % Keys.up(e.location)),
				move.to_dict())
		&"smell":
			var smell: SmellReadout = SmellModel.read(_starter, _env)
			result.readout = smell
			if smell.primary != &"" and not _seen_this_cycle(&"smell", "primary", String(smell.primary)):
				main_entry = _make_entry(&"smell", &"JOURNAL_LOG_SMELL", {"primary": String(smell.primary)})
				main_entry.args = {"smell": String(Keys.smell(smell.primary, "TITLE"))}
		&"inspect":
			var inspect: InspectAction = action
			var look: InspectionReadout = Inspection.read(_starter, _env, inspect.inspect_kind)
			result.readout = look
			if not _seen_this_cycle(&"inspect", "text_key", String(look.text_key)):
				main_entry = _make_entry(&"inspect", look.text_key,
					{"inspect_kind": String(look.inspect_kind), "text_key": String(look.text_key)})
		&"rename":
			var rename: RenameAction = action
			_starter.name = rename.new_name.strip_edges()
			main_entry = _make_entry(&"rename", &"JOURNAL_LOG_RENAME", rename.to_dict())
			main_entry.args = {"name": _starter.name}
		&"ack_event":
			var ack: AckEventAction = action
			_ledger.remove_pending(ack.event_uid)
		&"discard_starter":
			var discard: DiscardStarterAction = action
			main_entry = _discard_starter(discard)
		&"adopt":
			var adopt: AdoptStarterAction = action
			_adopt(StarterPresets.make(&"new_game", action.at_unix), adopt.starter_name, adopt.path)
	# 4. derive
	_refresh()
	# 5. history
	_history.record_action(action, before, derived_before, env_before)
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
	# A fridge move that fires off_to_nap is told by the event's own journal entry (game-copy §11).
	if main_entry != null and main_entry.kind == &"environment":
		for e: SimEvent in result.events:
			if e.id == &"off_to_nap":
				main_entry = null
				break
	# 7. journal
	if main_entry != null:
		entries.append(main_entry)
		result.journal_entry = main_entry
	if action.kind == &"feed" and not _history.onboarding_path.is_empty():
		entries.append(_day_one_entry())
	for entry: JournalEntry in entries:
		_append_journal(entry)
	var event_entries: Array[JournalEntry] = _record_events(result.events)
	_collect_releases()
	# 8. save
	_save()
	# 9. signals
	action_applied.emit(result)
	_emit_state()
	_emit_entries(entries)
	_emit_entries(sync_entries)
	_emit_entries(event_entries)
	_emit_releases()
	return result


## After the B6 demo (Phase 4): the real save is made from the demo's state (architecture §5.5). The slice
## names the gifted starter with apply(AdoptStarterAction) instead.
func adopt_starter(state: StarterState, starter_name: String) -> void:
	_adopt(state, starter_name, &"tour")
	_refresh()
	_save()
	_emit_state()


# ------------------------------------------------------------------ getters (read-only copies)
func is_booted() -> bool:
	return _booted


## The new-game start is still to do: the gifted starter has no name yet (M.'s note, then naming, then
## AdoptStarterAction). True on the first launch, and again after a kill before naming finished.
func is_first_run() -> bool:
	return _starter.name.strip_edges().is_empty()


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


## The journal in uid order, which is the order things were written. Show it in this order: at_unix can run
## backwards across a clock hold or re-anchor (architecture §5.3), so never sort by it.
func get_journal() -> Array[JournalEntry]:
	return _journal.duplicate()


## This launch found saves but none could be read, so a new game began (D-024 quarantine). The UI shows a
## calm notice once; is_first_run() is also true, so the new-game start names the new starter.
func recovered_this_launch() -> bool:
	return _recovered_this_launch


func get_memorials() -> Array[Memorial]:
	return _memorials.duplicate()


## Every event still waiting (cards and sheets until acknowledged, deferred nudges), oldest first.
func get_pending_events() -> Array[SimEvent]:
	return _ledger.pending.duplicate()


func get_catalog() -> SimCatalog:
	return _catalog


func get_settings() -> SettingsStore:
	return _settings


## UI changes get_settings()'s fields, then calls this: writes settings.cfg and emits Bus.settings_changed.
func save_settings() -> Error:
	if _settings == null:
		return ERR_UNCONFIGURED
	var err: Error = _settings.save_settings()
	var bus: Node = get_node_or_null("/root/Bus") if is_inside_tree() else null
	if bus != null:
		bus.emit_signal(&"settings_changed")
	return err


func get_last_catch_up() -> CatchUpResult:
	return _last_summary


## The "while you were away" selection for the latest launch or resume. Built before session_ready and
## resumed fire. `first_launch` is true on the very first launch.
func get_return_summary() -> ReturnSummary:
	return _return


## The current cycle's forecast (status tap during a rise phase).
func get_forecast() -> PeakForecast:
	return Forecast.peak_window(_starter, _env)


## WINDOW_* for the status tap's FORECAST_LINE, or &"" when there is no forecast (hungry, dormant...).
func get_forecast_window_key() -> StringName:
	return ForecastWindow.for_forecast(get_forecast(), _starter.sim_time_unix, now_unix(), local_utc_offset_s())


## What a feed would do, for the feed sheet's schedule question. Changes nothing.
func forecast_feed(feed: FeedAction) -> PeakForecast:
	return Forecast.peak_window(_starter, _env, feed)


## The feed sheet for a schedule answer (&"soon", &"later", &"tomorrow"): the preset that fits, its grams,
## discard, forecast words, notes and hooch step. Changes nothing. Runs up to 3 forecasts (about 40 ms).
func plan_feed(answer: StringName, flour_id: StringName, hooch_choice: StringName = &"pour_off") -> FeedPreview:
	return FeedPlanner.plan(_starter, _env, _history, answer, flour_id, hooch_choice, now_unix(),
		local_utc_offset_s())


## The same preview for a feed the UI already has (an exact preset, or last_feed_action()). Changes nothing.
func preview_feed(feed: FeedAction, answer: StringName = &"") -> FeedPreview:
	return FeedPlanner.preview(_starter, _env, _history, feed, answer, now_unix(), local_utc_offset_s())


## "Feed like last time" (AC-05.3): a new FeedAction equal to the last accepted feed field by field, or
## 1:1:1 white_bread with Pour off before the first feed. Apply it as is for the 2-tap path.
func last_feed_action() -> FeedAction:
	var last: FeedAction = FeedAction.from_dict(_history.last_feed) if not _history.last_feed.is_empty() else null
	return last if last != null else FeedAction.from_ratio(1.0, 1.0, &"white_bread")


## The memorial page before the discard is committed (the starter must be moldy, else null). The same
## numbers DiscardStarterAction will record.
func preview_memorial() -> Memorial:
	if not _starter.moldy:
		return null
	return _build_memorial(_clock.now_unix())


## Which start the next discard gives: &"first_restart" (M.'s spare, RESTART_BODY_FIRST) or &"restart"
## (a friend's spoonful, RESTART_BODY_LATER). Read it before applying DiscardStarterAction.
func restart_preset() -> StringName:
	return &"first_restart" if _memorials.is_empty() else &"restart"


## The current starter's `starter_seed` (game-copy §1.4).
func starter_seed() -> int:
	return StarterState.seed_of(_starter.id)


## The name field's suggestion after `presses` taps on "Suggest another" (narrative §6.1): NAME_SUGGEST_NN.
func name_suggestion_key(presses: int) -> StringName:
	return Keys.name_suggestion(starter_seed(), presses)


## The shared night fade (D-043) for the session's "now": 0 day, 1 night. Follows the debug time scale.
func get_night_factor() -> float:
	return NightFade.at_unix(float(now_unix()), local_utc_offset_s())


## Keys.format() with the device's UTC offset, so {time} and dates read in local time.
func format_text(text_key: StringName, args: Dictionary = {}) -> String:
	return Keys.format(text_key, args, local_utc_offset_s())


func now_unix() -> int:
	return _clock.now_unix() if _clock != null else 0


func local_utc_offset_s() -> int:
	return _clock.local_utc_offset_s() if _clock != null else 0


# ------------------------------------------------------------------ debug time (dev overlay, debug builds)
## Debug builds only: runs sim time `scale` times faster, so mold_found and the memorial are reachable in one
## sitting. Returns false (and does nothing) in release builds, where no DebugClock exists.
## The first time travel saves the real state one last time at real time, then moves every later save to a
## sandbox (`<save dir>_time_travel`) for the rest of the run, so a scaled timestamp never reaches the real
## save. The next normal launch loads the real save and catches up as usual.
func set_debug_time_scale(scale: float) -> bool:
	wait_for_catch_up()
	if not _booted or not (_clock is DebugClock):
		return false
	var dc: DebugClock = _clock
	if not is_equal_approx(scale, 1.0):
		_enter_time_travel()
	dc.set_time_scale(scale)
	if _timer != null and _timer.is_inside_tree():
		_schedule_timer()
	return true


func get_debug_time_scale() -> float:
	if _clock is DebugClock:
		var dc: DebugClock = _clock
		return dc.get_time_scale()
	return 1.0


## Debug builds only: jumps `seconds` ahead as if the app had been closed that long (background, then
## resume), so the return flow plays. Uses the time-travel sandbox like set_debug_time_scale().
func debug_advance(seconds: int) -> CatchUpResult:
	if not _booted or not (_clock is DebugClock) or seconds <= 0:
		return CatchUpResult.empty(_starter.sim_time_unix)
	_enter_time_travel()
	on_background()
	var dc: DebugClock = _clock
	dc.advance(float(seconds))
	return on_resume()


## True once this run's saves go to the time-travel sandbox.
func is_time_traveling() -> bool:
	return _time_travel


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
func _finish_boot(summary: CatchUpResult, first_launch: bool) -> void:
	_booted = true
	_foreground = true
	_journal_transitions(summary)
	var entries: Array[JournalEntry] = _record_events(summary.events)
	_prepare_return(summary, first_launch)
	_collect_releases()
	_save()
	_emit_state()
	session_ready.emit(summary)
	_emit_entries(entries)
	_emit_releases()


## Builds the return summary for a launch or resume. When it shows, the events it covers are told there (and
## in the journal), so they never come back as toasts or cards: only the prompt is still raised.
func _prepare_return(summary: CatchUpResult, first_launch: bool) -> void:
	if first_launch:
		_return = ReturnSummary.for_first_launch(summary.to_unix)
	else:
		_return = ReturnSummary.build(summary, _derived)
	summary.play_time_lapse = _return.show and not summary.keyframes.is_empty() \
		and (_settings == null or _settings.show_time_lapse)
	if not _return.show:
		return
	for e: SimEvent in summary.events:
		if e == _return.prompt:
			continue
		_released[e.uid] = true
		_ledger.remove_pending(e.uid)


## Loads the latest save, or starts a new game when there is none (or none could be read). Returns true on
## the very first launch.
func _load_or_new() -> bool:
	var now: int = _clock.now_unix()
	var report: SaveLoadReport = _store.load_latest(_is_payload_valid)
	var parts: Parts = _decode_payload(report.payload, false) if report.ok else null
	if parts != null:
		_apply_parts(parts)
		return false
	_begin_new_game(now, &"new_game")
	if not report.first_run:
		_meta.recovered_from = "quarantine"
		_recovered_this_launch = true
	return report.first_run


## Starts a worker-thread catch-up when the clock rules call for one of ASYNC_MIN_STEPS or more. Returns false
## (and does nothing) otherwise, so the caller runs the synchronous path.
func _start_job(kind: StringName, first_launch: bool) -> bool:
	var now: int = _clock.now_unix()
	var decision: TimeResolution = TimePolicy.resolve(_starter.sim_time_unix, now)
	@warning_ignore("integer_division")
	var steps: int = (Sim.grid(now) - _starter.sim_time_unix) / SimConstants.GRID_S
	if decision.action != &"catch_up" or steps < ASYNC_MIN_STEPS:
		return false
	# The shared rule list is built here, on the main thread, never lazily on the worker.
	EventRules.registry()
	_refresh()
	_emit_state()
	var job := CatchUpJob.new()
	job.kind = kind
	job.first_launch = first_launch
	job.starter = _starter.copy()
	job.env = _env.copy()
	job.history = _history.copy()
	job.ledger = _ledger.copy()
	job.catalog = _catalog
	job.to_unix = now
	job.utc_offset_s = _clock.local_utc_offset_s()
	job.mono_ms = _clock.monotonic_msec()
	_job = job
	_job_id = WorkerThreadPool.add_task(job.run, true, "Sourdough catch-up")
	set_process(true)
	return true


## Swaps a finished worker-thread catch-up in, then continues exactly as boot() or on_resume() do.
func _finish_job() -> void:
	WorkerThreadPool.wait_for_task_completion(_job_id)
	var job: CatchUpJob = _job
	_job = null
	_job_id = -1
	set_process(false)
	_starter = job.starter
	_env = job.env
	_history = job.history
	_ledger = job.ledger
	# The session clock resumes from where the catch-up stopped; the next tick covers the time it took.
	_session_now = job.to_unix
	_last_wall = job.to_unix
	_last_mono_ms = job.mono_ms
	_refresh()
	_last_summary = job.result
	if job.kind == &"boot":
		_finish_boot(job.result, job.first_launch)
	else:
		_finish_resume(job.result)


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


## Journals newly admitted events (once, when admitted). Returns the entries; the caller emits
## journal_appended after its other signals. Display is _collect_releases()'s job.
func _record_events(events: Array[SimEvent]) -> Array[JournalEntry]:
	var out: Array[JournalEntry] = []
	for e: SimEvent in events:
		var key: StringName = e.key_for("JOURNAL_TITLE")
		var data: Dictionary = {"event_id": String(e.id), "event_uid": e.uid}
		if e.id == &"peaked_while_away":
			# events-catalog §3.2: the _AWAY_ peak lines double as the journal's peak log lines.
			var word: String = str(e.payload.get("rise_word", ""))
			if word.is_empty():
				word = String(Inspection.peak_word(DictReader.float_of(e.payload.get("peak_rise", 0.0))))
			key = StringName("EVENT_PEAKED_WHILE_AWAY_AWAY_%s" % word)
		var entry: JournalEntry = _make_entry(&"event", key, data)
		entry.at_unix = e.created_unix
		# Rules put the copy's placeholder values in the payload (events-catalog.md).
		entry.args = DictReader.canonical_dict(e.payload)
		_append_journal(entry)
		out.append(entry)
	return out


## Decides which pending events to drop as stale and which to release now, and updates the ledger (so the
## next save already has it). Returns true when the ledger changed. _emit_releases() sends the signals.
func _collect_releases() -> bool:
	var changed: bool = false
	var now: int = _starter.sim_time_unix
	for e: SimEvent in _ledger.pending.duplicate():
		if EventScheduler.is_stale(e, _derived, now):
			_ledger.remove_pending(e.uid)
			changed = true
			if _released.has(e.uid):
				_to_withdraw.append(e.uid)
	for e: SimEvent in _ledger.pending.duplicate():
		if _released.has(e.uid) or e.not_before_unix > now:
			continue
		_released[e.uid] = true
		_to_raise.append(e)
		if e.tier == &"info":
			_ledger.remove_pending(e.uid)
			changed = true
	return changed


func _emit_releases() -> void:
	var withdraw: Array[int] = _to_withdraw.duplicate()
	var raise: Array[SimEvent] = _to_raise.duplicate()
	_to_withdraw.clear()
	_to_raise.clear()
	for uid: int in withdraw:
		event_withdrawn.emit(uid)
	for e: SimEvent in raise:
		event_raised.emit(e)


func _emit_entries(entries: Array[JournalEntry]) -> void:
	for e: JournalEntry in entries:
		journal_appended.emit(e)


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


## The real save gets one last write at real time; every later save of this run goes to the sandbox.
func _enter_time_travel() -> void:
	if _time_travel:
		return
	var res: CatchUpResult = _live_sync(true)
	_journal_transitions(res)
	_record_events(res.events)
	_save()
	_time_travel = true
	var sandbox := SaveStore.new(_store.base_dir + TIME_TRAVEL_SUFFIX)
	sandbox.clock = _clock
	_store = sandbox
	_save()


## The gifted, still unnamed starter of a brand-new game (and the fallback when every save failed). Private:
## T3 reaches a new game through boot() (no save) and names it with AdoptStarterAction.
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


## Makes `state` the player's named starter, timestamped now (architecture §5.5). Keeps the gifted starter's
## id, so the journal and seed stay with it.
func _adopt(state: StarterState, starter_name: String, path: StringName) -> void:
	var now: int = _clock.now_unix()
	var id: String = _starter.id
	_starter = state.copy()
	_starter.id = id if not id.is_empty() else _new_id()
	_starter.name = starter_name.strip_edges()
	_starter.rebase_to(now)
	_env = StarterPresets.environment_for(&"new_game", now)
	_history.reset_for_new_starter()
	_history.onboarding_path = path
	_reset_session_clock(now)


func _build_memorial(now: int) -> Memorial:
	var m := Memorial.new()
	m.starter_id = _starter.id
	m.name = _starter.name
	m.born_unix = _starter.born_unix
	m.ended_unix = now
	m.cause = &"mold"
	var journal_feeds: int = 0
	for e: JournalEntry in _journal:
		if e.starter_id == _starter.id and e.kind == &"feed":
			journal_feeds += 1
	# real_feeds is new in Phase 3; a Phase 2 save only has the journal count.
	m.feeds_count = maxi(_history.real_feeds, journal_feeds)
	m.peaks_count = _history.peaks
	m.best_rise = _history.best_rise
	@warning_ignore("integer_division")
	m.unfed_days = _history.warm_unfed_s / 86400
	return m


func _discard_starter(action: DiscardStarterAction) -> JournalEntry:
	var now: int = action.at_unix
	var m: Memorial = _build_memorial(now)
	var entry: JournalEntry = _make_entry(&"memorial", &"MEMORIAL_TITLE", m.to_dict())
	entry.args = {"name": m.name}
	var preset: StringName = restart_preset()
	_memorials.append(m)
	_starter = StarterPresets.make(preset, now)
	_starter.id = _new_id()
	_starter.name = action.new_name.strip_edges()
	_env = StarterPresets.environment_for(preset, now)
	_history.reset_for_new_starter()
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
	# game-copy §11: ratio, flour (a key; Keys.format translates it) and grams kept.
	entry.args = {
		"ratio": feed.ratio_text(),
		"flour": String(Keys.flour(feed.main_flour())),
		"grams": roundi(feed.kept_g),
	}
	return entry


## The first feed after adoption closes the new-game start (narrative §8.2, B8): the Day one page.
func _day_one_entry() -> JournalEntry:
	var skip: bool = _history.onboarding_path == &"skip"
	var entry: JournalEntry = _make_entry(&"milestone", &"JOURNAL_DAY_ONE_TITLE", {
		"milestone": "day_one", "path": String(_history.onboarding_path),
		"body_key": "JOURNAL_DAY_ONE_SKIP_BODY" if skip else "JOURNAL_DAY_ONE_BODY",
	})
	entry.args = {"name": _starter.name}
	_history.onboarding_path = &""
	return entry


## The feed sheet showed FEED_ROUTINE_HINT for this feed if its conditions held; note when, so it shows at
## most once a week (game-mechanics §2.2). The cheap history checks run before the forecast.
func _note_routine_hint(feed: FeedAction, before: StarterState) -> void:
	var probe := PeakForecast.new()
	probe.has_window = true
	if not FeedPlanner.routine_hint(_history, probe, feed.at_unix):
		return
	if FeedPlanner.routine_hint(_history, Forecast.peak_window(before, _env, feed), feed.at_unix):
		_history.routine_hint_unix = feed.at_unix


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


## Every entry goes through here. data and args are stored in their saved form (DictReader.saved_form), so an
## entry is the same before and after a save (QA's PROP-02 finding).
func _append_journal(entry: JournalEntry) -> void:
	entry.data = DictReader.saved_form(entry.data)
	entry.args = DictReader.saved_form(entry.args)
	JournalEntry.append_capped(_journal, entry)


func _journal_transitions(res: CatchUpResult) -> void:
	for t: Dictionary in res.transitions:
		var to_state: String = t.get("to", "")
		var cause: String = t.get("cause", "")
		var at: int = t.get("at_unix", 0)
		var e: JournalEntry = _make_entry(&"state_change", Keys.status_word(StringName(to_state), StringName(cause)),
			t.duplicate())
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
