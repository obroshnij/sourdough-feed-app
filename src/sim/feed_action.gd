class_name FeedAction
extends GameAction
## A feed (data-models.md §4, spec §2.1 and §6). Carries grams, so the sim and journal never depend on UI math.

const TARGET_TOTAL_G: float = 150.0
## game-mechanics §2.3 gives 154 g for 1:5:5 (flour and water rounded to 5 g); data-models §4 says
## within 1 g of 150. This tolerance admits the designer's presets. Open decision for the director.
const MASS_TOLERANCE_G: float = 5.0
const HYDRATION_MIN: float = 40.0
const HYDRATION_MAX: float = 200.0
const HOOCH_CHOICES: Array[StringName] = [&"pour_off", &"stir_in"]

var kept_g: float = 50.0
var flour_g: Dictionary[StringName, float] = {}
var water_g: float = 50.0
## Spec §2.1 `hooch_choice`. Not in data-models v0; added from the spec. Both end with hooch 0.
var hooch_choice: StringName = &"pour_off"


func _init() -> void:
	kind = &"feed"


## The slice's derived discard (game-mechanics §2.3): ratio 1 : f : w, total fixed at 150 g.
static func from_ratio(f: float, w: float, flour_id: StringName, hydration_pct: float = 100.0,
		target_total_g: float = TARGET_TOTAL_G) -> FeedAction:
	var a := FeedAction.new()
	var keep: float = roundf(target_total_g / (1.0 + f + w))
	var flour: float = keep * f
	var water: float = flour * hydration_pct / 100.0
	if f >= 5.0:
		flour = roundf(flour / 5.0) * 5.0
		water = roundf(water / 5.0) * 5.0
	a.kept_g = keep
	a.flour_g = {flour_id: flour}
	a.water_g = water
	return a


func flour_total_g() -> float:
	var total: float = 0.0
	for k: StringName in flour_g:
		total += flour_g[k]
	return total


func mass_after_g() -> float:
	return kept_g + flour_total_g() + water_g


func hydration_pct() -> float:
	var f: float = flour_total_g()
	return water_g / f * 100.0 if f > 0.0 else 0.0


## The ratio as 1 : x : y, returned as Vector2(x, y).
func ratio() -> Vector2:
	if kept_g <= 0.0:
		return Vector2.ZERO
	return Vector2(flour_total_g() / kept_g, water_g / kept_g)


func validate(state: StarterState, _env: EnvironmentState, _catalog: SimCatalog) -> StringName:
	if state.moldy:
		return REASON_MOLDY
	if kept_g < 1.0 or kept_g > state.mass_g:
		return REASON_KEEP_RANGE
	if flour_g.is_empty():
		return REASON_FLOUR
	for k: StringName in flour_g:
		if not SimConstants.FLOURS.has(k) or flour_g[k] < 0.0:
			return REASON_FLOUR
	if flour_total_g() <= 0.0:
		return REASON_FLOUR
	if water_g < 0.0:
		return REASON_WATER
	var h: float = hydration_pct()
	if h < HYDRATION_MIN or h > HYDRATION_MAX:
		return REASON_WATER
	if absf(mass_after_g() - TARGET_TOTAL_G) > MASS_TOLERANCE_G:
		return REASON_MASS
	if not HOOCH_CHOICES.has(hooch_choice):
		return REASON_HOOCH_CHOICE
	return &""


func to_dict() -> Dictionary:
	var flours: Dictionary = {}
	for k: StringName in flour_g:
		flours[String(k)] = flour_g[k]
	var r: Vector2 = ratio()
	return {
		"kind": "feed",
		"kept_g": kept_g,
		"flour_g": flours,
		"water_g": water_g,
		"hooch_choice": String(hooch_choice),
		"ratio_flour": r.x,
		"ratio_water": r.y,
		"hydration_pct": hydration_pct(),
	}
