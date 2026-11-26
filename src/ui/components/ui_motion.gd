class_name UiMotion
extends RefCounted
## Durations and easing from ux-design.md §15, with the reduce-motion fallbacks. UiRoot sets `reduce` from
## the in-app setting (the OS value can't be read on phones). Times in seconds.

static var reduce: bool = false

const SHEET_OPEN: float = 0.30
const SHEET_CLOSE: float = 0.22
const SHEET_OPEN_REDUCED: float = 0.15
const SHEET_CLOSE_REDUCED: float = 0.12
const CARD_IN: float = 0.28
const CARD_OUT: float = 0.20
const CARD_SLIDE: float = 24.0
const TOAST_IN: float = 0.22
const TOAST_OUT: float = 0.18
const TOAST_SLIDE: float = 12.0
const PRESS_IN: float = 0.08
const PRESS_OUT: float = 0.12
const PRESS_SCALE: float = 0.96
const CHIP_SELECT: float = 0.12
const STATUS_FADE: float = 0.25
const STATUS_PULSE: float = 1.06
## Toasts stay 2.5 s plus 70 ms per character, at most 7 s (ux-design §12).
const TOAST_BASE: float = 2.5
const TOAST_PER_CHAR: float = 0.07
const TOAST_MAX: float = 7.0
## Long-press on an action bar button shows the large label (ux-design §6).
const LONG_PRESS: float = 0.5
## A sheet closes on a swipe of 25% of its height or 700 pt/s (ux-design §6).
const SWIPE_FRACTION: float = 0.25
const SWIPE_SPEED: float = 700.0


static func sheet_open() -> float:
	return SHEET_OPEN_REDUCED if reduce else SHEET_OPEN


static func sheet_close() -> float:
	return SHEET_CLOSE_REDUCED if reduce else SHEET_CLOSE


static func toast_duration(text: String) -> float:
	return minf(TOAST_BASE + TOAST_PER_CHAR * text.length(), TOAST_MAX)


## The 0.96 press scale (80 ms in, 120 ms out). Reduce motion keeps the color change only.
static func press(control: Control, down: bool) -> void:
	if reduce:
		control.scale = Vector2.ONE
		return
	control.pivot_offset = control.size * 0.5
	var tw: Tween = control.create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var target: Vector2 = Vector2.ONE * (PRESS_SCALE if down else 1.0)
	tw.tween_property(control, "scale", target, PRESS_IN if down else PRESS_OUT)
