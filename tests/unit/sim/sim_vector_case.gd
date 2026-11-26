class_name SimVectorCase
extends TestCase
## Shared helpers for the spec §18 golden vectors: a port of the trace helpers in
## tools/sim-reference/sim.py (trace, ratio_vector, converted, state_times). Owner: T1.

const U3: Array[float] = [0.0, 0.5, 1.0]
## Spec §18 drift allowances: hours, rise.
const TOL_T: float = 0.3
const TOL_R: float = 0.05


class Row:
	var state: StringName = &""
	var rise: float = 0.0
	var smells: Array[StringName] = []
	var hooch: bool = false
	var mold_stage: StringName = &""


class Trace:
	## Hours to the first at_peak phase, -1 if never.
	var at_peak: float = -1.0
	var peak_t: float = 0.0
	var peak_rise: float = 0.0
	## state id -> first hour seen
	var first: Dictionary = {}
	## checkpoint hour -> Row
	var rows: Dictionary = {}
	var end: StarterState = null

	func row(h: int) -> Row:
		var r: Row = rows[h]
		return r


# ---------------------------------------------------------------- sim.py helpers
static func env_at(t: float, rh: float = 50.0, cover: StringName = &"loose_lid") -> EnvironmentState:
	return EnvironmentState.make(t, rh, cover)


static func counter() -> EnvironmentState:
	return EnvironmentState.at_location(&"counter")


static func fridge() -> EnvironmentState:
	return EnvironmentState.at_location(&"fridge")


static func at_temp(s: StarterState, t: float) -> StarterState:
	var c: StarterState = s.copy()
	c.temp_c = t
	return c


## sim.py feed_ratio() on a copy.
static func fed(s: StarterState, a: float = 1.0, b: float = 1.0, flour: StringName = &"white_bread",
		hyd: float = 100.0, kept: float = 50.0, u: float = 0.5, stir_in: bool = false) -> StarterState:
	var c: StarterState = s.copy()
	SimFixtures.feed_ratio(c, a, b, flour, hyd, kept, u, stir_in)
	return c


## sim.py advance() on a copy: round(hours * 60) steps.
static func advance(s: StarterState, hours: float, env: EnvironmentState) -> StarterState:
	var c: StarterState = s.copy()
	for i: int in roundi(hours * 60.0):
		Sim.step(c, env)
	return c


static func smells(s: StarterState, env: EnvironmentState) -> Array[StringName]:
	return SmellModel.shown(SmellModel.intensities(s, env))


static func trace(s: StarterState, hours: float, env: EnvironmentState, cps: Array[int] = []) -> Trace:
	var rec := Trace.new()
	var x: StarterState = s.copy()
	rec.peak_rise = x.rise
	var n: int = roundi(hours * 60.0)
	for i: int in n:
		_on(rec, i, float(i) * 60.0 / 3600.0, x, env, cps)
		Sim.step(x, env)
	_on(rec, n, hours, x, env, cps)
	rec.end = x
	return rec


static func _on(rec: Trace, i: int, h: float, x: StarterState, env: EnvironmentState, cps: Array[int]) -> void:
	var d: DerivedState = StateDeriver.derive(x, env)
	if d.rise_phase == &"at_peak" and rec.at_peak < 0.0:
		rec.at_peak = h
	if x.rise > rec.peak_rise:
		rec.peak_rise = x.rise
		rec.peak_t = h
	if not rec.first.has(d.state):
		rec.first[d.state] = h
	if i % 60 == 0:
		@warning_ignore("integer_division")
		var hour: int = i / 60
		if cps.has(hour):
			var r := Row.new()
			r.state = d.state
			r.rise = x.rise
			r.smells = smells(x, env)
			r.hooch = x.hooch >= 0.1
			r.mold_stage = StateDeriver.mold_stage(x)
			rec.rows[hour] = r


static func ratio_vector(start: StarterState, a: float, b: float, t: float, kept: float, hours: float = 48.0,
		cps: Array[int] = [], flour: StringName = &"white_bread", hyd: float = 100.0,
		keep_temp: bool = false) -> Array[Trace]:
	var env: EnvironmentState = env_at(t)
	var begin: StarterState = start if keep_temp else at_temp(start, t)
	var out: Array[Trace] = []
	for u: float in U3:
		out.append(trace(fed(begin, a, b, flour, hyd, kept, u), hours, env, cps))
	return out


static func converted(start: StarterState, flour: StringName = &"white_bread", hyd: float = 100.0) -> StarterState:
	var s: StarterState = start
	for i: int in 3:
		s = fed(s, 1.0, 1.0, flour, hyd)
		s = advance(s, 12.0, counter())
	return s


## [first: Dictionary state -> h, marks: Dictionary ("hooch", "watch") -> h, end: StarterState]
static func state_times(s: StarterState, hours: float, env: EnvironmentState) -> Array:
	var first: Dictionary = {}
	var marks: Dictionary = {}
	var x: StarterState = s.copy()
	for i: int in roundi(hours * 60.0):
		var h: float = float(i) * 60.0 / 3600.0
		var st: StringName = StateDeriver.derive(x, env).state
		if not first.has(st):
			first[st] = h
		if x.hooch >= 0.1 and not marks.has("hooch"):
			marks["hooch"] = h
		if x.mold_risk >= 0.3 and not marks.has("watch"):
			marks["watch"] = h
		Sim.step(x, env)
	return [first, marks, x]


# ---------------------------------------------------------------- range checks (sim.py Checker)
func within(name: String, values: Array[float], lo: float, hi: float, tol: float = 0.0) -> void:
	for v: float in values:
		check_between(v, lo - tol, hi + tol, name)


func about(name: String, values: Array[float], x: float, tol: float) -> void:
	within(name, values, 0.95 * x, 1.05 * x, tol)


func check_peak(name: String, recs: Array[Trace], ap: Vector2, pk: Vector2, ht: Vector2 = Vector2.ZERO,
		ht_about: float = 0.0) -> void:
	if ap != Vector2.ZERO:
		within(name + " at_peak", at_peaks(recs), ap.x, ap.y, TOL_T)
	within(name + " peak time", peak_times(recs), pk.x, pk.y, TOL_T)
	if ht != Vector2.ZERO:
		within(name + " peak height", heights(recs), ht.x, ht.y, TOL_R)
	if ht_about > 0.0:
		about(name + " peak height", heights(recs), ht_about, TOL_R)


static func at_peaks(recs: Array[Trace]) -> Array[float]:
	var out: Array[float] = []
	for r: Trace in recs:
		out.append(r.at_peak)
	return out


static func peak_times(recs: Array[Trace]) -> Array[float]:
	var out: Array[float] = []
	for r: Trace in recs:
		out.append(r.peak_t)
	return out


static func heights(recs: Array[Trace]) -> Array[float]:
	var out: Array[float] = []
	for r: Trace in recs:
		out.append(r.peak_rise)
	return out


static func states_at(recs: Array[Trace], h: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for r: Trace in recs:
		var s: StringName = r.row(h).state
		if not out.has(s):
			out.append(s)
	return out


static func rises_at(recs: Array[Trace], h: int) -> Array[float]:
	var out: Array[float] = []
	for r: Trace in recs:
		out.append(r.row(h).rise)
	return out


func check_states(name: String, recs: Array[Trace], h: int, allowed: Array[StringName]) -> void:
	for s: StringName in states_at(recs, h):
		check(allowed.has(s), "%s: state %s not in %s" % [name, s, allowed])
