class_name StarterState
extends RefCounted
## Stored starter variables (data-models.md §2, spec §1 v1). Pure data.
## Defaults are the reference model's `State()`: the seed state of spec §18.
## `flour_mix` keys are always kept in sorted order, so a save round-trip can never change the
## float summation order in `Sim.rates`.

const FLOAT_FIELDS: Array[String] = [
	"food", "food_at_feed", "yeast", "lab", "acid", "rise", "peak_rise", "peak_rate", "hooch",
	"dryness", "vigor", "vigor_at_feed", "maturity", "starved_h", "mold_risk", "temp_c",
	"since_feed_s", "mass_g", "culture_hydration", "feed_u", "feed_jitter",
]

# bookkeeping (architect, designer)
var id: String = ""
var name: String = ""
var born_unix: int = 0
var sim_time_unix: int = 0

# sim variables (spec §1)
var food: float = 0.05
var food_at_feed: float = 0.0
var yeast: float = 0.9
var lab: float = 0.95
var acid: float = 0.85
var rise: float = 1.15
var peak_rise: float = 2.2
var peak_rate: float = 0.5
var hooch: float = 0.0
var dryness: float = 0.0
var vigor: float = 1.0
var vigor_at_feed: float = 1.0
var maturity: float = 0.6
var starved_h: float = 0.0
var mold_risk: float = 0.0
var moldy: bool = false
var temp_c: float = 22.0
var since_feed_s: float = 0.0
var mass_g: float = 100.0
var culture_hydration: float = 100.0
var flour_mix: Dictionary[StringName, float] = {&"white_bread": 1.0}
var feed_u: float = 0.5
var feed_jitter: float = 1.0


## Sets `sim_time_unix` to grid(now) and `born_unix` to now (data-models §2.1). Relative fields are untouched.
## The caller also clears `PlayerHistory.recent_feed_unix`.
func rebase_to(now_unix: int) -> void:
	sim_time_unix = now_unix - posmod(now_unix, SimConstants.GRID_S)
	born_unix = now_unix


## The `starter_seed` of game-copy §1.4 (name suggestions, epitaph): a non-negative int from the starter's
## 16-hex id, fixed for the starter's life. 0 for an empty or non-hex id.
static func seed_of(starter_id: String) -> int:
	var head: String = starter_id.substr(0, 7)
	if head.is_empty() or not head.is_valid_hex_number():
		return 0
	return head.hex_to_int()


## Replaces flour_mix with the same entries in sorted key order.
func set_flour_mix(mix: Dictionary[StringName, float]) -> void:
	var names: PackedStringArray = []
	for k: StringName in mix:
		names.append(String(k))
	names.sort()
	var sorted_mix: Dictionary[StringName, float] = {}
	for n: String in names:
		sorted_mix[StringName(n)] = mix[StringName(n)]
	flour_mix = sorted_mix


func copy() -> StarterState:
	var s := StarterState.new()
	s.id = id
	s.name = name
	s.born_unix = born_unix
	s.sim_time_unix = sim_time_unix
	s.food = food
	s.food_at_feed = food_at_feed
	s.yeast = yeast
	s.lab = lab
	s.acid = acid
	s.rise = rise
	s.peak_rise = peak_rise
	s.peak_rate = peak_rate
	s.hooch = hooch
	s.dryness = dryness
	s.vigor = vigor
	s.vigor_at_feed = vigor_at_feed
	s.maturity = maturity
	s.starved_h = starved_h
	s.mold_risk = mold_risk
	s.moldy = moldy
	s.temp_c = temp_c
	s.since_feed_s = since_feed_s
	s.mass_g = mass_g
	s.culture_hydration = culture_hydration
	s.flour_mix = flour_mix.duplicate()
	s.feed_u = feed_u
	s.feed_jitter = feed_jitter
	return s


func to_dict() -> Dictionary:
	var d: Dictionary = {
		"id": id,
		"name": name,
		"born_unix": born_unix,
		"sim_time_unix": sim_time_unix,
		"moldy": moldy,
	}
	for f: String in FLOAT_FIELDS:
		d[f] = get(f)
	var mix: Dictionary = {}
	for k: StringName in flour_mix:
		mix[String(k)] = flour_mix[k]
	d["flour_mix"] = mix
	return d


## Returns null on any missing key, wrong type or unknown flour id. Never logs an error.
static func from_dict(d: Dictionary) -> StarterState:
	var r := DictReader.new(d)
	var s := StarterState.new()
	s.id = r.text("id")
	s.name = r.text("name")
	s.born_unix = r.integer("born_unix")
	s.sim_time_unix = r.integer("sim_time_unix")
	s.moldy = r.flag("moldy")
	for f: String in FLOAT_FIELDS:
		s.set(f, r.num(f))
	var mix: Dictionary[StringName, float] = r.num_map("flour_mix")
	if not r.ok or mix.is_empty():
		return null
	for k: StringName in mix:
		if not SimConstants.FLOURS.has(k):
			return null
	s.set_flour_mix(mix)
	return s
