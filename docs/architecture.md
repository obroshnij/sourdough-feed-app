# Architecture

Owner: `tech-architect`. Status: **v1, synced to the code** on `phase-3-slice` at e94b644 (2026-11-27, D-040 to D-050). Engine: Godot 4.7.2, typed GDScript. The call sequences the UI follows are in the top doc comment of `src/core/game_session.gd`; this doc doesn't repeat them.
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
4. Enforced by `qa-engineer`'s LINT-01, which scans `src/sim/**/*.gd` (comments stripped) for forbidden tokens and fails on any hit: `extends Node`, `Node.new`, `get_tree(`, `Time.`, `OS.`, `Engine.`, `Input.`, `DisplayServer.`, `FileAccess`, `DirAccess`, `load(`, `preload(`, `ResourceLoader`, `ResourceSaver`, global `randi(`, `randf(`, `randi_range(`, `randf_range(`, `randfn(`, `seed(`, `randomize(`, `tr(` (D-041). Methods on a passed-in RNG are allowed.

## 2. Directory layout

`src/sim/`, `src/core/` and `src/main/` list the files on `phase-3-slice`. `view/` and `ui/` are owned by T2 and T3, who keep their own layout under those roots.

```
project.godot                      shared, owner: T1 (§13, §14.2)
src/
  main/        main.tscn, main.gd        composes World + UI, sets content scale, calls Session.start(),
                                         adds DevOverlay in debug builds
  main/dev/    integrated_capture.gd/.tscn   dev only: full-game capture from a fixture (§14.1)
  sim/         state:    starter_state.gd  environment_state.gd  derived_state.gd  starter_snapshot.gd
               numbers:  sim_constants.gd  sim_catalog.gd  flour_profile.gd  location_preset.gd
                         container_profile.gd  cover_profile.gd
               actions:  game_action.gd  feed_action.gd  set_environment_action.gd  smell_action.gd
                         inspect_action.gd  rename_action.gd  ack_event_action.gd
                         discard_starter_action.gd  adopt_starter_action.gd  action_result.gd
               model:    sim.gd  sim_rates.gd  state_deriver.gd  visual_params.gd  visual_mapper.gd
                         starter_presets.gd  demo.gd  sim_fixtures.gd  local_day.gd
               readouts: smell_model.gd  smell_readout.gd  inspection.gd  inspection_readout.gd
                         forecast.gd  peak_forecast.gd  forecast_window.gd  feed_planner.gd  feed_preview.gd
                         catch_up.gd  catch_up_result.gd  time_lapse_keyframe.gd
               records:  player_history.gd  daily_bucket.gd  journal_entry.gd  memorial.gd  dict_reader.gd
  sim/events/  sim_event.gd  event_context.gd  event_rule.gd  event_rules.gd
               event_scheduler.gd  event_ledger.gd  return_summary.gd  return_line.gd
  sim/events/rules/   T4: rule_index.gd (the registry list), rule_facts.gd (shared helpers),
                      rule_<event_id>.gd for the 8 slice rules
  core/        game_session.gd  bus.gd  clock.gd  system_clock.gd  debug_clock.gd  fake_clock.gd
               time_policy.gd  time_resolution.gd  save_store.gd  save_codec.gd  save_decoded.gd
               save_load_report.gd  save_meta.gd  save_migrations.gd  settings_store.gd
               i18n_loader.gd  keys.gd  milestones.gd  night_fade.gd
  core/dev/    dev_flags.gd  dev_overlay.gd   (PerfLog not built)
  view/        T2: world.tscn, jar, camera, shaders, VFX, time-lapse player, dev/ (scrubber, look probe)
  ui/          T3: ui_root.tscn, theme/, hud/, sheets/, components/
  i18n/        en.csv (generated)  pending_core.csv  pending_view.csv  pending_ui.csv   (*.translation git-ignored)
data/          not created (D-042). Sim numbers live in SimConstants, mirroring tools/sim-reference/sim.py,
               and SimCatalog.builtin() builds the profiles in code (data-models.md §3). T1 keeps the path
               for later .tres profiles
assets/3d/     jar_v0.glb (art-director)
tests/         run_tests.gd  run.sh  lib/  fixtures/  scenarios/  unit/sim/  unit/core/  unit/view/  unit/ui/
spikes/        Phase 1 only, has .gdignore
```

## 3. Scene tree, autoloads, signals

### 3.1 Autoloads (exactly two)

| Order | Name | Script | class_name | Role |
|---|---|---|---|---|
| 1 | `Bus` | `src/core/bus.gd` | none | Signals only. The ui and view contract. No state. |
| 2 | `Session` | `src/core/game_session.gd` | `GameSession` | Owns the game state, the clock, the save store and `sim_rng`. The only mutator. |

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
   └─ DevOverlay (CanvasLayer 100)        debug builds only, added by Main.gd (§5.2)
```

`DevOverlay` (`src/core/dev/dev_overlay.gd`, T1) is hidden by default and toggled by F3 (the `dev_overlay` action). It is never created in a release build, so a release has no node, no input and no time controls. Its labels are developer text, not tr keys. Captures are not a node: T2's scrubber has `--capture`, and `src/main/dev/integrated_capture.tscn` captures the full game.

### 3.3 Signals

`Session` (core to ui and view):

| Signal | Payload | Fired when |
|---|---|---|
| `session_ready(summary: CatchUpResult)` | catch-up result, may be empty | After launch load and catch-up. `get_return_summary()` is ready in the handler |
| `resumed(summary: CatchUpResult)` | same | After returning from background. Same |
| `state_changed(snapshot: StarterSnapshot, visuals: VisualParams)` | display-ready values | Every grid step that changes them, after every action, and once with the saved state when a worker-thread catch-up starts (§11) |
| `action_applied(result: ActionResult)` | ok or rejected with a reason key | After `apply()`, including `REASON_NOT_READY` refusals |
| `event_raised(event: SimEvent)` | one event | Once per run per event, when due (§7). `event.presentation()` says toast, card or sheet |
| `event_withdrawn(uid: int)` | uid | A raised card or sheet went stale before it was acknowledged. The UI hides it |
| `journal_appended(entry: JournalEntry)` | one entry | After the journal grows |
| `save_failed(reason_key: StringName)` | key | Save error (UI shows a calm notice). Once per run of failures |

`Bus` (ui and view, plus one core signal). Additions land in `bus.gd` by request to T1:

| Signal | Direction | Meaning |
|---|---|---|
| `sheet_opened(sheet_id: StringName)` / `sheet_closed(sheet_id)` | ui to view | Camera stops inertia, dims VFX |
| `camera_focus_requested(target: StringName)` | ui to view | `bubbles`, `surface`, `height`, `top`, `home`, `mold`. Inspection moves the camera. T3 sends `mold` when the `mold_found` sheet opens (D-023), and `camera_focus_released()` when it closes |
| `settings_changed()` | core to view and ui | Emitted by `Session.save_settings()`. Read the values from `Session.get_settings()` |
| `time_lapse_started()` / `time_lapse_finished()` | view to ui | Bracket the away time-lapse (below). `finished` fires after a natural end or a skip |
| `time_lapse_skip_requested()` | ui to view | The skip pill or a tap anywhere (`ux-design.md` §12). T2 jumps to the last keyframe, restores the live visuals and night factor, then emits `time_lapse_finished()` |
| `camera_focus_released()` | ui to view | Back to the player's orbit |
| `smell_moment_started()` / `smell_moment_finished()` | ui to view | Camera nudge, wisps |
| `feed_moment(step: StringName)` | ui to view | `discard`, `scoop`, `pour`, `stir` animations |
| `jar_region_changed(region: Rect2)` | ui to view | The free space between the top HUD plate and the action bar, in UI units (pt, since stretch is off, §13). Emitted on every layout change (text size, safe areas, rotation). The camera frames the jar to it (`ux-design.md` §2, §19.5) |
| `starter_tapped(where: StringName)` | view to ui | `starter`, `glass`. A tap on the jar |
| `interaction_started()` / `interaction_ended()` | both | Drives the frame cap (§11) |

**The away time-lapse handshake.** Nobody hands a result across the ui and view line. Both read the same `CatchUpResult` from `session_ready` or `resumed`:
- T2 starts playback by itself when `result.play_time_lapse` is true, emits `time_lapse_started`, plays `keyframes` over `time_lapse_duration_s()`, and turns 3D input off until `time_lapse_finished`.
- T3 skips the summary when `Session.is_first_run()`. Otherwise, when `play_time_lapse` is true, it hides the HUD, shows the skip pill and waits for `time_lapse_finished`, then shows the summary card and the prompt. When false, it shows the card at once.
- `play_time_lapse` is set by `Session` (`data-models.md` §8), so both sides always agree.

## 4. Action pipeline

```
UI builds FeedAction ──► Session.apply(action) ──► ActionResult
   0. ready    not booted, or a worker-thread catch-up running → REASON_NOT_READY (D-050)
   1. sync     advance the sim to grid(now) (same clock rules as resume, §5.3)
   2. validate action.validate(state, env, catalog); an ack also needs a pending uid → reject, nothing changes
   3. mutate   feed / env replace / readout for smell, inspect / rename / ack / discard / adopt
   4. derive   StateDeriver.derive(state, env) → state id + rise phase
   5. history  PlayerHistory.record_action(...), seen counts
   6. events   EventRules.process(ctx, EventRules.registry()) → scheduler → ledger (§7)
   7. journal  hooch line, then the action's line, then the Day one page, then one line per event
   8. save     SaveStore.save(...) (atomic, §6)
   9. signals  action_applied, state_changed, journal_appended, event_withdrawn, event_raised
  10. view     JarView: VisualMapper output → shader uniforms, eased by T2
```

- Every player act is an action, including `smell` and `inspect`. They change no sim variable, but they update `PlayerHistory` (seen counts), can fire milestone events, and write the journal subject to the dedupe rule in `game-mechanics.md` §4. The readout comes back in `ActionResult.readout`.
- A rejected action stops at step 2: no mutation, journal entry or save. The step 1 sync may still have advanced the state to `grid(now)`, which is time passing, not the action's effect.
- Actions: `FeedAction`, `SetEnvironmentAction`, `SmellAction`, `InspectAction`, `RenameAction`, `AckEventAction`, `DiscardStarterAction` (after `moldy`: memorial, then a new starter, one save, D-047), `AdoptStarterAction` (names the gifted starter of a new game). Fields are in `data-models.md` §4.
- While moldy, feed, smell and place are refused (D-043). Inspect, journal and the discard flow stay open.
- Read-only helpers the sheets call, which never mutate: `plan_feed()`, `preview_feed()` and `last_feed_action()` (`FeedPreview`, `data-models.md` §4.1), `get_forecast_window_key()`, `preview_memorial()`, `restart_preset()`, `name_suggestion_key()`, `format_text()`, `get_return_summary()`, `get_pending_events()`.
- Actions apply at `grid(now)`, the last 60 s grid point at or before now. The journal records the real `at_unix`.

## 5. Time, stepping and catch-up

### 5.1 Model
- Time is **Unix seconds, `int`**, UTC. Time zone and daylight saving don't touch the sim. Local time (`local_utc_offset_s`) is an input to quiet hours and calendar events only.
- The sim steps on a **fixed 60 s grid aligned to Unix time** (`grid(t) = t - posmod(t, 60)`). `StarterState.sim_time_unix` is always on the grid.
- Live play and offline catch-up call the same `Sim.step(state, env, 60)`. So one long catch-up and many short sessions take **identical steps** and give identical results, provided the environment only changes at grid points (it does, because actions apply at `grid(now)`).
- Catch-up cap: **14 days = 20,160 steps**. Beyond that, the state is held and `sim_time_unix` jumps to now. `CatchUpResult.capped = true`. The scientist accepts this (spec §16): it understates weakening after very long fridge absences, but the starter stays recoverable. The return summary always says so with its `AWAY_CAPPED` row (D-024).

### 5.2 `Clock` seam
`Clock` (`RefCounted`): `now_unix() -> int`, `local_utc_offset_s() -> int`, `monotonic_msec() -> int` (the in-session guard in §5.3, so `FakeClock` can test it; never saved).
- `SystemClock`: `Time.get_unix_time_from_system()` and `Time.get_time_zone_from_system().bias` (minutes, times 60) **[ran]**.
- `DebugClock`: wraps `SystemClock`, adds `set_time_scale()` and `advance(s)`. `monotonic_msec()` is scaled too, so the in-session guard sees consistent deltas. Constructed **only** when `OS.is_debug_build()`. Release builds construct `SystemClock` directly, so no scale path exists.
- `FakeClock` (tests): `set_now`, `advance`, `set_offset`.

**Debug time travel (D-017, D-050).** Debug builds only, driven by the F3 `DevOverlay` (§3.2): time scales of 1, 60, 600 and 3600x (`Session.set_debug_time_scale()`) and jumps of +1 h, +1 d and +3 d (`Session.debug_advance()`, which runs `on_background()`, advances the clock, then `on_resume()`, so the full return flow plays). Scaled time only means more ordinary 60 s steps per real second, never a scaled `dt`.
- **Save sandbox.** The first time travel of a run saves the real state once more at real time, then switches the store to `<save dir>_time_travel` (`user://saves_time_travel`) for the rest of the run (`is_time_traveling()`). A launch with `--time-scale=` other than 1 starts in the sandbox. So a scaled timestamp never reaches the real save, and the next normal launch loads the real save and catches up as usual. Tested by `test_debug_time_travel_never_touches_the_real_save` and QA's OD-19 contract test.
- Release builds: both calls return without doing anything, because no `DebugClock` exists.

### 5.3 Clock rules (`src/core/time_policy.gd`)
Let `gap = state.sim_time_unix - clock.now_unix()`.

| Case | Action |
|---|---|
| `gap <= 0` | Catch up `min(-gap, 14 d)` |
| `0 < gap <= CLOCK_REANCHOR_GAP_S` (21,600 s = 6 h) | Elapsed 0. Keep the anchor (the clock went back a little; no rewind, no double count) |
| `gap > CLOCK_REANCHOR_GAP_S` | Re-anchor: `sim_time_unix = grid(now)`, state unchanged, `meta.clock_reanchors += 1`. Fixes "set to 2030 by mistake, then corrected", which would otherwise freeze the starter for years |
| In session | `Session` keeps the last wall time and `Clock.monotonic_msec()` (`Time.get_ticks_msec()` in `SystemClock`). If wall delta exceeds monotonic delta by more than 300 s while foregrounded, advance by the monotonic delta only. Ticks are never saved |

This amends D-013 ("latest clock time ever seen"). See ADR-006.

### 5.4 Catch-up
`CatchUp.run(state, env, history, ledger, catalog, to_unix, utc_offset_s, app_foreground: bool) -> CatchUpResult`, pure. It uses `EventRules.registry()`; `run_with_rules(..., rules)` takes an explicit list for tests. No RNG: catch-up contains no feeds, and event rules use none. Live ticks call it too, with `app_foreground = true`:
1. Loop `Sim.step` per grid point up to `to_unix` (capped).
2. After each step: derive, `PlayerHistory.record_step`, evaluate event rules, admit through the scheduler.
3. Record state transitions (with `cause`) and the time-lapse `keyframes`: at most 30, always the first, the last and every transition (`data-models.md` §8).
4. Return the result. `Session` then builds `ReturnSummary.build(result, derived)`: at most 3 lines and 1 prompt.

Cost work (T1, 2a6d063): one reused previous-state buffer (`StarterState.copy_from`), context fields set once, and the ledger's day rolled only when `LocalDay.day_index()` changes. Numbers in §11.

Local time inside one catch-up uses the offset read at resume for the whole window. A catch-up that spans a daylight-saving change applies quiet hours and day keys up to 1 h off for the part before the change (accepted limit). Live play reads `clock.local_utc_offset_s()` on every tick, so a change takes effect at once.

### 5.5 Tutorial demo (B6, `game-mechanics.md` §8.1 and §8.2): Phase 4
The slice has no demo. A new game names the gifted starter with `AdoptStarterAction` (path `skip`), which builds a fresh `new_game` preset rebased to now (`data-models.md` §2.1). The demo below arrives with the `tour` path in Phase 4. It is the only sped-up time a release build has, and it never touches the clock:
1. `StarterPresets.make(preset_id, now)` builds a **temporary** state (`data-models.md` §2.1).
2. `Demo.run(state, env, steps) -> Array[VisualParams]` (pure, `src/sim/demo.gd`) runs ordinary `Sim.step(state, env, 60)` calls. Playback speed comes from running many 60 s steps per frame, **never from a scaled `dt`**, so the demo shows exactly what the real sim does. The view plays the frames like the time-lapse.
3. When the demo reaches `at_peak` (or the player skips, which uses the same at-peak preset), UI calls `Session.adopt_starter(state, name)`. It runs `StarterState.rebase_to(now)`, which sets the timestamps to now, and creates the real save from it. Sim time is never ahead of the wall clock, so §5.3 is untouched.

Cost: a toy 11-variable step loop ran **14 days in 22 ms on an Apple M4 [ran, Mac estimate]**. The scientist's Python model of the real v1 equations ran 10 days with derivation in 0.12 s in CPython, and found that a 5-day run split at random points equals the unsplit run exactly (spec §16). A forecast is about 700 steps. Budget: 250 ms on the Mac for 14 days with the real sim and rules. Measured: 230 ms with the 8 slice rules, and long catch-ups run off the main thread anyway (§11, D-050).

## 6. Launch, resume, background

### 6.1 Launch (D-039: `Main` starts the boot, not `Session._ready`)

| When | Who | Does |
|---|---|---|
| Autoload ready, before Main is in the tree | `Session._ready()` | Parses dev flags (debug builds only): `--fixture=`, `--time-scale=`, `--perf-log=`, `--capture=`. Registers translations with `I18nLoader.load_all()` (§10). Connects to `Bus` for the frame cap (§11). **Loads nothing** |
| After World and UI are ready (children are ready before their parent), so both have connected to `Session` signals | `Main._ready()` | Sets `content_scale_factor` (and a 2x window on a 2x desktop screen, §13), calls `Session.start()`, then adds `DevOverlay` in debug builds |
| Once | `Session.start()` | Builds the real seams unless `setup()` already ran: `SystemClock` (`DebugClock` in debug builds), `SaveStore` at `user://saves` (`user://fixture_saves` with `--fixture=`, the sandbox with `--time-scale=`, §5.2), `SettingsStore`. Then `boot_async()` (or `boot_from_fixture(path)`: no catch-up, shown as of now; or `boot()` when `async_catch_up` is false), then starts the 60 s grid timer and the idle frame-cap timer |

`boot()` (synchronous; `boot_async()` does the same with step 3 on a worker thread when it is 2 h or more, §11):
1. `SaveStore.load_latest()` tries `save.json`, `save.tmp`, `save.prev` (`data-models.md` §9.4). If none passes, the gifted, unnamed starter from the `new_game` preset. If saves existed but all failed, `meta.recovered_from = "quarantine"` and `recovered_this_launch()` is true, so the UI shows a calm notice once.
2. Restore `sim_rng`: create it, set `seed`, then set `state` from the saved decimal string. **Never set `seed` after `state`**, because that resets the stream **[ran]**.
3. Apply the clock rules (§5.3) and run catch-up.
4. Journal the transitions and events, build the return summary (`ReturnSummary.for_first_launch()` on the very first launch, else `build()`), set `play_time_lapse`, and save immediately (the catch-up result is now the truth).
5. Emit `state_changed`, `session_ready(summary)`, `journal_appended`, then `event_withdrawn` and `event_raised` for what is due (§7). When the summary shows, the events it covers are marked released and never come back as toasts or cards; only its prompt is raised.

**New game.** `is_first_run()` means "the starter has no name": true on the first launch, after a quarantine recovery, and again after a kill before naming. The UI then shows M.'s note, then naming (with `name_suggestion_key()`), then `apply(AdoptStarterAction)` (`data-models.md` §4). The Day one journal page follows the first feed.

Tests never call `start()`. They use `GameSession.new()`, `setup(FakeClock.new(), SaveStore.new(dir))`, then `boot()`. So a `-s` run never touches `user://saves`. `Session.shutdown()` (debug builds only) drops every seam and all state, so a test can boot `Main` again in the same process.

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
| `NOTIFICATION_WM_GO_BACK_REQUEST` | 1007 | Android back. `quit_on_go_back = false`. UI (T3) handles it: closes the top sheet, or with no sheet calls `Session.save_and_quit()` |
| `NOTIFICATION_APPLICATION_RESUMED` | 2014 | `resume_async()` in the app (`on_resume()` when `async_catch_up` is false): clock rules, catch-up, return summary, `resumed(summary)` |
| `NOTIFICATION_APPLICATION_FOCUS_IN` | 2016 | Same as resumed, only if `on_background()` ran (the desktop pair of FOCUS_OUT) |

`on_background()` and `on_resume()` are public and synchronous, so tests call them directly. `on_background()` first waits for a running worker-thread catch-up, so the save holds its result (§11).

## 7. Event system

- **Rules** (`src/sim/events/rules/rule_<id>.gd`, each extending `EventRule`) are pure and deterministic: `evaluate(ctx: EventContext) -> SimEvent` (or null). `ctx` is defined in `data-models.md` §5. After an action, `ctx.prev_state` is the pre-action state.
- **The live registry.** `EventRules.registry()` returns T4's `RuleIndex.all()`, built once and shared by every caller, including the catch-up worker thread. So rules keep **no state** between calls; everything they remember lives in `PlayerHistory` or the ledger. `Session` builds the list on the main thread before a worker starts. The 8 slice rules: `mold_found`, `warning_signs`, `first_rise`, `peak_now`, `peaked_while_away`, `hungry_again`, `hooch_forming`, `back_to_strength`.
- **Tie order (D-048).** When several rules fire on one step they are admitted in `RuleIndex` order, which is the list above. It follows the return summary's keep priority: attention, milestone, peak, hunger and hooch, then other info.
- **Rule readings (D-048).** `warning_signs` and `mold_found` fire every step until admitted, so a safety sheet is never lost to a cap. No good-news event fires while `unhealthy` or `moldy` (`RuleFacts.shows_danger`). "Once per starter" is `RuleFacts.fired_for_starter()` (after `born_unix`), because the scheduler's `one_time` flag is per save.
- **Evaluated at every grid step boundary**, live and in catch-up, and right after every action (`EventRules.process(ctx, rules)`).
- **Trigger types** (`game-designer`): `state_enter`, `threshold_cross`, `duration`, `action_outcome`, `milestone`, `calendar`, `ambient`. `ambient` rules read stored per-feed values, not an RNG. For example, `big_bubble` fires when `rise_phase` enters `near_peak` and `feed_u >= 0.85` (spec §14.1). The sim produces the bubble, so the jar shows it (hard rule 2).
- **`EventScheduler.admit(event, ledger, local_minute_of_day, cooldown_s, one_time) -> bool`** is pure. The rule supplies `cooldown_s` and `one_time`. It applies them, daily caps (nudge 2, attention 1, info 4), at most 1 pending `attention` (only `mold_found` may replace a waiting one), and quiet hours 22:00 to 08:00 local (nudges are deferred with `not_before_unix`). Numbers are owned by `game-designer`. The caller rolls the ledger's day first.
- **`EventLedger`** (saved) holds `next_uid`, last-fired per id, one-time flags, daily counts, and pending events.
- **Release (in `Session`, not pure).** After each tick, action, launch or resume, `Session` drops stale pending events (`EventScheduler.is_stale()`: `expires_if` or `expires_unix`) and emits `event_withdrawn(uid)` for any already raised. Then it raises each pending event once per run when `not_before_unix` has passed. A toast (`info`) leaves the pending list when raised. Cards and sheets stay pending until `AckEventAction`, and a relaunch raises them again (the "raised" set is not saved). Every admitted event is journaled once, when admitted.
- **One RNG**: `sim_rng`, with exactly one draw per feed (`feed_u`). Events have none, so adding an event rule can never change the starter's outcome or the RNG stream. A future rule that needs variety derives it from stored per-cycle values like `feed_u`.
- **Presentation** lives in ui: never interrupt an open sheet, the feed sequence, the smell moment, inspection or the time-lapse, and queue toasts (§9.1).

## 8. Rendering

### 8.1 Renderer tiers
- `rendering/renderer/rendering_method = "mobile"` (and `.mobile = "mobile"`). `rendering/rendering_device/fallback_to_opengl3 = true` is the 4.7.2 default **[ran]**, so a device without Vulkan falls back to Compatibility.
- `QualityTier` (`src/view/quality_tier.gd`) reads `RenderingServer.get_current_rendering_method()` **[ran: method exists]** at startup:

| Tier | When | Glass | Extras |
|---|---|---|---|
| B | `mobile` and the player hasn't chosen "reduce effects" | Front faces only: screen-texture refraction with a normal offset, a depth check and an analytic far wall | Full VFX |
| A | `gl_compatibility`, or "reduce effects" | Back faces then front faces (`render_priority` -1, then +1), fresnel, specular, small cubemap | Reduced VFX |

- **Switching tiers swaps the glass material.** A runtime bool can't turn off the screen copy: Tier B with refraction off still cost 4.52 ms GPU against Tier A's 3.63 [spike, Mac estimate].
- Compile-time `#if CURRENT_RENDERER == RENDERER_COMPATIBILITY` removes the screen-texture code from Compatibility builds. Verified in both renderers [spike].
- **Compatibility color needs its own `Environment` preset**, which `QualityTier` applies per renderer. The starter renders near white there [spike], but tonemap and exposure don't fix it. Only ambient sky contribution does, at the cost of black shadows, so the root cause is open (ADR-001). Presets express ambient as `ambient_light_sky_contribution` or as sky energy, never `ambient_light_energy`, which does nothing with the sky source. Enabling Compatibility `adjustment_enabled` is a pipeline switch to cost-test first. The T2 view track owns this. Acceptance is the measured "Reference look" table in `art-direction.md` §3 (colors with tolerances, starter hue 30 to 40 degrees in every state, nothing clipped), met in both renderers, and `art-director` signs off (§14.1).
- **Everything inside the glass is opaque.** The starter, the liner streaks (alpha scissor) and the hooch band all render in the opaque pass. Only `Jar_Glass` is transparent (one node, surface 0 outer, surface 1 inner).
- **The starter is one `ShaderMaterial`.** Every `VisualParams` field maps 1:1 to a uniform with the same name (`data-models.md` §7). `custom_aabb` covers the maximum rise (3.0x) and dome.
- Mesh contract with `art-director` (`jar_v0.glb`, enforced by `art/blender/scripts/verify_glb.py`): mesh nodes `Jar_Glass`, `Starter_Body`, `Starter_Liner`, `Jar_Lid_Loose`, `Jar_Lid_Tight`, `Cloth_Cover`, `Rubber_Band`, `Counter`, and empties `StarterFloor` and `StarterRim`. Shape data lives in UV2 (x radial, y height fraction). glTF node extras arrive as `get_meta("extras")` **[ran]**. `jar_geometry.gd` mirrors them as constants and asserts a match at load.
- The set (D-049): `Kitchen_Wall` in `kitchen_wall.glb` (one draw call, `art-direction.md` §18.2) and the 2.20 m `Counter`. The Phase 2 card `Backdrop_placeholder` is removed from `jar_v0.glb` and `verify_glb.py` (art-director's change, landing with the next merge). `jar_view.gd` still looks the node up and hides it; that lookup finds nothing afterwards and can go (T2).
- **Places (Phase 4, `art-direction.md` §19, agreed with `art-director`).**
  - Each place is a light preset plus a set swap around the jar. `assets/3d/places.glb` holds `Place_Proofing_Box` and the Empties `Spot_Window_Sill` and `Spot_Proofing_Box`. `window_sill` reuses `Kitchen_Wall` with a second atlas.
  - The view reads `StarterSnapshot.location` from `state_changed`. No new Bus signal or `VisualParams` field. `&""` or an unknown id shows the counter.
  - **The jar root stays at the origin.** The view offsets the place set by minus the spot's translation, because the camera aims at world-space targets (`HOME_TARGET`, `JarGeometry.FLOOR_Y_M`).
  - Acceptance:
    - a ray check per place with 0 misses, and no set mesh between the camera and the jar over the whole orbit and every focus preset
    - the visible set within D-031's 16k triangles, with under 30 draw calls
    - `places.glb` checked by `verify_glb.py`

### 8.2 Day and night: one curve (D-043, D-049)
- **`NightFade`** (`src/core/night_fade.gd`, T1) is the one shared night curve, a pure function of local seconds of day: 0 by day, 1 at night. Night eases in from 17:00 to 17:20 and out from 06:00 to 06:20 (smoothstep), per `art-direction.md` §3.
- **Callers.** `Session.get_night_factor()` for now (it follows the debug time scale), and `NightFade.at_unix(frame.at_unix, offset)` for a time-lapse frame. T2's lighting and T3's palette (`surface` to `surface_night`) both read it, so they change together.
- **Slice lighting is day and night only** (D-049): one axis. `NightFade.preset_weights()` already returns morning, afternoon and night weights for Phase 4's `morning` preset; the slice doesn't use it.
- Status on `phase-3-slice`: T2 uses it (111f37b). T3's palette still uses its own `UiPalette.night_blend_at()`, a linear fade from 16:50 to 17:10. T3's unmerged branch already reads `get_night_factor()`; `night_blend_at()` should go when it lands.

## 9. Input routing

| Rule | How |
|---|---|
| A touch belongs to what it started on | GUI consumes presses that start on a `STOP` Control. The camera **claims** a finger index when it sees that index's `InputEventScreenTouch` press in `_unhandled_input`. It then reads that index's drags and release in **`_input`**, because a drag that starts on the 3D view stops reaching `_unhandled_input` once the finger crosses a `STOP` Control [spike]. Unclaimed indices are ignored |
| What blocks the jar | Layout roots and the **top** HUD plate use `MOUSE_FILTER_IGNORE`, so a drag starting there can orbit. The **action bar plate**, cards, toasts and sheets use `STOP` across their whole area, so a near-miss between bar buttons or a tap on card text never reaches the 3D view (`ux-design.md` §6) |
| An open sheet blocks the 3D view | Every sheet has a full-screen scrim with `MOUSE_FILTER_STOP`. It also emits `Bus.sheet_opened` so the camera kills inertia |
| The time-lapse | T2 turns camera input off between `time_lapse_started` and `time_lapse_finished`. "A tap anywhere skips" (`ux-design.md` §12) is a T3 full-screen `STOP` layer plus the skip pill, both sending `Bus.time_lapse_skip_requested` |
| Orbit | One finger, `screen_relative`, with inertia. Yaw free, pitch clamped (limits owned by ux and art) |
| Pinch | Our own: two tracked indices, distance ratio to zoom. iOS sends no `InputEventMagnifyGesture` from touch |
| Double tap | Reset to home pose |
| Desktop testing | `input_devices/pointing/emulate_touch_from_mouse = true`. Keep `emulate_mouse_from_touch = true` (default) so Buttons get presses on phones. With both on, there are no duplicate events: one press and release gives exactly 2 `ScreenTouch` and 2 `MouseButton` events, and the camera reads only the touch events [spike] |

### 9.1 UI structure (constraints from `docs/ux-design.md` §12, §17 and §19)

- **One Theme**, `src/ui/theme/sourdough_theme.tres`, covers all 18 components. Default-looking controls never ship. Color roles: `surface`, `surface_alt`, `ink`, `ink_muted`, `accent`, `on_accent`, `outline`, plus five status tones. Hex values come from `art-director` and `ux-designer`.
- **Text size** (100%, 125%, 150%) scales Theme font sizes only, never `content_scale_factor`. Every text container grows vertically.
- **Event display** (T3) takes `Session.event_raised` and `event_withdrawn` and enforces the display rules: nothing interrupts an open sheet, at most one `attention` on screen, order attention then nudge then info. `event.presentation()` picks toast, card or sheet. Admission caps stay in the pure `EventScheduler`, and release in `Session` (§7). The UI only decides when to show. With `keep_messages` on, toasts and cards stay until dismissed.
- **Actions while not ready.** Until `session_ready` or `resumed`, T3 keeps the action bar disabled and quiet, because `apply()` refuses with `REASON_NOT_READY` (D-050).
- **Night palette**: `Session.get_night_factor()` (§8.2).
- Status, hint, smell, inspection, forecast and the time-lapse read only `Session` outputs (snapshots, readouts, `CatchUpResult`), never their own logic.
- **Accessibility**: every interactive Control sets `accessibility_name` through `tr()` now. The property exists in 4.7.2 **[ran]**. Mobile screen readers arrive with 4.8 (D-012).

## 10. Localization

- **`src/i18n/en.csv`** (columns `keys,en`) is the shipped catalog. It is **generated** from every `Key | Text | Max` row in `narrative.md`, `events-catalog.md` and `game-copy.md` (614 strings at wave A) by a build script that `narrative-designer` owns. The build fails on any error from narrative's copy checker (lengths, unique keys, banned words, mold lines say "discard"). The script strips `(sci)` review marks and converts straight quotes to curly ones (the Theme font must include U+2018, U+2019, U+201C, U+201D; `ux-designer` checks). Nobody hand-edits `en.csv`.
- Each code track may add **placeholder** keys only in its own file: `src/i18n/pending_core.csv`, `pending_view.csv`, `pending_ui.csv`. `narrative-designer` moves them into the docs (and so into `en.csv`) in a copy pass, and the track then deletes its row. No file has two writers.
- **Registration happens at runtime, not in `project.godot`** (D-039). `I18nLoader.load_all()` (`src/core/i18n_loader.gd`) is called from `Session._ready()`, is idempotent, and tests that need `tr()` may call it too:
  - `en.csv` uses the `csv_translation` importer, which writes `src/i18n/en.en.translation` (git-ignored, so a fresh checkout needs `--import`, which §12 requires anyway). The loader adds it with `TranslationServer.add_translation()` once it exists. Listing it in `project.godot` made a fresh `--import` log "Cannot open file", because the editor loads project translations before the first import has produced them (t1-sim-core).
  - The three `pending_*.csv` files use the `keep` importer, so they produce no `.translation` file. The loader parses each `keys,en` CSV itself (`FileAccess.get_csv_line()`, RFC 4180 quoting) and registers it only when it has rows. A header-only CSV given to the CSV importer logs "Locale 'en' does not contain any translation" (t1-sim-core).
  - `internationalization/locale/translations` stays unset.
- **Key format** (narrative's, already used by 614 strings): `^[A-Z][A-Z0-9_]*$`, an area prefix, then canonical ids uppercased. Examples: `STATUS_AT_PEAK_WORD`, `SMELL_YOGURT_2`, `INSPECT_BUBBLES_...`, `ACTION_...`. Keys are unique across all four CSVs.
- Code builds keys from canonical ids with one helper, `Keys.status_word(state_id)` and so on (`src/core/keys.gd`), so the uppercase mapping lives in one place.
- sim returns keys plus args. ui calls `Session.format_text(key, args)` (`Keys.format()` with the device's UTC offset): it translates args that are keys, and turns `time_unix`, `start_unix` and `end_unix` into a local `{time}`, `{start_date}` and `{end_date}` built from tr keys (US English pattern, D-003). Scene labels hold keys, with auto-translate on.
- Plurals: CSV plural support is **[unverified]**. MVP copy avoids count-dependent grammar or uses two keys (`.one` and `.other`).
- `tests/unit/ui/test_i18n_keys.gd` scans `.gd` and `.tscn` files for key literals and fails on any key missing from the CSVs.
- Lint (owned by `qa-engineer`, LINT-04 and LINT-06): key format, uniqueness across the CSVs, and the `Max` length column.

## 11. Performance and battery budgets

Phone numbers are targets. Nothing is measured on a phone yet (D-004).

| Budget | Target | Measured so far |
|---|---|---|
| Frame, interacting | 60 fps: CPU 8 ms, GPU 10 ms on a 2021 mid-range phone | Mac estimate at iPhone 17 Pro pixels, MSAA 4x: CPU 0.12 to 0.16 ms p50. GPU (Vulkan only) Tier A 3.60 / 6.34 ms p50 / p99, Tier B 4.76 / 6.46 [spike] |
| 3D resolution and AA | Start at `scaling_3d_scale` 0.75 and MSAA 2x until Phase 5 phones | 0.75 scale: GPU p50 3.63 to 2.34 ms (-35%). MSAA 4x costs 0.44 ms (3.63 vs 3.19 with it off) [spike] |
| Evidence protocol | Mac: GPU time from Vulkan (MoltenVK) only, plus frame time on Metal and Compatibility. Every number labeled "Mac estimate". Phone: re-measure as soon as a device exists (D-004) | Metal, opengl3 and ANGLE report no GPU time in 4.7.2 [spike] |
| Frame, idle | `Engine.max_fps = 30` after 3 s with no touch and no tween. Back to 60 on `interaction_started` | `Engine.max_fps` settable at runtime **[ran]** |
| Opaque full-screen UI (journal) | Hide `World` (no 3D draw) | |
| Catch-up, 14 days | 250 ms on the Mac, and never blocking the first jar frame | **229 to 230 ms** median with the 8 slice rules (T1, 2a6d063: Apple M4, headless editor binary, 9 runs in two interleaved rounds, Mac estimate), down from 292 to 296 ms before the cost work in §5.4. 206 ms with no rules (D-042). On a worker thread for 2 h or more (D-050) |
| Launch to first frame of the jar | 2 s on a phone | |
| Save | 128 KB or less, write under 10 ms | About **104.6 KB** from day 60 to day 365 in T1's long-play probe, held by the journal's 100 KB byte cap (9551f26, SAVE-13, `data-models.md` §6). Write time not measured yet |
| Scene | 16k tris or fewer, under 10 draw surfaces for the jar (art budget), under 30 draw calls total | `jar_v0.glb`: max 4 draw calls on Mobile, 10 on Compatibility [spike] |
| Screen | `display/window/energy_saving/keep_screen_on = false` (4.7.2 default is **true [ran]**) | |

- **Catch-up off the main thread (D-042's fallback, on since D-050).** The Mac passes the budget, but a phone is likely several times slower **[unverified, D-004]**, so the app never makes the first jar frame wait:
  - `boot_async()` and `resume_async()` load and show the saved state at once (`state_changed`), then, when the clock rules call for 120 steps (2 h, `ASYNC_MIN_STEPS`) or more, run `CatchUp.run` as a `WorkerThreadPool` task on copies of the starter, environment, history and ledger. Shorter catch-ups take a few milliseconds and stay synchronous.
  - While it runs: `is_catching_up()` is true, `apply()` refuses with `REASON_NOT_READY`, and the grid tick does nothing. `Session._process` polls the task, then swaps the copies in on the main thread and continues exactly like `boot()` or `on_resume()`, ending in `session_ready` or `resumed`.
  - The result and signals are byte-equal to the synchronous path (`tests/unit/core/test_catch_up_async.gd`). `CatchUp` is pure, touches only the objects passed in, and the rule registry is stateless, so no locks are needed.
  - Measured: `session_ready` arrived after 37 frames with the main loop running throughout (Mac estimate, D-050).
  - `wait_for_catch_up()` blocks until done. `on_background()`, `set_debug_time_scale()` and `shutdown()` call it, so a pause during a long catch-up saves the finished result. On a slow phone that wait happens inside the pause notification **[unverified on device]**.
  - Tests use synchronous `boot()` and `on_resume()`, and `Session.async_catch_up = false` turns the worker path off.
- **Check still missing.** No automated test times a 14-day catch-up with the full registry; the 230 ms comes from T1's one-off runs. A `tests/perf/` timing test (QA, labeled Mac estimate) and a first-phone measurement (D-004) remain to do.
- `low_processor_mode` is **not** used for the main scene. It only redraws on change, and the jar always breathes. It may be used for an opaque full-screen screen later.
- No physics nodes. No `_process` on nodes that only react to signals.

## 12. Testing

Command for humans and CI: **`tests/run.sh`** (owned by `qa-engineer`). It:
1. runs `godot --headless --path . --import`. **Required**: in a fresh checkout without `.godot/`, `class_name` types fail to resolve under `-s` and the run **exits 0** **[ran]**.
2. runs `godot --headless --path . -s res://tests/run_tests.gd -- [--filter=<substring>]` under an outer `perl -e 'alarm 300; exec @ARGV'` timeout. A runtime error directly in `_init` hangs **[ran]**.
3. passes only if the exit code is 0 **and** the last stdout line is the runner's `RESULT:` line with 0 failed. The exact line format, including skipped counts, is defined by `test-plan.md` R-5 and R-6. A parse error in the runner itself exits 0 **[ran]**.

`run_tests.gd` contract (all **[ran]** in 4.7.2):
- Runs from `_initialize()`, not `_init()`.
- Finds `tests/**/test_*.gd` recursively and `load()`s each one. A parse error gives a non-null script with `can_instantiate() == false`, which counts as FAIL. That includes `untyped_declaration` promoted to an error.
- Registers a `Logger` subclass with `OS.add_logger()`. Any `_log_error` during a test (a null call, `push_error`, a failed `assert`) fails that test. Needed because a runtime error aborts the test function silently and the runner carries on.
- A test with zero assertions fails.
- `quit(1)` on any failure gives exit 1.

`tests/run.sh --strict` also fails on any skip, and phase exit gates use it (D-041). Suites that wait for T1 pieces check `Milestones.has(id)` (`src/core/milestones.gd`; Phase 3 added `p3_contracts` and `p3_rules`).

Seams for `qa-engineer`: `Clock` and `FakeClock`; `sim_rng` injected (the only RNG); `SaveStore.new(base_dir)` plus `fault_point` (`before_tmp_write`, `mid_tmp_write`, `before_rename`, `after_rename`); `SaveStore.load_from_path()`; `--fixture=`; `Session.dump_state(path)`; pure entry points (`Sim.step`, `Sim.apply_feed`, `StateDeriver.derive`, `VisualMapper.from_state`, `EventRules.evaluate`, `EventRules.process`, `EventScheduler.admit`, `SmellModel.read`, `Inspection.read`, `CatchUp.run` and `run_with_rules`, `Forecast.peak_window`, `FeedPlanner.plan`, `ReturnSummary.build`, `NightFade.factor`); `Session.on_background()` and `on_resume()`; `boot_async()` plus `wait_for_catch_up()` for the worker path; `Session.shutdown()` (debug) to boot again in one process; `DevOverlay.session` to drive a test session; a `time_override` uniform plus `--capture=<png>`. `--perf-log=<csv>` is parsed but PerfLog isn't built.

## 13. Project settings (set in the Phase 2 contracts commit)

`project.godot` is committed in the exact form Godot 4.7.2 writes, so an import or a run leaves no diff (D-046). That form drops every comment and every key equal to the engine default. Four rows below are defaults and so are **not in the file**: stretch mode `disabled`, `rendering_method.mobile`, `fallback_to_opengl3` and `inferred_declaration`. `tests/unit/core/test_project_settings.gd` pins every row, checks that no hand-written comment is in the file, and checks the `dev_overlay` action.

| Setting | Value | Why |
|---|---|---|
| `display/window/handheld/orientation` | `1` (portrait) | Default 0 is landscape **[ran]** |
| `display/window/size/viewport_width` / `_height` | 390 / 844 | Desktop test window only. On phones the window is the screen |
| `display/window/stretch/mode` | `disabled` | `ux-designer` constraint: 1 UI unit = 1 pt or dp, layout at the real logical size (360 to 440 wide), not a stretched base. At boot `Main` sets `get_window().content_scale_factor = DisplayServer.screen_get_scale()` (API exists **[ran]**; Android return value is being checked in the spike **[unverified]**) |
| `rendering/renderer/rendering_method` and `.mobile` | `mobile` | §8.1 |
| `rendering/textures/vram_compression/import_etc2_astc` | `true` | Mobile texture formats (default false **[ran]**) |
| `rendering/scaling_3d/scale` | `0.75` | Starting value until Phase 5 phone numbers (ADR-011) |
| `rendering/anti_aliasing/quality/msaa_3d` | `1` (2x) | Same. Default 0 is off **[ran]** |
| `debug/gdscript/warnings/untyped_declaration` | `2` (error) | Hard rule 4. Errors under `-s` too **[ran]** |
| `debug/gdscript/warnings/unsafe_property_access`, `unsafe_method_access` | `2` | Typed code stays typed |
| `debug/gdscript/warnings/unsafe_call_argument`, `unsafe_cast` | `1` (warn) | Save decoding reads Variants. Errors here would force `@warning_ignore` everywhere |
| `debug/gdscript/warnings/inferred_declaration` | `0` | `:=` is typed and allowed |
| `input_devices/pointing/emulate_touch_from_mouse` | `true` | Desktop testing |
| `application/config/quit_on_go_back` | `false` | Back closes sheets first (§6.3) |
| `display/window/energy_saving/keep_screen_on` | `false` | Battery |
| `internationalization/locale/translations` | **unset** | Catalogs register at runtime through `I18nLoader` (§10, D-039) |
| `autoload` | `Bus`, `Session` | §3.1 |
| `input/*` | `dev_overlay` (F3) only | Until UI tracks need more (D-042) |

## 14. Phase 2 and 3 file ownership

Goal: at least three tracks in parallel git worktrees, with no file written by two tracks.

### 14.1 Tracks

| Track | Owns (writes) | Reads |
|---|---|---|
| **T1 sim and core** | `src/sim/**` (except `src/sim/events/rules/**`), `src/core/**`, `src/main/**` (except `src/main/dev/**`), `data/**`, `src/i18n/pending_core.csv`, `tests/unit/sim/**` (except `tests/unit/sim/rules/**`), `tests/unit/core/**`, `project.godot`, `tools/build/**` (t1-toolchain, D-044) | everything |
| **T2 view and shaders** | `src/view/**`, `src/i18n/pending_view.csv`, `tests/unit/view/**`. Also owns Compatibility color parity (the per-renderer `Environment` presets in `src/view/`), measured against the `art-direction.md` §3 "Reference look" table and signed off by `art-director` | `src/sim` types, `Bus`, `Session` API, `assets/3d/**` |
| **T3 UI** | `src/ui/**`, `src/i18n/pending_ui.csv`, `tests/unit/ui/**` | `src/sim` types, `Bus`, `Session` API |
| **T4 events content** (D-032 split, Phase 3) | `src/sim/events/rules/**` (the rules, `RuleIndex` with its order, `RuleFacts`), `tests/unit/sim/rules/**` | `src/sim/**` |
| Integrated captures | `src/main/dev/**` (`integrated_capture.gd` and `.tscn`, 4d08ff9). Written outside T1, so this row records it; director to confirm the owner | everything |
| Narrative | `src/i18n/en.csv` (generated) and its build script in `tools/i18n/` | the three narrative docs |
| QA | Everything under `tests/` except `tests/unit/<track>/**`: `run_tests.gd`, `run.sh`, `runner_selftest/`, `lib/`, `fixtures/`, `golden/`, `property/`, `save/`, `clock/`, `integration/`, `ui/`, `lint/`, `visual/`, `perf/` (layout from `test-plan.md` §2) | everything |
| Art | `assets/3d/**`, `art/**` | |

### 14.2 Shared files and their single owner

| File | Owner | Others |
|---|---|---|
| `project.godot` (settings, autoloads, input map) | T1 | Request changes from T1. It is stable under Godot's rewrite (§13, D-046), so an import or a run leaves no diff. If one appears anyway, don't commit it: tell T1, because it means a setting drifted |
| `src/core/bus.gd` (ui and view contract) | T1 writes it; the signal list comes from §3.3 | Additions by request, so both T2 and T3 see them |
| `src/sim/events/rules/rule_index.gd` (the registry list and tie order) | T4 | `EventRules.registry()` (T1) returns it unchanged. Order changes need a decision (D-048) |
| `src/sim/visual_params.gd` (sim and view contract) | T1 | Fields frozen from `data-models.md` §7. T2 requests changes |
| `src/core/game_session.gd` public API | T1 | Signatures frozen from §3.3 and §4 |
| `src/main/main.tscn` | T1 | Instances `world.tscn` and `ui_root.tscn` by path only, so T2 and T3 edit their own scenes freely |
| `.gitignore`, `.gitattributes` | director | |
| `export_presets.cfg` | T1 (Phase 5 release work) | Contains no secrets. Credentials stay in `.godot/` |

### 14.3 How parallel work starts
1. **Contracts commit (T1, first, alone):** `project.godot`; both autoloads; every public `class_name` file from `data-models.md` with real fields and stub methods; `GameSession` with the full public API (stub logic, which loads a fixture); `bus.gd` with all signals; the generated `en.csv` plus the three empty pending CSVs, all registered at runtime by `I18nLoader` (§10); empty `world.tscn` and `ui_root.tscn` instanced by `main.tscn`.
2. Then T1, T2 and T3 branch from that commit into worktrees. T2 develops against a `VisualParams` scrubber scene. T3 develops against `--fixture=` saves and the stub session.
3. Every worktree runs `tests/run.sh`, which includes the `--import` step. Each track commits the `.uid` and `.import` files for its own paths only.
4. Contract changes after the commit: ask T1 (or me) by message, and T1 lands them as a small commit that the others rebase onto.
