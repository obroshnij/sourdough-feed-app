class_name SliceHarness
extends RefCounted
## The AC integration harness (test-plan §2.6, layer L7). One harness is one simulated phone: a FakeClock,
## a temp save folder with its settings.cfg, and the real GameSession node in the scene tree. It drives
## the Session the way Main and the UI do:
## - launch(): a new Session node, setup() with the fakes, then boot(). This is Main's path through
##   Session.start() without the 60 s timer, which play() replaces.
## - apply(): a GameAction through Session.apply(), as a sheet's confirm button does.
## - play(): the app open in the foreground, the grid timer ticking.
## - close(): the app backgrounded (on_background saves), then the process is gone.
## - kill(): the process dies with no warning (no on_background).
## Every script signal on Session and on the Bus autoload is recorded in order in `heard`, so new
## signals from T1's contracts are recorded without a harness change.
## Synthetic data only (public repo): the starter is "Bramble", id 0123456789abcdef.

const T0: int = 1795651200  # on the 60 s grid
const MIN: int = 60
const HOUR: int = 3600
const DAY: int = 86400
const CAP_S: int = 14 * DAY
const STARTER_ID: String = "0123456789abcdef"
const STARTER_NAME: String = "Bramble"
## Irregular foreground tick lengths (s). None is a multiple of another, so ticks land at every
## offset within a grid minute. All stay under the 300 s wall-versus-monotonic guard.
const IRREGULAR_STEPS: Array[int] = [61, 59, 293, 7, 120, 241, 1, 179, 60, 299]

var dir: String = ""
var clock: FakeClock = null
## The current launch's store. Tests set `store.fault_point` to kill a save midway.
var store: SaveStore = null
var settings: SettingsStore = null
var session: GameSession = null
## Each {"source": &"session" or &"bus", "signal": StringName, "args": Array, "at_unix": int}.
var heard: Array[Dictionary] = []

var _tree: SceneTree = null
var _bus: Node = null
var _bus_links: Array[Dictionary] = []


func _init(label: String, start_unix: int = T0, utc_offset_s: int = 0) -> void:
	dir = QaTemp.make("int_" + label)
	clock = FakeClock.new(start_unix, utc_offset_s)
	_tree = Engine.get_main_loop() as SceneTree
	_bus = _tree.root.get_node_or_null("Bus")
	if _bus != null:
		_listen(_bus, &"bus")


# ------------------------------------------------------------------ the app lifecycle

## A launch: a fresh Session node on this phone's files, booted against the clock.
func launch() -> GameSession:
	return launch_with(clock)


## A launch against another clock, for example a real DebugClock for the debug time travel tests.
func launch_with(launch_clock: Clock) -> GameSession:
	kill()
	DirAccess.make_dir_recursive_absolute(dir)
	store = SaveStore.new(dir)
	settings = SettingsStore.new(dir.path_join("settings.cfg"))
	settings.load_settings()
	session = GameSession.new()
	_tree.root.add_child(session)
	session.setup(launch_clock, store, settings)
	_listen(session, &"session")
	session.boot()
	return session


## Backgrounded (the OS sends APPLICATION_PAUSED), then the process is gone.
func close() -> void:
	if session == null:
		return
	session.on_background()
	kill()


## The process dies with no warning: no on_background, no save.
func kill() -> void:
	if session == null:
		return
	session.free()
	session = null


## Close now, move the wall clock to `unix`, launch again.
func reopen_at(unix: int) -> GameSession:
	close()
	clock.set_now(unix)
	return launch()


## Background now, move the wall clock to `unix`, resume the same process (APPLICATION_RESUMED).
func resume_at(unix: int) -> CatchUpResult:
	session.on_background()
	clock.set_now(unix)
	return session.on_resume()


func apply(action: GameAction) -> ActionResult:
	return session.apply(action)


## The app open for `seconds`: real time passes and the grid timer ticks every `step_s`.
func play(seconds: int, step_s: int = MIN) -> void:
	var left: int = seconds
	while left > 0:
		var dt: int = mini(step_s, left)
		clock.advance(dt)
		session.tick()
		left -= dt


## The app open for `seconds`, ticking at IRREGULAR_STEPS lengths (a real timer drifts).
func play_irregular(seconds: int) -> void:
	var left: int = seconds
	var i: int = 0
	while left > 0:
		var dt: int = mini(IRREGULAR_STEPS[i % IRREGULAR_STEPS.size()], left)
		clock.advance(dt)
		session.tick()
		left -= dt
		i += 1


## Ticks minute by minute until `done` (Callable returning bool) is true or `max_s` has passed.
## Returns the seconds played, or -1 if `done` never became true.
func play_until(done: Callable, max_s: int) -> int:
	var played: int = 0
	while played < max_s:
		clock.advance(MIN)
		session.tick()
		played += MIN
		var verdict: Variant = done.call()
		if typeof(verdict) == TYPE_BOOL and verdict == true:
			return played
	return -1


## Frees the Session, disconnects from Bus and deletes the folder. Call from after_each.
func dispose() -> void:
	kill()
	if _bus != null:
		for link: Dictionary in _bus_links:
			var sig_name: StringName = link["signal"]
			var recorder: Callable = link["callable"]
			if _bus.is_connected(sig_name, recorder):
				_bus.disconnect(sig_name, recorder)
	_bus_links.clear()
	QaTemp.remove(dir)
	QaTemp.remove(dir + GameSession.TIME_TRAVEL_SUFFIX)


# ------------------------------------------------------------------ seeding a phone

## Writes a complete, valid save.json (all 8 sections) holding `starter` at grid(now), so the normal
## launch path loads it. `rng_seed` fixes the one sim draw per feed (first_draw() predicts it).
func seed_save(starter: StarterState, env: EnvironmentState = null, rng_seed: int = 1) -> Error:
	var s: StarterState = starter.copy()
	if s.id == "":
		s.id = STARTER_ID
	if s.name == "":
		s.name = STARTER_NAME
	s.sim_time_unix = Sim.grid(clock.now_unix())
	if s.born_unix == 0:
		s.born_unix = s.sim_time_unix - 30 * DAY
	var e: EnvironmentState = env.copy() if env != null else EnvironmentState.at_location(&"counter")
	e.changed_unix = s.sim_time_unix
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var meta := SaveMeta.new()
	meta.created_unix = s.born_unix
	var payload: Dictionary = {
		"environment": e.to_dict(),
		"events": EventLedger.new().to_dict(),
		"history": PlayerHistory.new().to_dict(),
		"journal": [],
		"memorials": [],
		"meta": meta.to_dict(),
		"rng": {"sim_seed": str(rng_seed), "sim_state": str(rng.state)},
		"starter": s.to_dict(),
	}
	DirAccess.make_dir_recursive_absolute(dir)
	return SaveStore.new(dir).save(payload)


## The MATURE fixture (spec §18): fed 1:1:1, then 12 h at the counter.
static func mature() -> StarterState:
	return SimFixtures.mature()


## The feed_u a session seeded with `rng_seed` draws on its first feed (Sim.apply_feed).
static func first_draw(rng_seed: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	return minf(rng.randf(), 0.9999999)


## The first seed from 1 whose first draw is within `tol` of `target`. Deterministic.
static func seed_for_draw(target: float, tol: float = 0.0005) -> int:
	for candidate: int in range(1, 200000):
		if absf(first_draw(candidate) - target) <= tol:
			return candidate
	return 1


# ------------------------------------------------------------------ reading the results

func state() -> StringName:
	return session.get_snapshot().state


func since_feed_h() -> float:
	return session.get_starter().since_feed_s / float(HOUR)


## Every recorded emission of `sig_name`, oldest first.
func heard_of(sig_name: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for h: Dictionary in heard:
		if h["signal"] == sig_name:
			out.append(h)
	return out


func count(sig_name: StringName) -> int:
	return heard_of(sig_name).size()


## The signal names heard since the last forget(), in order.
func names() -> Array[StringName]:
	var out: Array[StringName] = []
	for h: Dictionary in heard:
		var sig_name: StringName = h["signal"]
		out.append(sig_name)
	return out


func forget() -> void:
	heard.clear()


func path(file_name: String) -> String:
	return dir.path_join(file_name)


func bytes_of(file_name: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path(file_name))


## The payload stored in a save file (save.json by default), or {} if it can't be read.
func disk_payload(file_name: String = SaveStore.FILE_MAIN) -> Dictionary:
	return SaveStore.new(dir).load_from_path(path(file_name))


## The saved starter, decoded (floats come back from their hex form).
func disk_starter(file_name: String = SaveStore.FILE_MAIN) -> StarterState:
	var p: Dictionary = disk_payload(file_name)
	var d: Variant = p.get("starter", {})
	return StarterState.from_dict(d) if typeof(d) == TYPE_DICTIONARY else null


func disk_meta() -> Dictionary:
	var m: Variant = disk_payload().get("meta", {})
	return m if typeof(m) == TYPE_DICTIONARY else {}


## File names in the quarantine folder, sorted.
func quarantined() -> PackedStringArray:
	var q: String = path(SaveStore.QUARANTINE_DIR)
	if not DirAccess.dir_exists_absolute(q):
		return PackedStringArray()
	var files: PackedStringArray = DirAccess.get_files_at(q)
	files.sort()
	return files


func journal_of(kind: StringName) -> Array[JournalEntry]:
	var out: Array[JournalEntry] = []
	for e: JournalEntry in session.get_journal():
		if e.kind == kind:
			out.append(e)
	return out


## The saved payload text without `meta` (saved_unix and save_count legitimately differ), floats in
## their exact hex form. Two equal texts mean bit-identical state.
static func payload_text(payload: Dictionary) -> String:
	var copy: Dictionary = payload.duplicate(true)
	copy.erase("meta")
	return SaveCodec.payload_text(copy)


# ------------------------------------------------------------------ internals

func _listen(obj: Object, source: StringName) -> void:
	var script: Script = obj.get_script() as Script
	if script == null:
		return
	for sig: Dictionary in script.get_script_signal_list():
		var sig_name: StringName = sig["name"]
		var recorder: Callable = func(...args: Array) -> void:
			heard.append({"source": source, "signal": sig_name, "args": args, "at_unix": clock.now_unix()})
		obj.connect(sig_name, recorder)
		if source == &"bus":
			_bus_links.append({"signal": sig_name, "callable": recorder})
