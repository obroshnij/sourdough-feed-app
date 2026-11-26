extends TestCase
## DIFF-01 (test-plan §2.2): the GDScript sim replays the 24 golden schedules written by
## `python3 -I tools/sim-reference/sim.py trace tests/golden/reference_traces` and matches
## every stored field at every hourly row within |a - b| <= 1e-9 * max(|a|, |b|) + 1e-12.
## Labels (state, rise_phase, dormant_cause) must match too, except within one 60 s step of
## a transition: a mismatch passes only if our label one minute earlier or later equals the
## reference label.
##
## API agreed with t1-sim-core (2026-11-26), called at runtime so this file compiles first:
##   SimFixtures.seed_state() / mature() / young() -> StarterState (trace "start" via START_FIXTURE)
##   EnvironmentState.make(temp_c, rh, cover: StringName, container: StringName)
##   Sim.feed(s, kept_g, flours: Dictionary[StringName, float], water_g, feed_u, stir_in) -> bool
##   Sim.step(s, env, 60.0)               (both mutate s in place)
##   StateDeriver.derive(s, env) -> DerivedState (.state, .rise_phase, .dormant_cause; null = &"")
##   s.to_dict() keys = the trace row names
## Only sourdough-scientist regenerates the traces. run.sh's golden-fresh lint fails if they
## drift from sim.py.

const TRACE_DIR := "res://tests/golden/reference_traces"
const EXPECTED_TRACES := 24
const EXPECTED_ROWS := 3988
const REL_TOL := 1e-9
const ABS_TOL := 1e-12
const LABELS: PackedStringArray = ["state", "rise_phase", "dormant_cause"]
## Stored fields every row must carry (data-models §2, spec §1).
const STORED: PackedStringArray = [
	"food", "food_at_feed", "yeast", "lab", "acid", "rise", "peak_rise", "peak_rate", "hooch",
	"dryness", "vigor", "vigor_at_feed", "maturity", "starved_h", "mold_risk", "moldy", "temp_c",
	"since_feed_s", "mass_g", "culture_hydration", "flour_mix", "feed_u", "feed_jitter",
]
const MAX_REPORTED_PER_TRACE := 8
## Trace "start" value to the SimFixtures method. `seed()` is a GDScript global, so T1 named
## the seed fixture seed_state().
const START_FIXTURE: Dictionary[String, StringName] = {
	"seed": &"seed_state",
	"mature": &"mature",
	"young": &"young",
}

var _sim: GDScript
var _deriver: GDScript
var _fixtures: GDScript
var _env_script: GDScript


## Runs now: the committed traces are complete and well formed, so DIFF-01 can't pass on
## a truncated or partial set once it turns on.
func test_reference_traces_are_complete() -> void:
	var manifest: Dictionary = _read_json(TRACE_DIR.path_join("manifest.json"))
	if not check(not manifest.is_empty(), "manifest.json is missing or unreadable"):
		return
	var entries: Array = manifest.get("traces", [])
	check_eq(entries.size(), EXPECTED_TRACES, "traces listed in manifest.json")
	check_eq(manifest.get("dt_s", 0.0), 60.0, "manifest dt_s")
	var total: int = 0
	var problems: PackedStringArray = PackedStringArray()
	for entry: Variant in entries:
		var info: Dictionary = entry
		var trace: Dictionary = _read_json(TRACE_DIR.path_join(String(info.get("file", ""))))
		var id: String = info.get("id", "?")
		if trace.is_empty():
			problems.append("%s: file missing or unreadable" % id)
			continue
		var rows: Array = trace.get("rows", [])
		total += rows.size()
		if rows.size() != int(info.get("rows", -1)):
			problems.append("%s: %d rows, manifest says %s" % [id, rows.size(), info.get("rows")])
		if rows.size() != int(trace.get("end_h", -1.0)) + 1:
			problems.append("%s: %d rows for end_h %s (want one per hour, both ends)" % [id, rows.size(), trace.get("end_h")])
		if not START_FIXTURE.has(String(trace.get("start", ""))):
			problems.append("%s: unknown start state %s" % [id, trace.get("start")])
		for i: int in rows.size():
			var row: Dictionary = rows[i]
			if float(row.get("t_h", -1.0)) != float(i):
				problems.append("%s row %d: t_h is %s" % [id, i, row.get("t_h")])
				break
			var missing: PackedStringArray = PackedStringArray()
			for field: String in STORED + LABELS:
				if not row.has(field):
					missing.append(field)
			if not missing.is_empty():
				problems.append("%s row %d lacks %s" % [id, i, ", ".join(missing)])
				break
	check_eq(total, EXPECTED_ROWS, "rows across all traces")
	check(problems.is_empty(), "\n".join(problems))


func test_diff_01_gdscript_sim_matches_reference() -> void:
	if not require(&"m2_sim"):
		return
	_sim = T1Api.find_script(&"Sim")
	_deriver = T1Api.find_script(&"StateDeriver")
	_fixtures = T1Api.find_script(&"SimFixtures")
	_env_script = T1Api.find_script(&"EnvironmentState")
	for pair: Array in [[_sim, "Sim"], [_deriver, "StateDeriver"], [_fixtures, "SimFixtures"],
			[_env_script, "EnvironmentState"]]:
		if not check(pair[0] != null, "m2_sim landed but class %s is missing" % pair[1]):
			return
	var manifest: Dictionary = _read_json(TRACE_DIR.path_join("manifest.json"))
	var started_ms: int = Time.get_ticks_msec()
	var report: PackedStringArray = PackedStringArray()
	var traces_ok: int = 0
	for entry: Variant in manifest.get("traces", []):
		var info: Dictionary = entry
		var trace: Dictionary = _read_json(TRACE_DIR.path_join(String(info.get("file", ""))))
		var mismatches: PackedStringArray = _replay(trace)
		if check(mismatches.is_empty(), "%s (%s): %d mismatches" % [info.get("id"), info.get("description"), mismatches.size()]):
			traces_ok += 1
		else:
			for i: int in mini(mismatches.size(), MAX_REPORTED_PER_TRACE):
				report.append("  %s %s" % [info.get("id"), mismatches[i]])
	check_eq(traces_ok, EXPECTED_TRACES, "traces matching the reference")
	if not report.is_empty():
		fail("first mismatches per trace (trace, hour, field, reference, ours):\n" + "\n".join(report))
	print("  DIFF-01: %d of %d traces match, %.1f s (Mac estimate)"
			% [traces_ok, EXPECTED_TRACES, (Time.get_ticks_msec() - started_ms) / 1000.0])


## Replays one schedule exactly like sim.py run_schedule: per minute k, apply that minute's
## events in listed order, take the row if k % 60 == 0, then step if k < end.
func _replay(trace: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var fixture: StringName = START_FIXTURE.get(String(trace.get("start", "")), &"")
	var state: Object = null if fixture.is_empty() else _fixtures.call(fixture)
	var env: Object = _env_script.call(&"make", 22.0, 50.0, &"loose_lid", &"classic_jar")
	if state == null or env == null:
		out.append("could not build the start state or environment")
		return out
	var events_by_minute: Dictionary = {}
	for event: Variant in trace.get("events", []):
		var e: Dictionary = event
		var minute: int = roundi(float(e.get("t_h", 0.0)) * 60.0)
		if not events_by_minute.has(minute):
			events_by_minute[minute] = []
		(events_by_minute[minute] as Array).append(e)
	var rows: Array = trace.get("rows", [])
	var end_minute: int = roundi(float(trace.get("end_h", 0.0)) * 60.0)
	var labels_before: PackedStringArray = PackedStringArray()
	var pending_row: Dictionary = {}
	var pending_labels: PackedStringArray = PackedStringArray()
	for k: int in range(end_minute + 1):
		for event: Variant in events_by_minute.get(k, []):
			env = _apply_event(state, env, event as Dictionary)
		var at_hour: bool = k % 60 == 0
		if k % 60 == 59 or k % 60 == 1 or at_hour:
			var labels: PackedStringArray = _labels(state, env)
			if k % 60 == 1 and not pending_row.is_empty():
				_compare_labels(pending_row, labels_before, pending_labels, labels, out)
				pending_row = {}
			if k % 60 == 59:
				labels_before = labels
			if at_hour:
				var row: Dictionary = rows[int(k / 60.0)]
				_compare_fields(row, state.call(&"to_dict") as Dictionary, out)
				pending_row = row
				pending_labels = labels
				if k == 0:
					labels_before = labels
		if k < end_minute:
			_sim.call(&"step", state, env, 60.0)
	if not pending_row.is_empty():
		_compare_labels(pending_row, labels_before, pending_labels, PackedStringArray(), out)
	return out


func _apply_event(state: Object, env: Object, e: Dictionary) -> Object:
	if String(e.get("kind", "")) == "env":
		return _env_script.call(&"make", float(e.get("temp_c")), float(e.get("rh")),
				StringName(e.get("cover")), StringName(e.get("container")))
	var flours: Dictionary[StringName, float] = {}
	var raw: Dictionary = e.get("flours", {})
	for key: Variant in raw:
		flours[StringName(key)] = float(raw[key])
	_sim.call(&"feed", state, float(e.get("kept_g")), flours, float(e.get("water_g")),
			float(e.get("feed_u")), bool(e.get("stir_in")))
	return env


func _labels(state: Object, env: Object) -> PackedStringArray:
	var derived: Object = _deriver.call(&"derive", state, env)
	var out: PackedStringArray = PackedStringArray()
	for label: String in LABELS:
		out.append("" if derived == null else String(derived.get(label)))
	return out


func _compare_fields(row: Dictionary, ours: Dictionary, out: PackedStringArray) -> void:
	for field: String in STORED:
		_compare_value("h%s %s" % [row.get("t_h"), field], row[field], ours.get(field), out)


func _compare_value(where: String, ref: Variant, got: Variant, out: PackedStringArray) -> void:
	match typeof(ref):
		TYPE_FLOAT, TYPE_INT:
			if not typeof(got) in [TYPE_FLOAT, TYPE_INT]:
				out.append("%s: reference %s, ours %s (type %s)" % [where, show(ref), str(got), type_string(typeof(got))])
			elif not is_close(float(got), float(ref), REL_TOL, ABS_TOL):
				out.append("%s: reference %s, ours %s" % [where, show(ref), show(float(got))])
		TYPE_BOOL:
			if typeof(got) != TYPE_BOOL or bool(got) != bool(ref):
				out.append("%s: reference %s, ours %s" % [where, str(ref), str(got)])
		TYPE_DICTIONARY:
			if typeof(got) != TYPE_DICTIONARY:
				out.append("%s: reference %s, ours %s" % [where, str(ref), str(got)])
				return
			var ours: Dictionary = {}
			for key: Variant in (got as Dictionary):
				ours[String(key)] = (got as Dictionary)[key]
			var keys: Array = (ref as Dictionary).keys()
			if ours.size() != keys.size():
				out.append("%s: reference keys %s, ours %s" % [where, str(keys), str(ours.keys())])
			for key: Variant in keys:
				_compare_value("%s.%s" % [where, key], (ref as Dictionary)[key], ours.get(String(key)), out)
		_:
			out.append("%s: unexpected reference type %s" % [where, type_string(typeof(ref))])


func _compare_labels(row: Dictionary, before: PackedStringArray, at: PackedStringArray,
		after: PackedStringArray, out: PackedStringArray) -> void:
	for i: int in LABELS.size():
		var ref: Variant = row.get(LABELS[i])
		var want: String = "" if ref == null else String(ref)
		if at[i] == want:
			continue
		var near_transition: bool = (before.size() > i and before[i] == want) \
				or (after.size() > i and after[i] == want)
		if not near_transition:
			out.append("h%s %s: reference \"%s\", ours \"%s\" (not within one step of a transition)"
					% [row.get("t_h"), LABELS[i], want, at[i]])


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parser: JSON = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return {}
	return parser.data
