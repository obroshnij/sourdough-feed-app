class_name SafeInsets
extends RefCounted
## Safe-area insets in UI units (pt), with the floors from ux-design §2 and D-036:
## - HUD plate top = safe top + 8. Action bar bottom = safe bottom + 8. Side gutters 16 plus side insets.
## - Android: Godot can't tell gesture navigation from 3-button navigation, and the reported safe area may
##   leave out the navigation bar, so the bottom is max(reported, 48). The bar gap is then at least 56 dp.
## Read again on resume and on resize (ux-design §19.4).

const EDGE_GAP: float = 8.0
const GUTTER: float = 16.0
const ANDROID_BOTTOM_FLOOR: float = 48.0

var top: float = 0.0
var bottom: float = 0.0
var left: float = 0.0
var right: float = 0.0


static func make(t: float, b: float, l: float = 0.0, r: float = 0.0) -> SafeInsets:
	var s := SafeInsets.new()
	s.top = t
	s.bottom = b
	s.left = l
	s.right = r
	return s


## From the display, in pt (pixels divided by `px_per_pt`), with the platform floors. Desktop runs get zero
## insets: the desktop safe area describes the monitor, not the window.
static func from_display(px_per_pt: float) -> SafeInsets:
	var s := SafeInsets.new()
	if not OS.has_feature("mobile"):
		return s
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var screen: Vector2i = DisplayServer.screen_get_size()
	var k: float = maxf(px_per_pt, 0.01)
	s.top = maxf(float(safe.position.y), 0.0) / k
	s.left = maxf(float(safe.position.x), 0.0) / k
	s.bottom = maxf(float(screen.y - safe.end.y), 0.0) / k
	s.right = maxf(float(screen.x - safe.end.x), 0.0) / k
	return s.with_floors(OS.get_name())


func with_floors(os_name: String) -> SafeInsets:
	var s: SafeInsets = make(top, bottom, left, right)
	if os_name == "Android":
		s.bottom = maxf(s.bottom, ANDROID_BOTTOM_FLOOR)
	return s


func hud_top() -> float:
	return top + EDGE_GAP


## Space between the screen bottom and the action bar plate.
func bar_gap() -> float:
	return bottom + EDGE_GAP


func gutter_left() -> float:
	return GUTTER + left


func gutter_right() -> float:
	return GUTTER + right
