# Test plan

Owner: `qa-engineer`. Status: Phase 4 (polish and the rest of the MVP). Last updated 2026-11-27.

**Phase 4 additions:** the re-scope for iOS first and no screen readers (§3.14), the Phase 4 acceptance criteria AC-13 to AC-26 with their traceability (§3A), new edge cases EC-26 to EC-32 (§5), the iPhone play checklist MAN-D0 to MAN-D7 (§6), and Phase 4 open items (§13).

**Phase 3 additions:** the AC integration harness (§2.6), the traceability table that says what proves each AC row (§3.13), and the slice play-session checklists (§6, MAN-S0 to MAN-S5).

**Built on:**
- `vision.md`, `decisions.md`
- `architecture.md`, `data-models.md`, `technical-decisions.md`
- `starter-simulation-spec.md` v1 (ranges §1, mold §10, derivation §12, smell §13, inspection §14, vectors V1 to V17 §18)
- `game-mechanics.md` (BT-1 to BT-16, L-1 to L-11), `events-catalog.md`, `game-copy.md`, `ux-design.md`
- `art-direction.md` (state tells §6, `max_delta` §8)
- `decisions.md` D-038 to D-059

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
3. Acceptance criteria for the 12 vertical-slice items (and the Phase 4 re-scope, §3.14)
3A. Phase 4 acceptance criteria (AC-13 to AC-26)
4. Sim and time tests tied to the specs
5. Edge-case catalog
6. What can't be automated, with manual checklists
7. Performance
8. Accessibility checks
9. Device and screen matrix (the iPhone 13 Pro now, the rest in Phase 5)
10. Definition of done (Phases 2 to 4)
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
| First `--import` of a fresh clone (director, 2026-11-27, Phase 3) | **134** (SIGABRT) once; a second clone passed | Engine crash, not our code. The macOS report (`Godot-2026-11-27-084455.ips`) shows libmalloc aborting on "pointer being freed was not allocated" (a double free) in Godot's `WorkerThread 3`; Godot's frames are unsymbolized. The import log shows `en.csv` reimporting at the same moment as the two fonts on worker threads. QA did not reproduce it in 37 fresh first imports (1 alone, 12 four at a time, 24 six at a time; all exit 0 in 2 to 6 s). Handled by R-0's single retry. |

**JSON results (same setup), which drive the save tests:**
- Plain `JSON.stringify` doesn't round-trip 1/3. `JSON.stringify(d, "", true, true)` does, exactly.
- Integers parse back as floats.
- 2^53 + 1 is not preserved, so int64 RNG state must be stored as a string.
- Parse, then stringify, is not byte-stable (`1` becomes `1.0`, architect ran this), so the checksum covers the stored bytes.

**Runner requirements.** Accepted in `architecture.md` §12. QA owns `tests/run.sh` and `tests/run_tests.gd`.

| ID | Requirement |
|---|---|
| R-0 | `run.sh` first runs `godot --headless --path . --import`. If that import dies by a signal (exit 129 to 159, except 142, our own timeout, and 130 and 143, a person stopping the run), `run.sh` keeps the first log in `build/logs/import_crash_<time>.txt`, prints `WARN godot --import crashed (signal N, exit C), retrying once` with the log's tail, and imports once more. A second crash fails the run. A normal non-zero exit fails at once, never retried. After a retry the `RUN:` line ends with `import retried after signal N`, even under `--strict`, and every phase-exit report must quote that note (director, 2026-11-27). |
| R-1 | `run_tests.gd` extends `SceneTree`, runs from `_initialize()` and holds no test logic. |
| R-2 | Discovers `res://tests/**/test_*.gd`. A file that fails `can_instantiate()` counts as a failure. Files under `res://tests/perf/` run first, while the process is fresh, then the rest in path order. Measured 2026-11-27: the 14-day catch-up's median was about 228 ms alone but 256 to 283 ms after about 300 other tests in the same process, so a timing test run last would measure the suite, not the code. |
| R-3 | A `Logger` subclass registered with `OS.add_logger()`. Any `_log_error` during a test (a null call, `push_error`, an `assert`) fails that test. |
| R-4 | Tests extend `TestCase` (`tests/lib/case_base.gd`) and assert through its `check*` methods. A test with 0 checks fails. Tests never rely on `assert()`, which release builds strip. `skip(reason)` marks a test skipped. A failure recorded before the skip still fails it. `expect_error(fragment)` declares one logged error, which then fails the test only if it never appears. |
| R-5 | One `PASS`, `SKIP <file>::<test> <reason>` or `FAIL <file>::<test> <message>` line per test (a FAIL may add indented detail lines). The last line is exactly `RESULT: <n> passed, <m> failed, <k> skipped`. Then `quit(1 if m > 0 else 0)`. |
| R-6 | `run.sh` applies the outer timeout `perl -e 'alarm 600; exec @ARGV'` (`RUN_TIMEOUT_S`; 300 until the Phase 3 exit, when the suite reached about 210 s on the Mac). It passes only if the exit code is 0, the last stdout line matches `^RESULT: [0-9]+ passed, 0 failed, [0-9]+ skipped$`, and n > 0. Skips are printed and counted, never passes. `run.sh --strict` (the phase exit gate) also fails on any skip. Before the runner it runs five Python lints: `check_copy.py`, `build_catalog.py --check`, `sim.py vectors`, `verify_glb.py` on `assets/3d/jar_v0.glb` (AC-01.1, D-031, added in Phase 3), and golden-fresh (the committed traces equal a fresh `sim.py trace`). |
| R-7 | User args after `--`: `--filter=<substring of file::test>` and `--seeds=<n>` (default 100). `--update-golden` is refused when `CI=1`. Any other argument fails the run. Every test file is loaded before filtering, so a filter never hides a broken file. |
| R-8 | Loads every `.gd` under `res://src/` and fails on any that can't instantiate (LINT-03, `tests/lint/test_lint_03_typing.gd`). |
| R-9 | `run.sh --selftest` runs each case in `tests/runner_selftest/cases/` as a throwaway project through `run.sh`'s own judge, and checks both the outcome and the reason (`expect_output`). 35 cases (35 of 35 on 2026-11-27). The two added in Phase 3 run a stand-in engine, `tests/runner_selftest/fake_godot_abort.sh`, whose `--import` dies like the crash above: once (retried, then passes with the WARN) and twice (fails with "crashed again"). The original 33: a positive control, a parse error, an untyped declaration, a non-TestCase file, an empty suite, a null call, `push_error`, a failed `assert`, an error in a test's `_init`, 0 checks, skips (counted, can't hide a failure, fail under `--strict`, milestone gate), a hang, no tests, a runner parse error, a runner exiting 0 with failures or 1 without, output after `RESULT`, the filter (and that it can't hide a parse error), `--update-golden` under `CI=1`, an unknown argument, a fresh checkout and a stale `.godot/` (each also run without `--import` to prove R-0 is what makes it come out right), and planted LINT-01 and LINT-03 violations plus a clean near-miss file. |
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
  - `height` (spec §14, final): `at_mark` < 1.1, `a_little` < 1.5, `nearly_doubled` < 1.85, `doubled` < 2.4, `more_than_doubled` from 2.4. Trend: `rising`, `falling` or `steady`. `streak_line` when `peak_rise − rise` ≥ 0.2. (This line had the draft bands until 2026-11-27; `property/inspection_rules` tests the spec's.)
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
| SAVE-13 | A synthetic year: 2 feeds a day, every event, every smell and inspect | Size ≤ 128 KB, flat once the journal is full. Write < 10 ms (Mac estimate, architecture §11; PERF-04). The journal holds at most 400 entries and at most `JournalEntry.BYTE_CAP` (102,400) saved bytes, whichever binds first (T1, 9551f26: without the byte cap, the save passed 128 KB by day 120). Drop order: `state_change` first, then inspect and smell, then the oldest of any kind. `memorial` and `milestone` entries are never dropped (data-models §6). |
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

**The harness** (`tests/integration/slice_harness.gd`, Phase 3). One `SliceHarness` is one simulated phone: a `FakeClock`, a temp save folder with its own `settings.cfg`, and the real `GameSession` node in the scene tree. Tests extend `SliceCase` (`tests/integration/slice_case.gd`), which frees every phone after each test.

| Call | What it stands for |
|---|---|
| `seed_save(starter, env, rng_seed)` | A complete, valid `save.json` (all 8 sections), so the normal launch path loads it. The seed fixes the one draw per feed. `first_draw(seed)` predicts it, and `seed_for_draw(0.5)` finds a seed that matches the reference model's `feed_u` 0.5. |
| `launch()` | `Main`'s path through `Session.start()`: `setup()` with the fakes, `load_settings()`, `boot()`. The 60 s timer is replaced by `play()`. |
| `apply(action)` | A sheet's confirm button: `Session.apply()`. |
| `play(s)`, `play_irregular(s)`, `play_until(cond, max)` | The app open in the foreground, the grid timer ticking (irregular lengths, as a real timer drifts). |
| `close()` | Backgrounded (`on_background()` saves), then the process is gone. |
| `kill()` | The process dies with no warning: no background save. |
| `reopen_at(t)`, `resume_at(t)` | Close and launch at `t`. Background and resume the same process at `t`. |
| `store.fault_point` | Kills the next save midway (SAVE-08). |
| `heard` | Every script signal on `Session` and on the `Bus` autoload, in order, with the fake time. New signals from T1's contracts are recorded with no harness change. |

Rules: synthetic data only (the starter is "Bramble", id `0123456789abcdef`). Integration tests gate on `require()` for T1's milestones (`m2_sim`, `m4_save`, `m5_catchup`, and `p3_contracts` for the Phase 3 API). Exact state comparisons use the saved payload text (floats in hex, D-040), never a tolerance.

**Proving the tests can fail.** On 2026-11-27, four mutants were planted in T1's code and run against the suite. Each was caught by the test meant to catch it: humidity taken from the caller (AC-06.1), an extra RNG draw per feed (AC-05.1), the 14-day hold not moving the clock (AC-09.1, 30 days), and state changes not journaled at launch (AC-04.2, AC-09.1). All four were reverted.

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
| LINT-06 | **Safety copy** (prefixes from game-copy.md §16). Case-insensitive throughout. **Safety set** (`STATUS_MOLDY_`, `STATUS_UNHEALTHY_`, `SMELL_MUSTY_`, `SMELL_MOLDY_`, `INSPECT_*_MOLDY*`, `INSPECT_*_UNHEALTHY*`, `INSPECT_SURFACE_HOOCH_DARK_`, `EVENT_WARNING_SIGNS_`, `EVENT_MOLD_FOUND_`, `MOLD_`, `MEMORIAL_`, `NOTIF_WARNING_`, `REASON_MOLDY`, `REASON_NOT_MOLDY`): never "safe to", "still good", "scrape", "skim off", "just remove", "fine to use", "fine to eat", "ok to eat" or "okay to eat". **Must say "discard":** `STATUS_MOLDY_HINT`, `STATUS_MOLDY_TAP`, `SMELL_MOLDY_BODY`, `INSPECT_*MOLDY*_MEAN`, `MOLD_SHEET_BODY*`, `MOLD_FEED_BLOCKED`, `REASON_MOLDY_LOCKED` (game-copy §16, narrative's copy pass 2026-11-26), and `EVENT_MOLD_FOUND_JOURNAL_BODY` (added 2026-11-27 with the scientist-approved mold journal copy; mirrored in `check_copy.py` `MUST_DISCARD`). **Hunger set** (`STATUS_HUNGRY_`, `STATUS_DORMANT_STARVED_`, `SMELL_ACETONE_`, `SMELL_ALCOHOL_`, `SMELL_STRONGLY_ACIDIC_`, `EVENT_HOOCH_FORMING_`, `EVENT_HUNGRY_AGAIN_`, `EVENT_FIRST_ACETONE_`, `INSPECT_SURFACE_HOOCH_`, `INSPECT_*_HUNGRY*`, `FEED_HOOCH_`, `GLOSS_HOOCH`): never "danger", "unsafe", "toxic", "sick", "poison", "throw it out" or "throw away". **Any key:** never "probiotic", "gut health", "health benefit" or "cure". `run.sh`'s copy lint runs narrative's `check_copy.py` over the docs and the three `pending_*.csv` files ("pending CSVs" in its OK line), so placeholder rows are checked too. | Safety rules, hard rule 5 |
| LINT-07 | Nothing tracked matches `*.keystore`, `*.jks`, `*.p12`, `*.mobileprovision`, `*.pem`, `export_credentials.cfg` or `.env*`. `.godot/` and `*.translation` are untracked. | Hard rule 10 |
| LINT-08 | No U+2014 (em dash) in `src/i18n/*.csv` | Style |
| LINT-09 | The code's state, action, flour, location, container, cover and inspection-kind constants equal the `vision.md` lists | Canonical ids |
| LINT-10 | `DebugClock` and dev flags (`--fixture`, `--time-scale`, `--perf-log`, `--capture`) are reachable only behind `OS.is_debug_build()` | Vision time rules |
| LINT-11 | No key is duplicated across `en.csv` and the three `pending_*.csv` files. On 2026-11-27 (after T1's contracts) all three pending files are header-only, and `en.csv` has 657 strings. | Track separation (ADR-014) |
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
| AC-09.2 | Same | Reopen | "While you were away" shows only if the simulated time is ≥ 60 min (`AWAY_SUMMARY_MIN_S` = 3,600) **and** at least one event or state change happened (game-mechanics §8). Boundary from a grid-aligned close: 3,599 s away (3,540 s simulated) shows nothing, 3,600 s shows it. The rule counts simulated grid time, so a close in mid-minute can show it up to 59 s early (accepted 2026-11-27). | auto |
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
| AC-10.1 | Each slice event | Positive and negative scenarios | It fires in the positive scenario, with the right tier and payload, and never in the negative one. The thresholds are tested at the exact step they are crossed: `first_rise` when rise crosses 1.25 (spec §14.1 `RISE_NOTICEABLE`; this row said 1.4 before the spec's number was checked), `hooch_forming` when hooch crosses 0.1, `warning_signs` when `mold_risk` crosses 0.5 (the unhealthy onset). | auto |
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
| AC-12.15 | Every phone in the §9 matrix, text at 100% and 150% | Layout under the harness's fixed-size root | The jar region is ≥ 55% of the screen height on every iPhone at every text size, and ≥ 51% on 360 × 640 at every text size (T3 measured 52% at 100%, 51% at 150%, iPhones 61 to 66%). The larger Android profiles in §9 (Medium Phone, about 411 × 914, and the Pixel Pro XL class) are ≥ 55% at every text size (ux estimate for 411 × 914: 64 to 67%, not yet measured, so T3's layout test must add that profile). The bar plate is exactly 72 on every phone (no compact-height mode). The StatusPill is ≥ 44 tall. T3's layout test is the check. Source: D-043 and ux-design §1, §2, §4, §17 (7ef8608). | auto |

### 3.13 Traceability: what proves each row (Phase 3 exit)

As of 2026-11-27, on `phase-3-slice` at `23ba41f` (every track merged, including T2's and T3's backfill and T1's journal byte cap), plus QA's backfill.

**Status:**
- **covered**: a test in `tests/run.sh --strict` asserts the row's Then. For rows whose check type includes manual, capture or review, the automated part is asserted and the rest is in the named checklist.
- **waived**: carried forward by D-052, to Phase 4 or Phase 5.
- **manual only**: it needs eyes, hands or a device. The named checklist covers it.
- **open**: not covered, with the reason given.

**Where the tests live:**
- QA: `int/` = `tests/integration/`, plus `input/`, `property/`, `scenario/`, `perf/`, `save/`, `clock/`, `golden/`, `lint/`.
- T1: `t1/` = `tests/unit/core` and `tests/unit/sim`.
- T4: `t4/` = `tests/unit/sim/rules`.
- T2: `t2/` = `tests/unit/view`, where `t2/rows` is `test_phase3_rows.gd`.
- T3: `t3/` = `tests/unit/ui`, where `t3/backfill` is `test_backfill.gd`.

T1, T2, T3 and T4 rows are mapped from their owners' lists and assertion messages.

**Summary: 107 rows. 88 covered, 11 manual only, 8 waived (D-052), 0 open.**

| Group | Rows | Covered | Manual only | Waived | Open |
|---|---|---|---|---|---|
| AC-01 Jar | 7 | 4 | 2 | 1 | 0 |
| AC-02 Animated starter | 7 | 2 | 3 | 2 | 0 |
| AC-03 Rotate and zoom | 14 | 13 | 1 | 0 | 0 |
| AC-04 Lifecycle | 6 | 6 | 0 | 0 | 0 |
| AC-05 Feeding | 11 | 10 | 1 | 0 | 0 |
| AC-06 Temperature | 7 | 7 | 0 | 0 | 0 |
| AC-07 Smell | 8 | 7 | 1 | 0 | 0 |
| AC-08 Condition display | 8 | 7 | 1 | 0 | 0 |
| AC-09 Offline | 8 | 7 | 0 | 1 | 0 |
| AC-10 Events | 12 | 11 | 0 | 1 | 0 |
| AC-11 Save and load | 4 | 2 | 1 | 1 | 0 |
| AC-12 Mobile UI | 15 | 12 | 1 | 2 | 0 |

**Still uncovered, with the reason.** No row is open. These parts inside covered rows need a waiver or a later phase:
- AC-11.1: SAVE-19 (rename atomicity on Android) is a Phase 5 device check that D-052 doesn't list. SAVE-13 now holds: T1's byte cap (9551f26) fixed the size overrun QA found (146,561 bytes at 120 days before the fix).
  - AC-04.4: BT-12 is the B6 tutorial demo, a Phase 4 feature not in the slice.
  - AC-09.8: CLK-13's release-export run (Phase 5). LINT-10 checks the debug-only guards statically.
  - AC-03.10: the "fails with `--no-own-touches`" regression proof. The production camera has no such flag, so the test checks the mechanism directly.
  - AC-12.11: the no-sheet back case calls `save_and_quit()`, which would end the test process. It is in MAN-S5.

#### AC-01 A beautiful 3D jar

| Row | Proved by | Status |
|---|---|---|
| 01.1 | `t2/starter_uniforms::glb_matches_the_mesh_contract`, `lint glb` | covered |
| 01.2 | `t2/quality_tier::tier_a_draws_back_faces_before_front_faces`, `t2/starter_uniforms::liner_is_alpha_scissor_and_everything_inside_is_opaque` | covered |
| 01.3 | MAN-01, art review | manual only |
| 01.4 | MAN-01 (signed off, D-037) | manual only |
| 01.5 | `lint glb` (triangles). Draw calls on a device: Phase 5. | waived (D-052) |
| 01.6 | `t2/rows::ac_01_6_jar_centered_in_the_region_at_se_and_pro_max`, `t2/orbit_camera::jar_region_shifts_the_frame` | covered |
| 01.7 | `t2/quality_tier` (4 tests) | covered |

#### AC-02 An animated starter

| Row | Proved by | Status |
|---|---|---|
| 02.1 | Needs art's bounds. MAN-S1. | waived (D-052, Phase 4) |
| 02.2 | `int/ac04::rise_cycle_with_the_app_open`, `t1/sim_units::visual_mapper_rules`, `t2/live_visuals::easing_never_snaps_and_settles_in_about_1_5_s` | covered |
| 02.3 | Needs art's visible delta. MAN-02. | waived (D-052, Phase 4) |
| 02.4 | MAN-02 | manual only |
| 02.5 | MAN-02, MAN-S2 | manual only |
| 02.6 | `t2/rows::ac_02_6_reduce_motion_stops_decoration_not_the_sim`, `t2/live_visuals::pops_spawn_on_the_surface_and_stop_with_reduce_motion`, `t2/time_lapse::reduce_motion_shows_two_stills`. MAN-S4. | covered |
| 02.7 | MAN-02, MAN-S1 | manual only |

#### AC-03 Rotate and zoom

| Row | Proved by | Status |
|---|---|---|
| 03.1 | `t2/orbit_camera::orbit_rates_per_pt` | covered |
| 03.2 | `t2/orbit_camera::long_drags_stay_inside_limits_plus_band_and_settle` | covered |
| 03.2b | `input/ac03_input_routing::ac_03_10_a_jar_drag_crosses_the_bar_and_ends_cleanly` (real viewport routing, a STOP bar button) | covered |
| 03.3 | `t2/orbit_camera::pinch_zoom_range_with_band`. The haptic tick is MAN-05. | covered |
| 03.4 | `t2/touch_gestures::unclaimed_finger_is_ignored` | covered |
| 03.5 | `t2/orbit_camera::no_orbit_during_pinch_and_back_to_orbit_after` | covered |
| 03.6 | `t2/rows::ac_03_6_double_tap_still_reports_the_first_tap`, `t2/orbit_camera::double_tap_eases_home` | covered |
| 03.7 | `t2/orbit_camera::inertia_decays_with_tau_250ms`, `::reduce_motion_has_no_inertia` | covered |
| 03.8 | `t2/rows::ac_03_8_idle_return_home_and_off_with_reduce_motion` | covered |
| 03.9 | `t3/backfill::ac03_9_bar_press_dragged_away_never_acts` (the press cancels), `input/ac03_input_routing::ac_03_11_a_scrim_drag_never_moves_the_camera` (a bar drag never orbits) | covered |
| 03.10 | `input/ac03_input_routing::ac_03_10_a_jar_drag_crosses_the_bar_and_ends_cleanly` (orbit continues over the bar, the release reaches the camera, no button fires) | covered |
| 03.11 | `input/ac03_input_routing::ac_03_11_a_scrim_drag_never_moves_the_camera`, `t3/sheets::scrim_tap_closes_unless_disabled` | covered |
| 03.12 | `input/ac03_input_routing::ac_03_12_ten_thousand_random_touches`, `t2/touch_gestures::cancel_never_taps_and_frees_every_finger` | covered |
| 03.13 | MAN-03 | manual only |

#### AC-04 Starter lifecycle simulation

| Row | Proved by | Status |
|---|---|---|
| 04.1 | `t1/sim_vectors` V1 to V20 at `feed_u` 0, 0.5 and 1; `golden/diff_01`; `lint sim-vectors` | covered |
| 04.2 | `int/ac04::rise_cycle_with_the_app_open`, `::neglect_states_through_catch_up`, `int/ac05::timing_class_matches_the_state_at_mix` | covered |
| 04.3 | `t1/sim_units::state_precedence` | covered |
| 04.4 | `scenario/bt_and_leniency` (BT-4, 5, 6, 8, 10, 11, 14, 14b, 16), `int/ac10` (BT-1, 2, 3, 9), `int/ac04::neglect_states_through_catch_up` (BT-7), `t3/backfill::ac12_7_tap_budgets` (BT-13), `int/p3_contracts::a_week_away_fits_in_three_lines_and_one_prompt` (BT-15), `t1/phase3_sim::schedule_question_picks_one_preset_per_answer_at_the_counter` (BT-17). BT-12 is the Phase 4 tutorial demo. | covered |
| 04.5 | `scenario/bt_and_leniency`: `l_3_three_days_unfed_recovers_within_three_feeds`, `bt_16_l_10_l_11_no_loss_and_no_dead_ends` (11 fixtures × 10 actions), `sim_warn_03_warning_to_mold_at_every_temperature` (4 to 40 °C), BT-5 (L-2), BT-6 (L-8), BT-8 (L-9). Also `int/ac04` (L-4 to L-7 at V9) and `int/ac10` (L-1 schedules). | covered |
| 04.6 | `property/prop_sim`, `t1/catch_up`, `save/payload`, `int/ac09::any_absence_equals_the_app_left_open` | covered |

#### AC-05 Feeding interaction

| Row | Proved by | Status |
|---|---|---|
| 05.1 | `int/ac05::every_preset_and_flour`, `t1/sim_units::derived_discard_presets`, `::apply_feed_draws_exactly_once` | covered |
| 05.2 | `t3/backfill::ac05_2_feed_sheet_has_no_free_inputs`, `t3/feed_place_smell::feed_like_last_time_is_two_taps` | covered |
| 05.3 | `t3/feed_place_smell::feed_like_last_time_is_two_taps`, `int/p3_contracts::feed_like_last_time_is_the_same_feed` | covered |
| 05.4 | `t3/backfill`: `ac05_4_feed_from_a_return_in_three_taps`, `ac05_4_feed_from_the_nudge_in_three_taps`, `ac05_4_warning_quick_path_in_three_taps` | covered |
| 05.4b | `t3/backfill::ac05_4b_warning_safe_path_in_four_taps`, `t3/flows::warning_signs_look_first` | covered |
| 05.5 | `t3/backfill::ac05_5_no_hooch_step_below_the_threshold`, `t3/feed_place_smell::hooch_step_and_choice`, `int/ac05::hooch_pour_off_vs_stir_in`, `t4/hooch_forming` | covered |
| 05.6 | `t3/backfill::ac05_6_early_feed_shows_the_note_and_still_mixes`, `int/ac05::timing_class_matches_the_state_at_mix` | covered |
| 05.7 | `t3/feed_place_smell::feed_sequence_beats_skip_and_result`, `t2/live_visuals::feed_discard_then_settle_band_overshoots_six_percent`. MAN-S1, MAN-05. | covered |
| 05.8 | `int/ac05::kill_at_mix_never_duplicates_or_half_applies`, `int/ac11::killed_at_each_fault_point_mid_game` | covered |
| 05.9 | `t3/feed_place_smell::mix_spam_feeds_once` | covered |
| 05.10 | MAN-05 | manual only |

#### AC-06 Temperature control

| Row | Proved by | Status |
|---|---|---|
| 06.1 | `int/ac06::each_place_applies_with_its_fixed_climate`, `::temperature_is_not_a_free_input`, `t3/feed_place_smell::place_sheet_applies_at_once`, `lint/slice_scope` (no humidity in the UI) | covered |
| 06.2 | `int/ac06::a_move_is_a_move_at_its_grid_point` | covered |
| 06.3 | `int/ac06::warm_spot_peaks_before_the_counter`, `::fridge_sleeps_and_the_counter_wakes` | covered |
| 06.4 | `t3/flows::place_cards_show_the_temperature`, `int/ac06::fridge_sleeps_and_the_counter_wakes`, `t2/live_visuals::easing_never_snaps_and_settles_in_about_1_5_s`. MAN-S1. | covered |
| 06.5 | `int/ac06::flipping_places_is_one_segment_per_stay` | covered |
| 06.6 | `lint/slice_scope`, `t3/feed_place_smell::place_sheet_applies_at_once` | covered |
| 06.7 | `t3/backfill::ac06_7_fridge_in_three_taps` | covered |

#### AC-07 Smell interaction

| Row | Proved by | Status |
|---|---|---|
| 07.1 | `property/smell_rules::ac_07_1_intensities_match_spec_13_and_the_display_rules` (an independent copy of spec §13 within 1e-9, the display rules, the primary-by-hour script) | covered |
| 07.2 | `property/smell_rules::ac_07_2_sensory_line_variants_rotate_with_feeds`, `t3/feed_place_smell::smell_moment_and_card` | covered |
| 07.3 | `property/smell_rules::ac_07_3_musty_from_the_watch_stage_at_any_temperature`, `t3/backfill::ac07_3_musty_meaning_shows_every_time` | covered |
| 07.4 | `t3/backfill::ac07_4_hunger_smell_meaning_says_normal`, `t1/sim_vectors::v1`, `lint copy` | covered |
| 07.5 | `t3/backfill::ac07_5_meaning_three_times_then_one_tap_away` (T3 found and fixed the dropped meaning here) | covered |
| 07.6 | `t3/backfill::ac07_6_smell_moment_lasts_about_1_2_s`, `t3/feed_place_smell::smell_moment_and_card` | covered |
| 07.7 | `t3/flows::smell_moment_holds_events` | covered |
| 07.8 | MAN-07, MAN-S3 | manual only |

#### AC-08 Starter condition display

| Row | Proved by | Status |
|---|---|---|
| 08.1 | `t3/components::status_pill_icon_word_and_kind`, `t3/hud_layout::targets_text_and_names_for_every_status`, `t3/session_fixtures::every_fixture_drives_the_pill_and_hint` | covered |
| 08.2 | `t3/backfill::ac08_2_pill_crossfade_and_pulse` | covered |
| 08.3 | `int/ac08_no_digits::ac_08_3_no_digits_on_the_main_screen_toasts_or_cards` (12 fixtures, a feed and a first rise, the real UiRoot), `t3/flows::forecast_becomes_the_hint_after_a_feed` | covered |
| 08.4 | `property/inspection_rules` (spec §14 thresholds at value - ε and value; fuzz only when moldy; the camera at the framing in 500 ms), `t3/feed_place_smell::inspect_chip_moves_the_camera_and_reads_the_sim` (P0 chips only, the card in 2 taps), `t2/orbit_camera::bubbles_preset_stays_above_the_rim_at_every_rise` | covered |
| 08.5 | `t3/feed_place_smell::moldy_locks_feed_smell_and_place`, `t3/flows::mold_flow_to_memorial_and_restart`, `t1/phase3_session::moldy_locks_and_the_discard_flow`, `int/ac04::ec_07_moldy_stays_moldy_whatever_the_player_tries`, `lint copy`. MAN-S2, scientist sign-off. | covered |
| 08.6 | MAN-12, MAN-S4 | manual only |
| 08.7 | `t3/flows::new_state_dot_when_the_api_exists`, `t1/phase3_session::seen_states_for_the_new_dot` | covered |
| 08.8 | `t3/backfill::ac08_8_show_me_moves_the_camera_to_the_cue`, `lint copy` (lengths) | covered |

#### AC-09 Offline progression

| Row | Proved by | Status |
|---|---|---|
| 09.1 | `int/ac09::any_absence_equals_the_app_left_open`, `clock/clock_session` | covered |
| 09.2 | `int/p3_contracts::summary_needs_an_hour_and_a_change` | covered |
| 09.3 | `int/p3_contracts::a_week_away_fits_in_three_lines_and_one_prompt`, `t1/phase3_sim::return_summary_keeps_three_rows_and_one_prompt` | covered |
| 09.4 | `t3/backfill::ac09_4_attention_on_return_has_no_away_card` | covered |
| 09.5 | `int/ac09::time_lapse_frames_are_bounded_and_end_on_the_jar`, `int/p3_contracts::keyframes_keep_every_transition`, `t2/time_lapse` (4 tests), `t3/flows::away_summary_after_the_time_lapse` | covered |
| 09.6 | `int/ac04::time_lapse_frames_pass_the_warning_stage`, `t1/phase3_sim::return_summary_keeps_three_rows_and_one_prompt`, `int/ac10::warning_then_mold_at_the_counter` | covered |
| 09.7 | `perf/catch_up` (PERF-03, Mac estimate). The first jar frame on a device: Phase 5. | waived (D-052) |
| 09.8 | `clock/*`, `t1/session`, `int/ac05` (CLK-10, 18), `int/p3_contracts` (CLK-02), `int/clk_offsets` (CLK-06, 07, 15), `lint/04_10::lint_10_time_controls_are_debug_only` (CLK-13's guards; the release-export run is Phase 5) | covered |

#### AC-10 At least five contextual events

| Row | Proved by | Status |
|---|---|---|
| 10.1 | `int/ac10` crossing tests, `t4/*` | covered |
| 10.2 | `int/ac10::caps_cooldowns_and_quiet_hours_over_random_months`, `t1/event_engine::daily_caps_per_tier` | covered |
| 10.3 | `int/ac10`, `t4/*` cooldown tests, `t1/event_engine::cooldown_and_one_time` | covered |
| 10.4 | `int/ac10::quiet_hours_and_stale_nudges`, `int/clk_offsets::ac_10_4_quiet_hours_follow_the_new_offset_in_live_play`, `::clk_06_catch_up_uses_the_offset_read_at_resume`, `t4/hungry_again::quiet_hours_defer_to_8am` | covered |
| 10.5 | `int/ac10::quiet_hours_and_stale_nudges`, `t3/flows::withdrawn_card_hides` | covered |
| 10.6 | `int/ac10::a_second_attention_waits_for_the_first_ack`, `::warning_then_mold_at_the_counter`, `t4/warning_signs::mold_replaces_it_and_it_never_fires_when_moldy` | covered |
| 10.7 | The slice's only milestone is never shown as an event. | waived (D-052, Phase 4) |
| 10.8 | `t3/backfill::ac10_8_events_wait_for_the_feed_sequence_and_inspection`, `t3/flows::events_wait_for_sheets_then_show_by_priority`, `::smell_moment_holds_events`, `::away_summary_after_the_time_lapse` | covered |
| 10.9 | `int/ac10::twice_daily_for_a_month_needs_no_attention`, `::bt_2_once_daily_one_to_five`, `::bt_3_late_evening_feeds_create_no_night_nudges` | covered |
| 10.10 | `int/ac10::warning_then_mold_at_the_counter`, `::warning_gap_at_the_warm_spot`, `scenario/bt_and_leniency::sim_warn_03_warning_to_mold_at_every_temperature` | covered |
| 10.11 | `int/ac10::back_to_strength_after_the_fridge`, `t4/back_to_strength` | covered |
| 10.12 | `int/ac10::peak_closed_versus_open`, `t4/peak_now`, `t4/peaked_while_away` | covered |

#### AC-11 Save and load

| Row | Proved by | Status |
|---|---|---|
| 11.1 | `save/store`, `save/payload`, `t1/session`, `int/ac11`, `t1/phase3_session::journal_entries_are_identical_after_a_reload`, `save/year_and_v1::save_11_the_frozen_v1_save_still_loads_intact` (SAVE-11, `tests/fixtures/saves/v1_slice.json`), `::save_13_long_play_stays_inside_every_cap` (120 days, under 128 KB and flat), `perf/save::perf_04_a_full_size_save_writes_in_under_10_ms`. SAVE-19 needs Android (Phase 5). | covered |
| 11.2 | `int/ac11::killed_at_each_fault_point_mid_game`, `int/ac05::kill_at_mix_never_duplicates_or_half_applies`, `int/ac04::ec_25_*`, `save/store::save_08_kill_at_each_fault_point` | covered |
| 11.3 | MAN-S5 (Mac and the Android emulator) | manual only |
| 11.4 | Needs a second save version. | waived (D-052, Phase 4) |

#### AC-12 A polished mobile UI

| Row | Proved by | Status |
|---|---|---|
| 12.1 | `t3/backfill::ac12_1_and_12_2_cards_and_toasts_at_small_sizes`, `t3/hud_layout::targets_text_and_names_for_every_status` | covered |
| 12.2 | `t3/backfill::ac12_1_and_12_2_cards_and_toasts_at_small_sizes`, `t3/sheets::every_sheet_fits_at_every_size`, `t3/theme::type_scale_matches_ux_17` | covered |
| 12.3 | `t3/theme::contrast_day_and_night` | covered |
| 12.4 | `t3/theme::contrast_day_and_night` | covered |
| 12.5 | `t3/theme::no_control_uses_the_default_theme` | covered |
| 12.6 | Headless layout covered (`t3/hud_layout`); device captures: Phase 5. | waived (D-052) |
| 12.7 | `t3/backfill::ac12_7_tap_budgets` | covered |
| 12.8 | `t3/backfill::ac12_8_card_and_toast_motion`, `::ac08_2_pill_crossfade_and_pulse`, `t3/sheets::sheet_motion_and_reduce_motion` | covered |
| 12.9 | `t3/feed_place_smell::moldy_locks_feed_smell_and_place`, `t3/hud_layout::feed_emphasis_and_moldy_lock`. The quiet bar during a catch-up is an accepted exception (D-050). | covered |
| 12.10 | `t3/components::long_press_shows_the_large_label` | covered |
| 12.11 | `t3/backfill::ac12_11_android_back_closes_the_top_sheet`. The no-sheet case (save and quit) is in MAN-S5. | covered |
| 12.12 | Sheet timing captures: Phase 5. | waived (D-052) |
| 12.13 | MAN-12 | manual only |
| 12.14 | `lint/04_10::lint_04_scene_text_is_keys_and_every_tr_key_exists`, `lint/slice_scope::lint_12_pending_csvs_are_header_only`, `lint copy`, `lint catalog`, `t3/i18n_keys` | covered |
| 12.15 | `t3/hud_layout::insets_gutters_and_jar_region` (five profiles, 411 × 914 included) | covered |

### 3.14 Re-scope for Phase 4: iOS first (D-054), no screen readers (D-055)

Two new statuses:
- **Android phase:** Android-only behavior, moved to the later Android phase (D-054). Its headless tests stay in the suite, because the code stays portable. The 360 × 640 and 411 × 914 layout profiles stay too (D-054: they also protect small iPhones and large text).
- **dropped (D-055):** screen-reader work. The existing accessibility labels stay as they are, with no new work.

**Rows and parts that move:**

| Item | Was | Now |
|---|---|---|
| AC-12.11 Android back | covered | **Android phase.** iOS has no back button. `t3/backfill::ac12_11_android_back_closes_the_top_sheet` stays in the suite. |
| AC-11.1, the SAVE-19 part | Phase 5 (rename on Android) | Android phase |
| AC-11.3 kill from the app switcher | manual only (MAN-S5, Mac and Android emulator) | manual only, on the iPhone 13 Pro (MAN-D6). The Android boxes move to the Android phase. |
| AC-03.13, AC-05.10, AC-07.8 | manual on the Mac and the simulator | manual on the Mac and the iPhone 13 Pro (MAN-D3). The simulator can't render (D-044). |
| AC-12.6, the "every Android phone 56 dp" part | waived to Phase 5 | Android phase. The iPhone parts stay waived to Phase 5. |
| MAN-05: Android's three haptic levels | manual | Android phase. iOS haptics are judged on the iPhone (MAN-D4, D-059). |
| MAN-S0 to MAN-S5: every **A** box | manual | Android phase. Their iOS versions are in MAN-D. |
| EC-22 Android split screen | manual (Phase 5) | Android phase |
| §9 Android emulator profiles | Phase 5 | Android phase |
| A11Y-09 VoiceOver and TalkBack | manual after Godot 4.8 | **dropped (D-055)** |
| A11Y-08 `accessibility_name` on every interactive Control | auto | **frozen:** kept for existing Controls, no new work for Phase 4 Controls (D-055) |
| §6 "Screen readers" | needs Godot 4.8 | dropped (D-055). D-012 is superseded. |

**New counts for AC-01 to AC-12 (107 rows):**

| Status | Rows |
|---|---|
| covered | 87 |
| manual only | 11 |
| waived to Phase 5 (AC-01.5, AC-09.7, AC-12.6, AC-12.12) | 4 |
| carried into Phase 4, to be proven there (AC-02.1, AC-02.3, AC-10.7, AC-11.4; §3A.14) | 4 |
| Android phase (AC-12.11) | 1 |
| dropped (D-055) | 0 (no AC row was screen-reader only) |
| open | 0 |

BT-12, the tutorial demo, was waived to Phase 4 as part of AC-04.4. It is proven by AC-13.2 to AC-13.6.

---

## 3A. Phase 4 acceptance criteria (AC-13 to AC-26)

Owner: `qa-engineer`. Drafted 2026-11-27 on `phase-4-polish` (7914ffb), before T1's Phase 4 contracts.

**Scope:** `mvp-scope.md` "The rest of the MVP" and D-059. **Sources:** game-design §3; game-mechanics §2, §3, §5, §7, §8.1, §8.2; progression §2, §3, §5; events-catalog §4; narrative §9; ux-design §8, §10, §13 to §16; architecture §5.5; spec v1 §2.2, §4 to §6, §14, §15 and the scientist's v1.1 notes (2026-11-27); D-047, D-051, D-052, D-054 to D-059.

**Rules for this section:**
- **iOS first (D-054).** Device rows run on the user's iPhone 13 Pro (D-058) and are labeled "iPhone 13 Pro". Mac numbers stay "Mac estimate". No Android-only row is written here.
- **No screen-reader rows (D-055).** Visible accessibility stays: never color alone, text size, reduce motion, contrast.
- **The Check column names the track that writes the test**: QA (`tests/` outside the unit folders), T1 (`tests/unit/core`, `tests/unit/sim`), T2 (`tests/unit/view`), T3 (`tests/unit/ui`), T4 (`tests/unit/sim/rules`).
- **New placeholder tags:** `TBD-SND` (sound-designer, `audio-direction.md`), `TBD-T1` (a name or rule from T1's Phase 4 contracts), `TBD-T4` (T4's event rules).
- **Gating:** every test here runs under `tests/run.sh --strict` with no skips in the main suite. A test that needs T1's contracts lands in the commit that merges them, never as a skipped file.

### AC-13 Guided onboarding (B1 to B8, the demo, the skip path)

Play order (game-design §3): B1, B2, B3, B5, B6, B4, B7, B8. The B6 demo is the only sped-up time in a release build (game-mechanics §8.1, architecture §5.5).

| ID | Given | When | Then | Check |
|---|---|---|---|---|
| AC-13.1 | No save (first launch), the tour path | Onboarding runs | Beats show in exactly this order: B1, B2, B3, B5, B6, B4, B7, B8. One coach mark at a time, each ≤ 60 characters, with a 3 pt spotlight ring at ≥ 3:1 against the scene behind it (ux §14). No beat starts while another's sheet or card is open. | auto, T3 |
| AC-13.2 | The B1 start state: just mixed, young (maturity 0.2), `counter` (T1 names the preset, TBD-T1) | `Demo.run(state, env, steps)` | Every frame equals `VisualMapper.from_state` of a plain loop of 60 s `Sim.step` calls on a copy, field for field. The input state's `to_dict()` text is unchanged afterwards. No other step length is ever used (BT-12). | auto, QA |
| AC-13.3 | Same | `Demo.run_to_peak` | `rise_phase` goes `freshly_fed`, `developing`, `active`, `near_peak`, `at_peak` in that order, never back, never another phase, and stops on the first `at_peak` step. The jar pauses there (B6). The test prints N, the step count from feed to `at_peak`. | auto, QA |
| AC-13.4 | The demo playing in the UI | Feed to `at_peak` | Lasts 90 to 120 s of wall time (BT-12): N steps at the playback's steps per frame, measured with a fake frame clock. Reduce motion: TBD-UX (proposed: before and after stills, 1.2 s each, like AC-09.5). | auto, T3 |
| AC-13.5 | A first launch, the demo running | The whole demo, then a kill before the name is confirmed, then a relaunch 2 days later | The demo never changes the clock or the save: `Session.now_unix()` equals the device clock, `get_debug_time_scale()` stays 1, `is_time_traveling()` stays false, and the save bytes on disk are identical before and after the demo. After the relaunch, onboarding starts again at B1, and the starter adopted then is fresh at that moment (`at_peak`, `sim_time_unix` = `grid(now)`), never one that aged while it had no name. | auto, QA |
| AC-13.6 | The demo at `at_peak` | B4: the name is confirmed (`Session.adopt_starter`) | One save write. Its starter is `at_peak` by `rise_phase`, `sim_time_unix` = `grid(now)`, maturity 0.2, at `counter`, with the confirmed name. `meta` shows no time travel. A relaunch 60 s later catches up exactly 1 step and doesn't re-anchor (`meta.clock_reanchors` unchanged). | auto, QA |
| AC-13.7 | No save | "I've kept a starter before" (the skip path) | B2, B3, B5 and B6 never show. B4 (naming) and the B7 question do. The save comes from the same at-peak `new_game` preset, so the B7 feed's timing class is `on_time`. Every P0 and P1 option is open at once: 4 flours, 3 hydration presets, 5 places, 5 inspect kinds (progression §3). | auto, QA + T3 |
| AC-13.8 | The tour path, or the skip path | The B7 feed | Exactly one day-one journal entry, with body `JOURNAL_DAY_ONE_BODY` (tour) or `JOURNAL_DAY_ONE_SKIP_BODY` (skip) and the name. A second feed adds none. | auto, QA |
| AC-13.9 | B7 | The schedule question, then Mix | The 3 answers of game-mechanics §2.2 are offered, and the feed is the starter's first real-time feed. B8 shows the forecast in time-of-day words (no digits, AC-08.3) and the one fridge line. From the feed on, each minute's tick advances exactly 1 step. | auto, T3 |
| AC-13.10 | Any beat from B7 on | Killed, then relaunched | The named starter is there: never a second starter, never a lost name. If the B7 feed wasn't made, the B7 question shows again (TBD-UX). | auto, QA |
| AC-13.11 | A running game | Settings, "Replay tutorial" (ux §14), if it ships in Phase 4 | The coach marks and demo play on a copy. The real starter, journal and save are byte-unchanged apart from `meta`. | auto, T3 |
| AC-13.12 | The iPhone 13 Pro | MAN-D2 | Every item is ticked. | manual |

### AC-14 Flours and hydration (P1 feeding)

| ID | Given | When | Then | Check |
|---|---|---|---|---|
| AC-14.1 | A non-moldy starter, every P1 option open | Mix with each of 4 flours × 3 ratio presets × 3 hydration presets (36 feeds) | Session accepts all 36. Grams follow the derived discard with hydration (game-mechanics §2.3, rule TBD-GD): `keep = round(150 / (1 + f + f × h / 100))`, `flour = keep × f`, `water = flour × h / 100`, with 1:5:5 rounded to 5 g. Keep / flour / water (total): 1:1:1 at 60% 58 / 58 / 34.8 (150.8), at 125% 46 / 46 / 57.5 (149.5); 1:2:2 at 60% 36 / 72 / 43.2 (151.2), at 125% 27 / 54 / 67.5 (148.5); 1:5:5 at 60% 17 / 85 / 50 (152), at 125% 12 / 60 / 75 (147); 100% as AC-05.1. Every total is 150 ± 5 g. **QA finding (2026-11-27):** today's `FeedAction.from_ratio(f, f, flour, h)` keeps `w = f`, so 1:1:1 at 60% is 50 / 50 / 30 (130 g) and at 125% 162.5 g, and Session rejects all 6 non-100% presets with `REASON_MASS`. Sent to T1. | auto, QA |
| AC-14.2 | Any feed through `Session.apply()` | The new culture | `flour_mix` and `culture_hydration` equal spec §6, computed independently, within 1e-9: `kept_flour = kept × 100 / (100 + h)`, `culture_hydration = (kept_water + water) / (kept_flour + flour) × 100`, `flour_mix` a flour-weighted blend whose shares sum to 1 ± 1e-9. After 3 conversion feeds with a new flour, that flour holds a share ≥ 0.5, so the flour readouts (surface, smell) switch to it. | auto, QA |
| AC-14.3 | V5 and V6 (spec §18) | 3 conversion feeds 12 h apart, then the test feed, all through `Session.apply()` | V5's and V6's ranges plus drift (±0.3 h, ±0.05×): rye peaks 5.1 to 5.3 h at about 1.66×, whole_wheat 5.5 to 5.7 h and spelt 5.5 to 5.8 h at about 1.91×; 60% peaks 6.75 to 7.0 h at 2.33 to 2.35× with hooch never ≥ 0.1 in 48 h; 100% 6.2 to 6.4 h; 125% 6.0 to 6.2 h. The AC-14.1 grams keep the same inoculum fraction as V6 (58 / 150.8 = 50 / 130), so V6's ranges apply. | auto, QA (T1 covers the sim level) |
| AC-14.4 | The 4 flours at `at_peak` after 3 conversion feeds | `VisualMapper.from_state`, `SmellModel.read`, `Inspection.read` | Each flour differs from white in something the player can see or smell (game-mechanics §2.7): a `VisualParams` tint or fleck by at least the visible delta (TBD-ART), or the smell set. Rye's surface reads `cracked` (rye share ≥ 0.5 and rise ≥ 1.3). Rye-majority consistency at its peak reads `airy_pasty` (spec v1.1 §14). | auto, QA |
| AC-14.5 | The tour path (progression §3) | Play to each trigger | `white_bread` from the start; `whole_wheat` after the first real-time `first_peak`; `rye` and the hydration presets at stage `steady` (maturity 0.33); `spelt` at `mature` (0.50). A locked option is not offered (TBD-UX: hidden, or shown locked with a reason). Each unlock writes one journal line and one intro, once. Unlocks are per player, so they survive a discard and a new starter. | auto, T1 + T3 |
| AC-14.6 | A previous feed with rye at 60% | Feed, then Mix | 2 taps. The stored `FeedAction` equals the previous one field by field, flour and water included (AC-05.3 extended). | auto, T3 + QA |
| AC-14.7 | The feed sheet | Water presets | Labeled in words (Stiff, Standard, Loose, ux §8). Each row's grams match AC-14.1. The forecast updates when the preset changes and matches `Session.forecast_feed()` for that feed. | auto, T3 |

### AC-15 The new places: `window_sill` and `proofing_box`

| ID | Given | When | Then | Check |
|---|---|---|---|---|
| AC-15.1 | Any non-moldy starter | Move to `window_sill`, then to `proofing_box` | Applies at once. The environment equals spec §2.2: `window_sill` 18 °C and 55% RH, `proofing_box` 26 °C and 60% RH by default. Humidity comes from the place, never from the caller, and is never shown. One move line each in the journal. | auto, QA |
| AC-15.2 | `proofing_box` | Set 24, 30, 23.5 and 30.5 °C | 24 and 30 apply. 23.5 and 30.5 are rejected with `REASON_ENVIRONMENT`, and the save, journal and state stay byte-unchanged. The UI steps by 1 °C (TBD-UX) with 48 pt steppers, and the proofing box is the only place with a dial. | auto, QA + T3 |
| AC-15.3 | The same fed state (1:1:1) | One run per place | Peak order: proofing box at 30 °C < warm spot = proofing box at 26 °C < counter < window sill. The warm spot and the box at 26 °C peak in the same minute (humidity only changes dryness). The window sill peaks at about 8.7 h (spec §15, 18 °C), within 5% plus drift. | auto, QA |
| AC-15.4 | Unfed at `window_sill` | 14 days | `unhealthy` at about 5.8 d and `moldy` at about 11.4 d (spec §15), within 5% plus drift. Warning to mold ≥ 72 h. At the proofing box at 30 °C, warning to mold ≥ 59 h (SIM-WARN-03's floor). | auto, QA |
| AC-15.5 | progression §3 | Play | `window_sill` opens after `first_wake` or stage `steady`, whichever is first. `proofing_box` opens at `mature`. The skip path opens both (AC-13.7). | auto, T1 + T3 |
| AC-15.6 | The place sheet with 5 places, every phone in §9, text 100% to 150% | Layout | Every card and stepper ≥ 44 pt (48 standard), no overlap, no clipped text. The stepper shows only while the proofing box is selected. Each card shows its temperature with a word (Cold, Cool, Mild, Warm, ux §13), never color alone. | auto, T3 |
| AC-15.7 | Each place | Move there | The jar moves to its own spot with its own light (art-director). No `VisualParams` field jumps more than `max_delta`. Captures reviewed against art's references. | capture + review, T2 |

### AC-16 Traits and renaming

| ID | Given | When | Then | Check |
|---|---|---|---|---|
| AC-16.1 | 4 scripted 14-day schedules, one per signal (progression §5): ≥ 50% of hours at 24 °C or more (`energetic`); ≥ 50% at 18 °C or less (`patient`); 2 `comeback` or `rescued` (`resilient`); 8 changes of place, flour or ratio (`sensitive`) | Play to stage `steady` | The revealed trait is the scripted one, and `trait_revealed` fires once. Hours count from the environment's temperature (`EnvironmentState.temperature_c`, spec v1.1 §14.2), not the starter's lagging `temp_c`. A tie goes `resilient`, `patient`, `energetic`, `sensitive`. Every starter gets a trait. | auto, QA |
| AC-16.2 | Two runs that differ only in the revealed trait | The same schedule | Every starter and environment field is byte-identical. Traits change words only (progression §5, CLAUDE.md rule 2). | auto, QA |
| AC-16.3 | Another trait leads 14 days in a row | Play | It becomes dominant and the journal says so (`EVENT_TRAIT_DRIFT_*`). At most one change per 28 days. | auto, T1 |
| AC-16.4 | A revealed trait | Its copy | The reveal and trait page use `TRAIT_*`. The memorial epitaph is `MEMORIAL_EPITAPH_<TRAIT>`, else `MEMORIAL_EPITAPH_<1 + seed % 3>` (narrative §9.3). The trait never shows as a number or a bar. | auto, QA + T3 |
| AC-16.5 | A named starter | Rename to 1 character, 24 characters, " Dough " (padded), emoji, right-to-left text; then to "", spaces only, 25 characters | The first five apply, trimmed, each with one `JOURNAL_LOG_RENAME` entry. The last three are rejected with `REASON_NAME` and change nothing. Every accepted name survives a save and reload byte for byte (UTF-8, EC-20). | auto, QA |
| AC-16.6 | Settings | "Rename starter" (ux §14) | Within the UX §7 tap budget (TBD-UX). The pill and the journal header show the new name at once, and the pill never overflows at 150% text. | auto, T3 |

### AC-17 `consistency` and `development` inspection, and "What it means"

| ID | Given | When | Then | Check |
|---|---|---|---|---|
| AC-17.1 | Spec §14 `consistency` | States at value − ε and value for `h_eff` 75, `acid` 0.66 in each slack condition, and `h_eff` 110, plus cold `dormant` | First match wins: `stiff_dough`, `slack_soupy`, `airy_webby` (`airy_pasty` when rye is the main flour, spec v1.1), `loose_batter`, `thick_batter`. `firm_cold` replaces the last three when cold dormant. `h_eff = culture_hydration / absorb`, so white at 60% is stiff and rye at 100% (h_eff 80) is not. | auto, QA |
| AC-17.2 | Spec §14 `development` | Maturity 0.33, 0.50 and 0.83, and vigor 0.6 and 0.85, each at − ε and exact | Stages `young`, `steady`, `mature`, `seasoned` and strengths `weakened`, `steady`, `strong` switch exactly there. The copy is `UNHEALTHY` when unhealthy, `WEAKENED` when vigor < 0.6, else the stage. It never claims how reliable recent rises were (spec §14). | auto, QA |
| AC-17.3 | States from real sim runs: every flour, 60, 100 and 125%, every place, fed and then neglected to `moldy` | `Inspection.read` for all 5 kinds | Every observation and meaning key exists in `en.csv` with non-empty text, and no such text contains a digit. Every key for a `moldy` state is a moldy key, and its meaning says "discard" (LINT-06). | auto, QA |
| AC-17.4 | Spec v1.1 §14 | `surface` with `mold_risk` ≥ 0.3, not moldy | `is_warning` is true and the meaning is `INSPECT_SURFACE_UNHEALTHY_MEAN`, so it never fades. Below 0.3 (and not unhealthy) it is false. | auto, QA |
| AC-17.5 | Inspect, `consistency`; then `development` | The chip | `consistency`: the camera reaches the jar mouth from 50° above in 500 ms, and a spoon lifts a strand. `development`: a slow 40° orbit over 3 s at 1.2 × the home distance. Reduce motion: a 200 ms cut, and a still wide 3/4 view for `development` (ux §10). | auto + capture, T2 |
| AC-17.6 | Stage `steady`, or the skip path | Inspect | The `consistency` and `development` chips appear (with `getting_stretchy`). Before that, only the 3 P0 chips (AC-08.4). Chips are 156 × 48 pt in 2 columns. | auto, T3 |
| AC-17.7 | Any inspection kind | The meaning line (game-mechanics §5) | Shows on the first 3 views of each kind and level (`inspect.<kind>.level_<n>`). From the 4th view, a "What it means" button (`SMELL_MEANING_BTN`) shows it in 1 tap. A warning readout (`is_warning`) always shows its meaning and has no button. | auto, T3 |

### AC-18 The empty jar (D-047 follow-up)

The discard now commits at "Discard" in the confirmation, and "Not today" leaves an empty jar (narrative §9.2 step 6, D-059).

| ID | Given | When | Then | Check |
|---|---|---|---|---|
| AC-18.1 | `moldy`, the confirmation open | "Discard" | One atomic save: the memorial is written, the old starter is gone, and the save holds the empty jar. Then the restart page (`RESTART_*`). | auto, QA |
| AC-18.2 | The restart page | "Not today" (`RESTART_BTN_LATER`) | The empty-jar screen: `EMPTY_JAR_TITLE` and `EMPTY_JAR_BODY` and a clean jar. Feed, Smell, Place and Inspect are disabled with a visible reason, or hidden (TBD-UX). Journal and Settings work. "Start again" is offered. No timer, and nothing advances on its own. | auto, T3 |
| AC-18.3 | The empty jar | Relaunch 1 min, 8 h and 30 days later, and with the clock set back 1 day | Still the empty jar. No catch-up, no events, no journal entries, no notification scheduled (AC-20.6), no crash. | auto, QA |
| AC-18.4 | The empty jar | "Start again", then a name | The new starter is `first_restart` after the first loss and `restart` after later ones (game-mechanics §8.2), rebased to now: `sim_time_unix` = `grid(now)`, never a catch-up over the empty time. "Pick for me" names it in 1 tap. | auto, QA |
| AC-18.5 | Two losses, an empty-jar stay between them | The journal | Exactly one memorial per loss. Old chapters and entries are kept with their `starter_id`. The new chapter's entries carry the new id. The empty time writes nothing. | auto, QA |
| AC-18.6 | Taps | Discard to the empty jar; the empty jar to a named starter | "Discard it", "Discard", "Not today": 3 taps. "Start again", "Pick for me": 2 taps (TBD-UX). | auto, T3 |
| AC-18.7 | Copy on the restart page and the empty jar | Review | No blame, no rush, no nag (narrative §9.1). Scientist and narrative sign off. | review |

**EC-25 is rewritten for this** (§5): a kill before "Discard" keeps the moldy jar; a kill after it never brings the moldy jar back.

### AC-19 The 8 remaining events

Rules: game-mechanics §7.4 and events-catalog §4. T4 writes each rule's unit tests. QA writes the scenarios through `Session` with the full registry. In every row the event fires in the positive scenario with its tier, cooldown and payload, and never in a negative one.

| ID | Event | Positive | Negative | Then | Check |
|---|---|---|---|---|---|
| AC-19.1 | `first_acetone` (info, one-time per player, catalog §4.1) | The first smell whose primary is `acetone` or `alcohol` (24 h unfed at the counter, V1) | Catch-up with no smell; a second hungry smell; the next starter after a discard | Fires once, on that smell. The copy says hunger (LINT-06 hunger set). | auto, T4 + QA |
| AC-19.2 | `off_to_nap` (info, 24 h) | A move to `fridge` | A second fridge move within 24 h; a move anywhere else | The move's own journal line is replaced by the event's entry (game-copy §11). `first_nap` is journal only (AC-10.7). 50 flips in a minute give at most 1. | auto, T4 + QA |
| AC-19.3 | `waking_up` (info, once per fridge stay) | After a fridge stay, the first rise crossing 1.25 upward after a feed | A rise with no fridge stay; the second rise after the same stay; leaving the fridge with no feed | Fires once per stay, on the crossing step. `first_wake` is journal only. | auto, T4 + QA |
| AC-19.4 | `fed_before_peak` (nudge, 72 h) | A 3rd feed in a row with `rise_phase` `freshly_fed`, `developing` or `active` | An `on_time` feed in between resets the count | One "Got it" button. Nudge rules hold: deferred to 08:00 in quiet hours, dropped when stale, ≤ 2 nudges a day. EC-04 (12 feeds in 2 h) fires it once. | auto, T4 + QA |
| AC-19.5 | `warm_and_quick` (info, 72 h) | A feed at `warm_spot`, or the proofing box at 26 to 30 °C | `counter`, `window_sill`, `fridge` | Fires at the peak when feed-to-peak ≤ 0.85 × the forecast for the same feed at 22 °C (spec §14.1; warm spot about 0.80). | auto, T4 + QA |
| AC-19.6 | `getting_stretchy` (info, one-time per starter) | `maturity` crosses 0.33 | Maturity already ≥ 0.33 at load | Fires once per starter. `stage_steady` is journal only. The P1 chips open with it (AC-17.6). | auto, T4 + QA |
| AC-19.7 | `big_bubble` (info, ambient, 48 h, ≤ 1 a day) | `rise_phase` enters `near_peak` with `feed_u` ≥ 0.85 | `feed_u` 0.8499; a second qualifying cycle within 48 h | Fires on the entering step, and the jar shows it (`VisualParams.big_bubble`, CLAUDE.md rule 2). Variant `_TOAST_<1 + feed_count % 3>`. The first line dropped from a return summary. | auto, T4 + QA |
| AC-19.8 | `trait_revealed` (info, one-time per trait) | Stage `steady` (AC-16.1), and a drift (AC-16.3) | The same trait again | Once per trait. A drift uses `EVENT_TRAIT_DRIFT_*`. | auto, T4 + QA |

| ID | Given | When | Then | Check |
|---|---|---|---|---|
| AC-19.9 | All 16 rules (D-048's 8 plus these 8), every place and flour | 30-day random schedules, 1,000 seeds | AC-10.2 and AC-10.3 still hold: per local date ≤ 2 nudges, ≤ 1 attention created, ≤ 4 live info toasts, never more than 1 attention waiting, every cooldown. | auto, QA |
| AC-19.10 | Two or more rules fire on one step | Release | One fixed tie order over all 16 (D-048's order plus T4's for the new 8, TBD-T4). The same input gives the same order (PROP-12). | auto, T4 |
| AC-19.11 | `unhealthy` or `moldy` | Any step | No good-news event fires (D-048, extended): `waking_up`, `warm_and_quick`, `big_bubble`, `getting_stretchy` and `trait_revealed` join the list. | auto, T4 + QA |
| AC-19.12 | All 16 rules | PROP-12, PROP-13 | Events use no RNG. Removing any one rule leaves every starter field byte-identical. | auto, QA |
| AC-19.13 | The full registry | PERF-03 | The 14-day catch-up median ≤ 250 ms (Mac estimate, D-051). The same catch-up on the iPhone 13 Pro is recorded (MAN-D7). | auto (timed) + manual |

### AC-20 The warning-signs notification (`Notifier`, D-057)

Tested with a stand-in backend that records every call (TBD-T1). The real iOS plugin waits for an approved download and the iPhone (D-057).

| ID | Given | When | Then | Check |
|---|---|---|---|---|
| AC-20.1 | A new game | Any play | Off by default. No permission request until the player turns it on. While off, 0 `schedule` calls reach the backend. | auto, QA |
| AC-20.2 | On, a starter that isn't `unhealthy` or `moldy` | Backgrounded (`on_background()`) | Exactly 1 `schedule` call with `NOTIF_WARNING_TITLE` and `NOTIF_WARNING_BODY` (with `{name}`), at the first minute the sim derives `unhealthy` if nothing more is done: the same step function and environment, from the saved state, ± 60 s. | auto, QA |
| AC-20.3 | On | Any sequence of backgrounds, resumes, relaunches and kills | The backend never holds more than 1 pending notification. | auto, QA |
| AC-20.4 | A pending notification | Resume or relaunch | It is cancelled before `resumed` or `session_ready` fires. While the app is in the foreground, 0 are pending. | auto, QA |
| AC-20.5 | The forecast time falls between 22:00 and 08:00 local | Schedule | Moved to 08:00 local the next morning: later, never earlier, because the copy says it "is showing warning signs" (TBD-GD to confirm). The offset is the one read at background (CLK-06, CLK-07). | auto, QA |
| AC-20.6 | On | Background with: a fridge starter that stays out of `unhealthy` for 14 days; `unhealthy` already; `moldy`; the empty jar; a debug time-scale run | Nothing is scheduled in any case. Never a notification about mold (game-copy §15). | auto, QA |
| AC-20.7 | Any play | The backend log | Only `NOTIF_WARNING_*` keys are ever scheduled. `NOTIF_PEAK_SOON_*` and `NOTIF_HUNGRY_*` stay unused (D-025: one notification). | auto, QA |
| AC-20.8 | The same save, clock and offset | Background twice from identical states | The same `at_unix`. The forecast takes no RNG draw (`sim_state` unchanged). | auto, QA |
| AC-20.9 | The forecast on background | Timed | ≤ 250 ms, Mac estimate (TBD-ARCH; at most 14 days of steps without rules). The device time is recorded in MAN-D7, because iOS gives the pause notification only a few seconds. | auto (timed), QA |
| AC-20.10 | The iOS plugin wired | iPhone 13 Pro | The permission prompt shows once, after opting in. With the app closed, the notification arrives at its time. Tapping it opens the game, and returning cancels any other pending one. | manual (MAN-D6) |
| AC-20.11 | `NOTIF_WARNING_*` | Copy lint | Within 30 and 90 characters, in the LINT-06 safety set, no guilt. | auto (lint copy) |

### AC-21 Haptics through the hook

| ID | Given | When | Then | Check |
|---|---|---|---|---|
| AC-21.1 | `src/**` | Lint | `Input.vibrate_handheld` appears only in T1's haptics hook (TBD-T1). **Today** `src/view/orbit_camera.gd` calls it directly for the pinch-limit tick (Android only, ignoring the haptics setting). | auto (lint), QA |
| AC-21.2 | Haptics off | A full feed with hooch, a smell, 10 pokes, a pinch to both limits, a long press, a discard | 0 calls reach the backend (A11Y-06). With haptics on, the same script reaches it at least once, so the spy is live. | auto, QA |
| AC-21.3 | Haptics on, a fake clock | Each moment | The ux §6, §8, §9 and §15 pattern: poke, glass tap, pill tap, chip select, long press and pinch limit are light. Feed: hooch light, scrape light, flour medium, water 3 × light 150 ms apart, stir light every 180 ms, settle firm. Reduce motion feed: one firm. Smell: light, light, medium, 330 ms apart. Discard: firm. Timings within 1 frame. | auto, T2 + T3 |
| AC-21.4 | The level table | Read by the test | light, medium and firm map to one pure table: ux §15 (10 ms at 0.3, 20 ms at 0.6, 35 ms at 1.0), or the iOS values the user picks on the iPhone (D-059). | auto, T1 |
| AC-21.5 | Every haptic moment | The audio trigger list | Also has a sound (ux §15: haptics are never the only cue). | auto, QA |
| AC-21.6 | The iPhone 13 Pro | MAN-D4 | Every item is ticked. | manual |

### AC-22 Audio

| ID | Given | When | Then | Check |
|---|---|---|---|---|
| AC-22.1 | `assets/audio/**` | Lint | WAV for one-shots, Ogg Vorbis for anything longer than about 2 s, 44.1 or 48 kHz, mono unless `audio-direction.md` says otherwise, ≤ 2 MB in total. Every file has a line in `art/audio/LICENSES.md`: synthesized with its script, or CC0 with its source URL. | auto (lint), QA |
| AC-22.2 | Each file | Sample scan | Peak ≤ −3 dBFS (0.708 of full scale). The first and last samples are within TBD-SND of zero, so nothing clicks. Short effects are near −20 LUFS by sound-designer's measurement, which is reported, not gated. | auto (lint), QA |
| AC-22.3 | Each synthesized file | Its script rerun into a temp folder | Byte-identical to the committed file. | auto (lint), QA |
| AC-22.4 | Sound off | A feed, a smell, pokes, the time-lapse, the room tone | 0 sounds start, and the room tone stops within 1 frame. Sound back on resumes the room tone. The setting persists in `settings.cfg`. | auto, T2 |
| AC-22.5 | The volume setting (TBD-UX: steps or a slider) | Each value | Maps monotonically to the bus level. The lowest value is silent. It persists. | auto, T2 |
| AC-22.6 | Every sound | The trigger list in `audio-direction.md` | Each plays only from its Bus signal or Session event. Every sound moment also has a visual cue, so nothing depends on sound. | auto, T2 + QA |
| AC-22.7 | 100 pokes in 1 s, then a feed with bubble pops | Count voices | Never more than the voice limit playing at once (TBD-SND), with the stealing rule from `audio-direction.md`. | auto, T2 |
| AC-22.8 | The loudest overlap: the feed sequence, pops and the room tone | The master bus | Peak ≤ 0 dBFS (headroom or a limiter, TBD-SND). | capture (Mac), T2 |
| AC-22.9 | The app backgrounded; the iPhone's silent switch | Sound playing | Stops in the background and resumes on return. The silent switch mutes the game (proposed: the ambient iOS audio session category, checked as a project setting, TBD-SND and T2). | auto (setting) + manual (MAN-D5) |

### AC-23 Battery

| ID | Given | When | Then | Check |
|---|---|---|---|---|
| AC-23.1 | The app open | `interaction_ended`, then 3 s (`IDLE_AFTER_S`) with no input | `Engine.max_fps` is 30. On `interaction_started` it is 60 again at once (PERF-02). | auto, QA |
| AC-23.2 | Any animation that isn't a camera move: a sheet opening, the feed sequence, the smell moment, the time-lapse, a card, the demo | While it runs | `Engine.max_fps` stays 60, and the 3 s idle timer restarts when it ends. **Fails today (QA, from the code):** only `OrbitCamera` emits `interaction_started` and `interaction_ended`, and `Session.start()` arms the idle timer at boot, so 3 s after launch every non-camera animation runs at 30 fps. | auto, T2 |
| AC-23.3 | An opaque full-screen sheet (journal, settings) | Open, then closed | While open, low-processor mode is on or `World` is hidden, so 3D draw calls are 0 (PERF-09). Off again within 1 frame of closing. Never while the jar is visible, because the starter breathes (TBD-ARCH, T2). | auto, T2 |
| AC-23.4 | `project.godot` | PERF-10 | `keep_screen_on` = false, render scale 0.75, MSAA 2x, unless a decision row moves them. | auto, QA |
| AC-23.5 | The iPhone 13 Pro | MAN-D7 | 10 minutes idle on the main screen: battery drop, Xcode's Energy Impact level and whether the phone gets warm are recorded, labeled "iPhone 13 Pro". | manual |

### AC-24 The compact feed sheet

| ID | Given | When | Then | Check |
|---|---|---|---|---|
| AC-24.1 | 390 × 844 pt (the iPhone 13 Pro), 100% text, every P1 option open, hooch present | Open the feed sheet | Every control is visible with no scrolling: the hooch step, 3 schedule rows, 4 flour chips, 3 water chips, the early note, "Same as last time" and Mix. | auto, T3 |
| AC-24.2 | Every phone in §9, at 100%, 125% and 150% | Same | Mix is pinned and fully visible. If the sheet scrolls, Mix doesn't scroll away. No text clips. | auto, T3 |
| AC-24.3 | Same | Targets | Every control ≥ 44 pt (48 standard), schedule rows ≥ TBD-UX (64 pt in the slice), no overlap (AC-12.1). | auto, T3 |
| AC-24.4 | The jar above the sheet | A ratio picked | The ghost band line stays visible in the band above the sheet at every size (ux §8). | auto, T2 + T3 |
| AC-24.5 | Feed like last time | Feed, Mix | Still 2 taps (AC-05.3, AC-14.6). | auto, T3 |

### AC-25 The journal: merged quick place moves (OD-22)

| ID | Given | When | Then | Check |
|---|---|---|---|---|
| AC-25.1 | Several moves within the merge window (TBD-GD and T1: OD-22 proposed a few minutes) | Moves | One journal line, naming the final place. A move after the window starts a new line. | auto, QA |
| AC-25.2 | Same | The sim | Starter and environment bytes equal the unmerged run (AC-06.5). Merging touches only the journal. | auto, QA |
| AC-25.3 | An open merge window | Save and reload, or a kill | The merged line survives a reload. A kill leaves at most one line for the window. | auto, QA |
| AC-25.4 | A fridge move inside a window | `off_to_nap` | The event's own entry is kept (game-copy §11), and its cooldown is unchanged. | auto, QA |
| AC-25.5 | 50 flips a minute for a day | SAVE-13 | The journal stays inside its caps and the save inside 128 KB. | auto, QA |

### AC-26 Saves for the Phase 4 fields

| ID | Given | When | Then | Check |
|---|---|---|---|---|
| AC-26.1 | Every new saved field: trait scores and buckets, unlocks, the empty jar, notification opt-in and its pending id, the onboarding path, the merge window | Save and load, and the `save.prev` fallback | Bit for bit (SAVE-01). Corrupt values in the new fields are quarantined like any other (SAVE-05, SAVE-20). | auto, QA |
| AC-26.2 | `tests/fixtures/saves/v1_slice.json` (the frozen Phase 3 save) | Loaded by the Phase 4 build | It loads with no trait yet, notifications off, and unlocks derived from its history and maturity (TBD-GD: a v1 player past `steady` gets the `steady` unlocks at once, never locked out of what they had). If the empty jar bumps the save version (D-051), this is AC-11.4's migration test. | auto, QA |

### 3A.14 Carried from Phase 3 (D-052)

| Row | Phase 4 proof | Check |
|---|---|---|
| AC-02.1 | art-director's alive and calm bounds (TBD-ART, proposed 0.3% to 5% mean pixel change in 2 s) on Mac captures, plus the feel on the iPhone (MAN-D3) | capture + manual |
| AC-02.3 | art-director's visible delta per `VisualParams` field, then an auto test over the 5 pairs | auto, QA |
| AC-10.7 | The Phase 4 milestone pairs: `off_to_nap` with `first_nap`, `waking_up` with `first_wake`, `getting_stretchy` with `stage_steady`, `trait_revealed` with its milestone. One toast each, and the milestone in the journal only. | auto, QA |
| AC-11.4 | The first save-version bump (D-051) migrates `v1_slice.json` to a frozen expected payload (AC-26.2) | auto, QA |
| BT-12 | AC-13.2 to AC-13.6 | auto |

### 3A.15 Traceability (Phase 4)

Updated as tests land. **planned** means the row waits for the named track's code. `today` means QA built it against the API on `phase-4-polish` before T1's contracts.

| Group | Rows | auto | manual, capture or review | Covered now |
|---|---|---|---|---|
| AC-13 Onboarding | 12 | 11 | 1 | see below |
| AC-14 Flours and hydration | 7 | 7 | 0 | |
| AC-15 Places | 7 | 6 | 1 | |
| AC-16 Traits and renaming | 6 | 6 | 0 | |
| AC-17 Inspection | 7 | 7 | 0 | |
| AC-18 Empty jar | 7 | 6 | 1 | |
| AC-19 Events | 13 | 13 | 0 | |
| AC-20 Notification | 11 | 10 | 1 | |
| AC-21 Haptics | 6 | 5 | 1 | |
| AC-22 Audio | 9 | 8 | 1 | |
| AC-23 Battery | 5 | 4 | 1 | |
| AC-24 Compact feed sheet | 5 | 5 | 0 | |
| AC-25 Journal merge | 5 | 5 | 0 | |
| AC-26 Saves | 2 | 2 | 0 | |
| **Total** | **102** | **95** | **7** | |

Plus the 4 carried rows and BT-12 (§3A.14). AC-17.5 counts as auto with a capture part, and AC-15.7 as capture plus review. AC-19.13, AC-20.9 and AC-22.9 have a device part in MAN-D.

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
| EC-25 | Kills the app during the discard ceremony | **Phase 4 (the discard commits at "Discard", D-059):** (a) the mold sheet or the confirmation is showing; (b) right after "Discard", on the memorial or restart page; (c) during naming after "Start again"; (d) after the new name is confirmed. | (a) Nothing was saved: the moldy jar, no memorial, and the flow runs again. (b) and (c) The relaunch is the empty jar (AC-18.3), never the moldy jar, with exactly one memorial; "Start again" works from there. (d) The new starter, with exactly one memorial. Never two starters, never a lost memorial. The slice's version (discard and adopt as one atomic save at naming, D-047) is proved by `int/ac04::ec_25_discard_survives_a_kill_and_leaves_one_memorial` and `::ec_25_kill_before_the_name_is_confirmed_keeps_the_moldy_jar`; the second one flips to (c) in the commit that lands T1's empty jar. | auto |
| EC-26 | Takes a phone call during the B6 demo | Background mid-demo for 2 days, then return | The demo restarts or resumes on its copy. The adopted starter is fresh at the moment of naming (AC-13.5), not 2 days old, and no catch-up summary shows for an unnamed starter. | auto |
| EC-27 | Parks it in the proofing box at 30 °C and leaves | 14 days | The fastest legal mold. Warning to mold ≥ 59 h (AC-15.4). The memorial's `{days}` is ≥ 6 and the plural is right. With notifications on, exactly one warning notification was scheduled, at the unhealthy onset (AC-20.2). | auto |
| EC-28 | Turns on the notification, then keeps the starter in the fridge for a month | Background in the fridge | Nothing is scheduled (AC-20.6), because the fridge never reaches `unhealthy` inside the 14-day cap. Out of the fridge and back to the counter, the next background schedules it. | auto |
| EC-29 | Switches flour or hydration at every feed | 20 feeds alternating rye 60% and white 125% | Every feed accepted (AC-14.1). `flour_mix` shares sum to 1 and `culture_hydration` stays in 40 to 200 (PROP-03). The surface and consistency words follow the main flour. `sensitive` can win the trait, and nothing else changes in the sim (AC-16.2). | auto |
| EC-30 | Leaves the empty jar for a year | Relaunch at +365 d | Still the empty jar, no catch-up, no summary, no events, no crash, no notification (AC-18.3). "Start again" gives a fresh starter at now. | auto |
| EC-31 | Renames the starter 200 times | `RenameAction` 200 times | Each applies. The journal stays inside its caps (SAVE-13), and the old names never appear on the main screen. | auto |
| EC-32 | Skips onboarding, then discards on day one | Skip path, then force mold with F3 | The first restart uses `first_restart` (the cold spare), and the unlocks from the skip path survive (progression §3: unlocks are per player). | auto |

---

## 6. What can't be automated, with manual checklists

| Area | Why not automated | Covered by |
|---|---|---|
| Beauty of the jar, glass and starter | Taste. Pixel diffs only catch regressions. | MAN-01, MAN-02 vs. `art/previews/jar_v0_<state>.png` for the 8 rendered states (`freshly_fed`, `active`, `at_peak`, `collapsing`, `hungry`, `dormant`, `unhealthy`, `moldy`). The other 3 states are checked against their UX §11 jar cues. |
| "Alive but calm" motion | AC-02.1 is only a proxy | MAN-02 |
| Gesture feel, one-handed reach | Needs a hand on a real screen | MAN-03, A11Y-07 |
| Haptics | Not produced in a headless run. The hook's calls are tested (AC-21.2, AC-21.3); the feel needs a phone | MAN-D4 on the iPhone 13 Pro (D-058, D-059) |
| Sound | Headless audio is a dummy driver. Files and routing are tested (AC-22); the mix needs ears | MAN-D5 |
| Smell moment delight | Taste | MAN-07 |
| Copy tone | Taste | MAN-09 (narrative), scientist safety sign-off |
| Screen readers | Dropped (D-055) | none |
| Release-build behavior | Needs a release export | CLK-13, release smoke test (Phase 5) |
| Real frame time, thermals, battery | Needs a phone. Now the iPhone 13 Pro, labeled "iPhone 13 Pro" (D-058) | MAN-D7, PERF-05, PERF-08 |
| A real notification | Needs the iOS plugin and the phone (D-057) | MAN-D6 |

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

### Slice play session (Phase 3 exit, D-046)

These are the checklists the user follows when playing the slice on the Mac and on the Android emulator. Tick each box per platform: **M** (Mac, Mobile renderer), **C** (Mac, Compatibility renderer), **A** (Android emulator). For any fail, note what you saw, the platform and the time, and send it to the director.

Timings and smoothness on the Mac and the emulator are estimates (D-004). The emulator draws with a software GPU, so judge looks there, not speed.

Not in the slice, so not checked here: the "Try inspecting the surface" button and the empty jar (both Phase 4, D-047), the window sill and proofing box, other flours, and the guided onboarding.

#### MAN-S0 Run steps

Run all commands from the repo root.

**Mac (windowed, phone-sized):**
1. Import once after any pull: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import`
2. Play (Mobile renderer): `/Applications/Godot.app/Contents/MacOS/Godot --path . res://src/main/main.tscn`
3. Play (Compatibility renderer): add `--rendering-method gl_compatibility` before `res://`.
4. **F3** shows and hides the dev overlay. Its first row sets the time speed (1x, 60x, 600x, 3600x). Its second row jumps ahead as if the app had been closed that long (+1 h, +1 d, +3 d), so the time-lapse and the return summary play.
   - From the first use, the overlay's status line says "SANDBOX SAVE". That run saves to a separate sandbox folder, and your real game is untouched.
   - A normal launch afterwards is your real game again. To go back to the sandbox, launch with `-- --time-scale=60` at the end.
5. Start in a given state: add `-- --fixture=res://tests/unit/ui/fixtures/<state>.json` at the end. Fixture runs save to their own folder, too. States: `freshly_fed`, `developing`, `active`, `near_peak`, `at_peak`, `collapsing`, `hungry`, `dormant_cold`, `dormant_starved`, `recovering`, `unhealthy`, `moldy`.
6. The real save lives in `~/Library/Application Support/Godot/app_userdata/Sourdough/saves/`. To start a brand-new game, quit and move that `saves` folder to the Trash yourself.

**Android emulator:**
1. `tools/build/export_android_debug.sh --run`. It boots the `Pixel_9` emulator if needed, installs a fresh debug build (no save) and launches it.
2. Close the app: swipe it away from the recent-apps view.
3. Move time: open Settings, then System, then Date & time. Turn off "Set time automatically", then change the date or time. If F3 doesn't reach the emulator, use this instead of the overlay.
4. The emulator's back button is Android back.

The iOS simulator can't draw this project (D-044), so it isn't part of this session.

- [ ] M C A: The game starts with no error dialog, and the jar shows within a few seconds.
- [ ] M A: A first launch shows M.'s note, then naming with a suggested name and "Suggest another". The name you pick shows at the top.
- [ ] M: After an F3 session, a normal launch shows your real starter as you left it, not the sandbox one.

#### MAN-S1 Feel, motion and the time-lapse

- [ ] M C A: Left alone, the starter looks alive but calm: slow breathing and bubbles, no flicker, no swimming texture.
- [ ] M A: Drag to turn the jar. It stops softly near ±70°, like a rubber band, not a wall. Pinch (trackpad or two fingers) zooms smoothly, with no jump when the second finger lands.
- [ ] M A: Start a drag on the jar, slide over the action bar and let go there. The jar keeps turning, and no button fires.
- [ ] M A: Double-tap (double-click) resets the view smoothly.
- [ ] M A: Turn the jar, then leave it alone for 20 s. The view eases back home over about a second and a half.
- [ ] M C A: Feed, then Mix (2 taps) reuses last time's choices, and "Same as last time" shows. The feed plays (about 6 s the first time, shorter after). There's no Skip the first time and there is one after. The rubber band snaps on at the new level.
- [ ] M C A: Feed while it's still rising. A gentle line says it'll take longer to peak, and Mix still works.
- [ ] M C A: After feeding, the forecast is in words ("around dinner time"), never a countdown or numbers.
- [ ] M C A: Open Place. Each place card shows its temperature. Moving happens at once, with no "are you sure". The jar moves and the light changes, with nothing popping.
- [ ] M C: Feed, then F3 "+1 d". A short time-lapse plays (3 to 6 s), and a tap skips it. Then the "while you were away" card shows at most 3 lines, with no blame.
- [ ] A: The same with the emulator's date moved 1 day ahead.
- [ ] M A: Close and reopen within a few minutes. No time-lapse and no "while you were away" card.

#### MAN-S2 The moldy flow (F3)

Start from your named starter. Feed it, open F3, and use "+3 d" three times (once more if it isn't moldy yet).

- [ ] M C: The first "+3 d" gives a hungry, sour starter. Hooch and sharp smells are called normal hunger, never danger.
- [ ] M C: The second one brings the warning signs card. "Look first" is the main button and shows the surface. "Feed it now" is also offered. Don't feed.
- [ ] M C: When mold appears, the camera moves close to it. The card has no close X and says to discard it. It never says "scrape", "skim" or "safe".
- [ ] M C: The mold looks clearly like mold at phone size, but not gross. There's no pink, orange or red anywhere except on the moldy starter (D-026).
- [ ] M C: "Not yet" closes the card. A discard card then stays above the action bar, and a tap can't dismiss it.
- [ ] M C: Feed, Smell and Place each show a small lock badge, not just a gray color. Tapping each explains why.
- [ ] M C: Inspect and Journal still work. Inspect, then Surface, shows the fuzz and says to discard it.
- [ ] M C: Quit, then relaunch into the sandbox (`-- --time-scale=60`). It's still moldy, and the same cards show.
- [ ] M C: Discard takes 2 taps ("Discard it", then "Discard"). The memorial page shows the old name and never moves on by itself.
- [ ] M C: The next page offers only "Start again" (no empty jar, D-047). Naming offers "Pick for me", which names the new starter in one tap.
- [ ] M C: Run it once more, but quit during naming. Relaunch into the sandbox: it's the moldy jar again, with no memorial, and the flow starts over (D-047).
- [ ] M C: Finish the flow, then quit and relaunch into the sandbox. There's exactly one memorial in the journal, the old entries are still there, and the new starter is calm. A starter fresh from the fridge says it's cold, not sick.

#### MAN-S3 Smell, inspect, status and day and night

- [ ] M C A: Smell is 1 tap. A short moment plays (camera nudge, wisps, about 1 s), then a card with a smell word and what it means. There are no numbers.
- [ ] M C: Smell twice in a row. The same line shows both times.
- [ ] M C: The meaning line shows the first three times a smell appears. After that it's one tap away, except for a musty smell, which always shows it.
- [ ] M C: On the `hungry` fixture, the smell reads as hunger (tangy, alcohol or nail-polish remover) and says it's normal and to feed it. Nothing says danger.
- [ ] M C: On the `unhealthy` fixture, "musty" is listed first and called a warning sign.
- [ ] M C A: Inspect Height, Bubbles and Surface. Each moves the camera in about half a second and shows a card within 3 s, 2 taps from the main screen. Bubbles looks from the rim, and Surface looks down into the jar. There's no Consistency or Development choice.
- [ ] M C: The words on each card match what the jar shows (a dome when it says domed, a layer of liquid when it says hooch).
- [ ] M C: Tap the status pill. A short card explains the state, and "Show me" moves the camera to what to look at.
- [ ] M C: Day and night: set F3 to 600x and watch an evening come (a few real minutes). The kitchen light and the screen colors fade to night together, and back in the morning. Text stays easy to read, and the status keeps its icon and word.
- [ ] M: Play once in a real evening at 1x. It looks like evening without the overlay.

#### MAN-S4 Reduce motion and the text sizes

- [ ] M C A: Settings, then reduce motion on. The camera stops gliding after a drag and doesn't drift back home. Sheets and cards appear without sliding, and the little bubble pops stop. The starter itself still rises, bubbles and settles.
- [ ] M C: When the status changes on screen, the pill crossfades with a small pulse. With reduce motion, only the crossfade.
- [ ] M C: With reduce motion on, a return shows a before picture and an after picture instead of the time-lapse. With the time-lapse setting off, there's neither.
- [ ] M C A: Text size at 100%, 125% and 150%. On the main screen, every sheet, every card and every toast, no text is cut off or overlapping, and every button is still easy to hit. The jar still fills at least half the screen.
- [ ] A: Haptics off: no vibration through a whole feed.
- [ ] M: Turn on grayscale (System Settings, then Accessibility, then Display, then Color filters). Every status can still be told apart by its icon and word, at day and at night.

#### MAN-S5 Quit, kill and come back

- [ ] M: Feed, then quit at once (Cmd+Q). Reopen: the feed is there once, in the jar and the journal.
- [ ] M: Feed, then force quit at once (Activity Monitor, then Force Quit). Reopen: the feed is there once.
- [ ] A: Feed, then swipe the app away. Reopen: the feed is there once.
- [ ] A: With a sheet open, Android back closes the sheet. With no sheet, back closes the app, and reopening shows the latest state.
- [ ] A: Set the date 1 hour back and reopen. Nothing replays, and the starter is unchanged. Set it forward again and play on normally.
- [ ] A: After a long absence, the action buttons are briefly unavailable while the game catches up, with no message, then come back (D-050).
- [ ] M A: Come back with the warning signs waiting (Android: on the counter, date 6 days ahead; Mac: F3 "+3 d" twice). There's no separate "while you were away" card. Its lines sit at the top of the warning card.
- [ ] A: Leave it on the counter, set the date 16 days ahead and reopen. The card says it was a long time. The time-lapse shows the warning signs, then mold and the discard path. No blame.
- [ ] A: Do the same with the starter in the fridge. It's sleepy and fine, never moldy, and one or two feeds wake it.

**Phase 4 note (D-054):** every **A** box above moves to the Android phase. Their iOS versions are in MAN-D.

### iPhone play session (Phase 4, D-058)

The user's iPhone 13 Pro (390 × 844 pt, iOS 27.2.1). Every number here is a real device number: label it "iPhone 13 Pro" with the build's commit, and it replaces a Mac estimate where one exists (D-058). For any fail, note what you saw and the time, and send it to the director.

**Not reachable on the phone yet:** the dev overlay opens with F3, and a phone has no F3 key. QA asked T1 for a touch way to open it in debug builds. Until it lands, skip the items marked **F3**.

#### MAN-D0 Run steps

1. One-time setup, which only you can do, is in the board's "Waiting on the user": sign in to Xcode, turn on Developer Mode, and trust the developer after the first install.
2. Build and install with t1-toolchain's device script (its name and flags will be in `tools/build/README.md`). Keep the phone unlocked and nearby.
3. To read the game's log: in Xcode, Window, then Devices and Simulators, select the phone, then Open Console. Or use the script's own log output.
4. For a true first launch, delete the app from the home screen (this deletes its save), then install again.

#### MAN-D1 Install, first launch and the renderer line

- [ ] The build installs, the icon appears, and the first launch shows the jar within a few seconds with no error.
- [ ] The log's renderer line names **Metal** and **Forward Mobile**, never OpenGL or Compatibility. Copy the exact line into your report.
- [ ] From launch to the main screen, the log has no "SCRIPT ERROR" or "ERROR:" line. Copy any you see.
- [ ] The top plate clears the notch, the action bar clears the home indicator, and no text is cut off.

#### MAN-D2 Onboarding

- [ ] The guided start comes in this order: M.'s note and the jar, a prompt to turn and zoom, a smell, a look at the bubbles, the sped-up rise, naming, the first feed with "When will you check on it next?", then a line about the fridge.
- [ ] The sped-up rise takes about one and a half to two minutes and stops at the peak. It looks like a real rise, only faster.
- [ ] Coach marks come one at a time, are short and easy to read, and the ring clearly shows what to touch.
- [ ] Lock the phone during the sped-up rise, wait a minute, unlock. No crash, and the start carries on or restarts calmly.
- [ ] Delete and reinstall, then pick "I've kept a starter before". The turn, smell, bubbles and sped-up lessons are skipped. Naming and the "When will you check" question still come, and all flours, water choices, 5 places and 5 inspect choices are open at once.

#### MAN-D3 Feel

- [ ] Left alone, the starter looks alive but calm, with no flicker or stutter.
- [ ] Turning the jar with either thumb is comfortable, and it stops softly near the sides. Pinch zoom is smooth, with no jump when the second finger lands. Double-tap resets the view.
- [ ] Start a drag on the jar and slide over the action bar. The jar keeps turning, and no button fires.
- [ ] Feed, then Mix (2 taps). The feed plays smoothly the whole way, never choppy. At the standard text size, the feed sheet shows every choice without scrolling.
- [ ] Smell, and every Inspect choice (Consistency and Development once open). Camera moves are smooth, and cards appear promptly.
- [ ] Move to every place, including the window sill and the proofing box. The jar moves and the light changes, with nothing popping. The proofing box's minus and plus buttons are easy to hit.
- [ ] Text size Largest: nothing is cut off on the main screen, the feed and place sheets, or any card.
- [ ] Reduce motion on: no camera glide, sheets fade instead of sliding, and the starter still rises.
- [ ] Discard a moldy starter (**F3**), then pick "Not today". The empty jar is calm, nothing nags, and "Start again" works.

#### MAN-D4 Haptics

- [ ] Haptics on: the feed has small taps on its steps and a firmer one when the band snaps on. Every pulse is short and soft, never a long buzz.
- [ ] Smell: three soft swells as it "breathes in".
- [ ] Poke the starter: one light tap. Pinch to the zoom limit: one light tick.
- [ ] Haptics off in Settings: no vibration at all through a feed, a smell, pokes and a pinch to the limit.
- [ ] Your verdict for D-059, in one line: are the built-in pulses good enough, or should we ask for an iOS haptics plugin?

#### MAN-D5 Sound

- [ ] Sound on, ringer on, medium volume: the room tone is quiet, and pops, lid, pour and stir match what you see. Nothing is loud, harsh or crackly.
- [ ] Sound off in Settings: silence through a feed and a smell.
- [ ] Each lower volume step is quieter, and the lowest is silent.
- [ ] Flip the ring/silent switch to silent. Write down whether the game goes quiet.
- [ ] Play music in another app, then open the game. Write down whether the music keeps playing.
- [ ] Swipe home while a sound plays: it stops. Back in the game, the room tone returns.

#### MAN-D6 Day and night, a real absence, the notification

- [ ] Play once in daylight and once in the evening at normal speed. The kitchen looks like day and then evening, text stays easy to read, and the status keeps its icon and word.
- [ ] Feed, then swipe home (don't close the app). Come back within an hour: no time-lapse and no "while you were away". Come back after an hour or more: a short time-lapse (a tap skips it) and at most 3 lines, with no blame. The action buttons may be briefly unavailable while it catches up.
- [ ] Feed, then swipe the app away in the app switcher at once. Reopen: the feed is there once, in the jar and the journal (AC-11.3).
- [ ] Once the notification is wired: turn it on in Settings, and the permission prompt shows once. Close the app with the starter on the counter. The warning arrives about when the starter would show warning signs (4 to 5 days at the counter, so use **F3**), never between 22:00 and 08:00. Tapping it opens the game.
- [ ] With the notification off in Settings, nothing ever arrives.

#### MAN-D7 Numbers to record

Label each "iPhone 13 Pro" with the commit.

| What | How | Target | Result |
|---|---|---|---|
| Launch to the first jar frame | Stopwatch from tapping the icon to the jar. 3 cold launches (swipe the app away in between), take the middle one | ≤ 2 s (PERF-05, AC-09.7) | |
| Frame rate while turning the jar | Xcode's FPS gauge (Debug navigator), or the F3 frame line once T1 adds it. 60 s of turning | a steady 60 (PERF-01) | |
| CPU and GPU time per frame while turning | Xcode's GPU report | CPU ≤ 8 ms, GPU ≤ 10 ms (PERF-01) | |
| Frame rate with no touch | After 3 s idle on the main screen | 30 (AC-23.1) | |
| Frame rate during the feed with no touch | Same gauge | 60 (AC-23.2) | |
| 14-day catch-up | The catch-up log line (asked of T1) after an **F3** jump | recorded (Mac estimate budget 250 ms) | |
| The notification forecast on background | Its log line (asked of T1) | recorded (AC-20.9) | |
| Memory | Xcode's memory gauge, highest value in a session | recorded | |
| Battery, 10 min idle on the main screen | Battery % before and after, Xcode's Energy Impact, warm or not | recorded (PERF-08, AC-23.5) | |
| Heat after 15 min of play | Is the phone warm to the touch? | not hot | |

---

## 7. Performance

**Labeling rule:** every reported number says "Mac estimate", "simulator estimate" or "iPhone 13 Pro" (a real device number, D-058). From Phase 4 the user's iPhone 13 Pro numbers replace Mac estimates where both exist (MAN-D7).

**PERF-03 under load (Phase 4, measured 2026-11-27, M4, Mac estimate):** with about ten other agents' Godot processes running (load average 7 to 14), the first strict gate failed PERF-03 with a median of 262.4 ms (runs 229.9 to 308.7 ms), and a run of `tests/perf/` alone with `--verbose` gave 316.8 ms and failed PERF-04 too (21.6 ms median, min 6.19). The full suite passed both an hour later in the same worktree with no code change. The code didn't regress; the machine was busy. Proposal OD-26.

The Mac and simulators use **regression gates**: fail on a slowdown of more than 20% against the approved baseline for the same machine and renderer. Absolute phone targets (architecture §11) are checked on a device.

| ID | Metric | Target | Where |
|---|---|---|---|
| PERF-01 | Frame while interacting (60 s scripted orbit) | Device: 60 fps, CPU ≤ 8 ms, GPU ≤ 10 ms (2021 mid-range). Mac and simulator: regression gate. Mac GPU numbers run only with `--rendering-driver vulkan` (MoltenVK). In 4.7.2, `viewport_get_measured_render_time_gpu` returns 0 on Metal, opengl3 and ANGLE. Compatibility uses uncapped frame time as its upper bound. | capture |
| PERF-01b | `PerfLog` on a driver that can't measure GPU time (Metal, Compatibility) | `gpu_ms` is written empty ("not measured"), never 0, and gates skip it. A logged 0 would silently pass every GPU gate. | auto |
| PERF-02 | Idle frame cap | `Engine.max_fps` = 30 after 3 s with no touch and no tween. Back to 60 within 1 frame of `interaction_started`. | auto (scripted, windowed) |
| PERF-03 | 14-day catch-up (20,160 steps), synchronous, the full rule registry | Median of 5 runs ≤ 250 ms, Mac estimate (D-051). `tests/perf/test_perf_catch_up.gd` prints every run. Measured 2026-11-27 (M4, other agents' Godot processes running, load average about 4): medians 227.0 to 241.5 ms over 7 gate runs, single runs 225.9 to 394.2 ms. Headroom 8.5 to 23 ms (3 to 9%). The median absorbs a single slow run; heavier load could still turn it red. Report the spread rather than raising the budget. The app runs long catch-ups on a worker thread (D-050), so this is the budget, not a frame hitch. | auto (timed) |
| PERF-04 | Save | ≤ 128 KB, write < 10 ms (Mac estimate). `tests/perf/test_perf_save.gd` pads a real save to the budget and times `SaveStore.save()`, median of 5, in a fresh process. Measured 2026-11-27 (M4): median 5.51 ms for 130,628 bytes. | auto (timed) |
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
| A11Y-06 | Haptics off: 0 calls to `Input.vibrate_handheld` during a full feed flow | auto (spy on T1's haptics hook): AC-21.2 |
| A11Y-07 | Reach: the five actions are in the UX §5 thumb zone on the 17 Pro Max | capture |
| A11Y-08 | Every interactive Control has an `accessibility_name` through `tr()`, ≤ 40 characters | **frozen (D-055):** the existing check stays for existing Controls. No new work for Phase 4 Controls |
| A11Y-09 | VoiceOver and TalkBack: read the status, use the five actions, finish a feed | **dropped (D-055)** |
| A11Y-10 | No flashing above 3 per second (WCAG 2.3.1), including bubble pops and VFX | review |
| A11Y-11 | Gestures are optional: every 3D action (reset, inspect framing) has a button path, and nothing requires a hold or multiple fingers | auto (UX §16) |
| A11Y-12 | Nothing auto-confirms. Cards stay until dismissed when "Keep messages on screen" is on | auto |
| A11Y-13 | An unguided task with a new player: "Check how your starter is doing and feed it", done without help in under 3 min | playtest (Phase 3) |

---

## 9. Device and screen matrix (the iPhone 13 Pro now, the rest in Phase 5)

**The real device (Phase 4, D-058).** The user's iPhone 13 Pro, iOS 27.2.1, 390 × 844 pt (the same size as the 17e row below), notch, ProMotion. It runs MAN-D0 to MAN-D7, and its numbers are labeled "iPhone 13 Pro". The safe-area insets (expected top 47, bottom 34) are read from the device in MAN-D1, not assumed.

**iOS simulators.** They can't render this project (D-044), so they are only for boot and log checks. Verified installed with `xcrun simctl list devicetypes` (Xcode 27.2): iPhone SE (3rd generation), iPhone 17e, 17, 17 Pro and 17 Pro Max. The device-type plists don't contain screen sizes (checked), so the sizes below come from UX §2, and the 17e is marked assumed by UX. Confirm each from the booted simulator in Phase 2 and record it here.

| Device | Points (UX §2) | Why | Runs |
|---|---|---|---|
| iPhone SE (3rd gen) | 375 × 667, home button | Smallest iOS. UX lists it as supported (OD-14). | AC-12.1, AC-12.2 (150%), AC-12.6, AC-02.5 |
| iPhone 17e | 390 × 844 (assumed) | Smallest current iPhone | AC-12.6, captures |
| iPhone 17 Pro | 402 × 874 | Reference size, ProMotion | All capture rows, PERF-01 (simulator estimate) |
| iPhone 17 Pro Max | 440 × 956 | Largest, hardest reach | A11Y-07, MAN-03, AC-12.6 |

**Android emulator: Android phase (D-054).** Nothing below runs until iOS is done. The 360 × 640 and 411 × 914 headless layout profiles still run in every gate (D-054). Before that phase, the SDK still lacks platform 36, build-tools 36.1.0 and the NDK (OD-10). Verify the profiles against the installed AVDs.

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

## 10. Definition of done (Phases 2 to 4)

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

**Phase 3 features** are also done only when:
- every AC row the feature touches is **covered** or **manual only** in §3.13, and the table is updated in the same commit
- an integration test drives the feature through `Session.apply()` or the lifecycle calls, not only through its own unit
- its MAN-S item has been run on the Mac (Mobile and Compatibility) and, for anything touch or save related, on the Android emulator

**Phase 3 exit:**
- Every row in §3.13 is covered or manual only, or has a written waiver from the director.
- `tests/run.sh --strict` is green on a fresh clone.
- The user has run MAN-S0 to MAN-S5 on the Mac and the Android emulator (D-046).

**Phase 4 features** are also done only when:
- every AC-13 to AC-26 row the feature touches is covered or manual only in §3A.15, updated in the same commit
- its tests land in the same commit as the code they test, so `tests/run.sh --strict` never sees a skip
- anything on the device (feel, haptics, sound, frame time, battery, the notification) has its MAN-D item run on the iPhone 13 Pro, with the numbers labeled
- no new Android-only work (D-054) and no new screen-reader work (D-055)

**Phase 4 exit (D-059):**
- Every row in §3A is covered or manual only, or has a written waiver from the director. The 4 carried rows (§3A.14) too.
- `tests/run.sh --strict` is green on a fresh clone, with the R-0 import note quoted if a retry happened.
- The build runs on the iPhone 13 Pro, and the user has run MAN-D0 to MAN-D7.

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
| Integration harness (Phase 3) | `SliceHarness` and `SliceCase` in `tests/integration/` (§2.6) | AC-04 to AC-11 |
| Phase 3 contracts (`p3_contracts`, agreed with T1 2026-11-27) | `Session.shutdown()` (debug only, so tests can boot the real `Main` again). `Session.get_return_summary()`, a pure `ReturnSummary.build()` with keys and args, no `tr()`. `Session.last_feed_action()`. `event_raised` once per event, `event_withdrawn(uid)` when stale (the hold is T3's EventPresenter). `NightFade.factor()` and `NightFade.at_unix()`, both pure. `is_time_traveling()`: a debug time scale saves to `<save dir>_time_travel`, never the real save. `is_first_run()` means "no name yet", plus `recovered_this_launch()`. The journal is in uid order. | AC-03.10, AC-05.3, AC-09.2 to 09.4, AC-10.8, CLK-06, 07, MAN-S0 |
| Phase 4 contracts (asked of T1 2026-11-27, names TBD-T1) | A `Milestones` id for the contracts. A stand-in `Notifier` backend that records `schedule` and `cancel`, and a pure warning-time function from the state, environment, now and offset. A haptics hook with an injectable sink that records the level and time. The B1 start state as a named preset. How the save marks the empty jar. A touch way to open the dev overlay, and a debug log line per catch-up and per forecast. | AC-13, AC-18, AC-20, AC-21, MAN-D |

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
| OD-19 | **A debug time scale wrote saves ahead of the real clock** (QA, from reading `debug_clock.gd` and `start()`). After 10 min at `--time-scale=60`, the save sat about 10 h in the future. The next normal launch froze the starter for up to 6 h, or re-anchored. | t1-sim-core | **Resolved in `p3_contracts`**: the real save is written once at real time, then scaled runs save to `<save dir>_time_travel`. `int/p3_contracts::time_travel_never_touches_the_real_save` proves it with a real `DebugClock`: after the switch, an 8 h `debug_advance` and a feed leave the real `save.json` byte-identical, and the next normal launch neither re-anchors nor catches up more than 5 steps. MAN-S0 checks it by hand. The sandbox folder outlives the run, so a later `--time-scale` launch starts from its future-dated save (dev only). |
| OD-20 | Tests could boot the real `Main` only once per process (the autoload's `_booted` latches) | t1-sim-core | **Resolved in `p3_contracts`**: `Session.shutdown()`, debug only. Unblocks AC-03.2b, 03.10 and 03.11. |
| OD-21 | After every save file is bad, the new starter had no name and `is_first_run()` was false | t1-sim-core, t3-ui | **Resolved in `p3_contracts`**: `is_first_run()` means "no name yet", so T3 runs M.'s note and naming. `recovered_this_launch()` drives the calm notice (OD-3 copy still needed). QA's AC-11 total-loss test flips its first-run assertion in the merge that brings the contracts. |
| OD-22 | 50 place flips in a minute write 50 journal lines (measured). EC-10 says "no spam". The sim is untouched, so this is about the journal only. | game-designer, T1 | **In T1's Phase 4 contracts (D-059).** AC-25 tests the merge; the window length is still TBD-GD. |
| OD-23 | When to freeze the first migration fixture (SAVE-11, AC-11.4) | director | Proposal: freeze `tests/fixtures/saves/v1_*.json` from the build the user plays at the Phase 3 exit. That is the first save a person keeps, and later schema changes must migrate it. |
| OD-24 | A journal entry made while the clock is held (clock set back under 6 h) carries the wall time, which is earlier than older entries. `int/ac09::clock_back_holds_and_a_feed_applies_at_the_anchor` asserts it: an inspect at T0 + 2 h, the clock back to T0 + 1 h, then a feed stamped T0 + 1 h with the later uid. | t1-sim-core, t3-ui | **Resolved**: the journal's order is uid order, never `at_unix` (stated in T1's journal API). T3 must not sort by time. |
| OD-18 | **A JSON save round trip is not bit-exact in 4.7.2.** The number parser isn't correctly rounded: 0.00038268223404884337 reads back as 0.00038268223404884, and 1.9469610637576158 (a `peak_rise` from T1's Session) as 1.946961063757616. QA measured 29,798 of 100,000 random doubles (1e-6 to 1e3) coming back 1 ulp off. `String.to_float()` and `var_to_str` are no better. `var_to_bytes` is exact. ADR-005's evidence (1/3) has no leading zeros, so it passed. A Session reloaded from its own save differs from the in-memory one (seen: `food` 1 ulp). That breaks SAVE-01 deep-equal, PROP-02 "byte-identical with a save and load midway" and the exactness of PROP-01. | tech-architect | **Resolved: option (a).** Every float in the payload is a 16-char hex string of its IEEE-754 bytes (`encode_double`, then `hex_encode()`, little-endian; data-models §1, §9.2, ADR-005). PROP-01, PROP-02 and SAVE-01 stay exact with no tolerance. Tests: the encoding (`test_save_engine_facts.gd`, runs now) and the real save path (`test_save_payload.gd`: a reload is bit-exact, and the stored payload has no decimal numbers; waits for m4_save and m5_catchup). |
| OD-25 | **Hydration presets are rejected today** (AC-14.1). `FeedAction.from_ratio(f, f, flour, h)` keeps `w = f`, so 1:1:1 at 60% is 50 / 50 / 30 g (130 g) and at 125% 162.5 g, and `validate` rejects all 6 non-100% presets with `REASON_MASS`. QA ran a probe over the 9 combinations. | T1, game-designer | Sent to T1 2026-11-27. Proposal: keep derives from `1 + f + f × h / 100`, which keeps every total in 147 to 152 g and keeps V6's inoculum fraction. AC-14.1 lists the grams. |
| OD-26 | **PERF-03 is flaky under machine load.** With about ten agents' Godot processes running, the median went to 262 ms, then 317 ms with `--verbose`, against 250 ms, with no code change (§7). T4's 8 rules will add cost too. | director | Keep the 250 ms budget, but gate on the **fastest of 7 runs** (load only ever adds time, so the minimum tracks the code), and print the median and spread. Or run `tests/perf/` as its own step only when the machine is quiet. QA changes neither without the director's OK. |
| OD-27 | **The idle frame cap slows non-camera animations** (AC-23.2). Only `OrbitCamera` emits `interaction_started` and `interaction_ended`, and `Session.start()` arms the 3 s idle timer at boot, so sheets, the feed sequence, the smell moment, cards and the time-lapse run at 30 fps unless the camera moved in the last 3 s. Found by reading the code. | T2, tech-architect | Every tween owner (sheets, feed sequence, smell moment, time-lapse, demo) raises a "busy" count on Bus while it runs, and the cap drops only when the count is 0 and 3 s have passed. QA tests it in AC-23.2. |
| OD-28 | A warning notification that falls in quiet hours: move it later (08:00) or earlier (before 22:00)? | game-designer | Later. Earlier would say "is showing warning signs" before it is, and warning to mold is ≥ 59 h anywhere, so 10 h later is safe (AC-20.5). |
| OD-29 | Unlocks for a save made before Phase 4 (the user's own Phase 3 save, `v1_slice.json`) | game-designer, T1 | Derive them at load from maturity and history, so a player already past `steady` gets the `steady` unlocks at once (AC-26.2). |
| OD-30 | `src/view/orbit_camera.gd` calls `Input.vibrate_handheld(10, 0.3)` directly for the pinch-limit tick, on Android only, ignoring the haptics setting | T2 (through T1's hook) | Route it through the hook. AC-21.1's lint fails on any direct call outside the hook. S3 today (iOS gets no tick), S2 in the Android phase. |
| OD-31 | iOS audio session: should the silent switch mute the game, and should other apps' music keep playing? | sound-designer, T2 | The ambient category: it follows the silent switch and mixes with other audio, as a calm game should. AC-22.9 and MAN-D5. |
| OD-32 | The "richer journal" (mvp-scope P1: rise sketches, stage snapshots, name and trait pages) is not in D-059's work list | director | Either list it for T3 in Phase 4 or move it to P2 in `mvp-scope.md`. No AC rows until then. |
| OD-33 | The F3 dev overlay can't be opened on a phone (no F3 key), and the device has no catch-up or forecast timing in its log | T1 | Asked 2026-11-27: a touch way to open it in debug builds, plus one debug log line per catch-up and per notification forecast. MAN-D marks the F3 items. |
| OD-34 | **"6 ObjectDB instances were leaked at exit": found.** Only `tests/unit/view/test_touch_gestures.gd` leaks (QA ran every folder, then every file, with `--verbose`). The test holds `g: TouchGestures`, and `before_each` connects g's signals to lambdas that write the test's members, so the two hold each other. | T2 | Add `func after_each() -> void: g = null`. Verified on a scratch copy: 5 passed, 0 leaked, and the 3 "resources still in use" are gone. Then QA proposes that `run.sh --strict` fails on any "leaked at exit" line, so a new leak shows up in the commit that adds it. |
| OD-35 | `first_acetone` is "one-time per player" in events-catalog §4.1 and "One-time" in game-mechanics §7.4 | game-designer, narrative | AC-19.1 follows the catalog (per player, so it doesn't repeat for a new starter) unless told otherwise. |
| OD-36 | Spec v1.1 (scientist, 2026-11-27): `pleasantly_tangy` peaks at acid 0.80, was 0.72. `tests/property/test_smell_rules.gd` transcribes 0.72 | QA, T1 | QA changes its copy in the merge that brings T1's `SmellModel` change, so the gate never sees one without the other. The other v1.1 changes are AC-14.4, AC-16.1 and AC-17.4. |
| OD-37 | `mvp-scope.md` still says Godot 4.8 before any store release, and `roadmap.md` Phase 4 still lists the 4.8 upgrade and a screen-reader pass | director | Both are superseded by D-055. |
