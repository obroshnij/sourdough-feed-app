class_name Unlocks
extends RefCounted
## What the player can pick (progression.md §3). Unlocks pace information, not power. They are per player:
## they survive a lost starter (PlayerHistory.unlocks is never reset by a new starter). Pure.
##
## Always open: white_bread, counter, warm_spot, fridge, height, bubbles, surface, and 100% hydration.
## Earned (canonical ids, plus `hydration` for the 60 and 125% presets):
##   whole_wheat    the first real-time peak (a feed, then at_peak)
##   window_sill    a fridge wake, or stage steady
##   rye, hydration, consistency, development    stage steady
##   spelt, proofing_box    stage mature
## The skip path ("I've kept a starter before") opens everything at once (game-design §3).
## Each new unlock writes one journal line (UNLOCK_<ID>_TOAST, body UNLOCK_<ID>_BODY); consistency and
## development share UNLOCK_INSPECT_*.

const BASE: Array[StringName] = [
	&"white_bread", &"counter", &"warm_spot", &"fridge", &"height", &"bubbles", &"surface",
]
## Earned ids in the order they are journaled when several open at once.
const EARNED: Array[StringName] = [
	&"whole_wheat", &"window_sill", &"rye", &"hydration", &"consistency", &"development", &"spelt",
	&"proofing_box",
]
const STEADY: float = 0.33
const MATURE: float = 0.50


static func is_open(unlocks: Dictionary[StringName, int], id: StringName) -> bool:
	return BASE.has(id) or unlocks.has(id)


## The earned ids whose conditions hold now and that aren't open yet, in EARNED order. `maturity` is the
## current starter's; `peaks` and `fridge_wakes` say whether it ever peaked or left the fridge cold.
static func due(unlocks: Dictionary[StringName, int], maturity: float, has_peaked: bool,
		had_fridge_wake: bool) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in EARNED:
		if unlocks.has(id):
			continue
		var ok: bool = false
		match id:
			&"whole_wheat":
				ok = has_peaked
			&"window_sill":
				ok = had_fridge_wake or maturity >= STEADY
			&"rye", &"hydration", &"consistency", &"development":
				ok = maturity >= STEADY
			&"spelt", &"proofing_box":
				ok = maturity >= MATURE
		if ok:
			out.append(id)
	return out


## The journal line for an unlock: UNLOCK_<ID>_TOAST. consistency and development share UNLOCK_INSPECT.
static func toast_key(id: StringName) -> StringName:
	return StringName("UNLOCK_%s_TOAST" % _key_part(id))


static func body_key(id: StringName) -> StringName:
	return StringName("UNLOCK_%s_BODY" % _key_part(id))


static func _key_part(id: StringName) -> String:
	if id == &"consistency" or id == &"development":
		return "INSPECT"
	return String(id).to_upper()
