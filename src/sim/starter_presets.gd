class_name StarterPresets
extends RefCounted
## Start states (data-models.md §2.1, game-mechanics.md §8.2). Pure. Each preset is reached by running the
## real sim from the reference's MATURE fixture, so it is a state the sim can actually produce.
##   new_game       at_peak, maturity 0.2, counter
##   first_restart  dormant (cold), maturity 0.2, temp_c about 4: fed, 1 h out, then 14 d in the fridge
##   restart        at_peak, maturity 0.2, counter

const IDS: Array[StringName] = [&"new_game", &"first_restart", &"restart"]
const PRESET_MATURITY: float = 0.2

static var _cache: Dictionary[StringName, StarterState] = {}


## A fresh starter for `preset_id`, timestamped at `now_unix`. id and name are empty; Session fills them.
static func make(preset_id: StringName, now_unix: int) -> StarterState:
	if not _cache.has(preset_id):
		_cache[preset_id] = _build(preset_id)
	var s: StarterState = _cache[preset_id].copy()
	s.rebase_to(now_unix)
	s.id = ""
	s.name = ""
	return s


## Every preset starts at the counter.
static func environment_for(_preset_id: StringName, now_unix: int) -> EnvironmentState:
	return EnvironmentState.at_location(&"counter", now_unix)


static func _build(preset_id: StringName) -> StarterState:
	var s: StarterState = SimFixtures.young()
	SimFixtures.feed_ratio(s)
	var counter: EnvironmentState = EnvironmentState.at_location(&"counter")
	if preset_id == &"first_restart":
		var fridge: EnvironmentState = EnvironmentState.at_location(&"fridge")
		for i: int in 60:
			Sim.step(s, counter)
		for i: int in SimConstants.CATCH_UP_CAP_STEPS:
			Sim.step(s, fridge)
	else:
		for i: int in 48 * 60:
			if StateDeriver.derive(s, counter).rise_phase == &"at_peak":
				break
			Sim.step(s, counter)
	s.maturity = PRESET_MATURITY
	return s
