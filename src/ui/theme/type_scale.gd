class_name TypeScale
extends RefCounted
## The type scale from ux-design.md §17, in pt at each in-app text size. Text size scales these Theme font
## sizes only, never content_scale_factor (architecture.md §9.1), so touch targets don't balloon.

enum Role { TITLE, BUTTON, BODY, BAR_LABEL, BAR_POPUP }

## Standard 100%, Large 125%, Largest 150%. Same values as SettingsStore.TEXT_SCALES.
const SCALES: Array[float] = [1.0, 1.25, 1.5]

## Role -> [100%, 125%, 150%]. Name, card and sheet titles; status word and buttons; body, hint, chip and
## toast; action bar label (capped at 16). The long-press popup shows the bar label at 200% (28).
const SIZES: Dictionary[Role, Array] = {
	Role.TITLE: [20, 25, 30],
	Role.BUTTON: [17, 21, 26],
	Role.BODY: [16, 20, 24],
	Role.BAR_LABEL: [14, 16, 16],
	Role.BAR_POPUP: [28, 28, 28],
}

## Line height: 1.35 for body text, 1.2 for titles and buttons.
const BODY_LINE_HEIGHT: float = 1.35
const TITLE_LINE_HEIGHT: float = 1.2


## The nearest supported scale index for a stored text_scale.
static func index_of(text_scale: float) -> int:
	var best: int = 0
	for i: int in SCALES.size():
		if absf(SCALES[i] - text_scale) < absf(SCALES[best] - text_scale):
			best = i
	return best


static func size(role: Role, text_scale: float) -> int:
	var row: Array = SIZES[role]
	var v: int = row[index_of(text_scale)]
	return v
