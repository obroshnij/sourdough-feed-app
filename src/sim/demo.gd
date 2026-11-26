class_name Demo
extends RefCounted
## The B6 tutorial demo (architecture.md §5.5). Ordinary 60 s steps on a temporary copy; playback speed
## comes from showing many steps per frame, never from a scaled dt, so the demo is exactly the real sim.


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
static func run_to_peak(state: StarterState, env: EnvironmentState, max_steps: int = 48 * 60) -> StarterState:
	var s: StarterState = state.copy()
	for i: int in max_steps:
		if StateDeriver.derive(s, env).rise_phase == &"at_peak":
			break
		Sim.step(s, env)
	return s
