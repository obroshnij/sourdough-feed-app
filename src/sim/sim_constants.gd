class_name SimConstants
extends RefCounted
## Spec v1 numbers (docs/starter-simulation-spec.md) and the canonical ids (docs/vision.md).
## The parameter tables mirror the `P`, `FLOURS`, `COVER_DRY`, `CONTAINER_DRY` and `LOCATIONS` tables in
## tools/sim-reference/sim.py exactly. Change them only together with the spec and the reference.

# --- time grid (architecture.md §5.1)
const DT_S: float = 60.0
const GRID_S: int = 60
const CATCH_UP_CAP_S: int = 14 * 86400
const CATCH_UP_CAP_STEPS: int = 20160
const AWAY_SUMMARY_MIN_S: int = 3600

# --- temperature response (spec §3)
const Y_TMIN: float = 8.0
const Y_TOPT: float = 27.0
const Y_TMAX: float = 36.0
const L_TMIN: float = 3.5
const L_TOPT: float = 32.5
const L_TMAX: float = 41.0
const TAU_H: float = 1.5
const T_ENV_MIN: float = 0.0
const T_ENV_MAX: float = 40.0

# --- rates (spec §7, §19)
const MU_Y: float = 0.405
const MU_L: float = 0.540
const KS_FOOD: float = 0.03
const CAP: float = 1.5
const POP_FLOOR: float = 0.001
const DEATH_Y: float = 0.012
const DEATH_L: float = 0.006
const EAT: float = 0.16
const LAB_GAS: float = 0.35
const GAS_GAIN: float = 0.45
const LEAK: float = 0.085
const LEAK_ACID: float = 0.5
const ACID_RATE: float = 0.22
const ACID_STARVE: float = 0.02
const L_ACID_STOP: float = 0.95
const Y_ACID_STOP: float = 1.15
const HOOCH_RATE: float = 0.022
const HOOCH_DELAY_H: float = 6.0
const VIGOR_GRACE_H: float = 8.0
const VIGOR_LOSS: float = 0.0075
const VIGOR_GAIN: float = 0.11
const VIGOR_FLOOR: float = 0.15
const MOLD_ONSET_H: float = 24.0
const MOLD_RATE: float = 0.0070
const MOLD_MULT_CAP: float = 2.2
const MOLD_SLOW: float = 0.6
const MOLD_FEED_KEEP: float = 0.3
const MOLD_DECAY: float = 0.02
const DRY_RATE: float = 0.045
const MAT_STEP: float = 0.01024
const MAT_W_CAP: float = 2.5

# --- derivation (spec §12)
const HUNGRY_FOOD: float = 0.10
const DORMANT_COLD_FERM: float = 0.30
const DORMANT_STARVED_H: float = 60.0
const RECOVER_VIGOR: float = 0.6
const RECOVER_AT_FEED: float = 0.75
const MOLD_WATCH: float = 0.3
const MOLD_WARN: float = 0.5
## spec v1.1 §13.1: a smell is "faint" when every non-musty intensity is under this (after cold damping).
const SMELL_FAINT_MAX: float = 0.30

# --- clamping ranges (spec §1)
const STARVED_H_MAX: float = 336.0
const RISE_MIN: float = 1.0
const RISE_MAX: float = 3.0

# --- tables (spec §2.2, §4). Flour columns: speed, acid, absorb, retain.
const FLOURS: Dictionary = {
	&"white_bread": [1.00, 1.00, 1.00, 1.00],
	&"whole_wheat": [1.20, 1.35, 1.12, 0.85],
	&"rye": [1.35, 1.70, 1.25, 0.65],
	&"spelt": [1.10, 1.10, 0.95, 0.85],
}
const COVER_DRY: Dictionary = {&"loose_lid": 0.35, &"cloth": 1.0, &"tight_lid": 0.05}
const CONTAINER_DRY: Dictionary = {
	&"classic_jar": 1.0, &"wide_mouth_jar": 1.3, &"ceramic_crock": 1.0, &"fermentation_vessel": 0.3,
}
## location id -> [temperature_c, humidity_pct, temperature_min_c, temperature_max_c]
const LOCATIONS: Dictionary = {
	&"counter": [22.0, 50.0, 22.0, 22.0],
	&"warm_spot": [26.0, 40.0, 26.0, 26.0],
	&"window_sill": [18.0, 55.0, 18.0, 18.0],
	&"fridge": [4.0, 70.0, 4.0, 4.0],
	&"proofing_box": [26.0, 60.0, 24.0, 30.0],
}

# --- canonical ids (vision.md). LINT-09 compares these with vision.md.
const STATES: Array[StringName] = [
	&"freshly_fed", &"developing", &"active", &"near_peak", &"at_peak", &"collapsing",
	&"hungry", &"dormant", &"recovering", &"unhealthy", &"moldy",
]
const RISE_PHASES: Array[StringName] = [
	&"hungry", &"freshly_fed", &"at_peak", &"collapsing", &"developing", &"near_peak", &"active",
]
const ACTIONS: Array[StringName] = [&"feed", &"smell", &"inspect", &"environment", &"journal"]
const FLOUR_IDS: Array[StringName] = [&"white_bread", &"whole_wheat", &"rye", &"spelt"]
const LOCATION_IDS: Array[StringName] = [&"counter", &"warm_spot", &"fridge", &"window_sill", &"proofing_box"]
const CONTAINER_IDS: Array[StringName] = [&"classic_jar", &"wide_mouth_jar", &"ceramic_crock", &"fermentation_vessel"]
const COVER_IDS: Array[StringName] = [&"loose_lid", &"cloth", &"tight_lid"]
const INSPECT_KINDS: Array[StringName] = [&"bubbles", &"consistency", &"height", &"surface", &"development"]
## Spec §13 order. Ties in the smell list sort by this order.
const DESCRIPTORS: Array[StringName] = [
	&"wet_flour", &"mildly_fruity", &"fresh_yeasty", &"yogurt", &"pleasantly_tangy",
	&"strongly_acidic", &"alcohol", &"acetone", &"cheesy", &"musty",
]
const TIERS: Array[StringName] = [&"info", &"nudge", &"attention"]
const MATURITY_STAGES: Array[StringName] = [&"young", &"steady", &"mature", &"seasoned"]
## Lower bounds of each maturity stage (spec §9).
const MATURITY_STAGE_MIN: Array[float] = [0.0, 0.33, 0.50, 0.83]


static func maturity_stage(maturity: float) -> StringName:
	var stage: StringName = MATURITY_STAGES[0]
	for i: int in MATURITY_STAGES.size():
		if maturity >= MATURITY_STAGE_MIN[i]:
			stage = MATURITY_STAGES[i]
	return stage
