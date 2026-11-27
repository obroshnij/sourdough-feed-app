extends TestCase
## Finger tracking (ux-design.md §6 thresholds): taps, double taps, our own pinch, cancel.

var g: TouchGestures
var taps: int = 0
var doubles: int = 0
var pinches: Array[float] = []
var orbits: Array[Vector2] = []


func before_each() -> void:
	g = TouchGestures.new()
	taps = 0
	doubles = 0
	pinches = []
	orbits = []
	g.tapped.connect(func(_p: Vector2) -> void: taps += 1)
	g.double_tapped.connect(func(_p: Vector2) -> void: doubles += 1)
	g.pinched.connect(func(s: float) -> void: pinches.append(s))
	g.orbited.connect(func(d: Vector2) -> void: orbits.append(d))


## Breaks a reference cycle: g's signals hold lambdas that capture this test, and this test holds g. Without
## it, the run ended with "6 ObjectDB instances were leaked at exit" (QA, OD-34).
func after_each() -> void:
	g = null


func test_tap_within_slop_and_time() -> void:
	g.press(0, Vector2(10, 10), 0)
	g.move(0, Vector2(16, 10), 50)
	g.release(0, Vector2(16, 10), 120)
	check_eq(taps, 1, "a 6 pt wiggle is still a tap")
	g.press(0, Vector2(10, 10), 1000)
	g.move(0, Vector2(25, 10), 1050)
	g.release(0, Vector2(25, 10), 1100)
	check_eq(taps, 1, "15 pt of travel is a drag")


func test_double_tap_window_and_distance() -> void:
	g.press(0, Vector2(100, 100), 0)
	g.release(0, Vector2(100, 100), 50)
	g.press(0, Vector2(110, 110), 300)
	g.release(0, Vector2(110, 110), 340)
	check_eq(doubles, 1, "two taps 290 ms and 14 pt apart")
	check_eq(taps, 2, "both taps still reported, so a poke never waits")
	g.press(0, Vector2(100, 100), 2000)
	g.release(0, Vector2(100, 100), 2050)
	g.press(0, Vector2(140, 100), 2200)
	g.release(0, Vector2(140, 100), 2250)
	check_eq(doubles, 1, "40 pt apart is not a double tap")


func test_pinch_reports_span_ratio() -> void:
	g.press(0, Vector2(100, 100), 0)
	g.press(1, Vector2(200, 100), 0)
	g.move(1, Vector2(300, 100), 10)
	check_eq(pinches.size(), 1, "one pinch step")
	check_close(pinches[0], 2.0, 0.0, 1e-6, "span 100 to 200 pt")
	check_eq(orbits.size(), 0, "no orbit while two fingers are down")
	g.release(1, Vector2(300, 100), 20)
	g.release(0, Vector2(100, 100), 20)
	check_eq(taps, 0, "a pinch is never a tap")


func test_unclaimed_finger_is_ignored() -> void:
	g.press(0, Vector2(100, 100), 0)
	g.move(5, Vector2(300, 300), 10)
	g.release(5, Vector2(300, 300), 20)
	check(g.is_claimed(0), "the claimed finger stays")
	check_eq(g.fingers.size(), 1, "finger 5 never joined")


func test_cancel_never_taps_and_frees_every_finger() -> void:
	g.press(0, Vector2(100, 100), 0)
	g.release(0, Vector2(100, 100), 40, true)
	check_eq(taps, 0, "a canceled touch is not a tap")
	g.press(0, Vector2(100, 100), 100)
	g.press(1, Vector2(150, 100), 100)
	g.cancel_all()
	check(not g.active(), "no finger left claimed")
