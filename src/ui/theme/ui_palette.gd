class_name UiPalette
extends RefCounted
## The UI color roles (art-direction.md §2.2, ux-design.md §16.1) with the night variant.
## `night` is Session.get_night_factor() (NightFade, D-043): 0 by day, 1 at night. Only the surfaces change at night:
## sheets and cards use surface_night, and the HUD plates use it at alpha 0.94 instead of 0.88.

const SURFACE := Color("#FBF6EC")
const SURFACE_NIGHT := Color("#EDE3D2")
const SURFACE_ALT := Color("#F1E7D6")
const INK := Color("#33241A")
const INK_MUTED := Color("#6A5444")
const ACCENT := Color("#4F6B47")
const ON_ACCENT := Color("#FFFCF5")
const OUTLINE := Color("#8A7461")
const DISABLED := Color("#8F7D6E")
## The `unhealthy` pill fill (ux-design §11 and §16.1).
const CARE_FILL := Color("#F4E4BE")

const TONE_GOOD := Color("#4F7A45")
const TONE_REST := Color("#4E6A80")
const TONE_WATCH := Color("#8A6414")
const TONE_CARE := Color("#6E4F12")
const TONE_STOP := Color("#8E2B22")
const TONES: Dictionary[StringName, Color] = {
	&"good": TONE_GOOD, &"rest": TONE_REST, &"watch": TONE_WATCH, &"care": TONE_CARE, &"stop": TONE_STOP,
}

## Plates over the 3D scene never go below 0.88 (ux-design §16.1: ink_muted fails at 0.80 at night).
const PLATE_ALPHA_DAY: float = 0.88
const PLATE_ALPHA_NIGHT: float = 0.94
const SCRIM_ALPHA: float = 0.30
const SHADOW_ALPHA: float = 0.18

var night: float = 0.0


func _init(night_blend: float = 0.0) -> void:
	night = clampf(night_blend, 0.0, 1.0)


## Sheets, cards and the base of the plates.
func surface() -> Color:
	return SURFACE.lerp(SURFACE_NIGHT, night)


## The HUD and action bar plates over the 3D scene.
func plate() -> Color:
	var c: Color = surface()
	c.a = lerpf(PLATE_ALPHA_DAY, PLATE_ALPHA_NIGHT, night)
	return c


func scrim() -> Color:
	var c: Color = INK
	c.a = SCRIM_ALPHA
	return c


func shadow() -> Color:
	var c: Color = INK
	c.a = SHADOW_ALPHA
	return c


static func tone(tone_id: StringName) -> Color:
	return TONES.get(tone_id, INK)


## Pressed fills: 8% lower lightness (ux-design §17, PrimaryButton pressed).
static func pressed(c: Color) -> Color:
	var out: Color = Color.from_ok_hsl(c.ok_hsl_h, c.ok_hsl_s, maxf(c.ok_hsl_l - 0.08, 0.0), c.a)
	return out
