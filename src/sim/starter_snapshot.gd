class_name StarterSnapshot
extends RefCounted
## What the HUD reads (data-models.md §8). The HUD shows the state as an icon plus a word, never color alone.

var name: String = ""
var state: StringName = &""
var rise_phase: StringName = &""
## &"cold" or &"starved" when dormant, else &"". Copy picks _COLD or _STARVED lines from it.
var dormant_cause: StringName = &""
var since_feed_s: float = 0.0
## unhealthy or moldy.
var is_warning: bool = false
## False when moldy.
var can_feed: bool = true
var maturity_stage: StringName = &"young"
var location: StringName = &"counter"
## Phase 4. The jar holds no starter (after "Discard", until "Start again"). Then state, rise_phase and name
## are empty, can_feed is false, and the HUD shows the empty-jar screen (EMPTY_JAR_TITLE, EMPTY_JAR_BODY).
var empty_jar: bool = false
## Phase 4. The revealed trait (Traits.IDS), &"" before the reveal: picks the trait copy variants.
var trait_id: StringName = &""


static func make(s: StarterState, d: DerivedState, env: EnvironmentState) -> StarterSnapshot:
	var snap := StarterSnapshot.new()
	snap.name = s.name
	snap.location = env.location
	if s.empty:
		snap.empty_jar = true
		snap.state = &""
		snap.can_feed = false
		snap.maturity_stage = &""
		return snap
	snap.state = d.state
	snap.rise_phase = d.rise_phase
	snap.dormant_cause = d.dormant_cause
	snap.since_feed_s = s.since_feed_s
	snap.is_warning = d.state == &"unhealthy" or d.state == &"moldy"
	snap.can_feed = not s.moldy
	snap.maturity_stage = SimConstants.maturity_stage(s.maturity)
	snap.location = env.location
	return snap
