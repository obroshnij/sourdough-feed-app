class_name SliceCase
extends TestCase
## Base for the AC integration tests in tests/integration/. Makes harnesses (one per simulated phone)
## and frees them after each test, so no test sees another's files or Session.

const T0: int = SliceHarness.T0
const MIN: int = SliceHarness.MIN
const HOUR: int = SliceHarness.HOUR
const DAY: int = SliceHarness.DAY
const CAP_S: int = SliceHarness.CAP_S
## Spec §18 drift allowances on top of a vector's range: hours, rise.
const TOL_H: float = 0.3
const TOL_RISE: float = 0.05
## art-direction §8: the largest change per 60 s step that doesn't read as a pop (PROP-10). Feeds and
## entering moldy are exempt. `peak_line` must not drop within a cycle; `mold` is 0 until moldy.
const MAX_DELTA: Dictionary[String, float] = {
	"rise": 0.02, "dome": 0.03, "lumps": 0.03, "bubble_density": 0.03, "bubble_size": 0.02,
	"activity": 0.05, "streak_amount": 0.05, "hooch_depth": 0.02, "surface_dryness": 0.02,
	"sheen": 0.03, "dullness": 0.02,
}
const TINT_MAX_DELTA: float = 0.02

var _harnesses: Array[SliceHarness] = []


func before_each() -> void:
	# The root only takes children once the first frame has run.
	await (Engine.get_main_loop() as SceneTree).process_frame


func after_each() -> void:
	for h: SliceHarness in _harnesses:
		h.dispose()
	_harnesses.clear()


## A new phone. Integration tests need T1's real sim, saves and catch-up.
func phone(label: String, start_unix: int = T0, utc_offset_s: int = 0) -> SliceHarness:
	var h := SliceHarness.new(label, start_unix, utc_offset_s)
	_harnesses.append(h)
	return h


## A phone holding the MATURE fixture at the counter, launched. `rng_seed` fixes the feed draw.
func mature_phone(label: String, rng_seed: int = 1, env: EnvironmentState = null) -> SliceHarness:
	var h: SliceHarness = phone(label)
	check_eq(h.seed_save(SliceHarness.mature(), env, rng_seed), OK, label + ": seed save written")
	h.launch()
	return h


func ready_for_integration() -> bool:
	return require(&"m2_sim") and require(&"m4_save") and require(&"m5_catchup")


## A 1:1:1 white_bread feed, the slice's default.
static func feed_111(flour: StringName = &"white_bread") -> FeedAction:
	return FeedAction.from_ratio(1.0, 1.0, flour)


## Hours since T0, for messages.
static func hours(unix: int) -> String:
	return "%.2f h" % (float(unix - T0) / float(HOUR))


## The fields that moved more than max_delta from `a` to `b`, as "field +delta". Empty when calm.
static func pops_between(a: VisualParams, b: VisualParams) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var da: Dictionary = a.to_dict()
	var db: Dictionary = b.to_dict()
	for field: String in MAX_DELTA:
		var delta: float = absf(float(db[field]) - float(da[field]))
		if delta > MAX_DELTA[field] + 1e-12:
			out.append("%s +%.4f" % [field, delta])
	for c: int in 3:
		if absf(b.tint[c] - a.tint[c]) > TINT_MAX_DELTA + 1e-12:
			out.append("tint[%d]" % c)
	if b.peak_line < a.peak_line:
		out.append("peak_line dropped")
	return out
