# Architecture

Owner: `tech-architect`. Status: **draft v0, wave A** (2026-11-26). Engine: Godot 4.7.2, typed GDScript.
Related: [`data-models.md`](data-models.md) (every type named here), [`technical-decisions.md`](technical-decisions.md) (why, with evidence).

Claims about Godot 4.7.2 are marked **[ran]** (verified with a headless run in a scratch project, details in `technical-decisions.md`), **[src]** (read in the 4.7.2-stable source), or **[unverified]**.

## 1. Layers and the dependency rule

```
 src/ui ──────┐            src/view
   │          │               │
   │   (signals on Bus)  ◄────┤
   ▼          ▼               ▼
 src/core  (Session, Bus, Clock, SaveStore)
   │
   ▼
 src/sim   (pure: data + functions, no engine state)
```

| Layer | Path | Holds | May use | Must never |
|---|---|---|---|---|
| sim | `src/sim/` | Starter model, derivation, `VisualMapper`, smell, inspection, events (rules, scheduler, ledger), catch-up, forecast, journal entry type | `RefCounted`, `Resource` data classes, math, a `RandomNumberGenerator` **passed in** | Touch `Node`, `SceneTree`, `Time`, `OS`, `Engine`, `Input`, `FileAccess`, `load()`/`preload()` of assets, global `randi()`/`randf()`, `tr()` |
| core | `src/core/` | `GameSession` (autoload `Session`), `Bus` autoload, `Clock`, `SaveStore`, save codec and migrations, settings store, dev tools | sim, engine APIs | Reference anything in `src/ui` or `src/view` |
| view | `src/view/` | Jar scene, starter and glass shaders, camera rig, VFX, quality tier | sim types (read only), `Session` signals and getters, `Bus` | Mutate sim state, call `Sim.*` mutators, reference `src/ui` |
| ui | `src/ui/` | Theme, HUD, sheets, overlays, away summary | `Session.apply()` and getters, sim types (read only), `Bus`, `tr()` | Mutate sim state directly, reference `src/view` |

Rules:
1. **Only `Session.apply()` mutates the game state.** UI builds an action object and hands it over.
2. **ui and view never reference each other.** They talk only through `Bus` signals (§3.3). That is what lets two tracks build them in parallel.
3. sim strings are **keys**, never text. `tr()` happens in ui.
4. Enforced by `tests/unit/sim/test_sim_purity.gd`, which scans `src/sim/**/*.gd` for forbidden tokens (`Node`, `get_tree`, `Time.`, `OS.`, `Engine.`, `Input.`, `FileAccess`, `load(`, `randi(`, `randf(`, `tr(`) and fails on any hit.

## 2. Directory layout (Phase 2 target)

```
project.godot                      shared, owner: core track (§13)
src/
  main/        main.tscn, main.gd                    composes World + UI, adds dev nodes
  sim/         starter_state.gd  environment_state.gd  feed_action.gd  actions.gd
               flour_profile.gd  location_preset.gd  container_profile.gd  cover_profile.gd
               sim.gd  sim_constants.gd  state_deriver.gd  visual_params.gd  visual_mapper.gd
               starter_presets.gd  demo.gd
               smell_model.gd  inspection.gd  forecast.gd  catch_up.gd  catch_up_result.gd
               player_history.gd  journal_entry.gd  starter_snapshot.gd
  sim/events/  sim_event.gd  event_context.gd  event_rule.gd  event_rules.gd
               event_scheduler.gd  event_ledger.gd  return_summary.gd
  sim/events/rules/   one file per rule, rule_<event_id>.gd
  core/        game_session.gd  bus.gd  clock.gd  system_clock.gd  debug_clock.gd  fake_clock.gd
               time_policy.gd  save_store.gd  save_codec.gd  save_migrations.gd  settings_store.gd
  core/dev/    dev_flags.gd  perf_log.gd  capture.gd  dev_overlay.tscn
  view/        world.tscn  jar_view.gd  jar_geometry.gd  orbit_camera.gd  touch_gestures.gd
               quality_tier.gd  shaders/*.gdshader  vfx/
  ui/          ui_root.tscn  theme/sourdough_theme.tres  hud/  sheets/  overlays/  components/
  i18n/        en.csv (generated)  pending_core.csv  pending_view.csv  pending_ui.csv   (*.translation git-ignored)
data/
  flours/*.tres  locations/*.tres  containers/*.tres  covers/*.tres
assets/3d/     jar_v0.glb (art-director)
tests/         run_tests.gd  run.sh  lib/  fixtures/  scenarios/  unit/sim/  unit/core/  unit/view/  unit/ui/
spikes/        Phase 1 only, has .gdignore
```

## 3. Scene tree, autoloads, signals

### 3.1 Autoloads (exactly two)

| Order | Name | Script | class_name | Role |
|---|---|---|---|---|
| 1 | `Bus` | `src/core/bus.gd` | none | Signals only. The ui and view contract. No state. |
| 2 | `Session` | `src/core/game_session.gd` | `GameSession` | Owns the game state, the clock, the save store and the RNGs. The only mutator. |

- The autoload names differ from the `class_name` on purpose. A `class_name` equal to an autoload name is a conflict.
- `Clock`, `SaveStore` and the settings store are plain `RefCounted` objects that `Session` owns and receives through `setup()`. They are not autoloads, so tests construct them with fakes.
- Autoloads are added **after** a `-s` script's `_init` runs **[ran]**. Tests never use the autoload instances. They do `GameSession.new()` plus `setup(FakeClock.new(), SaveStore.new("user://test_tmp/<case>"))`.

### 3.2 Main scene tree

```
root
├─ Bus                      autoload
├─ Session                  autoload
└─ Main (Node, main.tscn)              core track
   ├─ World (Node3D, world.tscn)       view track
   │  ├─ WorldEnvironment, KeyLight, FillLight
   │  ├─ CameraRig (orbit_camera.gd) ─ Camera3D
   │  ├─ Jar (jar_v0.glb instance, jar_view.gd)
   │  └─ Vfx
   ├─ UI (CanvasLayer, layer 10, ui_root.tscn)   ui track
   │  ├─ Hud (top bar + bottom action bar)
   │  ├─ Sheets (sheet host)
   │  └─ Overlays (away summary, toasts, dialogs)
   └─ Dev (added at runtime, debug builds only: PerfLog, DevOverlay, Capture)
```

### 3.3 Signals

`Session` (core to ui and view):

| Signal | Payload | Fired when |
|---|---|---|
| `session_ready(summary: CatchUpResult)` | catch-up result, may be empty | After launch load and catch-up |
| `resumed(summary: CatchUpResult)` | same | After returning from background |
| `state_changed(snapshot: StarterSnapshot, visuals: VisualParams)` | display-ready values | Every grid step that changes them, and after every action |
| `action_applied(result: ActionResult)` | ok or rejected with a reason key | After `apply()` |
| `event_raised(event: SimEvent)` | one event | Scheduler releases an event for display |
| `journal_appended(entry: JournalEntry)` | one entry | After the journal grows |
| `save_failed(reason_key: StringName)` | key | Save error (UI shows a calm notice) |

`Bus` (ui to view, and back). Frozen in the Phase 2 contracts commit:

| Signal | Direction | Meaning |
|---|---|---|
| `sheet_opened(sheet_id: StringName)` / `sheet_closed(sheet_id)` | ui to view | Camera stops inertia, dims VFX |
| `camera_focus_requested(target: StringName)` | ui to view | `bubbles`, `surface`, `height`, `top`, `home`. Inspection moves the camera |
| `camera_focus_released()` | ui to view | Back to the player's orbit |
| `smell_moment_started()` / `smell_moment_finished()` | ui to view | Camera nudge, wisps |
| `feed_moment(step: StringName)` | ui to view | `discard`, `scoop`, `pour`, `stir` animations |
| `starter_tapped(where: StringName)` | view to ui | `starter`, `glass`. A tap on the jar |
| `interaction_started()` / `interaction_ended()` | both | Drives the frame cap (§11) |

## 4. Action pipeline

```
UI builds FeedAction ──► Session.apply(action) ──► ActionResult
   1. sync     advance the sim to grid(now) (same clock rules as resume, §5.3)
   2. validate action.validate(state, env) → reject with reason key, nothing changes
   3. mutate   Sim.apply_feed(state, feed, sim_rng) / env replace / no-op for smell, inspect
   4. derive   StateDeriver.derive(state, env) → state id + rise phase
   5. history  PlayerHistory.record_action(...)
   6. events   EventRules.evaluate(ctx, event_rng) → EventScheduler.admit(...) → ledger
   7. journal  JournalEntry appended
   8. save     SaveStore.save(...) (atomic, §6)
   9. signals  action_applied, state_changed, journal_appended, event_raised
  10. view     JarView: VisualMapper output → shader uniforms, tweened over 0.6 s
```

- Every player act is an action, including `smell` and `inspect`. They change no sim variable, but they write the journal, `PlayerHistory` (seen counts) and milestone events. The readout comes back in `ActionResult.readout`.
- Actions: `FeedAction`, `SetEnvironmentAction`, `SmellAction`, `InspectAction`, `RenameAction`, `AckEventAction`, `DiscardStarterAction` (after `moldy`: memorial, then a new starter). Fields are in `data-models.md`.
- Actions apply at `grid(now)`, the last 60 s grid point at or before now. The journal records the real `at_unix`.

## 5. Time, stepping and catch-up

### 5.1 Model
- Time is **Unix seconds, `int`**, UTC. Time zone and daylight saving don't touch the sim. Local time (`local_utc_offset_s`) is an input to quiet hours and calendar events only.
- The sim steps on a **fixed 60 s grid aligned to Unix time** (`grid(t) = t - posmod(t, 60)`). `StarterState.sim_time_unix` is always on the grid.
- Live play and offline catch-up call the same `Sim.step(state, env, 60)`. So one long catch-up and many short sessions take **identical steps** and give identical results, provided the environment only changes at grid points (it does, because actions apply at `grid(now)`).
- Catch-up cap: **14 days = 20,160 steps**. Beyond that, the state is held and `sim_time_unix` jumps to now. `CatchUpResult.capped = true`. The scientist accepts this (spec §16): it understates weakening after very long fridge absences, but the starter stays recoverable. Open for the director: a narrative line for "away more than 14 days".

### 5.2 `Clock` seam
`Clock` (`RefCounted`): `now_unix() -> int`, `local_utc_offset_s() -> int`.
- `SystemClock`: `Time.get_unix_time_from_system()` and `Time.get_time_zone_from_system().bias` (minutes, times 60) **[ran]**.
- `DebugClock`: wraps `SystemClock`, adds `time_scale` and `advance(s)`. Constructed **only** when `OS.is_debug_build()`. Release builds construct `SystemClock` directly, so no scale path exists.
- `FakeClock` (tests): `set_now`, `advance`, `set_offset`.

### 5.3 Clock rules (`src/core/time_policy.gd`)
Let `gap = state.sim_time_unix - clock.now_unix()`.

| Case | Action |
|---|---|
| `gap <= 0` | Catch up `min(-gap, 14 d)` |
| `0 < gap <= CLOCK_REANCHOR_GAP_S` (21,600 s = 6 h) | Elapsed 0. Keep the anchor (the clock went back a little; no rewind, no double count) |
| `gap > CLOCK_REANCHOR_GAP_S` | Re-anchor: `sim_time_unix = grid(now)`, state unchanged, `meta.clock_reanchors += 1`. Fixes "set to 2030 by mistake, then corrected", which would otherwise freeze the starter for years |
| In session | `Session` keeps the last wall time and `Time.get_ticks_msec()`. If wall delta exceeds monotonic delta by more than 300 s while foregrounded, advance by the monotonic delta only. Ticks are never saved |

This amends D-013 ("latest clock time ever seen"). See ADR-006.

### 5.4 Catch-up
`CatchUp.run(state, env, history, ledger, to_unix, utc_offset_s, event_rng, app_foreground: bool) -> CatchUpResult`, pure:
1. Loop `Sim.step` per grid point up to `to_unix` (capped).
2. After each step: derive, `PlayerHistory.record_step`, evaluate event rules, admit through the scheduler.
3. Record state transitions (for the summary and the journal) and about 30 evenly spaced `VisualParams` snapshots (for the time-lapse replay).
4. Return the result. `ReturnSummary.build(result)` picks at most 3 lines and 1 prompt.

### 5.5 Tutorial demo (B6, `game-mechanics.md` §8.1 and §8.2)
The only sped-up time a release build has, and it never touches the clock:
1. `StarterPresets.make(preset_id, now)` builds a **temporary** state (`data-models.md` §2.1).
2. `Demo.run(state, env, steps) -> Array[VisualParams]` (pure, `src/sim/demo.gd`) runs ordinary `Sim.step(state, env, 60)` calls. Playback speed comes from running many 60 s steps per frame, **never from a scaled `dt`**, so the demo shows exactly what the real sim does. The view plays the frames like the time-lapse.
3. When the demo reaches `at_peak` (or the player skips, which uses the same at-peak preset), `StarterState.rebase_to(now)` sets the timestamps to now and `Session` creates the real save from it. Sim time is never ahead of the wall clock, so §5.3 is untouched.

Cost: a toy 11-variable step loop ran **14 days in 22 ms on an Apple M4 [ran, Mac estimate]**. The scientist's Python model of the real v1 equations ran 10 days with derivation in 0.12 s in CPython, and found that a 5-day run split at random points equals the unsplit run exactly (spec §16). A forecast is about 700 steps. Budget: 250 ms on the Mac for 14 days with the real sim and rules. If over, run `CatchUp.run` on `WorkerThreadPool`. It is pure and touches only its own objects, so this is safe.

## 6. Launch, resume, background

### 6.1 Launch (`Session._ready`, before Main is in the tree)
1. Parse dev flags (debug builds only): `--fixture=`, `--time-scale=`, `--perf-log=`, `--capture=`.
2. `SaveStore.load()`: `save.json`, verify the checksum, migrate. On failure, `save.prev`. On failure, a new starter, with `meta.recovered_from` set and a calm notice.
3. Restore the RNGs: create them, then set `state` from the saved decimal string. **Never set `seed` after `state`**, because that resets the stream **[ran]**.
4. Apply the clock rules (§5.3) and run catch-up.
5. Save immediately (the catch-up result is now the truth).
6. Emit `session_ready(summary)`. UI shows "while you were away" if `summary.simulated_s >= AWAY_SUMMARY_MIN_S` (3,600 s, the return threshold agreed by `ux-designer` and `game-designer` in `game-mechanics.md` §8).

### 6.2 Foreground
- A 60 s timer, aligned to the grid, advances the sim to `grid(now)` and emits `state_changed`.
- Save: after every action, on every state-id change, and every 10 min.

### 6.3 Background and quit
`Session._notification(what)`:

| Notification | Value [ran] | Handling |
|---|---|---|
| `NOTIFICATION_APPLICATION_PAUSED` | 2015 | `on_background()`: advance to now, save. Mobile backgrounding |
| `NOTIFICATION_APPLICATION_FOCUS_OUT` | 2017 | Same, idempotent (desktop and mobile) |
| `NOTIFICATION_WM_CLOSE_REQUEST` | 1006 | Save, then quit (desktop) |
| `NOTIFICATION_WM_GO_BACK_REQUEST` | 1007 | Android back. `quit_on_go_back = false`. UI closes the top sheet. With no sheet, save then `get_tree().quit()` |
| `NOTIFICATION_APPLICATION_RESUMED` | 2014 | `on_resume()`: clock rules, catch-up, `resumed(summary)` |

`on_background()` and `on_resume()` are public, so tests call them directly.

## 7. Event system

- **Rules** (`src/sim/events/rules/rule_<id>.gd`, each extending `EventRule`) are pure: `evaluate(ctx: EventContext, rng: RandomNumberGenerator) -> SimEvent` (or null). `ctx` holds `prev_state`, `state`, `env`, `history`, `ledger`, `now_unix`, `local_minute_of_day`, `app_foreground`, and `last_action` when the step follows an action.
- **Evaluated at every grid step boundary**, live and in catch-up, and right after every action.
- **Trigger types** (`game-designer`): `state_enter`, `threshold_cross`, `duration`, `action_outcome`, `milestone`, `calendar`, `ambient`. Only `ambient` uses the RNG.
- **`EventScheduler.admit(event, ledger, local_minute_of_day) -> bool`** is pure. It applies per-id cooldowns, daily caps (nudge 2, attention 1, info 4), at most 1 pending `attention`, and quiet hours 22:00 to 08:00 local (nudges are deferred with `not_before_unix`). Numbers are owned by `game-designer`.
- **`EventLedger`** (saved) holds `next_uid`, last-fired per id, one-time flags, daily counts, and pending events.
- **Two RNG streams**: `sim_rng` (feed jitter only) and `event_rng` (ambient events). Adding an event rule never changes the starter's outcome.
- **Presentation** is not pure and lives in ui: never interrupt an open sheet, and queue toasts.

## 8. Rendering

### 8.1 Renderer tiers
- `rendering/renderer/rendering_method = "mobile"` (and `.mobile = "mobile"`). `rendering/rendering_device/fallback_to_opengl3 = true` is the 4.7.2 default **[ran]**, so a device without Vulkan falls back to Compatibility.
- `QualityTier` (`src/view/quality_tier.gd`) reads `RenderingServer.get_current_rendering_method()` **[ran: method exists]** at startup:

| Tier | When | Glass | Extras |
|---|---|---|---|
| B | `mobile` and the player hasn't chosen "reduce effects" | Tier A plus screen-texture refraction (front pass only) | Full VFX |
| A | `gl_compatibility`, or "reduce effects" | Back faces then front faces, fresnel, specular, small cubemap | Reduced VFX, `scaling_3d_scale` 0.85 |

- Shader branching: compile-time `#if CURRENT_RENDERER == RENDERER_COMPATIBILITY` for features that don't exist there (the screen texture), plus a `tier_b` bool uniform for the runtime toggle. `godot-developer` is verifying the define in the spike **[unverified]**.
- **Everything inside the glass is opaque.** The starter, the liner streaks (alpha scissor) and the hooch band all render in the opaque pass. Only `Jar_Glass` is transparent: one node, surface 0 outer and surface 1 inner, two passes ordered by `render_priority` (-1 back faces, +1 front faces).
- **The starter is one `ShaderMaterial`.** Every `VisualParams` field maps 1:1 to a uniform with the same name (`data-models.md` §7). `custom_aabb` covers the maximum rise (3.0x) and dome.
- Mesh contract with `art-director`: node names `Jar_Glass`, `Starter_Body`, `Starter_Liner`, `Jar_Lid_Loose`, `Jar_Lid_Tight`, `Cloth_Cover`, `Rubber_Band`, `Counter`, `Backdrop_placeholder`. Shape data lives in UV2 (x radial, y height fraction). glTF node extras arrive as `get_meta("extras")` **[ran]**. `jar_geometry.gd` mirrors them as constants and asserts a match at load.

## 9. Input routing

| Rule | How |
|---|---|
| A touch belongs to what it started on | GUI consumes presses that start on a `STOP` Control. The camera reads only `InputEventScreenTouch` and `InputEventScreenDrag` in `_unhandled_input`, and tracks a finger index only if it saw that index's press. Drags for untracked indices are ignored |
| What blocks the jar | Layout roots and the **top** HUD plate use `MOUSE_FILTER_IGNORE`, so a drag starting there can orbit. The **action bar plate**, cards, toasts and sheets use `STOP` across their whole area, so a near-miss between bar buttons or a tap on card text never reaches the 3D view (`ux-design.md` §6) |
| An open sheet blocks the 3D view | Every sheet has a full-screen scrim with `MOUSE_FILTER_STOP`. It also emits `Bus.sheet_opened` so the camera kills inertia |
| Orbit | One finger, `screen_relative`, with inertia. Yaw free, pitch clamped (limits owned by ux and art) |
| Pinch | Our own: two tracked indices, distance ratio to zoom. iOS sends no `InputEventMagnifyGesture` from touch |
| Double tap | Reset to home pose |
| Desktop testing | `input_devices/pointing/emulate_touch_from_mouse = true`. Keep `emulate_mouse_from_touch = true` (default) so Buttons get presses on phones. Duplicate-event behavior is checked in the spike **[unverified]** |

### 9.1 UI structure (constraints from `docs/ux-design.md` §12, §17 and §19)

- **One Theme**, `src/ui/theme/sourdough_theme.tres`, covers all 18 components. Default-looking controls never ship. Color roles: `surface`, `surface_alt`, `ink`, `ink_muted`, `accent`, `on_accent`, `outline`, plus five status tones. Hex values come from `art-director` and `ux-designer`.
- **Text size** (100%, 125%, 150%) scales Theme font sizes only, never `content_scale_factor`. Every text container grows vertically.
- **`EventPresenter`** (`src/ui/overlays/`) takes `Session.event_raised` and enforces the display rules: nothing interrupts an open sheet, at most one `attention` on screen, order attention then nudge then info. Admission caps stay in the pure `EventScheduler` (§7). The presenter only decides when to show.
- Status, hint, smell, inspection, forecast and the time-lapse read only `Session` outputs (snapshots, readouts, `CatchUpResult`), never their own logic.
- **Accessibility**: every interactive Control sets `accessibility_name` through `tr()` now. The property exists in 4.7.2 **[ran]**. Mobile screen readers arrive with 4.8 (D-012).

## 10. Localization

- **`src/i18n/en.csv`** (columns `keys,en`) is the shipped catalog. It is **generated** from every `Key | Text | Max` row in `narrative.md`, `events-catalog.md` and `game-copy.md` (614 strings at wave A) by a build script that `narrative-designer` owns. The build fails on any error from narrative's copy checker (lengths, unique keys, banned words, mold lines say "discard"). The script strips `(sci)` review marks and converts straight quotes to curly ones (the Theme font must include U+2018, U+2019, U+201C, U+201D; `ux-designer` checks). Nobody hand-edits `en.csv`.
- Each code track may add **placeholder** keys only in its own file: `src/i18n/pending_core.csv`, `pending_view.csv`, `pending_ui.csv`. `narrative-designer` moves them into the docs (and so into `en.csv`) in a copy pass, and the track then deletes its row. No file has two writers.
- All four CSVs are registered once in `internationalization/locale/translations` in the contracts commit. Generated `*.translation` files are git-ignored (`.gitignore`), so a fresh checkout needs `--import`, which is required anyway (§12).
- **Key format** (narrative's, already used by 614 strings): `^[A-Z][A-Z0-9_]*$`, an area prefix, then canonical ids uppercased. Examples: `STATUS_AT_PEAK_WORD`, `SMELL_YOGURT_2`, `INSPECT_BUBBLES_...`, `ACTION_...`. Keys are unique across all four CSVs.
- Code builds keys from canonical ids with one helper, `Keys.status_word(state_id)` and so on (`src/core/keys.gd`), so the uppercase mapping lives in one place.
- sim returns keys plus args. ui calls `tr(key).format(args)`. Scene labels hold keys, with auto-translate on.
- Plurals: CSV plural support is **[unverified]**. MVP copy avoids count-dependent grammar or uses two keys (`.one` and `.other`).
- `tests/unit/ui/test_i18n_keys.gd` scans `.gd` and `.tscn` files for key literals and fails on any key missing from the CSVs.
- Lint (owned by `qa-engineer`, LINT-04 and LINT-06): key format, uniqueness across the CSVs, and the `Max` length column.

## 11. Performance and battery budgets

Phone numbers are targets. Nothing is measured on a phone yet (D-004).

| Budget | Target | Measured so far |
|---|---|---|
| Frame, interacting | 60 fps: CPU 8 ms, GPU 10 ms on a 2021 mid-range phone | Pending spike (Mac estimates) |
| Frame, idle | `Engine.max_fps = 30` after 3 s with no touch and no tween. Back to 60 on `interaction_started` | `Engine.max_fps` settable at runtime **[ran]** |
| Opaque full-screen UI (journal) | Hide `World` (no 3D draw) | |
| Catch-up, 14 days | 250 ms on the Mac | Toy loop 22 ms **[ran]** |
| Launch to first frame of the jar | 2 s on a phone | |
| Save | 128 KB or less, write under 10 ms | |
| Scene | 16k tris or fewer, under 10 draw surfaces for the jar (art budget), under 30 draw calls total | Pending GLB |
| Screen | `display/window/energy_saving/keep_screen_on = false` (4.7.2 default is **true [ran]**) | |

- `low_processor_mode` is **not** used for the main scene. It only redraws on change, and the jar always breathes. It may be used for an opaque full-screen screen later.
- No physics nodes. No `_process` on nodes that only react to signals.

## 12. Testing

Command for humans and CI: **`tests/run.sh`** (owned by `qa-engineer`). It:
1. runs `godot --headless --path . --import`. **Required**: in a fresh checkout without `.godot/`, `class_name` types fail to resolve under `-s` and the run **exits 0** **[ran]**.
2. runs `godot --headless --path . -s res://tests/run_tests.gd -- [--filter=<substring>]` under an outer `perl -e 'alarm 300; exec @ARGV'` timeout. A runtime error directly in `_init` hangs **[ran]**.
3. passes only if the exit code is 0 **and** the last stdout line matches `^RESULT: [0-9]+ passed, 0 failed$`. A parse error in the runner itself exits 0 **[ran]**.

`run_tests.gd` contract (all **[ran]** in 4.7.2):
- Runs from `_initialize()`, not `_init()`.
- Finds `tests/**/test_*.gd` recursively and `load()`s each one. A parse error gives a non-null script with `can_instantiate() == false`, which counts as FAIL. That includes `untyped_declaration` promoted to an error.
- Registers a `Logger` subclass with `OS.add_logger()`. Any `_log_error` during a test (a null call, `push_error`, a failed `assert`) fails that test. Needed because a runtime error aborts the test function silently and the runner carries on.
- A test with zero assertions fails.
- `quit(1)` on any failure gives exit 1.

Seams for `qa-engineer`: `Clock` and `FakeClock`; `sim_rng` and `event_rng` injected; `SaveStore.new(base_dir)` plus `fault_point` (`before_tmp_write`, `mid_tmp_write`, `before_rename`, `after_rename`); `SaveStore.load_from_path()`; `--fixture=`; `Session.dump_state(path)`; pure entry points (`Sim.step`, `Sim.apply_feed`, `StateDeriver.derive`, `VisualMapper.from_state`, `EventRules.evaluate`, `EventScheduler.admit`, `SmellModel.read`, `Inspection.read`, `CatchUp.run`, `Forecast.peak_window`, `ReturnSummary.build`); `Session.on_background()` and `on_resume()`; a `time_override` uniform plus `--capture=<png>`; `--perf-log=<csv>`.

## 13. Project settings (set in the Phase 2 contracts commit)

| Setting | Value | Why |
|---|---|---|
| `display/window/handheld/orientation` | `1` (portrait) | Default 0 is landscape **[ran]** |
| `display/window/size/viewport_width` / `_height` | 390 / 844 | Desktop test window only. On phones the window is the screen |
| `display/window/stretch/mode` | `disabled` | `ux-designer` constraint: 1 UI unit = 1 pt or dp, layout at the real logical size (360 to 440 wide), not a stretched base. At boot `Main` sets `get_window().content_scale_factor = DisplayServer.screen_get_scale()` (API exists **[ran]**; Android return value is being checked in the spike **[unverified]**) |
| `rendering/renderer/rendering_method` and `.mobile` | `mobile` | §8.1 |
| `rendering/textures/vram_compression/import_etc2_astc` | `true` | Mobile texture formats (default false **[ran]**) |
| `debug/gdscript/warnings/untyped_declaration` | `2` (error) | Hard rule 4. Errors under `-s` too **[ran]** |
| `debug/gdscript/warnings/unsafe_property_access`, `unsafe_method_access` | `2` | Typed code stays typed |
| `debug/gdscript/warnings/unsafe_call_argument`, `unsafe_cast` | `1` (warn) | Save decoding reads Variants. Errors here would force `@warning_ignore` everywhere |
| `debug/gdscript/warnings/inferred_declaration` | `0` | `:=` is typed and allowed |
| `input_devices/pointing/emulate_touch_from_mouse` | `true` | Desktop testing |
| `application/config/quit_on_go_back` | `false` | Back closes sheets first (§6.3) |
| `display/window/energy_saving/keep_screen_on` | `false` | Battery |
| `internationalization/locale/translations` | the three generated translation files | §10 |
| `autoload` | `Bus`, `Session` | §3.1 |

## 14. Phase 2 and 3 file ownership

Goal: at least three tracks in parallel git worktrees, with no file written by two tracks.

### 14.1 Tracks

| Track | Owns (writes) | Reads |
|---|---|---|
| **T1 sim and core** | `src/sim/**` (except `src/sim/events/rules/**`), `src/core/**`, `src/main/**`, `data/**`, `src/i18n/pending_core.csv`, `tests/unit/sim/**`, `tests/unit/core/**`, `project.godot` | everything |
| **T2 view and shaders** | `src/view/**`, `src/i18n/pending_view.csv`, `tests/unit/view/**` | `src/sim` types, `Bus`, `Session` API, `assets/3d/**` |
| **T3 UI** | `src/ui/**`, `src/i18n/pending_ui.csv`, `tests/unit/ui/**` | `src/sim` types, `Bus`, `Session` API |
| T4 events content (optional, can fold into T1) | `src/sim/events/rules/**`, `tests/unit/events/**` | `src/sim/**` |
| Narrative | `src/i18n/en.csv` (generated) and its build script in `tools/i18n/` | the three narrative docs |
| QA | `tests/run_tests.gd`, `tests/run.sh`, `tests/lib/**`, `tests/fixtures/**`, `tests/scenarios/**` | everything |
| Art | `assets/3d/**`, `art/**` | |

### 14.2 Shared files and their single owner

| File | Owner | Others |
|---|---|---|
| `project.godot` (settings, autoloads, translations list, input map) | T1 | Never commit changes to it. If the editor rewrites it, `git checkout project.godot` before committing. Request changes from T1 |
| `src/core/bus.gd` (ui and view contract) | T1 writes it; the signal list comes from §3.3 | Additions by request, so both T2 and T3 see them |
| `src/sim/visual_params.gd` (sim and view contract) | T1 | Fields frozen from `data-models.md` §7. T2 requests changes |
| `src/core/game_session.gd` public API | T1 | Signatures frozen from §3.3 and §4 |
| `src/main/main.tscn` | T1 | Instances `world.tscn` and `ui_root.tscn` by path only, so T2 and T3 edit their own scenes freely |
| `.gitignore`, `.gitattributes` | director | |
| `export_presets.cfg` | T1 (Phase 5 release work) | Contains no secrets. Credentials stay in `.godot/` |

### 14.3 How parallel work starts
1. **Contracts commit (T1, first, alone):** `project.godot`; both autoloads; every public `class_name` file from `data-models.md` with real fields and stub methods; `GameSession` with the full public API (stub logic, which loads a fixture); `bus.gd` with all signals; the generated `en.csv` plus the three empty pending CSVs, all registered; empty `world.tscn` and `ui_root.tscn` instanced by `main.tscn`.
2. Then T1, T2 and T3 branch from that commit into worktrees. T2 develops against a `VisualParams` scrubber scene. T3 develops against `--fixture=` saves and the stub session.
3. Every worktree runs `tests/run.sh`, which includes the `--import` step. Each track commits the `.uid` and `.import` files for its own paths only.
4. Contract changes after the commit: ask T1 (or me) by message, and T1 lands them as a small commit that the others rebase onto.
