class_name TimeLapseKeyframe
extends RefCounted
## One frame of the "while you were away" time-lapse (game-mechanics §8 step 1). Everything in it was
## produced by the sim during catch-up, so the replay shows only what really happened (hard rule 2).

## Sim time of the step this frame shows.
var at_unix: int = 0
## The shader uniforms at that step (VisualMapper output).
var visuals: VisualParams = null
## The derived state id at that step.
var state: StringName = &""
## &"cold" or &"starved" when state is dormant, else &"".
var dormant_cause: StringName = &""
## True when the state changed on this step. Transition frames are never thinned away.
var transition: bool = false


static func make(at: int, v: VisualParams, d: DerivedState, is_transition: bool) -> TimeLapseKeyframe:
	var k := TimeLapseKeyframe.new()
	k.at_unix = at
	k.visuals = v
	k.state = d.state
	k.dormant_cause = d.dormant_cause
	k.transition = is_transition
	return k
