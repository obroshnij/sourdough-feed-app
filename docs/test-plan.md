# Test plan

Owner: `qa-engineer`. Status: Phase 1 draft (wave A). Last updated 2026-11-26.

**Built on:**
- `vision.md`, `decisions.md`
- `architecture.md`, `data-models.md`, `technical-decisions.md`
- `starter-simulation-spec.md` v1 (ranges §1, mold §10, derivation §12, smell §13, inspection §14, vectors V1 to V17 §18)
- `game-mechanics.md` (BT-1 to BT-16, L-1 to L-11), `events-catalog.md`, `game-copy.md`, `ux-design.md`
- The art-director's reference-render plan (by message)

**Not landed yet:** `art-direction.md`.

Numbers taken from a draft are tagged, and they move when the owning spec moves. **QA never tunes a number. It tests the number the owner publishes.**

**Placeholder tags:** `TBD-SCI`, `TBD-GD`, `TBD-UX`, `TBD-ART`, `TBD-ARCH`, `TBD-NAR`. A `v1` tag means a number from `starter-simulation-spec.md` v1.

**Check types:**

| Tag | Meaning |
|---|---|
| `auto` | Headless runner, every commit |
| `capture` | Windowed run with the capture harness or `PerfLog`, measured by script |
| `review` | A named reviewer compares against a named reference with a checklist |
| `manual` | A checklist on the Mac, a simulator or a device |

## Contents

1. Runner contract (measured in Phase 1)
2. Strategy by layer
3. Acceptance criteria for the 12 vertical-slice items
4. Sim and time tests tied to the specs
5. Edge-case catalog
6. What can't be automated, with manual checklists
7. Performance
8. Accessibility checks
9. Device and screen matrix (Phase 5)
10. Definition of done (Phases 2 and 3)
11. Bug severity scale
12. Seams the tests use
13. Open items

---

## 1. Runner contract (measured in Phase 1)

**Evidence.** Godot `4.7.2.stable.official.ed1daf0bf`, macOS. Each case ran `Godot --headless --path . -s res://<script>.gd` in a scratch project outside the repo, under a 15 s outer `perl alarm`.

| Case | Exit code | Risk |
|---|---|---|
| `quit(0)` / `quit(1)` | 0 / 1 | None |
| Parse error in the `-s` script | **0** | False pass |
| Untyped `var` with `untyped_declaration=2` | **0** | False pass |
| Null call inside a called function, then `quit(0)` | **0** | False pass. The function returns a default and the run continues. |
| Runtime error or failed `assert` directly in `_init()` | hangs (killed at 15 s, exit 142) | CI hangs |
| `--quit-after 120` on a hanging script | **0** | False pass. Never use it as a watchdog. |
| Fresh checkout without `.godot/`: `class_name` types don't resolve under `-s` | **0** | False pass. Found by tech-architect (architecture §12). |
| Prototype runner: `load()` per file, `can_instantiate()` check, custom `Logger` via `OS.add_logger()` | **1**, printed `RESULT: 1 passed, 3 failed` | Works. Caught a parse error in a test file, a null call and a failed assert. |

**JSON results (same setup), which drive the save tests:**
- Plain `JSON.stringify` doesn't round-trip 1/3. `JSON.stringify(d, "", true, true)` does, exactly.
- Integers parse back as floats.
- 2^53 + 1 is not preserved, so int64 RNG state must be stored as a string.
- Parse, then stringify, is not byte-stable (`1` becomes `1.0`, architect ran this), so the checksum covers the stored bytes.

**Runner requirements.** Accepted in `architecture.md` §12. QA owns `tests/run.sh` and `tests/run_tests.gd`.

| ID | Requirement |
|---|---|
| R-0 | `run.sh` first runs `godot --headless --path . --import`. |
| R-1 | `run_tests.gd` extends `SceneTree`, runs from `_initialize()` and holds no test logic. |
| R-2 | Discovers `res://tests/**/test_*.gd`. A file that fails `can_instantiate()` counts as a failure. |
| R-3 | A `Logger` subclass registered with `OS.add_logger()`. Any `_log_error` during a test (a null call, `push_error`, an `assert`) fails that test. |
| R-4 | Tests extend `TestCase` (`tests/lib/case_base.gd`) and assert through its `check*` methods. A test with 0 checks fails. Tests never rely on `assert()`, which release builds strip. `skip(reason)` marks a test skipped. A failure recorded before the skip still fails it. `expect_error(fragment)` declares one logged error, which then fails the test only if it never appears. |
| R-5 | One `PASS`, `SKIP <file>::<test> <reason>` or `FAIL <file>::<test> <message>` line per test (a FAIL may add indented detail lines). The last line is exactly `RESULT: <n> passed, <m> failed, <k> skipped`. Then `quit(1 if m > 0 else 0)`. |
| R-6 | `run.sh` applies the outer timeout `perl -e 'alarm 300; exec @ARGV'` (`RUN_TIMEOUT_S`). It passes only if the exit code is 0, the last stdout line matches `^RESULT: [0-9]+ passed, 0 failed, [0-9]+ skipped$`, and n > 0. Skips are printed and counted, never passes. `run.sh --strict` (the phase exit gate) also fails on any skip. Before the runner it runs four Python lints: `check_copy.py`, `build_catalog.py --check`, `sim.py vectors`, and golden-fresh (the committed traces equal a fresh `sim.py trace`). |
| R-7 | User args after `--`: `--filter=<substring of file::test>` and `--seeds=<n>` (default 100). `--update-golden` is refused when `CI=1`. Any other argument fails the run. Every test file is loaded before filtering, so a filter never hides a broken file. |
| R-8 | Loads every `.gd` under `res://src/` and fails on any that can't instantiate (LINT-03, `tests/lint/test_lint_03_typing.gd`). |
| R-9 | `run.sh --selftest` runs each case in `tests/runner_selftest/cases/` as a throwaway project through `run.sh`'s own judge, and checks both the outcome and the reason (`expect_output`). 33 cases: a positive control, a parse error, an untyped declaration, a non-TestCase file, an empty suite, a null call, `push_error`, a failed `assert`, an error in a test's `_init`, 0 checks, skips (counted, can't hide a failure, fail under `--strict`, milestone gate), a hang, no tests, a runner parse error, a runner exiting 0 with failures or 1 without, output after `RESULT`, the filter (and that it can't hide a parse error), `--update-golden` under `CI=1`, an unknown argument, a fresh checkout and a stale `.godot/` (each also run without `--import` to prove R-0 is what makes it come out right), and planted LINT-01 and LINT-03 violations plus a clean near-miss file. |
| R-10 | Tests that need T1 code call `require(&"<milestone>")` and SKIP until T1 lists that id in `Milestones.LANDED` (`src/core/milestones.gd`). Stubs from the contracts commit skip instead of failing, and each test turns on in the commit that makes its code real. Ids: `contracts`, `m2_sim`, `m3_clock`, `m4_save`, `m5_catchup` (`tests/lib/t1_api.gd`). QA only: `QA_FORCE_MILESTONES=m3_clock,m4_save tests/run.sh` runs gated tests early to report problems to T1. Never set it in CI or in a green-run report. |

---

## 2. Strategy by layer

| Layer | What it proves | How | Runs | When |
|---|---|---|---|---|
| L1 Lint and static | `CLAUDE.md` hard rules | LINT-01 to LINT-11 | headless | every commit |
| L2 Pure sim unit | Equations, derivation, readouts, `VisualMapper`, `Forecast` | runner | headless | every commit |
| L3 Golden scenarios | Scientist vectors, designer BT targets | runner, 100 seeds (1,000 nightly) | headless | every commit |
| L4 Property | Invariants over random schedules | seeded generators | headless | fast set every commit, long set nightly |
| L5 Save | Durability, migration, fallback | `SaveStore(base_dir)` plus `fault_point` | headless | every commit |
| L6 Clock | Elapsed time, re-anchoring, local time | `FakeClock` | headless | every commit |
| L7 Integration | Action, state, `VisualParams`, journal, events, save | `Session` with fakes, no rendering | headless | every commit |
| L8 UI scripted | Flows, tap budgets, routing, layout rules | scenes plus `Input.parse_input_event()`, mounted under a **fixed-size root Control** (for example 390 × 844 or 360 × 640) owned by the harness, never anchored to the window | headless (OD-11, verified) | every commit |
| L9 Visual capture | The look vs. the references | `--capture=<png>` with `time_override`, then review | Mac windowed | each milestone and art change |
| L10 Performance | Frame, catch-up and save cost | `--perf-log=<csv>` | Mac (estimate), simulator (estimate), device later | each milestone |
| L11 Manual | Feel, delight, device-only behavior | §6 checklists | Mac, simulator, device later | each milestone |

**Proposed test layout** (QA owns it in Phase 2):
- `tests/run_tests.gd`, `tests/run.sh`, `tests/runner_selftest/`
- `tests/unit/<track>/**` belongs to each implementation track (for example `tests/unit/sim/` to T1, architecture §14.1). QA owns everything else under `tests/`.
- `tests/golden/` (`vectors.json`), `tests/property/`
- `tests/save/`, `tests/clock/`, `tests/integration/`, `tests/ui/`, `tests/lint/`
- `tests/visual/` (plus `approved/<renderer>/`), `tests/perf/`
- `tests/fixtures/`, with saves in `tests/fixtures/saves/` (data-models §9.5). Synthetic data only, because the repo is public. Hand-written fixtures may be a bare payload with no header (`--fixture=` and `load_from_path()` accept that in debug builds). The `saves/v<N>_*` migration fixtures stay full files.

### 2.1 Pure sim unit tests (L2)

- **Temperature response:** `ferm(T)`, `dec(T)` and `mold_t(T)` at 0 to 40 °C in 1 °C steps equal spec §3 within 1e-9 relative. `mold_t` ≥ 0 everywhere, and `dec` > 0 (1.6 at 40 °C). `T_env` outside 0 to 40 is clamped.
- **Step procedure:** one test per spec §7 numbered step, in order:
  - rates use the start-of-step state and `temp_c`
  - clamp
  - `moldy` latch
  - `peak_rise` from the new rise
  - `peak_rate` from the pre-clamp step-2 rate
  - `temp_c`
  - `since_feed_s += 60`
- **Thermal lag:** `temp_c` approaches the location temperature with the spec's 1.5 h constant, with no overshoot.
- **Feed math:**
  - Food, populations and acid after a feed follow spec §6 dilution for 1:1:1, 1:2:2 and 1:5:5 (slice presets), plus 1:10:10 and 1:50:50 (sim-level, for P2).
  - A feed multiplies `mold_risk` by 0.3 and resets `starved_h` and `dryness` to 0.
  - One `sim_rng` draw per feed, stored as `feed_u` in [0, 1). `feed_jitter = 0.95 + 0.10 × feed_u` (spec §17). Never `randfn`.
- **Derived discard** (game-mechanics §2.3): `keep_g = round(150 / (1 + f + w))`, `flour_g = keep_g × f`, `water_g = flour_g × hydration / 100`. Expected: 1:1:1 gives 50/50/50 (150 g), 1:2:2 gives 30/60/60 (150 g), 1:5:5 gives 14/70/70 (154 g, flour and water rounded to 5 g).
- **Derivation thresholds** at value − ε, value and value + ε (§4.1), including every rise-phase rule in spec §12.1.
- **Precedence:** every pair of overlapping states. Spec §12.2 order: `moldy` > `unhealthy` > `dormant` > `hungry` > `recovering` > rise phases.
- **Feed timing class** (game-mechanics §2.4):
  - `freshly_fed`, `developing`, `active` → `early`
  - `near_peak`, `at_peak`, `collapsing` → `on_time`
  - `hungry` → `late`
  - `dormant`, `recovering` → `very_late`
  - `unhealthy` → `rescue`
  - `moldy` → no feed
- **`SmellModel.read`:** each spec §13 formula at its breakpoints.
  - Display the top 3 with intensity ≥ 0.15, and `musty` always first.
  - Words: faint from 0.15, clear from 0.35, strong from 0.7.
  - `moldy` gives `{musty: 1.0}` only.
- **`Inspection.read`:** every spec §14 key at its thresholds. Some examples:
  - `height`: `at_mark` < 1.1, `up_a_quarter` < 1.4, `up_half` < 1.75, `doubled` < 2.25. Trend at ±0.02. `streak_line` when `peak_rise − rise` ≥ 0.2.
  - `surface`: hooch bands at 0.1, 0.4 and 0.8. `skin` at dryness 0.3, `crust` at 0.7. `fuzzy_spots` **only** when `moldy`.
- **`VisualMapper.from_state(state, env)`:** golden table, purity and continuity (PROP-10, PROP-11).
- **`Forecast.peak_window`:** simulated with jitter 0.95 and 1.05, up to 48 h. It returns no window for `dormant`, `unhealthy`, `moldy` and `hungry`.

### 2.2 Golden scenario tests (L3)

- Spec §18 vectors **V1 to V17** are transcribed into `tests/golden/vectors.json`, starting from the `MATURE` fixture. Each has inputs, checkpoints and ranges. Every row is tuned unless spec §15 names a source.
- **Tolerance:** the spec's ranges already cover jitter from 0.95 to 1.05. On top of that, allow ±0.3 h on times and ±0.05 on rise for float drift (spec §18).
- Every vector runs for every seed: 100 per commit, 1,000 nightly. The spec says every vector holds for every seed.
- A failure prints the vector id, seed, checkpoint, variable, range and actual value.
- **Cross-platform floats:** runs on the same platform are bit-exact (V17). Across CPUs, `exp` and `pow` can differ in the last bits, which the drift allowance absorbs.
- **Reference model:** `tools/sim-reference/sim.py` (spec v1, §7 step order).
  - `sim.py vectors` checks every §18 range plus drift, prints one FAIL line per miss, and exits 1. **QA ran it: 243 checks, 0 failed, exit 0.**
  - **Mutation check (QA, on a scratch copy):** `mu_y` +10% alone fails 18 checks with exit 1, so the checks catch a real change.
  - It's the gate for every spec knob change (spec §19). It runs in CI wherever `python3` is available, and in Phase 2 it moves into `run.sh` as an optional step.
- **DIFF-01 (differential test):** `python3 -I tools/sim-reference/sim.py trace OUTDIR` writes T01 to T24 plus `manifest.json`.
  - 24 schedules, 3,988 hourly rows, about 3 MB.
  - Every event carries an explicit `feed_u`, so no RNG is involved.
  - The coverage includes fridge round trips, location moves mid-rise, stir-in, a refused feed on a moldy starter, and the 0 °C and 40 °C domain edges.
  - **QA ran it twice: exit 0, and the two outputs were byte-identical.**
  - In Phase 2 the traces are committed to `tests/golden/reference_traces/`. Only the scientist regenerates them, and only when the spec changes.
  - The GDScript sim replays each schedule and must match every stored field, `state`, `rise_phase` and `dormant_cause` at every hourly row: `|a − b| ≤ 1e-9 × max(|a|, |b|) + 1e-12`. Labels may differ only within one 60 s step of a transition in the reference trace.
  - The port must repeat the reference's exact operations (plain multiplication for integer powers, `log(x) / log(3)`, as listed in the README).
  - This catches port bugs the range-based vectors would miss.
- Vectors **V18** (1:2:2 at 22 °C, `at_peak` starts at 8.0 to 8.4 h) and **V19** (1:5:5 at 22 °C, 10.75 to 11.4 h) back BT-1, BT-2 and BT-17. **V20** covers stir-in.
- **Definitions (spec §18):**
  - "Peak" is the max-rise time. `at_peak` starts 0.05 to 0.15 h earlier, and V1 to V3, V18 and V19 give both.
  - "About X" means X ± 5% plus drift.
  - V5 and V6: three conversion feeds 12 h apart at 22 °C, then the identical 4th feed is t = 0.

### 2.3 Property tests (L4)

Generators produce random schedules: slice feeds, plus sim-level feeds (keep 1 g and up, any ratio up to 1:50:50), location changes, and gaps from 1 min to 14 d. The seed and a shrunk schedule print on failure.

| ID | Property | Pass condition |
|---|---|---|
| PROP-01 | One long catch-up equals many short sessions | `CatchUp.run` over D, vs. 2 to 500 random sessions summing to D (session lengths not multiples of 60 s), D ≤ 14 d. **Exact equality** of the serialized payload, excluding `meta`, because `saved_unix` and `save_count` legitimately differ. Architecture §5.1 and spec §16 / V17: a fixed 60 s Euler grid aligned to Unix time, and actions apply at `grid(now)`. |
| PROP-02 | Determinism | The same save, seed and action log give byte-identical payload text (excluding `meta`), including with a save and load midway. |
| PROP-03 | Ranges (spec §1) | After every step of 10,000 schedules, the ranges below hold. No NaN, no INF. |
| PROP-04 | Mold only from its causes | `mold_risk` never rises unless `food` < 0.10 **and** `starved_h` > 24 weighted hours (spec §10). Any schedule with a feed at least every 24 h at ≤ 24 °C keeps `mold_risk` at 0. |
| PROP-05 | Mold is latched | Once `moldy`, every later action and any elapsed time keeps it `moldy`. |
| PROP-06 | Temperature order | Time to peak for 1:1:1 falls from 12 °C to the spec §3 optimum, then rises. Sampled every 1 °C. The V2 and V12 anchors: 20 °C 7.1 to 7.4 h, 28 °C 4.6 to 4.8 h, 32 °C 4.5 to 4.6 h, 35 °C 5.0 to 5.2 h. |
| PROP-07 | Ratio order | At 24 °C: 1:1:1 < 1:2:2 < 1:5:5 < 1:10:10 < 1:50:50. |
| PROP-08 | Feeding never hurts | Feeding any non-moldy starter lowers `mold_risk` or leaves it unchanged (L-9). |
| PROP-09 | Closed vocabulary | The state is always one of the 11 canonical ids, and smell descriptors come from the spec list. |
| PROP-10 | Visual continuity | With no action, each `VisualParams` field changes by at most its art-direction §8 `max_delta` per 60 s step (for example rise 0.02, dome 0.03, hooch_depth 0.02). `peak_line` never decreases within a cycle. The mold field stays 0 except its latched 2 s fade-in. Feeds and `moldy` entry are exempt. The view adds 1.5 s smoothing on top (a capture check, not a sim check). |
| PROP-11 | `VisualMapper` purity | The same state and environment give identical `VisualParams` on two calls and after a save round-trip. |
| PROP-12 | Event determinism | The same save and clock schedule give the same events (id, time, tier). |
| PROP-13 | Events consume no RNG | `EventRules.evaluate(ctx)` takes no RNG. Adding or removing any event rule leaves every starter variable and `sim_state` byte-identical (architecture §7). |
| PROP-14 | Maturity only grows | `maturity` never decreases (spec §1). |
| PROP-15 | Cover and container touch only dryness | Two runs that differ only in `cover` or `container` are identical in every field except `dryness` and `mold_risk`. The mold speed ratio is ≤ 1.4 (spec §2.2). |
| PROP-16 | Mold signs only at `moldy` | Unless `moldy`, the mold-spot and tint `VisualParams` fields are 0, `surface` never returns `fuzzy_spots`, and no copy key from the moldy set is shown (spec §10 safety guarantee). |

**Ranges** (spec §1):

| Variables | Range |
|---|---|
| `food`, `food_at_feed`, `acid`, `hooch`, `dryness`, `maturity`, `mold_risk` | 0 to 1 |
| `vigor`, `vigor_at_feed` | 0.15 to 1 |
| `yeast`, `lab` | 0.001 to 1.5 |
| `rise`, `peak_rise` | 1.0 to 3.0 |
| `peak_rate` | ≥ 0 |
| `starved_h` | 0 to 336 |
| `temp_c` | 0 to 40 |
| `mass_g` | ≥ 1 |
| `culture_hydration` | 40 to 200 |
| `feed_u` / `feed_jitter` | 0 to 1 / 0.95 to 1.05 |
| `flour_mix` | shares sum to 1 ± 1e-9 |
| `since_feed_s` | ≥ 0 |
| `moldy` | once true, always true |

### 2.4 Save tests (L5)

Layout is per data-models §9.
- Files in `user://saves/`: `save.json`, `save.tmp` and `save.prev`.
- Line 1 is a header (`bytes`, `format`, `sha256`, `version`), then the payload bytes.
- Load order: `save.json`, then `save.tmp`, then `save.prev`.
- Settings live apart, in `user://settings.cfg`.

| ID | Given / When | Then |
|---|---|---|
| SAVE-01 | 1,000 random valid states are saved, then loaded | Deep-equal, bit for bit, including RNG strings, the journal, the event ledger and `meta`. Floats are stored as hex bit patterns (OD-18), so no tolerance. |
| SAVE-02 | Any save | The header parses. `sha256` and `bytes` match the payload bytes. The payload is sorted, full-precision JSON on one line. |
| SAVE-03 | `save.json` has a wrong sha256 or byte count | `save.tmp`, else `save.prev`, loads. The bad `save.json` is moved to `quarantine/` at load time, byte-identical, never deleted (data-models §9.4). |
| SAVE-04 | `save.json` truncated at 0, 1, 50% and len − 1 bytes, or the header line only | Same as SAVE-03. |
| SAVE-05 | Binary garbage, a JSON array, missing fields, wrong types (`"rise": "high"`), `NaN` text, a wrong `format` | Same as SAVE-03. No crash. |
| SAVE-20 | Every corrupt case in SAVE-03 to SAVE-05 and SAVE-10 | **0 logged engine or script errors** (the R-3 Logger count). The loader must use `JSON.new().parse()` and `typeof()` checks, not `JSON.parse_string()` or typed assignment, which log errors (architect ran this, data-models §1 and §9.4). Catches a loader regression. |
| SAVE-06 | All candidate files are bad | First, every candidate moves to `user://saves/quarantine/<unix>_<name>`, keeping the newest 5 sets. Then a new starter with `meta.recovered_from = "quarantine"` and a calm notice. The quarantined bytes equal the originals. 6 failures in a row leave exactly 5 sets. (data-models §9.4) |
| SAVE-07 | No save files | First-run flow. |
| SAVE-08 | `fault_point` = `before_tmp_write`, `mid_tmp_write`, `before_rename`, `after_rename` | The next load gives exactly the old or exactly the new state. For `after_rename`, `save.tmp` loads (the new state) and is renamed to `save.json` at once, so after the load `save.json` holds the new state. Never a mix, never a new starter. |
| SAVE-09 | A write error (disk full) | The old files are unchanged. The in-memory state is kept. `save_failed(reason_key)` fires once. The next trigger retries. |
| SAVE-10 | `version` > CURRENT | Moved to quarantine, never overwritten. The next candidate loads. |
| SAVE-11 | Migration | Every released version keeps `tests/fixtures/saves/v<N>_*.json` forever. Each one loads, migrates and equals the expected current-version payload. Fixtures are never edited. |
| SAVE-12 | Triggers: each action, each state-id change, every 10 min in the foreground, `APPLICATION_PAUSED` (2015), `FOCUS_OUT` (2017), `WM_CLOSE_REQUEST`, Android back with no sheet open | Each produces a write with a newer `saved_unix` and a higher `save_count`. |
| SAVE-13 | A synthetic year: 2 feeds a day, every event, every smell and inspect | Size ≤ 128 KB. Write < 10 ms (Mac estimate, architecture §11). The journal holds exactly 400 entries. Drop order: `state_change` first, then inspect and smell, then the oldest of any kind. `memorial` and `milestone` entries are never dropped (data-models §6). |
| SAVE-14 | `rng.sim_state` near 2^63 (the save's `rng` section holds only `sim_seed` and `sim_state`) | Round-trips as a string. Restore sets `state` only, never `seed` after `state` (that resets the stream, architect ran this). 3 straight feeds equal 1 feed, save, load, 2 feeds. |
| SAVE-15 | A fixed fixture | Fixed sha256 (golden). |
| SAVE-16 | Killed during catch-up, before the post-catch-up save | The relaunch catches up again from the same file, to the same result. |
| SAVE-17 | `save.json` corrupt, `save.prev` good. Load (from prev), save, then corrupt the new `save.json`. | The next load still finds a good file. The untrusted `save.json` is quarantined, never rotated into `save.prev` (data-models §9.3, fixed after this finding). |
| SAVE-18 | A corrupt save, or a corrupt `settings.cfg` | Each failure leaves the other file untouched. |
| SAVE-19 | Android emulator | `DirAccess.open(base).rename()` overwrites atomically. Phase 5, because it's unverified on Android (architect). |

### 2.5 Clock tests (L6)

Rules are from architecture §5.3, with `gap = sim_time_unix − now` and `CLOCK_REANCHOR_GAP_S = 21600`, which tests read from `src/core/time_policy.gd`.

| ID | Scenario | Expected |
|---|---|---|
| CLK-01 | Close at T, open at T + 8 h | 480 steps. `simulated_s` = 28,800. |
| CLK-02 | Open at T + 30 d | `simulated_s` = 14 d. `capped = true`. `sim_time_unix` = `grid(now)`. The summary says the time was long. |
| CLK-03 | Open at T − 1 h | 0 steps. The anchor is kept. The state is unchanged. No repeated events or journal entries. |
| CLK-04 | Close at T, open at T − 1 h, then open at T + 2 h | 2 h simulated in total. |
| CLK-05 | The clock jumps 5 years ahead, the app opens (capped at 14 d), the clock is corrected (gap > 6 h, so it re-anchors), then the app opens 1 h later | The last launch simulates 1 h. `reanchored = true` once. `meta.clock_reanchors` = 1. |
| CLK-06 | The local offset changes by +3600 and by −3600 (DST) | Sim results are byte-identical to a fixed-offset run. Quiet hours follow wall time. No nudge is created twice in the repeated hour. Caps count per local date (23 h and 25 h days). This holds in live play, where the offset is read every tick. **Catch-up:** one offset, read at resume, applies to the whole window, so quiet hours before a DST change inside it can be 1 h off (architecture §5.4, accepted limit). The test asserts exactly that documented behavior. |
| CLK-07 | The offset changes from UTC−5 to UTC+9 mid-day | The sim is unaffected. In live play, quiet hours and the 08:00 deferral use the new offset from the moment of the change. In catch-up, the offset read at resume applies to the whole window (same accepted limit as CLK-06). |
| CLK-08 | Elapsed is 14 d − 60 s, exactly 14 d, then 14 d + 60 s | `simulated_s` = min(elapsed, 14 d). Events exist only inside the simulated window. |
| CLK-09 | Foreground: the wall delta exceeds the monotonic delta by 299 s, then by 301 s | 299 s: the wall delta is used. 301 s: the monotonic delta only. |
| CLK-10 | The feed sheet is open, then the app is backgrounded for 8 h | On resume, catch-up runs first. The sheet's preview updates or the sheet closes (TBD-UX). The feed applies on Mix at `grid(now)`. Exactly 1 feed. |
| CLK-11 | 20 background and foreground cycles in 2 s | Simulated time equals wall time. No duplicates. `on_background()` is idempotent. |
| CLK-12 | The device clock reads 1970 after a battery drain | gap > 6 h, so it re-anchors with the state unchanged. Correcting the clock later credits that gap, capped at 14 d (see CLK-17). |
| CLK-13 | Debug time scale | `DebugClock` is constructed only when `OS.is_debug_build()` (LINT-10). A release-export check waits for the export templates (OD-9). |
| CLK-14 | App open 3 h with the clock running | Byte-identical to closed for 3 h (PROP-01). |
| CLK-15 | Dec 31 to Jan 1, and Feb 29 | The quiet window crosses midnight. Daily caps reset at local midnight. |
| CLK-16 | gap = 21,600 s, then 21,601 s | 21,600: hold the anchor. 21,601: re-anchor. |
| CLK-17 | **Known limit:** the clock is set back 2 d (re-anchor), the player plays 1 h, then the clock is corrected | The next launch credits about 2 d. That's accepted (architect ADR-006). The test asserts the credit is ≤ 14 d and needs a backwards jump > 6 h. |
| CLK-18 | Mix at `grid + 59 s` | The feed applies at `grid`. The journal records the real `at_unix`. Two feeds in the same minute apply in order at the same grid point. |

### 2.6 Integration (L7)

`Session` with `FakeClock`, a temp `SaveStore`, a seeded `sim_rng` and no rendering.

| ID | Action | Expected |
|---|---|---|
| INT-01 | `FeedAction` | Pipeline order is per architecture §4. When `action_applied` fires, the save on disk already contains the feed (save is step 8, before signals in step 9). `state_changed` carries `VisualMapper.from_state(state, env)`. One journal entry holds all the inputs. |
| INT-02 | `SetEnvironmentAction` | Same chain. The forecast is recomputed. |
| INT-03 | `SmellAction` | No sim variable changes. The readout is in `ActionResult.readout`. The journal is written once per descriptor per rise cycle (game-mechanics §4). |
| INT-04 | `InspectAction` for each slice kind | Same rules, and the readout comes from the state. |
| INT-05 | `on_resume()` after 25 h | `resumed(summary)`. Event times are real. `ReturnSummary.build` follows §4.2. Dropped items are in the journal. |
| INT-06 | `moldy`, then `DiscardStarterAction` | A memorial entry. The old journal is kept, and its entries keep the old `starter_id`. New entries get the new `starter_id`. The new starter starts clean. |
| INT-07 | A rejected action (Mix while `moldy`), with `FakeClock` frozen so step 1 sync can't advance time | `action_applied` reports rejected with a reason key. State, journal and save are byte-unchanged. |
| INT-08 | 100 pokes (`starter_tapped`) | The payload is byte-unchanged (UX §6: a poke never changes the sim). |

### 2.7 Lint and static checks (L1)

| ID | Check | Enforces |
|---|---|---|
| LINT-01 | `src/sim/**` has none of: `Time.`, `OS.`, `Engine.`, `randi(`, `randf(`, `randomize(`, `extends Node`, `Node.new`, `get_tree(`, `Input.`, `DisplayServer.`, `FileAccess`, `DirAccess`, `\bload(`, `preload(`, `tr(` (matches architecture §1) | Hard rule 1 |
| LINT-02 | `src/**` and `project.godot` have no `HTTPRequest`, `HTTPClient`, `StreamPeerTCP`, `StreamPeerTLS`, `PacketPeerUDP`, `WebSocketPeer`, `ENetMultiplayerPeer` or `JavaScriptBridge`, and no analytics plugin | Hard rule 6 |
| LINT-03 | Every `.gd` under `src/` instantiates (R-8), with the project's warning-as-error settings | Hard rule 4 |
| LINT-04 | `.tscn` `text`, `placeholder_text`, `tooltip_text` and `accessibility_name` values are empty or a key matching `^[A-Z][A-Z0-9_]*$` (architecture §10, ADR-014). Every `tr()` key exists in `src/i18n/en.csv` (generated by narrative-designer from their docs) or in `pending_core.csv`, `pending_view.csv` or `pending_ui.csv`, with a non-empty `en` value. | Hard rule 3 |
| LINT-05 | Starter `set_shader_parameter` calls appear only in the `JarView` adapter that consumes `VisualParams` | Hard rule 2 |
| LINT-06 | **Safety copy** (prefixes from game-copy.md §16). Case-insensitive throughout. **Safety set** (`STATUS_MOLDY_`, `STATUS_UNHEALTHY_`, `SMELL_MUSTY_`, `SMELL_MOLDY_`, `INSPECT_*_MOLDY*`, `INSPECT_*_UNHEALTHY*`, `INSPECT_SURFACE_HOOCH_DARK_`, `EVENT_WARNING_SIGNS_`, `EVENT_MOLD_FOUND_`, `MOLD_`, `MEMORIAL_`, `NOTIF_WARNING_`, `REASON_MOLDY`, `REASON_NOT_MOLDY`): never "safe to", "still good", "scrape", "skim off", "just remove", "fine to use", "fine to eat", "ok to eat" or "okay to eat". **Must say "discard":** `STATUS_MOLDY_HINT`, `STATUS_MOLDY_TAP`, `SMELL_MOLDY_BODY`, `INSPECT_*MOLDY*_MEAN`, `MOLD_SHEET_BODY*`, `MOLD_FEED_BLOCKED`, `REASON_MOLDY_LOCKED` (game-copy §16, narrative's copy pass 2026-11-26). **Hunger set** (`STATUS_HUNGRY_`, `STATUS_DORMANT_STARVED_`, `SMELL_ACETONE_`, `SMELL_ALCOHOL_`, `SMELL_STRONGLY_ACIDIC_`, `EVENT_HOOCH_FORMING_`, `EVENT_HUNGRY_AGAIN_`, `EVENT_FIRST_ACETONE_`, `INSPECT_SURFACE_HOOCH_`, `INSPECT_*_HUNGRY*`, `FEED_HOOCH_`, `GLOSS_HOOCH`): never "danger", "unsafe", "toxic", "sick", "poison", "throw it out" or "throw away". **Any key:** never "probiotic", "gut health", "health benefit" or "cure". Today `run.sh`'s copy lint runs narrative's `check_copy.py`, which reads the docs only. Placeholder rows in `pending_*.csv` (for example T1's 13 `REASON_*` keys) never pass through it, so the GDScript port over all four CSVs is what closes that gap (not built yet). | Safety rules, hard rule 5 |
| LINT-07 | Nothing tracked matches `*.keystore`, `*.jks`, `*.p12`, `*.mobileprovision`, `*.pem`, `export_credentials.cfg` or `.env*`. `.godot/` and `*.translation` are untracked. | Hard rule 10 |
| LINT-08 | No U+2014 (em dash) in `src/i18n/*.csv` | Style |
| LINT-09 | The code's state, action, flour, location, container, cover and inspection-kind constants equal the `vision.md` lists | Canonical ids |
| LINT-10 | `DebugClock` and dev flags (`--fixture`, `--time-scale`, `--perf-log`, `--capture`) are reachable only behind `OS.is_debug_build()` | Vision time rules |
| LINT-11 | No key is duplicated across `en.csv` and the three `pending_*.csv` files. Known on 2026-11-26: the 13 `REASON_*` keys sit in both `en.csv` and `pending_core.csv` until T1 deletes its rows, so this fails until then. | Track separation (ADR-014) |
| LINT-12 | At the Phase 3 exit and before any release, all `pending_*.csv` files are empty, so no placeholder copy ships | Hard rule 3 |

---

## 3. Acceptance criteria for the 12 vertical-slice items

Every Then is measurable. "Looks good" is never a pass condition. Slice scope comes from game-mechanics:
- Ratio presets 1:1:1, 1:2:2 and 1:5:5
- Flours `white_bread` and `whole_wheat`
- Hydration fixed at 100%, discard derived
- Locations `counter` 22 °C, `warm_spot` 26 °C and `fridge` 4 °C (spec §2.2)
- `loose_lid` and `classic_jar`, both fixed
- Inspect kinds `height`, `bubbles` and `surface`
- 6 events

### AC-01 A beautiful 3D jar

| ID | Given | When | Then | Check |
|---|---|---|---|---|
| AC-01.1 | The jar GLB in `assets/3d/` | Imported headless, and checked with `python3 art/blender/scripts/verify_glb.py` | The nodes in art-direction's mesh contract exist: `Jar_Glass`, `Starter_Body` (with UV2), `Starter_Liner`, `Jar_Lid_Loose`, `Jar_Lid_Tight`, `Cloth_Cover`, `Rubber_Band`, `Counter`, and the empties `StarterFloor` and `StarterRim`. Every mesh has normals and UV0. The checker exits 0. The checker also asserts each cover's visible set ≤ 16k. **QA re-ran it after the cloth rebuild: PASS, exit 0.** Visible sets: loose lid 13,568, tight lid 12,512, cloth 14,552. All variants: 18,680. | auto |
| AC-01.2 | The jar scene | Loaded | Glass draws back faces before front faces (render priority back < front, D-009). Every material inside the glass is opaque or alpha-scissor. | auto |
| AC-01.3 | Fixture `at_peak`, from the art-direction §7 preview pose: target (0, 0.105, 0), distance 0.58 m, pitch −15°, vertical FOV 33.4° (KEEP_HEIGHT), near 0.01 | 36 captures at 10° yaw steps across the yaw range | The reviewer finds 0 frames where the starter or liner draws in front of the near glass, 0 flicker between neighbors and 0 z-fighting at the rim. | capture + review |
| AC-01.4 | Mobile Tier A, Mobile Tier B, Compatibility Tier A, captured at the art-direction "preview pose" | Compared with `art/previews/jar_v0_<state>.png` and the per-state tells in `art-direction.md` "Reference renders" | art-director ticks all of MAN-01. The references are Blender Cycles renders, so a Godot capture must match the **tells**, not the pixels. Compatibility has no missing object and no black or magenta surface. | review |
| AC-01.5 | Main scene, idle, slice configuration (loose lid, no cloth) | `Performance` monitors | ≤ 16k rendered triangles. From the checker's per-node counts, jar_v0's visible set is 13,568. Fewer than 10 draw surfaces for the jar. Fewer than 30 draw calls total (architecture §11). | capture |
| AC-01.6 | Default pose, iPhone SE and 17 Pro Max sizes | Projected jar AABB | The jar is centered in the jar region (UX §2: between the HUD plate and the action bar) within ±4% of its height. It fills at least TBD-UX % of the region. | capture |
| AC-01.7 | The glass materials | Shader code is scanned, then "reduce effects" is toggled | The Tier A glass shader has no `hint_screen_texture`. Tier B is the only one that samples the screen. The toggle swaps the material, and no bool uniform exists for it. Compatibility always uses Tier A. | auto |

### AC-02 An animated starter

| ID | Given | When | Then | Check |
|---|---|---|---|---|
| AC-02.1 | Each non-moldy fixture, idle | Two frames 2 s apart | The mean absolute pixel difference in the starter region is ≥ TBD-ART (proposed 0.3%), so it's alive, and ≤ TBD-ART (proposed 5%), so it's calm. | capture |
| AC-02.2 | 1:1:1 `white_bread` at 24 °C | Sim and mapper, 60 s steps, through peak and collapse | `rise` equals the mapper's output for the sim state at every step, rises monotonically to `at_peak`, and no field jumps more than `max_delta` per step. | auto |
| AC-02.3 | All 11 state fixtures | Mapped | These pairs differ in at least one `VisualParams` field by at least the visible delta (TBD-ART): `freshly_fed`/`at_peak`, `at_peak`/`collapsing`, `freshly_fed`/`hungry`, `hungry`/`unhealthy`, and `moldy` vs. every other state. | auto |
| AC-02.4 | Six rise-phase stills, no HUD, random order | Named by a reviewer who didn't build them | At least 5 of 6 are correct. | review |
| AC-02.5 | `moldy`, iPhone SE size, no HUD | Shown to 3 reviewers | 3 of 3 identify mold. art-director confirms it shows every `moldy` tell from `jar_v0_moldy.png` (stylized, not gross). | review |
| AC-02.6 | Reduce motion on | Any state | The sim-driven rise, bubbles and hooch still animate (UX §15). The decorative motion listed in UX §15 is off. | auto + capture |
| AC-02.7 | 60 s per state | Watched | Every MAN-02 item is ticked. | review |

### AC-03 Rotate and zoom

Input is injected with `InputEventScreenTouch` and `InputEventScreenDrag`. Numbers are from UX §6.

| ID | Given | When | Then | Check |
|---|---|---|---|---|
| AC-03.1 | Home pose | One-finger drag of N pt horizontally, then vertically | Yaw changes by 0.30° × N and pitch by 0.20° × N, each ±1%. | auto |
| AC-03.2 | Any pose | A 10,000 pt drag in each direction | While dragging, yaw and pitch never pass the limits plus the rubber band (yaw ±70° + 8°, pitch −5° to +35° + 5°). After release, they settle back inside the limits. These limits apply to free orbit only. Inspection presets may exceed them: the `surface` preset is at 76° pitch (78° if art-director reports a cap height under 34 mm; ux-design §10). At 60° the view went through two layers of glass. | auto |
| AC-03.2b | A one-finger orbit in progress | The finger slides over the action bar | The camera keeps the finger from press to release and keeps orbiting (UX §6 rule 1). Same as AC-03.10, from the camera side. | auto |
| AC-03.3 | Two fingers, both started in 3D | Spread and pinch | Zoom stays within 1.0× to 2.2× of the home distance, plus an 8% rubber band while held. It settles inside on release. A light haptic tick fires at each limit. | auto |
| AC-03.4 | One finger orbiting | A second finger lands on a plate | It's ignored. No pinch starts and the orbit continues. | auto |
| AC-03.5 | Pinching | One finger lifts | Back to orbit, with a yaw jump < 1°. | auto |
| AC-03.6 | Any pose | Two taps ≤ 300 ms apart and ≤ 24 pt apart | The camera eases home over 350 ms (±1 frame) and ends within 0.1° and 1 mm of home. The first tap's poke still plays. | auto |
| AC-03.7 | Release at velocity v | Inertia with τ = 250 ms | After 1.25 s (5τ) the speed is < 1% of v. No drift after 10 s. With reduce motion on, there's no inertia. | auto |
| AC-03.8 | No touch for 20 s | Idle | The camera eases home over 1,500 ms. Off with reduce motion. | auto |
| AC-03.9 | A touch starts on an action-bar button | It drags over the jar | No orbit. The press cancels once the touch leaves the button by > 10 pt. | auto |
| AC-03.10 | A touch starts on the jar | It drags across the action bar (a `STOP` Control) and releases there | Orbit continues for the whole drag. The release reaches the camera, so the gesture ends cleanly and no finger is left claimed. No button activates. Mechanism (architecture §9): the camera claims the finger on press in `_unhandled_input`, then follows its drags and release in `_input`. **Regression proof:** with the spike's `--no-own-touches` behavior, this test must fail. | auto |
| AC-03.11 | Any sheet open | Touches on the scrim | A tap closes the sheet (except during the feed sequence and on attention sheets). A drag does nothing. The camera never moves. | auto |
| AC-03.12 | Any pose | 10,000 random events: 1 to 3 fingers, random indices, out-of-order releases, canceled touches | No NaN. The pose stays within the clamps and bands. After all fingers lift, a one-finger drag orbits normally. | auto |
| AC-03.13 | Mac with mouse, iOS simulator | MAN-03 | Every item is ticked. | manual |

### AC-04 Starter lifecycle simulation

| ID | Given | When | Then | Check |
|---|---|---|---|---|
| AC-04.1 | The scientist's vectors | 100 seeds per commit, 1,000 nightly | Every checkpoint is in range for every seed. | auto |
| AC-04.2 | The §4.3 recipes | Run | All 11 states are reached at their checkpoints. | auto |
| AC-04.3 | Overlapping-state fixtures | Derived | Precedence matches the spec. | auto |
| AC-04.4 | BT-1 to BT-12, BT-14, BT-14b, BT-16, BT-17 (§4.2) | Run | Every pass condition holds. | auto |
| AC-04.5 | L-1 to L-11 (§4.2) | Run | Every floor holds. A v1 number under a design floor is reported to the director, not tuned by QA. | auto |
| AC-04.6 | PROP-01 to PROP-09, PROP-13 | Run | All hold. | auto |

### AC-05 Feeding interaction

| ID | Given | When | Then | Check |
|---|---|---|---|---|
| AC-05.1 | A non-moldy starter | Mix with each preset and flour | Keep, flour and water equal the game-mechanics §2.3 table. The next derivation is `freshly_fed`. `since_feed_s` = 0. One journal entry. `state_changed` fires. A save is written. | auto |
| AC-05.2 | The feed sheet | It opens | Last time's ratio, flour and hooch choice are preselected. The slice offers no free keep, hydration or ratio input. Mix is disabled with a shown reason only when the starter is `moldy`. | auto |
| AC-05.3 | An earlier feed, the main screen visible | Feed, then Mix | **2 taps.** The stored `FeedAction` equals the previous one, field by field, except the time (BT-13). | auto |
| AC-05.4 | A return with the time-lapse, or a pending attention | Skip, then Feed (or the secondary "Feed it now"), then Mix | **3 taps or fewer** (BT-13, UX §7). | auto |
| AC-05.4b | `warning_signs` attention pending on return | The primary path: Skip, "Look first" (runs the `surface` check), "Feed now", Mix | **4 taps or fewer** (UX §7). "Look first" is the bottom, primary button on the sheet. "Feed it now" is secondary, and still reaches fed in 3 or fewer (AC-05.4). | auto |
| AC-05.5 | `hooch` ≥ 0.1 (spec §15, "visible") | The feed sheet opens | The hooch step comes first, with "Pour off" as the default. `stir_in` adds hydration with no acid effect (V20: +0.8 hydration points at hooch 0.46, and the peak moves by ≤ 0.05 h). `pour_off` is journal-only, with no sim change beyond the feed reset. At 0.1 − ε, there's no hooch step. `hooch_forming` fires when hooch crosses 0.1. | auto |
| AC-05.6 | The state at Mix | Each state | The timing class matches §2.1. `early` shows the non-blocking line. | auto |
| AC-05.7 | After Mix | The sequence runs | It lasts about 6 s, can be skipped after the first feed, and the band snaps on. The forecast card shows words, never a countdown or digits. | auto + manual |
| AC-05.8 | Mix tapped | The process is killed at Mix, mid-sequence and after the sequence | After relaunch, the feed exists exactly once, in both the state and the journal. | auto + manual |
| AC-05.9 | 20 taps in 1 s on Mix | Fast tapping | Exactly 1 feed. | auto |
| AC-05.10 | Mac and simulator | MAN-05 | Every item is ticked. | manual |

### AC-06 Temperature control

| ID | Given | When | Then | Check |
|---|---|---|---|---|
| AC-06.1 | Each of `counter`, `warm_spot`, `fridge` | Selected | It applies instantly, with no confirmation. The environment equals spec §2.2: `counter` 22 °C / 50% RH, `warm_spot` 26 °C / 40%, `fridge` 4 °C / 70%. Temperature is read-only. RH is never shown. `temp_c` approaches the new temperature with the 1.5 h thermal constant, with no overshoot. | auto |
| AC-06.2 | A move at time t | Advance | The result is byte-equal to a run that changes the environment at `grid(t)`. | auto |
| AC-06.3 | 1:1:1 in each location | Run | Peak order: `warm_spot` < `counter` (v1 at 22 °C: 6.1 to 6.3 h). `fridge` gives `dormant` within 3 h of the move, once `ferm(temp_c)` < 0.30. Moving a cold `dormant` back to the counter leaves `dormant` within 6 h (L-11). | auto |
| AC-06.4 | The environment sheet | Opened | It shows the location and the temperature in °C. The move tweens the jar to its spot and the light changes. No `VisualParams` field jumps more than `max_delta`. | auto + capture |
| AC-06.5 | 50 moves between fridge and counter in 1 min | Run | Byte-equal to one segment per actual stay. `off_to_nap` and `waking_up` respect their cooldowns. | auto |
| AC-06.6 | Slice scope | The environment sheet | No cover or container control is offered (both fixed). `window_sill` and `proofing_box` are absent until their P1 unlock. | auto |
| AC-06.7 | 3 taps from the main screen | Move to the fridge | Done within the UX §7 budget of 3. | auto |

### AC-07 Smell interaction

| ID | Given | When | Then | Check |
|---|---|---|---|---|
| AC-07.1 | Every state fixture | `SmellModel.read` | Intensities equal the spec §13 formulas within 1e-9. The displayed set is the top 3 with intensity ≥ 0.15. Ties sort by the vision descriptor order, and `musty` is always first. The intensity words match the bands. The sets match spec §13's typical-set table at 22 °C and the V1 checkpoint sets. | auto |
| AC-07.2 | The same state and the same `feed_count` | Smell 10 times | The same variant key every time. The rule is `n = 1 + (feed_count + DESCRIPTOR_ORDER.find(d)) % 3`, and the faint level uses `1 + feed_count % 2` (game-copy §16). Every variant appears within any 3 consecutive feeds, and no line repeats on consecutive cycles. | auto |
| AC-07.3 | `mold_risk` ≥ 0.3, at any `temp_c` from 0 to 40 | Smell | `musty` is shown (≥ 0.2, exempt from cold damping, spec §13) and listed first. Its meaning line shows every time and says it's a warning sign. Below 0.3, there's no `musty`. | auto |
| AC-07.4 | `hungry` | Smell | The set follows spec §13 and the V1 checkpoints. `alcohol` takes over from `pleasantly_tangy` at about 16 h. `acetone` and `strongly_acidic` follow later. The meaning says normal and feed it. LINT-06 passes. | auto |
| AC-07.5 | A descriptor's 1st, 2nd, 3rd and 4th appearance | Smell | The meaning line shows on the first 3 appearances. After that it's one tap away (except `musty`). | auto |
| AC-07.6 | The main screen | 1 tap on `smell` | The moment lasts about 1.2 s (dolly 600 ms in, 400 ms out). Then the card shows a descriptor word and no digits. | auto |
| AC-07.7 | A smell moment in progress | An event triggers | It waits until the moment ends. | auto |
| AC-07.8 | Mac and simulator | MAN-07 | Every item is ticked. | manual |

### AC-08 Starter condition display

| ID | Given | When | Then | Check |
|---|---|---|---|---|
| AC-08.1 | Each of the 11 state fixtures | The main screen | The pill shows that state's icon shape (UX §11) and its `STATUS_<ID>_WORD`, `STATUS_<ID>_HINT` and `STATUS_<ID>_TAP` keys, all non-empty. `dormant` uses `STATUS_DORMANT_COLD_*` when `ferm(temp_c)` < 0.30, else `STATUS_DORMANT_STARVED_*`. All 11 icons differ. The word renders in ink, and the tone is on the icon and border only. | auto |
| AC-08.2 | App open | The state changes | The pill updates when `state_changed` fires: a 250 ms crossfade plus a pulse, crossfade only with reduce motion. | auto |
| AC-08.3 | The main screen, its toasts and cards | All visible text | No `[0-9]` outside the player-typed name (UX §4). | auto |
| AC-08.4 | Inspect `height`, `bubbles`, `surface` | Each chip | The camera reaches the kind's framing in 500 ms. The card appears within 3 s. The readout keys follow spec §14 at its thresholds. Two taps (UX §7). `consistency` and `development` are absent in the slice. | auto |
| AC-08.5 | `moldy` | Every action | Inspect and Journal work. Feed, Smell and Place are locked: each shows a 12 pt lock badge (never color alone) and, when tapped, a visible reason: Feed gives the `MOLD_FEED_BLOCKED` toast, Smell the "Best not" card (`SMELL_MOLDY_*`), Place the `REASON_MOLDY_LOCKED` toast. `mold_found` can be closed with "Not yet", and then a non-dismissable discard card stays above the bar. Discarding takes exactly 2 taps: "Discard it", then "Discard" in the confirmation (UX §7). The `surface` inspect and the status explainer say discard. The scientist signs off on every `unhealthy` and `moldy` string. LINT-06 passes. (UX numbers per ux-designer, 2026-11-26. D-043: T3 builds the locks in Phase 3.) | auto + review |
| AC-08.6 | Grayscale captures of all 11 states, in random order | Reviewed | Every state is named from the icon and word alone. | review |
| AC-08.7 | A state shown for the first time | The main screen | The pill shows the "new" dot until tapped, and once only. | auto |
| AC-08.8 | Status pill tapped | Explainer card | Body ≤ 120 characters. "Show me" moves the camera to the state's main cue. | auto |

### AC-09 Offline progression

| ID | Given | When | Then | Check |
|---|---|---|---|---|
| AC-09.1 | Close at T | Reopen at T + Δ, Δ in {1 min, 59 min, 60 min, 8 h, 25 h, 3 d, 7 d, 13 d, 14 d, 30 d} | `simulated_s` = min(Δ, 14 d). The state is byte-equal to a foreground run of the same length. | auto |
| AC-09.2 | Same | Reopen | "While you were away" shows only if Δ ≥ 60 min (`AWAY_SUMMARY_MIN_S` = 3,600) **and** at least one event or state change happened (game-mechanics §8). Boundary: 3,599 s and 3,600 s. | auto |
| AC-09.3 | 7 days away, many events | Reopen | At most 3 summary lines and 1 prompt. Keep priority and drop order per §4.2. Every dropped item is in the journal (BT-15). | auto |
| AC-09.4 | Attention pending on return | Reopen | The summary card is skipped, and its lines go at the top of the attention sheet. | auto |
| AC-09.5 | Any qualifying return | The time-lapse | It uses ≤ 30 `CatchUpResult.snapshots`, plays 3 to 6 s (longer absences get longer, capped at 6 s), and a tap skips it. Reduce motion shows a before still and an after still, 1.2 s each. With the setting off, it's skipped. | auto |
| AC-09.6 | Return to `moldy` | Reopen | The time-lapse runs past the warning stages. The summary names when the warnings began. Then `mold_found` shows. | auto |
| AC-09.7 | A 14-day catch-up | Resume | `CatchUp.run` takes ≤ 250 ms (Mac estimate). The first jar frame comes within 2 s (device target, Mac value recorded as an estimate). | capture |
| AC-09.8 | CLK-01 to CLK-18 | Run | All pass. | auto |

### AC-10 At least five contextual events

Slice events (game-mechanics §7.4):
- `first_rise` (info)
- `peaked_while_away` (info, with the variant `peak_now`)
- `hungry_again` (nudge)
- `hooch_forming` (info)
- `back_to_strength` (info)
- `warning_signs` (attention)

`events-catalog.md` §3 confirms these six ids. `mold_found` (attention) is the loss path. QA supports catalog OD-E1: build it in the slice behind the debug time scale, so its safety copy gets tested on screen. AC-09.6 and EC-01 already need it.

| ID | Given | When | Then | Check |
|---|---|---|---|---|
| AC-10.1 | Each slice event | Positive and negative scenarios | It fires in the positive scenario, with the right tier and payload, and never in the negative one. The thresholds are tested at value ± ε: `first_rise` when rise crosses 1.4, `hooch_forming` when hooch crosses 0.1, `warning_signs` when `mold_risk` crosses 0.5. | auto |
| AC-10.2 | 30-day random schedules, 1,000 seeds | Evaluate | Per local date: ≤ 2 nudges and ≤ 1 attention created, ≤ 4 live info toasts, all info logged. **Never more than 1 attention waiting.** | auto |
| AC-10.3 | Same | Same | Each cooldown in §4.2 holds. | auto |
| AC-10.4 | Quiet hours 22:00 to 08:00 local, including DST and offset-change days | Evaluate | Info is logged. A nudge is deferred to 08:00, re-checked, and dropped if stale. Attention is never deferred or dropped. | auto |
| AC-10.5 | A nudge was created | The player fed before it showed | It's dropped silently (`expires_if`). | auto |
| AC-10.6 | An attention is waiting | A second attention triggers | It's held until the first is acknowledged, except `mold_found`, which replaces it. | auto |
| AC-10.7 | An event and a milestone at the same moment | Released | Only the event shows. The milestone goes only to the journal. | auto |
| AC-10.8 | An open sheet, the feed sequence, the smell moment, inspection or the time-lapse | An event triggers | It waits until that closes. That includes attention. | auto |
| AC-10.9 | BT-1, BT-2, BT-3, BT-9 | Run | 0 attention events. | auto |
| AC-10.10 | BT-7 and SIM-WARN-03 | Run | At `counter`: `warning_signs` (unhealthy onset) comes ≥ 72 h before `mold_found`. v1 is about 106 h, within V9's ranges (unhealthy 104 to 111 h, moldy 207 to 219 h). At any location or temperature from 4 to 40 °C: ≥ 59 h. Spec §10 guarantees ≥ 60 h (bound 60.6 h), and 59 h is the scientist's test floor. Well above L-6's 48 h. | auto |
| AC-10.11 | `back_to_strength` | A rise after a very_late feed | It fires only if `peak_rise` ≥ 85% of the pre-neglect value. | auto |
| AC-10.12 | `peaked_while_away` | A peak phase with `ctx.app_foreground` false, then one in the foreground | The first gives `peaked_while_away`, the second `peak_now`. Once per rise cycle. | auto |

### AC-11 Save and load

| ID | Given | When | Then | Check |
|---|---|---|---|---|
| AC-11.1 | SAVE-01 to SAVE-18 | Run | All pass. | auto |
| AC-11.2 | A running game | Killed at each `fault_point` | Relaunch shows the state just before or just after the last action. Never a new starter. | auto |
| AC-11.3 | iOS simulator | Background with the home gesture, then kill from the app switcher | Relaunch has the latest feed. | manual |
| AC-11.4 | Builds N and N+1 with a schema change | Save in N, open in N+1 | Migration works, and the save matches the expected fixture (SAVE-11). | auto |

### AC-12 A polished mobile UI

| ID | Given | When | Then | Check |
|---|---|---|---|---|
| AC-12.1 | Every screen and sheet at iPhone SE and Android compact (360 × 640) sizes | Scene scan | Every input control's hit area is ≥ 44 × 44 pt (48 × 48 standard). Action bar slots are ≥ 64 × 64. Hit areas never overlap. | auto |
| AC-12.2 | Text at 100%, 125% and 150% with the longest copy | Every screen | Body text ≥ 16 pt at 100%. The type scale matches UX §17. No Label clips or overflows. Text containers grow vertically. | auto |
| AC-12.3 | Theme colors | Contrast computed | Text ≥ 4.5:1. Non-text (icons, borders, focus) ≥ 3:1. | auto |
| AC-12.4 | HUD plates over the 3D scene | Contrast computed | Plate alpha ≥ 0.88. Text contrast ≥ 4.5:1 against the plate blended over pure black **and** over pure white (worst case, so it needs no capture). No text sits directly on the 3D scene. | auto |
| AC-12.5 | Every Control | Its stylebox and font are resolved | Neither comes from `ThemeDB.get_default_theme()`. One Theme: `src/ui/theme/sourdough_theme.tres`. | auto |
| AC-12.6 | The §9 matrix | Layout per device | HUD plate top = safe top + 8. Bar bottom = safe bottom + 8, never below the UX §2 floor (SE 8, 17e / 17 Pro / 17 Pro Max 42, **every Android phone 56 dp**: max(reported, 48) + 8, because Godot can't tell gesture navigation from 3-button). Side gutters ≥ 16. | capture (Phase 5) |
| AC-12.7 | The 12 tap budgets in UX §7 | Scripted paths | Each path is within its budget. | auto |
| AC-12.8 | Motion | Tweens inspected | Durations and easing match UX §15 (sheet 300 / 220 ms, card 280 / 200 ms, and so on). With reduce motion, the listed fallbacks apply. | auto |
| AC-12.9 | A disabled control | Shown | A reason is visible. | auto |
| AC-12.10 | An action bar button | Long-press 500 ms | A 200% label popup appears. | auto |
| AC-12.11 | Android back | A sheet open, then no sheet | It closes the top sheet. With no sheet, it saves and quits. | auto |
| AC-12.12 | Sheet transitions | Captured | No regression over 20% (Mac and simulator estimates, §7). | capture |
| AC-12.13 | UX wireframes | MAN-12 | ux-designer and art-director tick every item. | review |
| AC-12.14 | Strings | LINT-04, LINT-06, LINT-08, LINT-11, LINT-12 | Pass. | auto |
| AC-12.15 | Every phone in the §9 matrix, text at 100% and 150% | Layout under the harness's fixed-size root | The jar region is ≥ 55% of the screen height on every iPhone at every text size, and ≥ 51% on 360 × 640 at every text size (T3 measured 52% at 100%, 51% at 150%, iPhones 61 to 66%). Other Android profiles: TBD-UX. The bar plate is exactly 72 on every phone (no compact-height mode). The StatusPill is ≥ 44 tall. T3's layout test is the check. Source: ux-designer, 2026-11-26, after D-043. **Pending:** committed D-043 still says 45% at 360 × 640 and a 64 pt compact bar under 700 pt, so the director needs to update it. | auto |

---

## 4. Sim and time tests tied to the specs

### 4.1 Sim spec v1

ε is 1e-6 for unitless values and 1 s for times.

| Spec v1 rule | Test |
|---|---|
| Ranges (§1) | PROP-03 |
| `moldy` latches at `mold_risk` ≥ 1.0. A feed on `moldy` is refused and changes nothing (V14). | SIM-DER-01 (1.0 − ε / 1.0), PROP-05, INT-07 |
| `unhealthy` at `mold_risk` ≥ 0.5 | SIM-DER-02 (0.5 − ε / 0.5) |
| `dormant`: `ferm(temp_c)` < 0.30 (below about 11 °C), or `starved_h` ≥ 60 weighted h | SIM-DER-03 (ferm 0.30 − ε / 0.30), SIM-DER-04 (`starved_h` 60 − ε / 60) |
| `recovering`: `vigor` < 0.6, or `vigor_at_feed` < 0.75 | SIM-DER-05, SIM-DER-06, each at its boundary |
| Rise phases, first match wins (§12.1) | SIM-PHASE-01 to 07, each rule at its boundary: food 0.10, `since_feed_s` 3,600, rise 1.05 and 1.15, 0.94 × `peak_rise`, `rise_rate` 0.2 and 0.75 × `peak_rate`, food 0.25 × `food_at_feed` |
| Precedence (§12.2) | SIM-PREC-01, every pair |
| One `sim_rng` draw per feed, stored as `feed_u`. `feed_jitter = 0.95 + 0.10 × feed_u`. `big_bubble` is deterministic from `feed_u`. | SIM-RNG-01 (within bounds, stored, never redrawn on load, exactly 1 draw per feed), PROP-13 |
| 60 s Euler grid, exactly invariant to splits | PROP-01, V17, CLK-18 |
| Keep from 1 g up to `mass_g`. Keep 0 is rejected. | V11, plus a rejection test. Unreachable from the slice UI (derived discard). |
| 12 feeds, 10 min apart | V10, EC-04 |
| 1:50:50 | V4, V11 (sim-level, P2) |
| Optimum and falloff | PROP-06, V2, V12 |
| Mold accrues only with `food` < 0.10 and `starved_h` > 24. `mold_t` ramps with temperature. | PROP-04, SIM-MOLD-01 (24 − ε / 24 + ε weighted h) |
| Multiplier cap 2.2: warning to mold ≥ 60 h (bound 60.6 h), watch to mold ≥ 77 h (bound 77.7 h), at any temperature | SIM-WARN-03: sweep 4 to 40 °C in 1 °C steps, every cover, RH 30 to 70%. Assert warning to mold ≥ **59 h** and watch to mold ≥ **76 h** (the spec's test floors). Both exceed L-6's 48 h "anywhere" floor. |
| Watch stage: `musty` shows and is listed first at any temperature (§13, fixed after QA's cold-damping finding) | SIM-WARN-01: no `musty` below 0.3. From 0.3, `musty` ≥ 0.2 and listed first, at `temp_c` 0 to 40. |
| Fridge `mold_risk` reaches 0.12 to 0.15 in 14 d | L-8, V13, V15 |
| A feed multiplies `mold_risk` by 0.3 | PROP-08, V9b |
| Counter neglect (V9): hungry 12.4 to 12.8 h, dormant 74 to 77 h, watch 72 to 80 h, unhealthy 104 to 111 h, moldy 207 to 219 h | V9, BT-7, L-4 to L-7 |
| 30 days away (V13) | EC-01, EC-02 |
| Once a day for 14 d at 22 and 24 °C: vigor ≥ 0.8 (measured min 0.89 and 0.83), `mold_risk` 0, never `recovering`, `dormant` or `unhealthy` (V16) | V16, L-1 |

### 4.2 Game designer (game-mechanics §7 to §10)

Defaults: `white_bread`, 100%, `loose_lid`, `counter` 22 °C. Steady state means 3 days of BT-1.

| ID | Scenario | Pass condition |
|---|---|---|
| BT-1 | 1:2:2, fed 08:00 and 20:00, 14 d | Never `unhealthy`. `mold_risk` < 0.3. At least 1 `at_peak` per 24 h. 0 attention events. `hungry` ≤ 4 h a day. |
| BT-2 | 1:5:5, fed 19:00, 14 d | Never `unhealthy`. `mold_risk` < 0.3. `at_peak` starts 9 to 13 h after each feed. 0 attention events. |
| BT-3 | 1:2:2, fed 07:00 and 22:00, 14 d | As BT-1, plus no nudge is created between 22:00 and 08:00. |
| BT-4 | Weekend in the fridge | 0 attention events. `mold_risk` < 0.3. `peak_rise` ≥ 85% of the pre-weekend value within 2 feeds. |
| BT-5 | 24 h away | `hungry`, no attention event. 1 feed gives ≥ 85% `peak_rise`. |
| BT-6 | 14 d in the fridge | Never `unhealthy`. Normal rise within 2 feeds. |
| BT-7 | Neglect on the counter | `unhealthy` ≥ 96 h. `moldy` ≥ 168 h. At least 72 h from `unhealthy` to `moldy`. At any location or temperature: at least 48 h (SIM-WARN-03 asserts 59 h). |
| BT-8 | Rescue at `unhealthy` onset | Out of `unhealthy` after 1 feed. Normal rise within 3 feeds. |
| BT-9 | 30 d of BT-1 | 0 attention events. ≤ 2 nudges per local day. |
| BT-10 | Determinism | Same states, events and summary, byte for byte (PROP-02, PROP-12). |
| BT-11 | Forecast | With the environment unchanged, `at_peak` starts inside the forecast window for 100% of feeds. Run over all slice presets, flours and locations, 1,000 seeds. |
| BT-12 | Tutorial demo (B6) | From feed to `at_peak` in 90 to 120 s of wall time. The demo steps a **temporary copy** of the state and never scales `Clock` (game-mechanics §8.1, `Demo.run` in architecture §5.5). The real save is created at `at_peak` with timestamps set to now. The saved state's `sim_time_unix` equals `grid(now)` at creation, and `meta` shows no time scale. |
| BT-13 | Taps | AC-05.3, AC-05.4 |
| BT-14 | Pacing, twice daily, from maturity 0.2 | `steady` by days 5 to 8, `mature` by 12 to 18, `seasoned` by 45 to 60 (v1: 6, 16, 51.5). |
| BT-14b | Pacing, once daily | Each stage within 1.5× its BT-14 day (v1: 8, 21, 69). |
| BT-15 | Return flow | AC-09.3 |
| BT-16 | No dead ends (L-11) | For each non-`moldy` state fixture, apply the corrective action (a feed, or a move to `counter` for a cold `dormant`). Within 6 h, the state is equal or lower in precedence and `mold_risk` hasn't risen. |
| BT-17 | Schedule question | Mature starter, `counter`, defaults. The forecast `at_peak` start falls in 4 to 7 h for 1:1:1, 7 to 10 h for 1:2:2 and 10 to 16 h for 1:5:5. Each answer suggests exactly its preset. v1 `at_peak` starts: 6.1 h, 8.0 to 8.4 h (V18), 10.75 to 11.4 h (V19). |

| ID | Leniency floor (game-mechanics §9) | Test |
|---|---|---|
| L-1 | Once or twice a day at `counter`, any P0 ratio: never `unhealthy` | BT-1, BT-2, plus a 1:1:1 once-a-day run for 14 d |
| L-2 | 1 day unfed: `hungry`. 1 feed gives a near-normal rise. | BT-5 |
| L-3 | 3 days unfed: `dormant`. Normal within 3 feeds (v1: 1 recovering feed, normal by feed 2 to 3). | V9 at 72 h, then a recovery check |
| L-4 | Earliest `unhealthy` ≥ 4 d at `counter` (v1: 4.5 d at counter, 3.5 d at `warm_spot`) | BT-7, V9 |
| L-5 | Earliest `moldy` ≥ 7 d at `counter` (v1: 8.9 d at counter, 7.1 d at `warm_spot`) | BT-7, V9 |
| L-6 | `unhealthy` to `moldy` ≥ 72 h at `counter`, ≥ 48 h anywhere (v1: 106 h at counter, about 86 h at `warm_spot`) | BT-7, AC-10.10, SIM-WARN-03 |
| L-7 | Watch stage (`musty`) to `moldy` ≥ 96 h at `counter` (v1: 138 h) | SIM-WARN-02 at `counter`. At any temperature, the spec's cap gives ≥ 77 h (asserted at ≥ 76 h, SIM-WARN-03). QA reports the measured `warm_spot` value. |
| L-8 | `fridge` never molds within the 14-day cap. Normal within 2 feeds. | EC-02, V7, V13 |
| L-9 | Any feed before `moldy` lowers `mold_risk`. Out of `unhealthy` after 1 feed, normal by feed 3. | PROP-08, BT-8, V9b |
| L-10 | No single action causes a loss | For every state fixture except `moldy` and every slice action: the result is never `moldy`. |
| L-11 | No dead ends within 6 h | BT-16 |

**Event rules** (§7.2 and §7.3):
- **Caps** above (AC-10.2).
- **One-time cooldowns:** `first_rise`, `first_acetone`, `getting_stretchy`, `trait_revealed` (per trait), `mold_found`.
- **Timed cooldowns:** `hungry_again` 12 h, `hooch_forming` 24 h, `back_to_strength` 24 h, `off_to_nap` 24 h, `fed_before_peak` 72 h, `warm_and_quick` 72 h, `big_bubble` 48 h (max 1 a day).
- **Per-episode cooldowns:** `waking_up` once per fridge stay. `peaked_while_away` once per rise cycle. `warning_signs` once per `unhealthy` episode, re-armed after 24 h out of it.
- **Randomness:** `big_bubble` is now deterministic from the stored `feed_u` (spec §17). The same save always gives the same ambient events.

**Return flow** (§8):
- Show it only when away ≥ 60 min with a change.
- At most 3 lines plus 1 prompt (an attention, else the newest valid nudge).
- Keep priority: attention > milestone > peak > hunger and hooch > other info > ambient.
- Drop order: ambient, then merged same-kind info, then the oldest info.
- More than 14 days: the summary says the time was long.

### 4.3 State reachability recipes (AC-04.2)

| State | Recipe | Check at |
|---|---|---|
Spec §12.2's typical day at 22 °C after a 1:1:1 feed:

| Phase | Window |
|---|---|
| `freshly_fed` | 0 to 0.3 h |
| `developing` | to 1.0 h |
| `active` | to 4.9 h |
| `near_peak` | to 6.1 h |
| `at_peak` | to 7.5 h |
| `collapsing` | to 12.8 h |

Each check time below sits at least 0.3 h inside its window, to absorb jitter and drift.

| State | Recipe (`MATURE` fixture, 22 °C unless noted) | Check at |
|---|---|---|
| `freshly_fed` | Feed 1:1:1 | t + 6 min |
| `developing` | Same | t + 0.65 h |
| `active` | Same | t + 3 h |
| `near_peak` | Same | t + 5.5 h |
| `at_peak` | Same | t + 6.8 h |
| `collapsing` | Same | t + 10 h |
| `hungry` | Same, unfed | t + 14 h (V9: from 12.4 to 12.8 h) |
| `dormant` | Unfed on the counter, or a move to the fridge | t + 80 h (V9: from 74 to 77 h), or 3 h after the move (1.5 h thermal constant) |
| `recovering` | 14 d in the fridge, then feed on the counter (V7) | t + 2 h |
| `unhealthy` | Unfed on the counter | t + 115 h (V9: from 104 to 111 h) |
| `moldy` | Same | t + 225 h (V9: 207 to 219 h) |

---

## 5. Edge-case catalog

| ID | Player | Setup | Expected | Check |
|---|---|---|---|---|
| EC-01 | Leaves for a month, starter on the counter | Reopen at T + 30 d | Capped at 14 d. `moldy` latched at about 8.9 d (V13). The time-lapse passes the warning stages. The summary names when the warnings began. `mold_found` shows, with no guilt copy. `warning_signs` is in the journal at least 72 h before mold. The memorial is offered. | auto + review |
| EC-02 | Leaves for a month, starter in the fridge | Same, in the fridge | `dormant`, vigor 0.6 to 0.7, `mold_risk` < 0.3 throughout (V13). After a counter feed: `recovering` at 2, 4, 8 and 12 h, peak 13.5 to 14.1 h. The next feed is normal (V7). | auto |
| EC-03 | Keeps it in the fridge for weeks, feeding weekly | 8 weeks, a feed every 7 d in the fridge | Never `unhealthy`. Status after each feed per OD-7. | auto |
| EC-04 | Feeds every 10 minutes | 12 feeds of 1:1:1 in 2 h | `freshly_fed` or `developing` throughout. Ranges hold, and `yeast` and `lab` sit at or near the 0.001 floor (V10). The timing class is `early` every time, so `fed_before_peak` fires once (72 h cooldown). 12 journal lines, one per feed (game-mechanics §2.6). 12 saves, no slowdown. The next peak comes about 25 h later at about 2.6× (V10). | auto |
| EC-05 | Discards everything | Slice: impossible (derived discard). Sim-level: keep 0 is rejected. Keep 1 g at 1:1:1 gives 3 g and behaves like V2 at 22 °C (V11). | `VisualMapper` still shows a visible layer (min height TBD-ART). No divide by zero. | auto |
| EC-06 | Chooses 1:50:50 | Slice: impossible (presets). Sim-level P2: 1 g + 50 g + 50 g at 22 °C, and 2 g kept at 24 °C | Peaks at about 18 h (V11), and at 15.6 to 16.7 h with 2.60 to 2.64× (V4). Not `hungry` before the peak. P2 free steppers need a max-mass rule (OD-6). | auto |
| EC-07 | Gets mold, then tries to keep playing | `moldy` fixture | AC-08.5: only inspect, journal and Discard work. A feed through the API is refused with every field unchanged (V14). Relaunch, clock back, and the `save.prev` fallback plus catch-up all give `moldy` again. Discard leads to the memorial and a new starter. | auto |
| EC-08 | Checks in every 5 minutes all day | 200 opens and smells in 16 h | Caps hold. One smell journal line per descriptor per cycle. No save slowdown. | auto |
| EC-09 | Feeds in the fridge | `fridge`, then Mix | `dormant` beats `freshly_fed` (spec §12.2), so the pill says dormant right after feeding. Intended: `STATUS_DORMANT_COLD_TAP` explains it (game-mechanics §1). The feed is still recorded, and the journal has the entry. | auto |
| EC-10 | Flips locations constantly | AC-06.5 | No drift, no spam. | auto |
| EC-11 | Flies across time zones | CLK-07 | The sim is unchanged. Quiet hours follow the new local time. | auto |
| EC-12 | Moves the clock a week ahead to skip waiting | Set +7 d, open | It's a real week away: allowed and harmless offline. Setting it back afterwards (gap > 6 h) re-anchors with no rewind and no freeze. | auto |
| EC-13 | Phone dies, clock reads 1970 | CLK-12 | No crash, no rewind. | auto |
| EC-14 | Storage full | SAVE-09 | The old save is intact and the game continues. A calm notice. | auto |
| EC-15 | Kills the app during catch-up | SAVE-16 | Same result on relaunch. | auto |
| EC-16 | First launch with a wrong clock | First run at 2100, then the real time | The second launch re-anchors (gap > 6 h). The starter is unchanged, with no 14-day jump. | auto |
| EC-17 | Ignores attention events | `warning_signs` waiting, then the player feeds it out of `unhealthy` | The attention can be acknowledged, and a later `mold_found` can still replace it (AC-10.6). It never blocks future warnings. | auto |
| EC-18 | Leaves a sheet open overnight | CLK-10 | Correct state on resume. 1 feed only. | auto |
| EC-19 | Phone call during a pinch | Canceled touches (AC-03.12) | No stuck finger. | auto + manual |
| EC-20 | Names the starter oddly | Empty, spaces only, 200 characters, emoji, RTL text | Rules per TBD-UX/NAR. Byte-exact save and restore (UTF-8). The pill never overflows. The only digits allowed on the main screen are the player's (AC-08.3). | auto |
| EC-21 | Dead-end hunt | Every non-moldy state fixture | BT-16 and L-11: the corrective action gives a state that is equal or lower in precedence, with `mold_risk` not rising, within 6 h. `moldy` has a discard and new-starter path. No soft lock. | auto |
| EC-22 | Android split screen or a resized window | Height down to 50% | No crash. Layout follows the safe area. | manual (Phase 5) |
| EC-23 | Low power mode or a hot phone | Device | The frame cap still applies. No sim or visual difference. | manual (device) |
| EC-24 | Taps the starter 100 times | INT-08 | The sim is byte-unchanged. | auto |
| EC-25 | Kills the app during the discard ceremony | After `DiscardStarterAction` is applied | Relaunch shows the new starter, and the memorial exists exactly once. | auto |

---

## 6. What can't be automated, with manual checklists

| Area | Why not automated | Covered by |
|---|---|---|
| Beauty of the jar, glass and starter | Taste. Pixel diffs only catch regressions. | MAN-01, MAN-02 vs. `art/previews/jar_v0_<state>.png` for the 8 rendered states (`freshly_fed`, `active`, `at_peak`, `collapsing`, `hungry`, `dormant`, `unhealthy`, `moldy`). The other 3 states are checked against their UX §11 jar cues. |
| "Alive but calm" motion | AC-02.1 is only a proxy | MAN-02 |
| Gesture feel, one-handed reach | Needs a hand on a real screen | MAN-03, A11Y-07 |
| Haptics | Not produced in a simulator or headless run | MAN-05, device only (D-004) |
| Smell moment delight | Taste | MAN-07 |
| Copy tone | Taste | MAN-09 (narrative), scientist safety sign-off |
| Screen readers | Needs Godot 4.8 (D-012) | A11Y-09 |
| Release-build behavior | Needs export templates (OD-9) | CLK-13, release smoke test |
| Real frame time, thermals, battery | No device yet | PERF-05, PERF-08 |

**Visual regression aid.** `--capture` images are diffed against `tests/visual/approved/<renderer>/`. A mean difference over 2%, or any 32 × 32 tile over 10%, flags the image for review. It never fails the build alone. Approvals are per renderer and per machine.

### MAN-01 Jar (art-director, against `jar_v0_*` and the art-direction tells, at the preview pose)
- [ ] Glass thickness is visible at the rim and the base.
- [ ] Fresnel edges are brighter than the center at all 36 orbit angles.
- [ ] One soft specular highlight, no mirror look.
- [ ] Tier B only: slight refraction with no screen-edge smear.
- [ ] No rim shimmer while orbiting.
- [ ] A contact shadow under the jar. A soft-focus backdrop.
- [ ] Lid, rubber band and fed-mark band read clearly at home zoom.
- [ ] 5 sampled colors are within ±8 per channel of the art-direction palette.

### MAN-02 Starter (art-director, plus the scientist for state tells)
- [ ] Creamy and glossy, never gray sludge.
- [ ] Bubbles visible through the glass and on top. They get bigger from `freshly_fed` to `at_peak`.
- [ ] Subtle breathing. No texture swimming.
- [ ] Streaks only after a collapse.
- [ ] Hooch reads as liquid.
- [ ] `moldy` is unmistakable at SE size, and not gross.
- [ ] Each state matches its UX §11 jar cue and the scientist's tells.

### MAN-03 Camera (Mac, simulator, device later)
- [ ] Right-thumb and left-thumb orbit are comfortable at SE and 17 Pro Max sizes.
- [ ] Pinch is smooth, with no jump when the second finger lands.
- [ ] Tapping bar buttons never orbits the camera.
- [ ] Rubber bands feel soft, not like a wall.
- [ ] No queasy motion at default sensitivity.

### MAN-05 Feeding
- [ ] Scrape, scoop, pour and stir play in order (about 6 s). They're skippable after the first feed.
- [ ] Haptics (device). Android: light at chip select and stir ticks (10 ms, 0.3), medium at the flour landing (20 ms, 0.6), firm at the band snap (35 ms, 1.0). iOS: a single level until Phase 2 (UX §15). None with haptics off. Every haptic moment also has a sound.
- [ ] The "Same as last time" line is noticed without help.

### MAN-07 Smell
- [ ] The dolly and wisps feel like a moment, not a loading delay.
- [ ] The card's words match what the jar shows.
- [ ] Reduce motion: no dolly, no wisp motion.

### MAN-09 Return flow and events
- [ ] No copy blames the player for being away.
- [ ] 3 lines plus 1 prompt are readable in under 10 s.
- [ ] Hooch and acetone read as normal hunger.
- [ ] Mold reads as "discard", kindly and clearly.

### MAN-12 UI polish (ux-designer, art-director)
- [ ] Every screen matches its UX wireframe.
- [ ] No default Godot look anywhere: scroll bars, sliders, focus rings.
- [ ] Nothing on the main screen looks like a dashboard.
- [ ] The status is readable in a grayscale capture.

---

## 7. Performance

**Labeling rule:** every reported number says "Mac estimate", "simulator estimate" or "device". There's no phone yet (D-004).

The Mac and simulators use **regression gates**: fail on a slowdown of more than 20% against the approved baseline for the same machine and renderer. Absolute phone targets (architecture §11) are checked on a device.

| ID | Metric | Target | Where |
|---|---|---|---|
| PERF-01 | Frame while interacting (60 s scripted orbit) | Device: 60 fps, CPU ≤ 8 ms, GPU ≤ 10 ms (2021 mid-range). Mac and simulator: regression gate. Mac GPU numbers run only with `--rendering-driver vulkan` (MoltenVK). In 4.7.2, `viewport_get_measured_render_time_gpu` returns 0 on Metal, opengl3 and ANGLE. Compatibility uses uncapped frame time as its upper bound. | capture |
| PERF-01b | `PerfLog` on a driver that can't measure GPU time (Metal, Compatibility) | `gpu_ms` is written empty ("not measured"), never 0, and gates skip it. A logged 0 would silently pass every GPU gate. | auto |
| PERF-02 | Idle frame cap | `Engine.max_fps` = 30 after 3 s with no touch and no tween. Back to 60 within 1 frame of `interaction_started`. | auto (scripted, windowed) |
| PERF-03 | 14-day catch-up (20,160 steps) | ≤ 250 ms Mac estimate. Architect's toy loop: 22 ms on M4. If over, `WorkerThreadPool`. | auto (timed) |
| PERF-04 | Save | ≤ 128 KB, write < 10 ms (Mac estimate) | auto |
| PERF-05 | Launch to first jar frame | Device ≤ 2 s. Mac recorded as an estimate. | capture |
| PERF-06 | Scene | ≤ 16k triangles, < 10 jar draw surfaces, < 30 draw calls | capture |
| PERF-07 | Hitches after warm-up: first open of each sheet, each state change | No frame over 50 ms (Mac estimate) | capture |
| PERF-08 | Battery: 10 min idle on the main screen | Device only, Phase 5 | manual |
| PERF-09 | Opaque full-screen UI (journal) | `World` hidden, so 3D draw calls are 0 | capture |
| PERF-10 | Project settings | `keep_screen_on` = `false`, `scaling_3d_scale` = 0.75, MSAA 2x (ADR-011). A LINT check on `project.godot`, so a perf regression from a setting change shows up as a diff. | auto |

**`PerfLog` CSV columns:** `unix_ms`, `scene`, `renderer`, `driver`, `tier`, `frame_ms`, `cpu_ms`, `gpu_ms` (empty when not measured), `draw_calls`, `primitives`. A summary line gives p50, p95, p99 and max. Baselines are kept per machine, renderer, driver and tier.

---

## 8. Accessibility checks

| ID | Check | How |
|---|---|---|
| A11Y-01 | Targets ≥ 44 pt (48 standard), bar slots ≥ 64, no overlap | AC-12.1 |
| A11Y-02 | Body ≥ 16 pt. 100%, 125% and 150% without clipping. | AC-12.2 |
| A11Y-03 | Contrast: text 4.5:1, non-text 3:1, plates over the scene in the worst case | AC-12.3, AC-12.4 |
| A11Y-04 | Status never by color alone | AC-08.1, AC-08.6 |
| A11Y-05 | Reduce motion disables exactly the UX §15 list and keeps the sim-driven starter motion | AC-02.6, AC-12.8 |
| A11Y-06 | Haptics off: 0 calls to `Input.vibrate_handheld` during a full feed flow | auto (spy on the haptics wrapper) |
| A11Y-07 | Reach: the five actions are in the UX §5 thumb zone on the 17 Pro Max | capture |
| A11Y-08 | Every interactive Control has an `accessibility_name` through `tr()`, ≤ 40 characters | auto (the property exists in 4.7.2, per architecture) |
| A11Y-09 | VoiceOver and TalkBack: read the status, use the five actions, finish a feed | manual, after the 4.8 upgrade (D-012) |
| A11Y-10 | No flashing above 3 per second (WCAG 2.3.1), including bubble pops and VFX | review |
| A11Y-11 | Gestures are optional: every 3D action (reset, inspect framing) has a button path, and nothing requires a hold or multiple fingers | auto (UX §16) |
| A11Y-12 | Nothing auto-confirms. Cards stay until dismissed when "Keep messages on screen" is on | auto |
| A11Y-13 | An unguided task with a new player: "Check how your starter is doing and feed it", done without help in under 3 min | playtest (Phase 3) |

---

## 9. Device and screen matrix (Phase 5)

**iOS simulators.** Verified installed with `xcrun simctl list devicetypes` (Xcode 27.2): iPhone SE (3rd generation), iPhone 17e, 17, 17 Pro and 17 Pro Max. The device-type plists don't contain screen sizes (checked), so the sizes below come from UX §2, and the 17e is marked assumed by UX. Confirm each from the booted simulator in Phase 2 and record it here.

| Device | Points (UX §2) | Why | Runs |
|---|---|---|---|
| iPhone SE (3rd gen) | 375 × 667, home button | Smallest iOS. UX lists it as supported (OD-14). | AC-12.1, AC-12.2 (150%), AC-12.6, AC-02.5 |
| iPhone 17e | 390 × 844 (assumed) | Smallest current iPhone | AC-12.6, captures |
| iPhone 17 Pro | 402 × 874 | Reference size, ProMotion | All capture rows, PERF-01 (simulator estimate) |
| iPhone 17 Pro Max | 440 × 956 | Largest, hardest reach | A11Y-07, MAN-03, AC-12.6 |

**Android emulator.** Blocked: the SDK lacks platform 36, build-tools 36.1.0 and the NDK (OD-10). Verify the profiles against the installed AVDs.

| Profile | Size | Why |
|---|---|---|
| Compact (UX §2) | 360 × 640 dp | Copy limits are computed at this width |
| Medium Phone (AVD) | about 411 × 914 dp | Common |
| A large phone (Pixel Pro XL class) | verify | Reach |

Each Android profile runs with:
- gesture navigation and 3-button navigation, expecting the same 56 dp bar inset on both (UX §2)
- the system font scale at 1.0 and at its maximum (UX §16 says the in-app size is used, so check that nothing breaks)
- the Vulkan (Mobile) and GLES3 (Compatibility fallback) renderers
- SAVE-19 (rename atomicity)

Every number from this matrix is an estimate until a device exists.

---

## 10. Definition of done (Phases 2 and 3)

A feature is done when:

1. Its acceptance rows exist in this plan before the code does.
2. Each `auto` row has a test, merged with the feature.
3. `tests/run.sh` passes: exit 0, `RESULT: n passed, 0 failed`, and n has grown. The output is pasted into the report. No test is called passing without its output.
4. LINT-01 to LINT-11 pass.
5. New strings have UPPER_SNAKE keys in `en.csv`, or as placeholders in the track's `pending_*.csv` (ADR-014).
6. If the schema changed: the version is bumped, a fixture is frozen in `tests/fixtures/saves/`, and the migration test passes.
7. If it's visual: captures are reviewed against the references by art-director (and ux-designer for UI).
8. No perf regression over 20% on the Mac baseline.
9. Its manual checklist has been run on the Mac, and on the simulator once the export templates exist.
10. No open S0 or S1 bugs against the feature.
11. When a spec number moves, the owner updates the spec first. QA then updates the vector.

**Before any Phase 2 feature work:**
- R-0 to R-9
- `FakeClock`
- `SaveStore` with `fault_point`
- `tests/fixtures/`
- LINT-01 to LINT-11

**Phase 3 exit:** all 12 AC groups are green, or each red row has a written waiver from the director.

---

## 11. Bug severity scale

| Level | Definition | Examples | Policy |
|---|---|---|---|
| S0 Blocker | Data loss, a safety error, a broken pillar, or the game can't run | Save reset or wipe (SAVE-06, SAVE-17). Crash on launch or resume. Mold outside its rules (PROP-04). Copy implying a contaminated starter is safe. Any network call. A secret in the repo. A sim freeze. | Fix first. Blocks the phase merge. |
| S1 Critical | A core loop is broken or tells the player wrong things | Feed, environment, smell or inspect can't complete. The status contradicts the sim. A rewind or double count. Broken event caps. Unreadable main-screen text. | Blocks the phase merge. |
| S2 Major | Real but with a workaround, or on a secondary path | The jar contradicts the status. Noticeable drops in normal use. A §5 edge case broken with a workaround. An a11y failure on a secondary screen. | Fix in the phase, or the director waives it in writing. |
| S3 Minor | Small or rare | A typo, a misalignment, a rare animation glitch | Backlog |
| S4 Cosmetic | Polish | Easing taste, 1 px | Backlog |

**Bug report fields:**
- id, severity, steps, expected, actual
- commit, renderer and tier, and where it ran
- a synthetic save fixture (public repo: never real player data)

---

## 12. Seams the tests use

All of these were accepted by tech-architect. The names are from `architecture.md` §5, §6 and §12 and `data-models.md` §9.

| Seam | Name | Tests |
|---|---|---|
| Clock | `Clock.now_unix()`, `local_utc_offset_s()`. `SystemClock`, `DebugClock` (debug only), and `FakeClock` with `set_now`, `advance`, `set_offset`. | CLK-*, AC-10.4 |
| Clock policy | `src/core/time_policy.gd`, `CLOCK_REANCHOR_GAP_S` = 21600, 300 s monotonic guard | CLK-05, CLK-09, CLK-16, CLK-17 |
| RNG | `sim_rng` only (one draw per feed, stored as `feed_u`). `sim_seed` and `sim_state` are saved as decimal strings and restored with `state` only. Events take no RNG. | PROP-02, PROP-13, SAVE-14, SIM-RNG-01 |
| Derived and view fields | `DerivedState.dormant_cause` (cold wins), `VisualParams.big_bubble`, `PlayerHistory.last_strong_peak_rise` (data-models §2, §5, §7) | AC-08.1, PROP-10, AC-10.11 |
| Files | `SaveStore.new(base_dir)`, `fault_point`, `load_from_path()` | SAVE-* |
| Fixtures | `--fixture=res://tests/fixtures/<name>.json`, `Session.dump_state(path)` | L7 to L9 |
| Pure entry points | `Sim.step`, `Sim.apply_feed`, `StateDeriver.derive`, `VisualMapper.from_state`, `EventRules.evaluate`, `EventScheduler.admit`, `SmellModel.read`, `Inspection.read`, `CatchUp.run`, `Forecast.peak_window`, `ReturnSummary.build` | L2 to L4 |
| Lifecycle | `Session.on_background()`, `on_resume()` | CLK-10, CLK-11, SAVE-12 |
| Capture | `time_override` uniform, `--capture=<png>` | AC-01, AC-02, AC-08.6 |
| Presets and demo | `StarterPresets.make`, `StarterState.rebase_to`, `Demo.run` (B6 tutorial, architecture §5.5) | BT-12, §4.3 recipes, fixtures |
| Perf | `PerfLog`, added by Main when `--perf-log=<csv>` is passed (debug builds) | PERF-* |

---

## 13. Open items

| ID | Item | Owner | Status or proposal |
|---|---|---|---|
| OD-1 | D-013 froze the sim after a corrected forward clock jump | tech-architect | **Resolved**: architecture §5.3 re-anchors when gap > 6 h. Needs a decisions.md update (director). |
| OD-2 | Mold warning gap | scientist, designer | **Resolved by spec v1.** At `counter`: unhealthy to mold about 106 h, watch to mold 138 h, meeting L-6 and L-7. Anywhere: the 2.2 cap gives ≥ 48 h. Spec §10 now guarantees ≥ 60 h warning to mold and ≥ 77 h watch to mold at any temperature. SIM-WARN-03 asserts 59 h and 76 h. |
| OD-3 | What the player sees when every save is bad | ux, narrative | Architecture: a new starter plus a calm notice. Copy is needed. |
| OD-4 | A save from a newer version | tech-architect | **Resolved**: it's moved to quarantine and never overwritten (data-models §9.4). |
| OD-5 | Ratio vs. hydration | designer | **Resolved**: ratio presets, hydration fixed at 100% in the slice. |
| OD-6 | Jar capacity | designer | **Resolved for the slice**: 150 g total. P2 free steppers need a max-mass rule. |
| OD-7 | Feeding in the fridge shows `dormant` immediately | designer | **Resolved**: intended, and the tap line explains it (game-mechanics §1). |
| OD-8 | Journal growth over a year or more, against the 128 KB budget | tech-architect | **Resolved**: capped at 400 entries with a fixed drop order (data-models §6). SAVE-13 asserts it. |
| OD-9 | Release-build and device checks need export templates (1,281 MB) | director | Approve before Phase 5. |
| OD-10 | Android SDK pieces missing | director | Install before Phase 5. |
| OD-11 | Does Control layout resolve under `--headless`? | godot-developer | **Resolved: yes, inside a fixed-size root Control.** The headless root window stays 64 × 64 whatever size is set. QA re-ran `spikes/jar-spike/scripts/headless_layout_probe.gd`: vbox 390 × 844, label 390 × 75 with 3 lines, button 390 × 48 at y = 79, exit 0. Only the default font is checked so far. Confirm Theme fonts in Phase 2. |
| OD-12 | Save rotation could push out the last good file (SAVE-17), and "none passes" kept no copy of the bad files (SAVE-06) | tech-architect | **Resolved**: data-models §9.3 and §9.4 (trusted rotation, quarantine). Logged in ADR-005. |
| OD-13 | `AWAY_SUMMARY_MIN_S` was 30 min in architecture, 60 min in game-mechanics | tech-architect | **Resolved**: 3,600 s. |
| OD-14 | iPhone SE is in UX §2 but not in the role-file matrix | director | Include it: it's the smallest layout, and the simulator is installed. |
| OD-15 | Clock set back > 6 h and later corrected credits the gap (≤ 14 d) | tech-architect | Accepted limit, documented in ADR-006. Tested by CLK-17, with the boundary in CLK-16. |
| OD-17 | Triangle budget: the art checker and architecture disagreed | art-director | **Resolved**: the checker now asserts ≤ 16k per visible cover set. It caught the cloth set at 17,408, rebuilt to 14,552. QA re-ran it: PASS. |
| OD-18 | **A JSON save round trip is not bit-exact in 4.7.2.** The number parser isn't correctly rounded: 0.00038268223404884337 reads back as 0.00038268223404884, and 1.9469610637576158 (a `peak_rise` from T1's Session) as 1.946961063757616. QA measured 29,798 of 100,000 random doubles (1e-6 to 1e3) coming back 1 ulp off. `String.to_float()` and `var_to_str` are no better. `var_to_bytes` is exact. ADR-005's evidence (1/3) has no leading zeros, so it passed. A Session reloaded from its own save differs from the in-memory one (seen: `food` 1 ulp). That breaks SAVE-01 deep-equal, PROP-02 "byte-identical with a save and load midway" and the exactness of PROP-01. | tech-architect | **Resolved: option (a).** Every float in the payload is a 16-char hex string of its IEEE-754 bytes (`encode_double`, then `hex_encode()`, little-endian; data-models §1, §9.2, ADR-005). PROP-01, PROP-02 and SAVE-01 stay exact with no tolerance. Tests: the encoding (`test_save_engine_facts.gd`, runs now) and the real save path (`test_save_payload.gd`: a reload is bit-exact, and the stored payload has no decimal numbers; waits for m4_save and m5_catchup). |
