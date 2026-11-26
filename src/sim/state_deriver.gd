class_name StateDeriver
extends RefCounted
## State labels from continuous variables (spec §12). Mirrors `rise_phase()` and `derive()` in sim.py.


## Spec §12.1, first match wins. `rr` is the rise rate from the §7 equations at this state.
## The at_peak row also requires peak_rate > 0, as the reference model does.
static func rise_phase(s: StarterState, rr: float) -> StringName:
	if s.food < SimConstants.HUNGRY_FOOD and (s.rise <= 1.0 + 0.5 * (s.peak_rise - 1.0) or s.peak_rise < 1.15):
		return &"hungry"
	if s.since_feed_s < 3600.0 and s.rise < 1.05:
		return &"freshly_fed"
	if s.rise >= 0.94 * s.peak_rise and s.rise > 1.15 and s.peak_rate > 0.0 and rr < 0.2 * s.peak_rate:
		return &"at_peak"
	if rr < 0.0 and s.rise < 0.94 * s.peak_rise:
		return &"collapsing"
	if s.rise < 1.15:
		return &"developing"
	if rr < 0.75 * s.peak_rate or s.food < 0.25 * s.food_at_feed:
		return &"near_peak"
	return &"active"


## Spec §12.2, first match wins: moldy, unhealthy, dormant, hungry, recovering, then the rise phase.
static func derive(s: StarterState, env: EnvironmentState) -> DerivedState:
	var d := DerivedState.new()
	d.ferm = Sim.ferm(s.temp_c)
	if s.moldy:
		d.state = &"moldy"
		return d
	var r: SimRates = Sim.rates(s, env)
	d.rise_rate = r.rise
	d.gas = r.gas
	d.activity = clampf(r.gas, 0.0, 1.0)
	var phase: StringName = rise_phase(s, r.rise)
	d.rise_phase = phase
	var cold: bool = d.ferm < SimConstants.DORMANT_COLD_FERM
	if s.mold_risk >= SimConstants.MOLD_WARN:
		d.state = &"unhealthy"
	elif cold or s.starved_h >= SimConstants.DORMANT_STARVED_H:
		d.state = &"dormant"
		d.dormant_cause = &"cold" if cold else &"starved"
	elif phase == &"hungry":
		d.state = &"hungry"
	elif s.vigor < SimConstants.RECOVER_VIGOR or s.vigor_at_feed < SimConstants.RECOVER_AT_FEED:
		d.state = &"recovering"
	else:
		d.state = phase
	return d


## &"none", &"watch", &"warning" or &"mold" (spec §10).
static func mold_stage(s: StarterState) -> StringName:
	if s.moldy:
		return &"mold"
	if s.mold_risk >= SimConstants.MOLD_WARN:
		return &"warning"
	if s.mold_risk >= SimConstants.MOLD_WATCH:
		return &"watch"
	return &"none"
