extends TestCase
## Phase 4, AC-13.2 and AC-13.3 (BT-12): the B6 demo is the real sim on a copy (architecture §5.5).
## The B1 start state is T1's to name (TBD-T1). Until it lands, these use what StarterPresets builds before it
## steps: the young fixture (maturity 0.2) just fed 1:1:1 with white flour, at the counter. The commit with
## T1's preset switches the start state here.

const PHASES: Array[StringName] = [&"freshly_fed", &"developing", &"active", &"near_peak", &"at_peak"]


func test_ac_13_2_demo_frames_are_plain_60_s_steps_on_a_copy() -> void:
	if not require(&"m2_sim"):
		return
	var env: EnvironmentState = EnvironmentState.at_location(&"counter")
	var start: StarterState = _b1()
	var before: String = _text(start)
	var frames: Array[VisualParams] = Demo.run(start, env, 480)
	check_eq(_text(start), before, "the demo leaves its input state untouched")
	check_eq(frames.size(), 480, "one frame per step")
	var s: StarterState = start.copy()
	var differ: int = 0
	var first: int = -1
	for i: int in frames.size():
		Sim.step(s, env, 60.0)
		var want: Dictionary = VisualMapper.from_state(s, env).to_dict()
		if var_to_str(frames[i].to_dict()) != var_to_str(want):
			differ += 1
			if first < 0:
				first = i
	check_eq(differ, 0, "frames equal VisualMapper over plain 60 s steps (first difference at step %d)" % first)
	var sparse: Array[VisualParams] = Demo.run(start, env, 480, 30)
	check_eq(sparse.size(), 16, "every 30th step gives 16 frames")
	check_eq(var_to_str(sparse[15].to_dict()), var_to_str(frames[479].to_dict()), "the sparse run ends on the same frame")


func test_ac_13_3_demo_rises_through_the_phases_in_order_and_stops_at_peak() -> void:
	if not require(&"m2_sim"):
		return
	var env: EnvironmentState = EnvironmentState.at_location(&"counter")
	var start: StarterState = _b1()
	var s: StarterState = start.copy()
	var seen: Array[StringName] = [StateDeriver.derive(s, env).rise_phase]
	var steps: int = 0
	while steps < 48 * 60 and seen[seen.size() - 1] != &"at_peak":
		Sim.step(s, env)
		steps += 1
		var p: StringName = StateDeriver.derive(s, env).rise_phase
		if p != seen[seen.size() - 1]:
			seen.append(p)
	check_eq(seen, PHASES, "rise_phase goes freshly_fed, developing, active, near_peak, at_peak and never back")
	var end: StarterState = Demo.run_to_peak(start, env)
	check_eq(StateDeriver.derive(end, env).rise_phase, &"at_peak", "run_to_peak ends at_peak")
	check_eq(_text(end), _text(s), "run_to_peak stops on the first at_peak step")
	print("    AC-13.3/BT-12: %d steps (%.2f h) from feed to at_peak; 90 to 120 s of playback is %.1f to %.1f steps a second" % [
		steps, steps / 60.0, steps / 120.0, steps / 90.0])
	check_between(steps / 60.0, 5.5, 8.0, "a young starter at 22 °C reaches at_peak in a normal cycle (spec §14: about 6.7 h)")


func _b1() -> StarterState:
	var s: StarterState = SimFixtures.young()
	SimFixtures.feed_ratio(s)
	# The B1 feed adds about 0.008 maturity; StarterPresets resets it, so the tour and skip paths both start
	# at 0.2 (game-mechanics §8.2). T1's B1 preset must do the same (AC-13.6, AC-13.7).
	s.maturity = StarterPresets.PRESET_MATURITY
	return s


static func _text(s: StarterState) -> String:
	return SaveCodec.payload_text({"starter": s.to_dict()})
