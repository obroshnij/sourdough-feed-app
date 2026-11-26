# Data models

Owner: `tech-architect`. Status: **v1, synced to the T1 code** on `phase-2-foundation` (2026-11-26, D-039 to D-042). The class files in `src/sim/` and `src/core/` are the source of truth for field names; this doc gives units, ranges and rules.
Sources: `starter-simulation-spec.md` v1 (§1, §2, §4, §12, §13, §14, §16, §17), `game-designer` event and history needs (by message), `art-director` mesh contract (by message).

## 1. Conventions

| Topic | Rule |
|---|---|
| Classes | Runtime data is `RefCounted` with a `class_name`. Profiles are `Resource` subclasses, but **no `data/*.tres` file exists yet** (D-042): the numbers live in `SimConstants` and `SimCatalog.builtin()` builds the profiles in code (§3). Everything lives in `src/sim/` unless noted |
| Ids | `StringName`, exactly the canonical ids in `vision.md` |
| Time | Absolute times are `int` Unix seconds, UTC, suffix `_unix`. Durations are `float` seconds (suffix `_s`) or hours (suffix `_h`) as noted |
| Units | Grams `_g`, Celsius `_c`, percent `_pct`, meters `_m`. Unitless 0..1 fields say so |
| Ranges | The sim clamps every stored float to its range after each step. A test asserts it (property test) |
| Serialization | Each class has `to_dict() -> Dictionary` and `static from_dict(d: Dictionary) -> <Class>`. `from_dict` converts numbers explicitly (`int(d.x)`), because JSON gives back every number as a float **[ran]**. It checks `typeof()` before every read and returns null on a missing key or wrong type. Assigning a wrong-typed Variant to a typed variable logs a script error **[ran]**, which the test runner's Logger counts as a failure, so a corrupt file must fail silently |
| 64-bit ints | RNG seeds and states are saved as **decimal strings**. As JSON numbers they lose precision above 2^53 **[ran]** |
| Floats | Every `float` in the save payload is saved as a **16-character hex string of its IEEE-754 bits**: the 8 bytes from `PackedByteArray.encode_double(0, x)`, then `hex_encode()` (little-endian byte order). Examples: 0.25 is `"000000000000d03f"`, 150.0 is `"0000000000c06240"`. Reason: Godot 4.7.2's JSON number parser isn't correctly rounded (for example, 1.9469610637576158 reads back as 1.946961063757616), so about a third of doubles come back 1 ulp off (33,968 of 100,000 between 1e-6 and 1e3), even with `full_precision` **[ran]**, found by `qa-engineer`. The bit pattern round-trips exactly (0 of 100,000 off) **[ran]**. The decoder also accepts a plain JSON number for a float field (lossy), so hand-written dev fixtures stay writable. The writer always writes hex (`SaveCodec.pack_floats`, D-040) |
| Free-form dictionaries | `JournalEntry.args` and `.data` and `SimEvent.payload` go through `DictReader.canonical()` on save and load: a whole number becomes an int, so `50.0` saves as `50`. Any other float is a hex string in the file **and stays a hex string after a load**, because nothing knows its type. So a value read from these dictionaries can be a float (in memory, before any reload), an int, or a hex string. **Always read numbers from them with `DictReader.float_of(v)`**, which accepts all three (NaN for anything else). `args` are formatted straight into text (`Keys.format()`, §6), so they hold only ints, Strings and bools. A decimal in `args` would print as 16 hex characters after a reload; format it into a String first |
| Text | No player-facing text in data. Keys only (`architecture.md` §10). The player's starter name is the one exception |

## 2. `StarterState` (stored)

Sim variables follow `starter-simulation-spec.md` §1 **v1** exactly (names, units and ranges; the spec is the authority, and this table must change when it does). Rows marked "architect" or "designer" are bookkeeping that the sim equations don't read.

| Field | Type | Unit | Range | Meaning | Source |
|---|---|---|---|---|---|
| `id` | String | | 16 hex chars | Unique per starter (for memorials) | architect |
| `name` | String | | 1 to 16 chars after trim | Player-given name. 16 is the `ux-design.md` §18 name slot, and every `{name}` string is length-checked at 16 (`game-copy.md`) | architect |
| `born_unix` | int | s | | Adopted at. Calendar milestones | designer |
| `sim_time_unix` | int | s | multiple of 60 | Time this state represents. The clock anchor | architect |
| `food` | float | 0..1 | 0..1 | Fermentable food per gram of flour (1 = fresh flour) | spec |
| `food_at_feed` | float | 0..1 | 0..1 | `food` right after the last feed. Phase detection | spec |
| `yeast` | float | relative | 0.001..1.5 | Yeast population (1 = ripe mature starter) | spec |
| `lab` | float | relative | 0.001..1.5 | Lactic acid bacteria population | spec |
| `acid` | float | 0..1 | 0..1 | Normalized acidity. Display pH about `6.0 - 2.6 * acid` (tuned) | spec |
| `rise` | float | ratio | 1.0..3.0 | Height divided by height right after the last feed | spec |
| `peak_rise` | float | ratio | 1.0..3.0 | Highest rise since the last feed. Also the streak line | spec |
| `peak_rate` | float | ratio/h | >= 0 | Highest rise slope since the last feed | spec |
| `hooch` | float | 0..1 | 0..1 | Liquid layer (1 = about 1 cm) | spec |
| `dryness` | float | 0..1 | 0..1 | Skin (0.3) to crust (0.7) | spec |
| `vigor` | float | 0..1 | 0.15..1 | Culture strength. Multiplies growth and gas | spec |
| `vigor_at_feed` | float | 0..1 | 0.15..1 | `vigor` at the last feed. Drives `recovering` | spec |
| `maturity` | float | 0..1 | 0..1 | How established. Never decreases | spec |
| `starved_h` | float | weighted h | 0..336 | Temperature-weighted hours since food ran out. Reset by a feed | spec |
| `mold_risk` | float | 0..1 | 0..1 | Watch 0.3, warning 0.5, mold 1.0 | spec |
| `moldy` | bool | | | Latched when `mold_risk` reaches 1.0. Never cleared | spec |
| `temp_c` | float | °C | 0..40 | The starter's own temperature. Lags the environment (1.5 h time constant). The environment input is clamped to 0..40 too | spec |
| `since_feed_s` | float | s | >= 0 | Time since the last feed. Relative, so rebasing (§2.1) never touches it | spec |
| `mass_g` | float | g | >= 1 | Starter in the jar. Changes only at feeds | spec |
| `culture_hydration` | float | % | 40..200 | Water / flour × 100 of the culture, blended at each feed | spec |
| `flour_mix` | `Dictionary[StringName, float]` | share | each 0..1, sum 1 | Flour composition, blended at each feed | spec |
| `feed_u` | float | 0..1 | [0, 1) | The one uniform draw per feed, `sim_rng.randf()` (never `randfn`), stored. Also drives `big_bubble` (spec §14.1) | spec |
| `feed_jitter` | float | multiplier | 0.95..1.05 | `0.95 + 0.10 * feed_u`, stored | spec |

**Derived, never stored** (`StateDeriver.derive()` returns them in `DerivedState`, below): `rise_rate` (from the spec §7 equations, so no previous-step field is needed), `gas`, `ferm(temp_c)`, `activity`, `state` id, `rise_phase`, `dormant_cause`. Also derived on demand: the mold stage (`StateDeriver.mold_stage()`: `none`, `watch`, `warning`, `mold`), the smell set (`SmellModel`).

### 2.1 Start presets and rebasing
`StarterPresets.make(preset_id: StringName, now_unix: int) -> StarterState` (pure, `src/sim/starter_presets.gd`). Values from `game-mechanics.md` §8.1 and §8.2:

| `preset_id` | When | Start |
|---|---|---|
| `new_game` | First launch | `at_peak`, maturity 0.2, `counter` |
| `first_restart` | First new starter after mold | `dormant`, `temp_c` 4, `counter` |
| `restart` | Later new starters | `at_peak` |

`StarterState.rebase_to(now_unix)` sets `sim_time_unix = grid(now_unix)` and `born_unix = now_unix`. Relative fields (`since_feed_s`, `starved_h`) are unchanged. The caller, `Session.adopt_starter(state, name)`, also clears `PlayerHistory.recent_feed_unix` entries from the demo. Used after the tutorial demo (`architecture.md` §5.5). Every preset starts at the `counter` (`StarterPresets.environment_for()`).

**State derivation** (spec §12, first match wins): `moldy`, `unhealthy`, `dormant`, `hungry`, `recovering`, then the rise phases (`freshly_fed`, `developing`, `active`, `near_peak`, `at_peak`, `collapsing`). `recovering` overlaps a rise phase, so `StateDeriver.derive()` returns both:

```gdscript
class_name DerivedState extends RefCounted
var state: StringName          # one of the 11 canonical ids
var rise_phase: StringName     # a rise-phase id, even when state is recovering or hungry. &"" only when moldy
var ferm: float                # ferm(temp_c), spec §3. Not clamped: about 1.33 at 35 °C
var dormant_cause: StringName  # &"cold" or &"starved" when state is dormant (cold wins), else &""
var activity: float            # 0..1, the clamped gas term (spec §13 gas_n). Breathing and bubble motion
var rise_rate: float           # d rise / dt in x/h, from the spec §7 equations at this state
var gas: float                 # gas production (spec §7), unclamped
```

`rise_phase` is `&""` for a moldy starter because the reference model computes no phase there. Code that indexes by phase checks for it.

## 3. `EnvironmentState` (stored) and profiles

| Field | Type | Unit | Range | Notes |
|---|---|---|---|---|
| `location` | StringName | | `counter`, `warm_spot`, `window_sill`, `fridge`, `proofing_box` | `&""` only for a raw environment (`EnvironmentState.make()`, reference traces and tests). A game save always has a canonical id |
| `temperature_c` | float | °C | presets 4..30 | Effective temperature. Set from the preset when the location changes (`EnvironmentState.at_location()`). Only `proofing_box` lets the player pick, 24..30. The sim clamps its input to 0..40 |
| `humidity_pct` | float | % | presets 40..70 | Fixed per location, not a player control (D-018). `Session` fills it from the preset on every move |
| `container` | StringName | | the 4 canonical ids | MVP ships `classic_jar` only (D-019) |
| `cover` | StringName | | `loose_lid`, `cloth`, `tight_lid` | MVP is a fixed `loose_lid` (D-019) |
| `changed_unix` | int | s | | Last environment change, applied at a grid point |

Profiles (`Resource`):

| Class | Fields |
|---|---|
| `FlourProfile` | `id`, `speed_mult`, `acid_mult`, `water_absorption`, `gas_retention` (spec §4 `retain`: how well the paste holds gas), `food_value` (nothing reads it yet), `tint: Color` (for `VisualMapper`), `fleck: float` 0..1 |
| `LocationPreset` | `id`, `temperature_c`, `temperature_min_c`, `temperature_max_c`, `humidity_pct`. No daily swing in v1 |
| `ContainerProfile` | `id`, `inner_radius_m`, `inner_height_m`, `liner_height_m`, `scene_path`, `dryness_mult` (spec §2.2 `container_dry`). classic_jar v0 (art contract, 2026-11-26): outer D 84 mm, H 170 mm, wall 3.5 mm, base 8 mm, inner r 0.0385, inner height 0.162, liner top 0.125 |
| `CoverProfile` | `id`, `dryness_mult` (spec §2.2 `cover_dry`), `node_name`. The v0 `evaporation_mult` and `mold_risk_mult` are **dropped**: spec §2.2 says covers and containers change only `dryness`, and mold only through it |

**Where the numbers live (D-042).** `SimConstants` holds every sim number and table, mirroring `P`, `FLOURS`, `COVER_DRY`, `CONTAINER_DRY` and `LOCATIONS` in `tools/sim-reference/sim.py` exactly, so `qa-engineer`'s DIFF-01 has one source to check. `FLOURS` rows are `[speed, acid, absorb, retain]`. `LOCATIONS` rows are `[temperature_c, humidity_pct, temperature_min_c, temperature_max_c]`. `Sim`, `StateDeriver` and the action validators read `SimConstants` directly. `VisualMapper` reads `SimCatalog.TINTS` and `SimCatalog.FLECKS` (placeholders until art-director's per-flour values land).

**No `data/*.tres` file exists.** `SimCatalog.builtin()` builds the four profile dictionaries (`Dictionary[StringName, FlourProfile]` and so on) in code from those tables. `Session` builds it once and passes it to `validate()`, `CatchUp.run()` and `EventContext`, so data-driven profiles can replace it later without a signature change. The sim never calls `load()`. Moving numbers into `.tres` files would add a second copy to keep in sync, so it waits until a designer needs to tune without code.

Cover id to GLB node (art-director contract): `loose_lid` = `Jar_Lid_Loose`, `tight_lid` = `Jar_Lid_Tight`, `cloth` = `Cloth_Cover`.

## 4. Actions

Base `GameAction` (`RefCounted`): `kind: StringName`, `at_unix: int` (set by `Session` to the real time, never by UI), `validate(state, env, catalog) -> StringName` (`&""` means ok, otherwise a reason key). Reason keys are tr keys in the `architecture.md` §10 format, constants on `GameAction` (`REASON_KEEP_RANGE`, `REASON_MASS` and so on) with rows in `src/i18n/pending_core.csv`. A feed on a moldy starter returns narrative's `MOLD_FEED_BLOCKED`.

| Class | `kind` | Fields | Validation, in order |
|---|---|---|---|
| `FeedAction` | `feed` | `kept_g: float`, `flour_g: Dictionary[StringName, float]`, `water_g: float`, `hooch_choice: StringName` (`pour_off` default, or `stir_in`; spec §2.1) | Not moldy. `1 <= kept_g <= state.mass_g`. Flour ids canonical, each >= 0, total > 0. `water_g >= 0`. Hydration 40..200%. `abs(mass_after_g - 150) <= 5` (below). `hooch_choice` canonical |
| `SetEnvironmentAction` | `environment` | `env: EnvironmentState` (full replacement). Build with `SetEnvironmentAction.to_location(id, temperature_c = NAN)` | Not moldy (`REASON_MOLDY_LOCKED`). Ids canonical, temperature inside the preset's min..max |
| `SmellAction` | `smell` | none | Always ok |
| `InspectAction` | `inspect` | `inspect_kind: StringName` (`bubbles`, `consistency`, `height`, `surface`, `development`) | Canonical kind |
| `RenameAction` | `rename` | `new_name: String` | 1 to 16 chars after trim (`GameAction.NAME_MAX_CHARS`) |
| `AckEventAction` | `ack_event` | `event_uid: int`, `choice: StringName` (may be empty) | `event_uid > 0`. `Session` also checks the ledger, because `validate` can't see it |
| `DiscardStarterAction` | `discard_starter` | `new_name: String` (the new starter's) | Only when moldy, and a valid name |

**Hooch choice.** Both choices end with `hooch = 0`. `stir_in` adds `5 × hooch` hydration points to the kept culture. `pour_off` has no other sim effect (spec §2.1, §6, V20). The journal's feed `data` records it.

**Feed mass (D-042).** The UI builds a feed with `FeedAction.from_ratio(f, w, flour_id, hydration_pct = 100)`, the `game-mechanics.md` §2.3 formula: total after feeding near `TARGET_TOTAL_G` = 150 g, keep derived, and flour and water rounded to 5 g when `f >= 5`. The 1:5:5 preset therefore gives keep 14, flour 70, water 70, which is **154 g**. Validation allows `MASS_TOLERANCE_G` = **±5 g** around 150 (v0 said ±1 g, which rejected that preset). The action still carries grams, so the sim and the journal never depend on UI math.

`FeedAction` derived values: `flour_total_g()`, `ratio() -> Vector2` (x = `flour_total_g/kept_g`, y = `water_g/kept_g`, read as `1 : x : y`), `hydration_pct() = water_g / flour_total_g * 100`, `mass_after_g()`.

`ActionResult`: `ok: bool`, `reason_key: StringName`, `action_kind: StringName`, `readout: RefCounted` (a `SmellReadout`, `InspectionReadout` or null), `events: Array[SimEvent]`, `journal_entry: JournalEntry` (null when rejected, or when a smell or inspect was deduped per `game-mechanics.md` §4).

## 5. Events

### `SimEvent`
| Field | Type | Notes |
|---|---|---|
| `uid` | int | From `EventLedger.next_uid` |
| `id` | StringName | Rule id, for example `&"peak_now"`. Text keys come from the id in the `events-catalog.md` format, never stored: `EVENT_<ID>_TOAST`, `EVENT_<ID>_JOURNAL_TITLE`, `EVENT_<ID>_JOURNAL_BODY`, plus personality variants (`EVENT_PEAK_NOW_PATIENT`) |
| `tier` | StringName | `info`, `nudge`, `attention` |
| `created_unix` | int | Sim time of the step that fired it |
| `local_minute_of_day` | int | 0..1439 |
| `payload` | Dictionary | Primitives only (int, float, String, bool). For example `{"peak_unix": ..., "peak_rise": 2.3}`. After a load, `peak_rise` is a hex string: read numbers with `DictReader.float_of()` (§1) |
| `expires_unix` | int | 0 = never |
| `expires_if` | StringName | Condition id that drops a stale event, for example `&"state_not_hungry"`. Empty = none |
| `not_before_unix` | int | Quiet-hours deferral |
| `status` | StringName | `pending`, `shown`, `acked`, `expired` |

### `EventLedger` (saved)
`next_uid: int`, `last_fired_unix: Dictionary[StringName, int]`, `once_flags: Dictionary[StringName, bool]`, `day_key: String` (local `YYYY-MM-DD`), `day_counts: Dictionary[StringName, int]` (per tier, current local day only), `pending: Array[SimEvent]` (cap 20; the oldest `info` is dropped first).

### `EventContext` (not saved)
`prev_state`, `prev_derived: DerivedState` (the derivation of `prev_state`, so `state_enter` rules compare labels without re-deriving), `state: StarterState`, `derived: DerivedState`, `env`, `history: PlayerHistory`, `ledger`, `now_unix`, `local_minute_of_day`, `utc_offset_s: int` (for day keys via `LocalDay.day_key()`), `app_foreground: bool`, `last_action: GameAction` (null on plain steps), `catalog` (for `Forecast` calls such as `warm_and_quick`'s 22 °C run).
- On a step that follows an action, `prev_state` is the state **before** the action (`comeback` reads its `starved_h`). On a plain step, it is the state one step earlier.
- No RNG. Rules are deterministic functions of the context. Phase triggers read `derived.rise_phase`, not `derived.state`.

### `PlayerHistory` (saved; counters requested by `game-designer`)
| Field | Type | Used by |
|---|---|---|
| `consecutive_early_feeds` | int | `fed_before_peak` |
| `last_strong_peak_rise` | float | `back_to_strength`: the last `peak_rise` from a cycle with `vigor_at_feed >= 0.75` |
| `smelled_descriptors` | `Dictionary[StringName, bool]` | `nose_for_it` milestone |
| `seen_counts` | `Dictionary[StringName, int]` | Meaning-line fade after 3. Keys `smell.<id>`, `inspect.<kind>.level_<n>` |
| `recent_feed_unix` | `Array[int]` (newest last, cap 3) | Feed-sheet routine hint (gaps between the last 3 feeds) |
| `daily` | `Array[DailyBucket]` (P1) | Traits. Ring of 14: `day_key`, `hours_warm` (>= 24 °C), `hours_cool` (<= 18 °C), `feeds`, `ratio_sum`, `changes`, `comebacks` |

## 6. Journal

### `JournalEntry`
| Field | Type | Notes |
|---|---|---|
| `uid` | int | |
| `starter_id` | String | Which starter. The journal outlives a starter (memorial, then a new one) |
| `at_unix` | int | Real time of the act (not grid time). `state_change` and `event` entries use the sim time they happened |
| `kind` | StringName | `feed`, `environment`, `smell`, `inspect`, `event`, `state_change`, `milestone`, `rename`, `memorial` |
| `state_id` | StringName | State at that moment |
| `text_key` | StringName | A tr key: `JOURNAL_LOG_FEED` (or `_AT_PEAK`, `_RESCUE`), `JOURNAL_LOG_MOVE_<LOCATION>`, `JOURNAL_LOG_SMELL`, the readout's `INSPECT_..._OBS`, `EVENT_<ID>_JOURNAL_TITLE`, `STATUS_<STATE>_WORD`, `MEMORIAL_TITLE` |
| `args` | Dictionary | ints, Strings and bools only. No decimals (§1). A feed sends `{"ratio": "1:5:5", "flour_g": 70}`. UI renders with `Keys.format(text_key, args)`, which first translates any arg that is itself a key (`FLOUR_RYE`), so the save stores keys, never text in one language |
| `data` | Dictionary | Facts. A feed stores `FeedAction.to_dict()` (`kept_g`, `flour_g`, `water_g`, `hooch_choice`, `ratio_flour`, `ratio_water`, `hydration_pct`) plus `timing`, `had_hooch` and `feed_u`. Read numbers with `DictReader.float_of()` (§1) |

Cap: 400 entries. On overflow, drop the oldest `state_change` entries first, then `inspect` and `smell`, then the oldest of any other kind. Never drop `memorial` or `milestone`. Smell and inspect entries also follow the dedupe rule in `game-mechanics.md` §4 (once per descriptor per rise cycle).

### `Memorial` (saved list)
`starter_id`, `name`, `born_unix`, `ended_unix`, `feeds_count: int`, `cause: StringName` (`mold`).

## 7. `VisualParams` (`VisualMapper.from_state(state, env) -> VisualParams`)

`Session` calls `VisualMapper.from_derived(state, env, derived)` with the derivation it already has, so it derives once per step. Every field maps to a starter-shader uniform **with the same name**, listed in `VisualParams.UNIFORMS`. `VisualMapper` holds a v0 mapping toward the `art-direction.md` §6 look-dev targets; `art-director` and `sourdough-scientist` tune it. This table fixes the names, types and ranges. Units are relative to the starter (ratios and 0..1), so `VisualMapper` never needs jar geometry. Only `level_m` is in meters, and the view converts everything else using `jar_geometry.gd`. One difference from the Phase 1 spike: the spike's `rise` is `ratio - 1` (0 = as fed), and the Phase 2 shader takes the ratio.

| Field / uniform | Type | Range | Meaning |
|---|---|---|---|
| `level_m` | float | 0..0.042 | Fed level: surface height above the starter floor at rise 1.0, from `mass_g` and the container. Also the rubber band height. About 0.030 for 150 g in classic_jar v0 |
| `rise` | float | 1.0..3.0 | The shader's surface height is `level_m * rise` (the art contract's `u_level`). 3.0 at the 0.042 max stays under the 0.125 liner top |
| `dome` | float | -1..1 | -1 collapsed (concave), 0 flat, +1 domed |
| `activity` | float | 0..1 | Breathing and bubble motion speed |
| `bubble_density` | float | 0..1 | Bubbles on the side and the top |
| `peak_line` | float | 0 or 1.0..3.0 | Highest rise this cycle, in the same units as `rise`. 0 = no streak line |
| `lumps` | float | 0..1 | Surface lumpiness (art contract `u_lumps`). Mapping pending sim spec and art |
| `hooch_depth` | float | 0..1 | Liquid band on top. 1 = `hooch_max` in the shader (about 1 cm, per the scientist) |
| `bubble_size` | float | 0..1 | Small and even (young) to large and irregular |
| `streak_amount` | float | 0..1 | Liner streak opacity below `peak_line` |
| `surface_dryness` | float | 0..1 | Skin or crust look |
| `sheen` | float | 0..1 | Glossiness of the surface |
| `tint` | Color | | From `flour_mix` via `FlourProfile.tint` |
| `fleck` | float | 0..1 | Bran flecks (whole_wheat, rye) |
| `dullness` | float | 0..1 | `unhealthy` look, before any mold (art and scientist decide) |
| `mold` | float | 0..1 | Nonzero **only** when the state is `moldy` (hard rule 2) |
| `big_bubble` | float | 0..1 | Nonzero for the cycle's big bubble: from the step `rise_phase` enters `near_peak` while `feed_u >= 0.85` (spec §14.1). The look and the decay are art's |
| `time_override` | float | -1 or >= 0 | -1 = use shader `TIME`. Tests and captures set a fixed value |

Non-uniform fields: `cover: StringName` (which lid node is visible).

## 8. Readouts

### `SmellReadout` (`SmellModel.read(state, env)`)
`primary: StringName` (descriptor id, or `&""` when nothing reaches 0.15), `secondary: Array[StringName]` (0 to 2, strongest first), `intensity: StringName` (`faint` >= 0.15, `clear` >= 0.35, `strong` >= 0.7), `intensity_value: float` 0..1 (not shown), `is_warning: bool` (true when `musty` is listed; it is then always first), `meaning_key: StringName` (`SMELL_<PRIMARY>_MEANING`), `intensities: Dictionary[StringName, float]` (every descriptor after cold damping, for tests and the journal).
Descriptor ids: `SimConstants.DESCRIPTORS`, the spec §13 order, which also breaks ties (`wet_flour`, `mildly_fruity`, `fresh_yeasty`, `yogurt`, `pleasantly_tangy`, `strongly_acidic`, `alcohol`, `acetone`, `cheesy`, `musty`). No randomness: the same state gives the same smell.

### `InspectionReadout` (`Inspection.read(state, env, kind)`)
| Field | Type | Notes |
|---|---|---|
| `inspect_kind` | StringName | One of the 5 kinds |
| `level` | int 0..4 | Index of the first observation in the kind's order. Only feeds the seen-count key `inspect.<kind>.level_<n>` (meaning-line fade) |
| `observations` | `Array[StringName]` | Spec §14 readout ids in display order, for example `[&"doubled", &"rising", &"streak_line"]` |
| `text_key` | StringName | The observation line, `INSPECT_<KIND>_<STATE>[_<VARIANT>]_OBS`, for example `INSPECT_HEIGHT_AT_PEAK_DOUBLE_OBS`. A recovering starter uses its rise phase |
| `meaning_key` | StringName | The meaning line, for example `INSPECT_HEIGHT_AT_PEAK_MEAN`. Fades after 3 views unless `is_warning`. The sim builds both keys, so the UI never does |
| `is_warning` | bool | `unhealthy` or `moldy`, or a `surface` read that shows `hooch_dark` |
| `camera_target` | StringName | Below |

| Kind | Camera target | Reveals |
|---|---|---|
| `bubbles` | `bubbles` (side close-up) | `activity`, `rise_phase` |
| `consistency` | `top` | `culture_hydration`, `hooch` |
| `height` | `height` | `rise`, `peak_rise` |
| `surface` | `surface` | `dryness`, `hooch`, `mold_risk` stage |
| `development` | `home` | `maturity`, `vigor` |

### `StarterSnapshot` (what the HUD reads; `StarterSnapshot.make(state, derived, env)`)
`name`, `state: StringName`, `rise_phase: StringName`, `dormant_cause: StringName` (`cold`, `starved` or `&""`; copy picks the `_COLD` or `_STARVED` line), `since_feed_s: float`, `is_warning: bool` (`unhealthy` or `moldy`), `can_feed: bool` (false when `moldy`), `maturity_stage: StringName` (`young`, `steady`, `mature`, `seasoned` from maturity 0, 0.33, 0.50, 0.83; `SimConstants.maturity_stage()`), `location: StringName`. The HUD shows the state as an icon plus a word (`Keys.status_word(state, dormant_cause)`, for example `STATUS_DORMANT_COLD_WORD`), never color alone.

### `CatchUpResult`
`from_unix`, `to_unix`, `simulated_s: int`, `capped: bool`, `reanchored: bool`, `steps: int`, `transitions: Array[Dictionary]` (`at_unix`, `from`, `to`), `events: Array[SimEvent]`, `snapshots: Array[VisualParams]` (at most 30, evenly spaced, for the time-lapse), `notable: Dictionary` (for example `peak_unix`, `peak_rise`, `hooch_first_unix`).

## 9. Save schema v1

### 9.1 Files (`SaveStore`, base dir `user://saves/`)
| File | Role |
|---|---|
| `save.json` | Current save |
| `save.tmp` | Write target, renamed over `save.json` |
| `save.prev` | The previous good save |
| `quarantine/<unix>_<name>` | Files that failed to load. Never deleted, except to keep the newest 5 sets |
| `user://settings.cfg` | Player preferences (`ConfigFile`), kept apart so a bad save never resets them, and the reverse |

### 9.2 File layout
Line 1 is a header. Everything after the first newline is the payload, byte for byte:

```
{"bytes":1874,"format":"sourdough.save","sha256":"<64 hex>","version":1}
{"environment":{...},"events":{...},...}
```

- Payload text: `JSON.stringify(payload, "", true, true)` (sorted keys, full precision). Floats are already hex strings by then (§1), so only ints and strings are JSON numbers and text. Full precision alone is not enough: it fixed `1/3` but leaves about a third of doubles 1 ulp off after parsing **[ran]**.
- `sha256` = `payload_text.sha256_text()`. `bytes` = UTF-8 byte length.
- **The checksum covers the stored bytes.** It is never recomputed from a re-serialized Dictionary, because parse then stringify is not byte-stable (`1` comes back as `1.0`) **[ran]**.

### 9.3 Write
1. Encode, then write header + `\n` + payload to `save.tmp`. Check `FileAccess.get_open_error()` and the written length.
2. If `save.json` exists **and is trusted** (it is the file this session loaded, or one this session wrote), rename it to `save.prev` (overwrites). An untrusted `save.json` (it failed to load this session) is moved to quarantine instead, so it can never push a good `save.prev` out (`qa-engineer` SAVE-17).
3. Rename `save.tmp` to `save.json`.

Renames use `DirAccess.open("user://saves").rename(...)`, **not** `DirAccess.rename_absolute()`. The instance path is POSIX `rename(2)` on iOS, Android and macOS. `rename_absolute` always goes through `ACCESS_FILESYSTEM`, which on Android is the Java `File.renameTo` path **[src]**. Overwrite on rename **[ran on macOS]**. Godot never calls `fsync` **[src]**, so a power cut can still damage the newest file. The checksum catches that, and the loader falls back.

Fault points for tests (`SaveStore.fault_point`): `before_tmp_write`, `mid_tmp_write` (writes half the bytes, then stops), `before_rename` (before step 2), `after_rename` (between steps 2 and 3).

### 9.4 Load
Mechanics (all silent on bad input, so no engine error is logged):
- Read with `FileAccess.get_file_as_bytes()` (silent when the file is missing **[ran]**). Split at the first `0x0A` byte.
- Hash the raw payload bytes with `HashingContext` (SHA-256). This equals `payload_text.sha256_text()` at write time **[ran]**. Decode to text only after the hash matches, because invalid UTF-8 decodes silently into a different string **[ran]**.
- Parse with `JSON.new().parse()` and check the returned `Error`. **Never `JSON.parse_string()`**: it logs an engine error on bad JSON **[ran]**.

Try in order: `save.json`, `save.tmp`, `save.prev`. If the winner is `save.tmp`, rename it to `save.json` at once, so the loaded file is the trusted `save.json` before any new write can overwrite `save.tmp`. The first file that passes all of these checks wins: header parses, `format` matches, `version <= CURRENT`, byte length and sha256 match, payload parses, migration succeeds, and `from_dict` succeeds. If none passes, first move every candidate file to `user://saves/quarantine/<unix>_<name>` (keep the newest 5 sets), then start a new starter with `meta.recovered_from = "quarantine"`. A decoder or migration bug in an update then costs nothing permanent, because a later patch can recover the files (`qa-engineer` SAVE-06). A file that fails while others pass is also quarantined, never deleted. A file with `version > CURRENT` is never overwritten: it is moved to quarantine as well.

### 9.5 Migration
`SaveMigrations.migrate(payload: Dictionary, from_version: int) -> Dictionary` runs pure steps `_v1_to_v2`, `_v2_to_v3` and so on in order. The next save writes the current version. Every released version keeps a fixture forever in `tests/fixtures/saves/v<N>_*.json`, and a test loads each one. Those are full save files, with header and checksum.

Dev fixtures: `--fixture=<path>` (debug builds only) and `SaveStore.load_from_path(path)` accept either a full save file or a **bare payload** JSON with no header line, so QA and the tracks can hand-write fixtures. A bare payload skips the checksum and still runs migration and `from_dict`.

### 9.6 Example payload v1 (synthetic values, pretty-printed here; the real file is one compact line)

For readability, floats below are shown as decimals. The real file writes each one as its hex bit pattern (§1), so `"food": 0.18` is stored as `"food": "0ad7a3703d0ac73f"` and `"mass_g": 150.0` as `"mass_g": "0000000000c06240"` (both checked with Python's `struct.pack('<d', x).hex()`). In the journal's free-form `data`, whole numbers are ints (`"kept_g": 50`) and `"feed_u": 0.7` is stored as `"666666666666e63f"`, which is also what it reads back as. `Session.dump_state(path)` writes this readable decimal form for humans. Exact comparisons use the real payload. Every section is required in a save; a dev fixture needs only `starter` and `environment` (§9.5).

```json
{
  "environment": {"changed_unix": 1795600020, "container": "classic_jar", "cover": "loose_lid",
                  "humidity_pct": 50.0, "location": "counter", "temperature_c": 22.0},
  "events": {"day_counts": {"info": 1, "nudge": 0, "attention": 0}, "day_key": "2026-11-26",
             "last_fired_unix": {"peak_now": 1795640400}, "next_uid": 8,
             "once_flags": {"first_feed": true}, "pending": []},
  "history": {"consecutive_early_feeds": 0, "daily": [], "last_strong_peak_rise": 2.2,
              "recent_feed_unix": [1795536000, 1795579200, 1795622400],
              "seen_counts": {"smell.fresh_yeasty": 2}, "smelled_descriptors": {"fresh_yeasty": true}},
  "journal": [{"args": {"flour_g": 50, "ratio": "1:1:1"}, "at_unix": 1795622411,
               "data": {"feed_u": 0.7, "flour_g": {"white_bread": 50}, "had_hooch": false,
                        "hooch_choice": "pour_off", "hydration_pct": 100, "kept_g": 50, "kind": "feed",
                        "ratio_flour": 1, "ratio_water": 1, "timing": "late", "water_g": 50},
               "kind": "feed", "starter_id": "a3f09c1e5b7d2468", "state_id": "collapsing",
               "text_key": "JOURNAL_LOG_FEED", "uid": 7}],
  "memorials": [],
  "meta": {"app_version": "0.2.0", "clock_reanchors": 0, "created_unix": 1795500000,
           "recovered_from": "", "save_count": 41, "saved_unix": 1795651233},
  "rng": {"sim_seed": "987654321", "sim_state": "5043351203278607731"},
  "starter": {"acid": 0.42, "born_unix": 1795500000, "culture_hydration": 100.0,
              "dryness": 0.05, "feed_jitter": 1.02, "feed_u": 0.7, "flour_mix": {"white_bread": 1.0},
              "food": 0.18, "food_at_feed": 0.67, "hooch": 0.0, "id": "a3f09c1e5b7d2468",
              "lab": 0.95, "mass_g": 150.0, "maturity": 0.61, "mold_risk": 0.0,
              "moldy": false, "name": "Dough Nut", "peak_rate": 0.31, "peak_rise": 2.2,
              "rise": 1.93, "since_feed_s": 28800.0, "sim_time_unix": 1795651200,
              "starved_h": 0.0, "temp_c": 21.8, "vigor": 0.88, "vigor_at_feed": 0.85,
              "yeast": 0.9}
}
```

Size estimate: about 150 B per journal entry, times 400, gives about 60 KB. Budget 128 KB (`architecture.md` §11).
