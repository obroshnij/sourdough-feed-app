class_name StatusStyle
extends RefCounted
## How each canonical state looks on the status pill (ux-design §11): an icon shape, a tone, and a pill kind.
## The word comes from Keys.status_word(). Status is never shown by color alone (CLAUDE.md rule 7).

enum Kind { NORMAL, PEAK, CARE, STOP }

## The 11 canonical state ids from vision.md.
const STATES: Array[StringName] = [
	&"freshly_fed", &"developing", &"active", &"near_peak", &"at_peak", &"collapsing",
	&"hungry", &"dormant", &"recovering", &"unhealthy", &"moldy",
]

const TONES: Dictionary[StringName, StringName] = {
	&"freshly_fed": &"good", &"developing": &"good", &"active": &"good", &"near_peak": &"good",
	&"at_peak": &"good", &"collapsing": &"watch", &"hungry": &"watch", &"dormant": &"rest",
	&"recovering": &"rest", &"unhealthy": &"care", &"moldy": &"stop",
}

## The state's main cue, for the explainer's "Show me" (Bus.camera_focus_requested targets).
const SHOW_ME: Dictionary[StringName, StringName] = {
	&"freshly_fed": &"height", &"developing": &"bubbles", &"active": &"bubbles", &"near_peak": &"height",
	&"at_peak": &"height", &"collapsing": &"height", &"hungry": &"surface", &"dormant": &"surface",
	&"recovering": &"bubbles", &"unhealthy": &"surface", &"moldy": &"surface",
}

## Feed gets the halo and dot badge in these states (ux-design §4).
const FEED_EMPHASIS: Array[StringName] = [&"hungry", &"collapsing"]


static func tone(state_id: StringName) -> StringName:
	return TONES.get(state_id, &"good")


static func kind(state_id: StringName) -> Kind:
	match state_id:
		&"at_peak":
			return Kind.PEAK
		&"unhealthy":
			return Kind.CARE
		&"moldy":
			return Kind.STOP
	return Kind.NORMAL


## Care and stop pills use the filled icon (art-director: pills are outline, except care and stop).
static func filled_icon(state_id: StringName) -> bool:
	var k: Kind = kind(state_id)
	return k == Kind.CARE or k == Kind.STOP


static func show_me_target(state_id: StringName) -> StringName:
	return SHOW_ME.get(state_id, &"home")
