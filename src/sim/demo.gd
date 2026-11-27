class_name Demo
extends RefCounted
## The B6 tutorial demo (architecture.md §5.5, game-mechanics §8.1). Ordinary 60 s steps on a temporary copy;
## playback speed comes from showing many sim minutes per real second, never from a scaled dt, so the demo is
## exactly the real sim. Nothing here touches a save: Session keeps the sandbox in memory only.
##
## The demo starts from StarterPresets `demo_start` ("just mixed", B1) and runs to at_peak. That end state
## equals the `new_game` preset, which AdoptStarterAction adopts on both the tour and the skip path.

## BT-12: feed to at_peak in 90 to 120 s of wall time. A design knob (game-designer).
const DURATION_S: float = 105.0
## One playback frame every this many 60 s steps (a young starter peaks after about 400 steps, so about 200
## frames, plus every state change).
const FRAME_EVERY_STEPS: int = 2
const MAX_STEPS: int = 48 * 60


## The B1 jar: a young starter just mixed at the counter, timestamped now.
static func start_state(now_unix: int) -> StarterState:
	return StarterPresets.make(&"demo_start", now_unix)


## Runs `steps` steps on a copy of `state` and returns one VisualParams every `every` steps.
static func run(state: StarterState, env: EnvironmentState, steps: int, every: int = 1) -> Array[VisualParams]:
	var frames: Array[VisualParams] = []
	var s: StarterState = state.copy()
	var n: int = maxi(1, every)
	for i: int in steps:
		Sim.step(s, env)
		if (i + 1) % n == 0:
			frames.append(VisualMapper.from_state(s, env))
	return frames


## Steps a copy until rise_phase is at_peak (at most max_steps) and returns it. The demo's end state.
static func run_to_peak(state: StarterState, env: EnvironmentState, max_steps: int = MAX_STEPS) -> StarterState:
	var s: StarterState = state.copy()
	for i: int in max_steps:
		if StateDeriver.derive(s, env).rise_phase == &"at_peak":
			break
		Sim.step(s, env)
	return s


## The B6 playback: steps `state` in place until rise_phase is at_peak and returns what the view plays, in
## the time-lapse's shape (CatchUpResult with keyframes, transitions and playback_s = DURATION_S). Keyframes:
## the first state, one every FRAME_EVERY_STEPS steps, every state change, and the at_peak state last. Not
## capped at CatchUpResult.MAX_KEYFRAMES. No history, events or journal: it is a sandbox.
static func playback(state: StarterState, env: EnvironmentState, max_steps: int = MAX_STEPS) -> CatchUpResult:
	var res := CatchUpResult.new()
	res.from_unix = state.sim_time_unix
	res.play_time_lapse = true
	res.playback_s = DURATION_S
	var d: DerivedState = StateDeriver.derive(state, env)
	res.keyframes.append(TimeLapseKeyframe.make(state.sim_time_unix, VisualMapper.from_derived(state, env, d), d,
		false))
	var steps: int = 0
	while d.rise_phase != &"at_peak" and steps < max_steps:
		Sim.step(state, env)
		steps += 1
		var nd: DerivedState = StateDeriver.derive(state, env)
		var changed: bool = nd.state != d.state
		if changed:
			res.transitions.append({
				"at_unix": state.sim_time_unix, "from": String(d.state), "to": String(nd.state),
				"cause": String(nd.dormant_cause),
			})
		var last: bool = nd.rise_phase == &"at_peak" or steps == max_steps
		if changed or last or steps % FRAME_EVERY_STEPS == 0:
			res.keyframes.append(TimeLapseKeyframe.make(state.sim_time_unix,
				VisualMapper.from_derived(state, env, nd), nd, changed))
		d = nd
	res.steps = steps
	res.simulated_s = steps * SimConstants.GRID_S
	res.to_unix = state.sim_time_unix
	return res
