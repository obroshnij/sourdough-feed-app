extends SceneTree
## Writes bare-payload fixture saves (data-models §9.5) for UI work, one per state the real sim reaches:
##   Godot --headless --path . -s res://tests/unit/ui/tools/make_fixtures.gd
## Each file is the first sim step at which StateDeriver reports that state, starting from SimFixtures.mature()
## fed 1:1:1 on the counter (and moved to the fridge for dormant). So the HUD shows only what the sim
## produced (CLAUDE.md rule 2). Load one with `Godot --path . -- --fixture=res://tests/unit/ui/fixtures/x.json`
## (debug builds) or GameSession.boot_from_fixture().

const OUT_DIR: String = "res://tests/unit/ui/fixtures"
const MAX_STEPS: int = 60 * 24 * 21
const NAME: String = "Bramble"
## Adopted 20 days before FakeClock's default start, so memorial dates read like a real game.
const BORN_UNIX: int = 1795651200 - 20 * 86400


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var found: Dictionary[StringName, bool] = {}
	_walk(&"counter", found)
	_walk(&"fridge", found)
	_recover(found)
	var missing: Array[StringName] = []
	for st: StringName in StatusStyle.STATES:
		if not found.has(st):
			missing.append(st)
	print("make_fixtures: wrote %d states, missing %s" % [found.size(), missing])
	quit(0)


func _walk(location: StringName, found: Dictionary[StringName, bool]) -> void:
	var s: StarterState = SimFixtures.mature()
	SimFixtures.feed_ratio(s)
	s.name = NAME
	s.born_unix = BORN_UNIX
	var env: EnvironmentState = EnvironmentState.at_location(location)
	for i: int in MAX_STEPS:
		var d: DerivedState = StateDeriver.derive(s, env)
		var key: StringName = d.state
		if d.state == &"dormant":
			key = StringName("dormant_%s" % d.dormant_cause)
		if not found.has(key):
			found[key] = true
			if d.state == &"dormant":
				found[&"dormant"] = true
			_write(key, s, env, i)
		if s.moldy:
			return
		Sim.step(s, env)


## recovering: starve on the counter for 80 h (run down), feed 1:1:1, then look for the recovering state.
func _recover(found: Dictionary[StringName, bool]) -> void:
	var s: StarterState = SimFixtures.mature()
	SimFixtures.feed_ratio(s)
	s.name = NAME
	s.born_unix = BORN_UNIX
	var env: EnvironmentState = EnvironmentState.at_location(&"counter")
	for i: int in 80 * 60:
		Sim.step(s, env)
	SimFixtures.feed_ratio(s)
	for i: int in 60 * 24:
		if StateDeriver.derive(s, env).state == &"recovering":
			found[&"recovering"] = true
			_write(&"recovering", s, env, i)
			return
		Sim.step(s, env)


func _write(key: StringName, s: StarterState, env: EnvironmentState, step: int) -> void:
	var payload: Dictionary = {"starter": s.to_dict(), "environment": env.to_dict()}
	var path: String = "%s/%s.json" % [OUT_DIR, key]
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(payload, "\t", true, true))
	f.close()
	print("make_fixtures: %s at step %d (%.1f h) in %s" % [key, step, step / 60.0, env.location])
