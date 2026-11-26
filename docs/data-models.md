# Data models

Owner: `tech-architect`. Status: **draft v0, wave A** (2026-11-26).
Sources: `starter-simulation-spec.md` v1 (§1, §12, §16, §17), `game-designer` event and history needs (by message), `art-director` mesh contract (by message). Numbers marked **pending sim spec** wait for `docs/starter-simulation-spec.md` v1.

## 1. Conventions

| Topic | Rule |
|---|---|
| Classes | Runtime data is `RefCounted` with a `class_name`. Data-driven profiles are `Resource` subclasses saved as `.tres` under `data/`. Everything lives in `src/sim/` unless noted |
| Ids | `StringName`, exactly the canonical ids in `vision.md` |
| Time | Absolute times are `int` Unix seconds, UTC, suffix `_unix`. Durations are `float` seconds (suffix `_s`) or hours (suffix `_h`) as noted |
| Units | Grams `_g`, Celsius `_c`, percent `_pct`, meters `_m`. Unitless 0..1 fields say so |
| Ranges | The sim clamps every stored float to its range after each step. A test asserts it (property test) |
| Serialization | Each class has `to_dict() -> Dictionary` and `static from_dict(d: Dictionary) -> <Class>`. `from_dict` converts numbers explicitly (`int(d.x)`), because JSON gives back every number as a float **[ran]**. It checks `typeof()` before every read and returns null on a missing key or wrong type. Assigning a wrong-typed Variant to a typed variable logs a script error **[ran]**, which the test runner's Logger counts as a failure, so a corrupt file must fail silently |
| 64-bit ints | RNG seeds and states are saved as **decimal strings**. As JSON numbers they lose precision above 2^53 **[ran]** |
| Floats | Every `float` in the save payload is saved as a **16-character hex string of its IEEE-754 bits**: the 8 bytes from `PackedByteArray.encode_double(0, x)`, then `hex_encode()` (little-endian byte order). Examples: 0.25 is `"000000000000d03f"`, 150.0 is `"0000000000c06240"`. Reason: Godot 4.7.2's JSON number parser isn't correctly rounded (for example, 1.9469610637576158 reads back as 1.946961063757616), so about a third of doubles come back 1 ulp off (33,968 of 100,000 between 1e-6 and 1e3), even with `full_precision` **[ran]**, found by `qa-engineer`. The bit pattern round-trips exactly (0 of 100,000 off) **[ran]**. The decoder also accepts a plain JSON number for a float field (lossy), so hand-written dev fixtures stay writable. The writer always writes hex |
| Text | No player-facing text in data. Keys only (`architecture.md` §10). The player's starter name is the one exception |

## 2. `StarterState` (stored)

Sim variables follow `starter-simulation-spec.md` §1 **v1** exactly (names, units and ranges; the spec is the authority, and this table must change when it does). Rows marked "architect" or "designer" are bookkeeping that the sim equations don't read.

| Field | Type | Unit | Range | Meaning | Source |
|---|---|---|---|---|---|
| `id` | String | | 16 hex chars | Unique per starter (for memorials) | architect |
| `name` | String | | 1 to 24 chars | Player-given name | architect |
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

**Derived, never stored** (functions on `Sim` and `StateDeriver`): `rise_rate` (from the §7 equations, so no previous-step field is needed), `gas`, `ph`, `ferm(temp_c)`, `activity`, `state` id, `rise_phase`, the smell set.

### 2.1 Start presets and rebasing
`StarterPresets.make(preset_id: StringName, now_unix: int) -> StarterState` (pure, `src/sim/starter_presets.gd`). Values from `game-mechanics.md` §8.1 and §8.2:

| `preset_id` | When | Start |
|---|---|---|
| `new_game` | First launch | `at_peak`, maturity 0.2, `counter` |
| `first_restart` | First new starter after mold | `dormant`, `temp_c` 4, `counter` |
| `restart` | Later new starters | `at_peak` |

`StarterState.rebase_to(now_unix)` sets `sim_time_unix = grid(now_unix)` and `born_unix = now_unix`, and clears `PlayerHistory.recent_feed_unix` entries from the demo. Relative fields (`since_feed_s`, `starved_h`) are unchanged. Used after the tutorial demo (`architecture.md` §5.5).

**State derivation** (spec §12, first match wins): `moldy`, `unhealthy`, `dormant`, `hungry`, `recovering`, then the rise phases (`freshly_fed`, `developing`, `active`, `near_peak`, `at_peak`, `collapsing`). `recovering` overlaps a rise phase, so `StateDeriver.derive()` returns both:

```gdscript
class_name DerivedState extends RefCounted
var state: StringName        # one of the 11 canonical ids
var rise_phase: StringName   # always a rise-phase id, even when state is recovering or hungry
var ferm: float              # 0..1, ferm(temp_c) from spec §3
var dormant_cause: StringName  # &"cold" or &"starved" when state is dormant (cold wins), else &""
var activity: float          # 0..1
```

## 3. `EnvironmentState` (stored) and profiles

| Field | Type | Unit | Range | Notes |
|---|---|---|---|---|
| `location` | StringName | | `counter`, `warm_spot`, `window_sill`, `fridge`, `proofing_box` | Designer may trim |
| `temperature_c` | float | °C | 2..35 (pending sim spec) | Effective temperature. Set from the preset when the location changes. Whether the player can nudge it inside the preset's range: **pending game-designer** |
| `humidity_pct` | float | % | 20..95 (pending) | From the preset |
| `container` | StringName | | MVP: `classic_jar` only | |
| `cover` | StringName | | `loose_lid`, `cloth`, `tight_lid` | |
| `changed_unix` | int | s | | Last environment change, applied at a grid point |

Profiles (`Resource`, one `.tres` per id; all numbers **pending sim spec**):

| Class | File | Fields |
|---|---|---|
| `FlourProfile` | `data/flours/<id>.tres` | `id`, `speed_mult`, `acid_mult`, `water_absorption`, `food_value`, `tint: Color` (for `VisualMapper`), `fleck: float` 0..1 |
| `LocationPreset` | `data/locations/<id>.tres` | `id`, `temperature_c`, `temperature_min_c`, `temperature_max_c`, `humidity_pct`. A daily swing (for example `window_sill`) would need local time in `Sim.step`: **pending sim spec** |
| `ContainerProfile` | `data/containers/<id>.tres` | `id`, `inner_radius_m`, `inner_height_m`, `liner_height_m`, `scene_path`. classic_jar v0 (art contract, 2026-11-26): outer D 84 mm, H 170 mm, wall 3.5 mm, base 8 mm, inner r 0.0385, inner height 0.162, liner top 0.125 |
| `CoverProfile` | `data/covers/<id>.tres` | `id`, `dryness_mult`, `evaporation_mult`, `mold_risk_mult`, `node_name` |

Profiles are loaded once by `Session` and passed into the sim as a `SimCatalog` (`Dictionary[StringName, FlourProfile]` and so on). The sim never calls `load()`.

Cover id to GLB node (art-director contract): `loose_lid` = `Jar_Lid_Loose`, `tight_lid` = `Jar_Lid_Tight`, `cloth` = `Cloth_Cover`.

## 4. Actions

Base `GameAction` (`RefCounted`): `kind: StringName`, `at_unix: int` (set by `Session`, never by UI), `validate(state, env, catalog) -> StringName` (empty means ok, otherwise a reason key such as `&"reason.keep_too_little"`).

| Class | `kind` | Fields | Validation |
|---|---|---|---|
| `FeedAction` | `feed` | `kept_g: float`, `flour_g: Dictionary[StringName, float]`, `water_g: float` | `1 <= kept_g <= state.mass_g`. Flour ids canonical, each >= 0, total > 0. `water_g >= 0`. Hydration and post-feed fill within limits (**pending sim spec and designer**: container capacity at 3.0x rise) |
| `SetEnvironmentAction` | `environment` | `env: EnvironmentState` (full replacement) | Ids canonical, temperature inside the preset range |
| `SmellAction` | `smell` | none | Always ok |
| `InspectAction` | `inspect` | `inspect_kind: StringName` (`bubbles`, `consistency`, `height`, `surface`, `development`) | Canonical kind |
| `RenameAction` | `rename` | `new_name: String` | 1 to 24 chars after trim |
| `AckEventAction` | `ack_event` | `event_uid: int`, `choice: StringName` (may be empty) | Event is pending |
| `DiscardStarterAction` | `discard_starter` | `new_name: String` | Only when the state is `moldy` |

The UI builds `FeedAction` from the player's ratio, flour and hydration choices with the formulas in `game-mechanics.md` §2.3 (total after feeding fixed at `target_total_g` = 150 g, keep derived). The action still carries grams, so the sim and the journal never depend on UI math. Validation adds `abs(mass_after_g - target_total_g) <= 1`.

`FeedAction` derived values: `flour_total_g`, `ratio` (`1 : flour_total_g/kept_g : water_g/kept_g`), `hydration_pct = water_g / flour_total_g * 100`, `mass_after_g`.

`ActionResult`: `ok: bool`, `reason_key: StringName`, `readout: RefCounted` (a `SmellReadout`, `InspectionReadout` or null), `events: Array[SimEvent]`, `journal_entry: JournalEntry`.

## 5. Events

### `SimEvent`
| Field | Type | Notes |
|---|---|---|
| `uid` | int | From `EventLedger.next_uid` |
| `id` | StringName | Rule id, for example `&"peak_now"`. Text keys `event.<id>.title` and `.body` |
| `tier` | StringName | `info`, `nudge`, `attention` |
| `created_unix` | int | Sim time of the step that fired it |
| `local_minute_of_day` | int | 0..1439 |
| `payload` | Dictionary | Primitives only (int, float, String, bool). For example `{"peak_unix": ..., "peak_rise": 2.3}` |
| `expires_unix` | int | 0 = never |
| `expires_if` | StringName | Condition id that drops a stale event, for example `&"state_not_hungry"`. Empty = none |
| `not_before_unix` | int | Quiet-hours deferral |
| `status` | StringName | `pending`, `shown`, `acked`, `expired` |

### `EventLedger` (saved)
`next_uid: int`, `last_fired_unix: Dictionary[StringName, int]`, `once_flags: Dictionary[StringName, bool]`, `day_key: String` (local `YYYY-MM-DD`), `day_counts: Dictionary[StringName, int]` (per tier, current local day only), `pending: Array[SimEvent]` (cap 20; the oldest `info` is dropped first).

### `EventContext` (not saved)
`prev_state`, `state: StarterState`, `derived: DerivedState`, `env`, `history: PlayerHistory`, `ledger`, `now_unix`, `local_minute_of_day`, `app_foreground: bool`, `last_action: GameAction` (null on plain steps), `catalog` (for `Forecast` calls such as `warm_and_quick`'s 22 °C run).
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
| `at_unix` | int | Real time of the act (not grid time) |
| `kind` | StringName | `feed`, `environment`, `smell`, `inspect`, `event`, `state_change`, `milestone`, `rename`, `memorial` |
| `state_id` | StringName | State at that moment |
| `text_key` | StringName | |
| `args` | Dictionary | Primitives for `tr(key).format(args)` |
| `data` | Dictionary | Facts, for example a feed's grams, ratio and hydration |

Cap: 400 entries. On overflow, drop the oldest `state_change` entries first, then `inspect` and `smell`, then the oldest of any other kind. Never drop `memorial` or `milestone`. Smell and inspect entries also follow the dedupe rule in `game-mechanics.md` §4 (once per descriptor per rise cycle).

### `Memorial` (saved list)
`starter_id`, `name`, `born_unix`, `ended_unix`, `feeds_count: int`, `cause: StringName` (`mold`).

## 7. `VisualParams` (`VisualMapper.from_state(state, env) -> VisualParams`)

Every field maps to a starter-shader uniform **with the same name**. Mapping rules from state are **pending sim spec and art direction**. This table fixes the names, types and ranges. Units are relative to the starter (ratios and 0..1), so `VisualMapper` never needs jar geometry. Only `level_m` is in meters, and the view converts everything else using `jar_geometry.gd`. One difference from the Phase 1 spike: the spike's `rise` is `ratio - 1` (0 = as fed), and the Phase 2 shader takes the ratio.

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
`primary: StringName` (descriptor id), `secondary: Array[StringName]` (0 to 2), `intensity: StringName` (`faint`, `clear`, `strong`), `intensity_value: float` 0..1 (not shown), `is_warning: bool` (true for `musty` and any descriptor the spec marks as a warning), `meaning_key: StringName`.
Descriptor ids: the seed list in `vision.md` (`wet_flour`, `mildly_fruity`, `fresh_yeasty`, `yogurt`, `pleasantly_tangy`, `strongly_acidic`, `alcohol`, `acetone`, `cheesy`, `musty`). Final list and mapping are **pending sim spec**. No randomness: the same state gives the same smell.

### `InspectionReadout` (`Inspection.read(state, env, kind)`)
`inspect_kind: StringName`, `level: int` 0..4, `text_key` (`inspect.<kind>.level_<n>`), `is_warning: bool`, `camera_target: StringName`.

| Kind | Camera target | Reveals (pending sim spec) |
|---|---|---|
| `bubbles` | `bubbles` (side close-up) | `activity`, `rise_phase` |
| `consistency` | `top` | `culture_hydration`, `hooch` |
| `height` | `height` | `rise`, `peak_rise` |
| `surface` | `surface` | `dryness`, `hooch`, `mold_risk` stage |
| `development` | `home` | `maturity`, `vigor` |

### `StarterSnapshot` (what the HUD reads)
`name`, `state: StringName`, `rise_phase: StringName`, `since_feed_s: float`, `is_warning: bool` (`unhealthy` or `moldy`), `can_feed: bool` (false when `moldy`). The HUD shows the state as an icon plus a word (`state.<id>.name`), never color alone.

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

For readability, floats below are shown as decimals. The real file writes each one as its hex bit pattern (§1), so `"food": 0.18` is stored as `"food": "0ad7a3703d0ac73f"` and `"mass_g": 150.0` as `"mass_g": "0000000000c06240"`. `Session.dump_state(path)` writes this readable decimal form for humans. Exact comparisons use the real payload.

```json
{
  "environment": {"changed_unix": 1795600020, "container": "classic_jar", "cover": "loose_lid",
                  "humidity_pct": 55.0, "location": "counter", "temperature_c": 22.0},
  "events": {"day_counts": {"info": 1, "nudge": 0, "attention": 0}, "day_key": "2026-11-26",
             "last_fired_unix": {"peak_now": 1795640400}, "next_uid": 8,
             "once_flags": {"first_feed": true}, "pending": []},
  "history": {"consecutive_early_feeds": 0, "daily": [], "last_strong_peak_rise": 2.2,
              "recent_feed_unix": [1795536000, 1795579200, 1795622400],
              "seen_counts": {"smell.fresh_yeasty": 2}, "smelled_descriptors": {"fresh_yeasty": true}},
  "journal": [{"args": {}, "at_unix": 1795622411, "data": {"flour_g": {"white_bread": 50.0},
               "kept_g": 50.0, "water_g": 50.0}, "kind": "feed", "state_id": "collapsing",
               "text_key": "journal.feed.basic", "uid": 7}],
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
