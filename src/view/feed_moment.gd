class_name FeedMoment
extends RefCounted
## Feed sequence visuals (Bus.feed_moment, art-direction.md §8). Pure: the caller passes dt and reads
## the outputs. It only animates between sim states: the fed state itself still comes from Session.
##   hooch    the lid lifts at the first beat into the jar, the level dips a little
##   discard  the lid lifts if it isn't up yet; the level drops (0.6 s, ease-in)
##   scoop    flour dust lands at +0.45 s, where feed_scoop.wav lands the flour (audio-direction §6)
##   pour     water: the level comes back with a damped wobble (0.8 s, 2 oscillations)
##   stir     lumps jump toward the fed look
##   settle   T1's last beat: the band snaps (0.35 s, ease-out back, 6% overshoot), lid lowers
## If the fed state never arrives, everything eases back after TIMEOUT_S.

const DISCARD_S: float = 0.6
const DISCARD_TO: float = 0.45
const LID_S: float = 0.5
const POUR_S: float = 0.8
const WOBBLE_MAX: float = 0.05     # rise ratio, about 1.5 mm at the 30 mm fed level
const BAND_S: float = 0.35
const BAND_OVERSHOOT: float = 0.06
const TIMEOUT_S: float = 8.0

## Multiplies the shown rise (1 = no change).
var rise_mul: float = 1.0
## 0 = lid on, 1 = lifted.
var lid: float = 0.0
## Added lumps (0..1), decays after the stir.
var lumps_add: float = 0.0
## Band move progress with overshoot, 0..1+ (1 = at the new level).
var band_t: float = 1.0
## One frame true when the pour starts (flour dust).
var dust: bool = false

var _step: StringName = &""
var _t: float = 0.0
var _from: float = 1.0
var _lid_from: float = 0.0
var _lid_to: float = 0.0
var _lid_t: float = 1.0
var _since_start: float = -1.0
var _dust_in: float = -1.0
const DUST_DELAY_S: float = 0.45


func active() -> bool:
	return _since_start >= 0.0


func begin(step: StringName) -> void:
	_step = step
	_t = 0.0
	_from = rise_mul
	if _since_start < 0.0:
		_since_start = 0.0
	match step:
		&"hooch", &"discard":
			if _lid_to < 1.0:
				_lift(1.0)
		&"scoop":
			_dust_in = DUST_DELAY_S
		&"stir":
			lumps_add = 0.6
		&"settle":
			settle()


## The fed state arrived from Session: snap the band, settle the level, lower the lid.
func settle() -> void:
	_step = &"settle"
	_t = 0.0
	_from = rise_mul
	band_t = 0.0
	_lift(0.0)


func step(dt: float) -> void:
	dust = false
	if not active():
		return
	_since_start += dt
	_t += dt
	if _dust_in >= 0.0:
		_dust_in -= dt
		if _dust_in < 0.0:
			dust = true
	match _step:
		&"discard":
			var k: float = clampf(_t / DISCARD_S, 0.0, 1.0)
			rise_mul = lerpf(_from, DISCARD_TO, k * k)
		&"hooch":
			var kh: float = clampf(_t / DISCARD_S, 0.0, 1.0)
			rise_mul = lerpf(_from, 0.92, kh * kh)
		&"pour", &"settle":
			rise_mul = _refill(_from, _t)
	if _step == &"settle":
		var kb: float = clampf(_t / BAND_S, 0.0, 1.0)
		band_t = _ease_out_back(kb)
	lumps_add = maxf(lumps_add - dt * 0.25, 0.0) if _step != &"stir" else lumps_add
	if _lid_t < 1.0:
		_lid_t = minf(_lid_t + dt / LID_S, 1.0)
		var kl: float = _lid_t * _lid_t * (3.0 - 2.0 * _lid_t)
		lid = lerpf(_lid_from, _lid_to, kl)
	if _since_start > TIMEOUT_S and _step != &"settle":
		settle()
	if _step == &"settle" and _t >= maxf(POUR_S, BAND_S) and _lid_t >= 1.0 and lumps_add <= 0.0:
		rise_mul = 1.0
		band_t = 1.0
		_since_start = -1.0
		_step = &""


## Back to 1.0 with a damped wobble: 2 oscillations over POUR_S, at most WOBBLE_MAX past 1.
static func _refill(from: float, t: float) -> float:
	var k: float = clampf(t / POUR_S, 0.0, 1.0)
	var base: float = lerpf(from, 1.0, 1.0 - pow(1.0 - k, 3.0))
	var wobble: float = WOBBLE_MAX * sin(k * TAU * 2.0) * (1.0 - k) * (1.0 - k)
	return base + wobble


static func _ease_out_back(k: float) -> float:
	# Penner's ease-out-back peaks at 4 s^3 / (27 (s + 1)^2) past 1: s = 1.285 gives the 6% of §8.
	var s: float = 1.285
	var x: float = k - 1.0
	return 1.0 + x * x * ((s + 1.0) * x + s)


func _lift(to: float) -> void:
	_lid_from = lid
	_lid_to = to
	_lid_t = 0.0
