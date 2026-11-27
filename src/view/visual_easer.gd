class_name VisualEaser
extends RefCounted
## Live VisualParams easing (art-direction.md §8): every field follows the sim's latest values with a
## critically damped spring that settles in about SETTLE_S, so a state change never snaps. Pure: the
## caller passes dt. Feeds snap the fields they change (feeds are animated events, §8 exempt).
## Non-uniform fields (cover) and time_override copy straight through.

const SETTLE_S: float = 1.5
## Critically damped: x(t) = (x0 + (v0 + w x0) t) e^(-w t). w t = 4.74 leaves 5% of a step.
const OMEGA: float = 4.74 / SETTLE_S
const EPS: float = 1e-5

var goal: VisualParams = VisualParams.new()
var shown: VisualParams = VisualParams.new()
var _vel: Dictionary[StringName, float] = {}
var _tint_vel: Vector3 = Vector3.ZERO


## Fields the spring moves (every float uniform; tint is handled per channel).
static func eased_fields() -> Array[StringName]:
	var out: Array[StringName] = []
	for u: StringName in VisualParams.UNIFORMS:
		if u != &"tint" and u != &"time_override":
			out.append(u)
	return out


func set_goal(p: VisualParams) -> void:
	goal = p.copy()
	shown.cover = goal.cover
	shown.time_override = goal.time_override


## Jump straight to the goal (first show, scrubber, end of a time-lapse).
func snap() -> void:
	shown = goal.copy()
	_vel.clear()
	_tint_vel = Vector3.ZERO


## Jump only some fields (a feed changes level, rise and lumps at once, §8).
func snap_fields(fields: Array[StringName]) -> void:
	for f: StringName in fields:
		shown.set(f, goal.get(f))
		_vel[f] = 0.0


func is_settled() -> bool:
	for f: StringName in eased_fields():
		if absf(float(shown.get(f)) - float(goal.get(f))) > EPS or absf(_vel.get(f, 0.0)) > EPS:
			return false
	var dt: Color = shown.tint - goal.tint
	return absf(dt.r) + absf(dt.g) + absf(dt.b) < EPS


func step(dt: float) -> VisualParams:
	if dt <= 0.0:
		return shown
	for f: StringName in eased_fields():
		var x: float = float(shown.get(f)) - float(goal.get(f))
		var r: Vector2 = _spring(x, _vel.get(f, 0.0), dt)
		shown.set(f, float(goal.get(f)) + r.x)
		_vel[f] = r.y
	var tx := Vector3(shown.tint.r - goal.tint.r, shown.tint.g - goal.tint.g, shown.tint.b - goal.tint.b)
	var cr: Vector2 = _spring(tx.x, _tint_vel.x, dt)
	var cg: Vector2 = _spring(tx.y, _tint_vel.y, dt)
	var cb: Vector2 = _spring(tx.z, _tint_vel.z, dt)
	shown.tint = Color(goal.tint.r + cr.x, goal.tint.g + cg.x, goal.tint.b + cb.x, goal.tint.a)
	_tint_vel = Vector3(cr.y, cg.y, cb.y)
	shown.cover = goal.cover
	shown.time_override = goal.time_override
	return shown


## Exact critically damped step of offset x with velocity v. Returns (x, v).
static func _spring(x: float, v: float, dt: float) -> Vector2:
	if absf(x) < EPS and absf(v) < EPS:
		return Vector2.ZERO
	var e: float = exp(-OMEGA * dt)
	var c: float = v + OMEGA * x
	var nx: float = (x + c * dt) * e
	var nv: float = (c - OMEGA * (x + c * dt)) * e
	return Vector2(nx, nv)
