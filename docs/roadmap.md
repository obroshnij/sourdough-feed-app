# Roadmap

Owner: director. Phases 2 to 5, built from [`mvp-scope.md`](mvp-scope.md), [`architecture.md`](architecture.md) §14 and [`test-plan.md`](test-plan.md). Each phase works on its own branch, and merging waits for the user's review (D-014).

## How every phase runs

- **Ownership:** only the owner writes a file (architecture §14, D-032). Code tracks work in separate git worktrees and rebase onto contract commits from T1.
- **Tracks:**
  - **T1** sim and core, also the owner of `project.godot`, the autoloads and the public API
  - **T2** view and shaders
  - **T3** UI
  - **QA**: `tests/` except each track's own unit tests
  - **Narrative**: `tools/i18n/` and the generated `en.csv`
  - **Art**: `art/` and `assets/3d/`
- **Done means tested:** a feature is done when its tests pass headless, `tests/run.sh` (which imports first) is green, and the matching acceptance rows pass. Nobody reports "works" without the command and its output.
- **Decisions** go into [`decisions.md`](decisions.md). The director settles disagreements.

## Before Phase 2 starts: needs the user's OK

| Download | Size | Why | Needed by |
|---|---|---|---|
| Godot 4.7.2 export templates (`.tpz` from the official Godot release on GitHub, checked against SHA512-SUMS) | 1,281 MB | Any iOS simulator or Android build, the shader baker, release checks | Phase 2 day-1 dry run |
| Figtree font (SIL OFL, from the Google Fonts repository) | under 1 MB | UI text (D-029) | Phase 2, T3 |
| Fraunces font (SIL OFL, from the Google Fonts repository) | under 1 MB | Starter name and journal titles, if it measures narrow enough | Phase 2, T3 |
| Android SDK platform 36, build-tools 36.1.0, cmdline-tools, NDK | a few GB | Gradle builds and the notification plugin. Prebuilt APK exports don't need them. | Phase 4 (notifications), Phase 5 |

## Phase 2: Foundation (branch `phase-2-foundation`)

**Goal:** a running Godot project with the real sim, clock, saves and the jar on screen, and green tests.

1. **Contracts commit (T1, alone):**
   - `project.godot`: portrait, stretch, the Mobile renderer, typing warnings as errors, translations.
   - The two autoloads, `Bus` and `Session`.
   - Every `class_name` from `data-models.md`, with real fields and stub methods.
   - The `GameSession` API, with stubs that load fixtures.
   - The generated `en.csv` and the three empty `pending_*.csv` files.
   - `main.tscn` instancing empty `world.tscn` and `ui_root.tscn`.

   QA lands `tests/run.sh`, the runner with its `Logger`, the runner self-tests and LINT-01 in the same window.
2. **Parallel worktrees:**
   - **T1:**
     - the sim in GDScript, matching the scientist's reference script (test vectors V1 to V20 within the spec's tolerances)
     - `time_policy`, the clock seams, `SaveStore` and its codec, catch-up and `StarterPresets`
     - the event engine with no rules yet
   - **T2:**
     - the jar scene from `assets/3d/jar_v0.glb`
     - glass Tiers A and B and the starter shader, both lifted from the spike
     - orbit and pinch
     - the quality-tier switch
     - a `VisualParams` scrubber scene
   - **T3:**
     - the Theme (palette with its night variant, Figtree)
     - the component inventory from ux-design
     - the HUD shell with the status pill and bottom bar, driven by fixture saves
   - **QA:** golden, property, save and clock suites, filled in as T1 lands.
   - **Narrative:**
     - move the copy checker and the `en.csv` build into `tools/i18n/`
     - add the "away more than 14 days" summary line (D-024)
   - **Art:**
     - the 42 icon files (D-034)
     - the kitchen set beyond the placeholder backdrop
     - a lighting pass against Godot screenshots
3. **Toolchain dry run (day 1 after templates):**
   - Export to the iPhone 17 Pro simulator (Compatibility only) and the Android emulator (prebuilt APK).
   - Time cold start with the shader baker (export without `--headless`).

**Exit criteria:**
- `tests/run.sh` is green.
- The sim's test vectors pass.
- The jar renders every state preset on the Mac in both renderers and on the iOS simulator.
- Save, load and catch-up are proven by tests.
- No file was written by two tracks.

## Phase 3: Vertical slice (branch `phase-3-slice`)

**Goal:** the 12 items in `mvp-scope.md`, with AC-01 to AC-12 passing.

- **T1:**
  - actions through `Session.apply()`
  - the 6 slice events and `mold_found`
  - the return summary and the journal model
  - the new-game start and naming
  - the debug time scale
- **T2:**
  - live `VisualParams` easing
  - state transitions, idle breathing, bubble pops (MultiMesh)
  - smell wisps, camera moves for inspection and the mold close-up
  - the time-lapse playback
- **T3:**
  - the feed sheet with the schedule question, discard in grams and the mix
  - the environment sheet (places)
  - the smell moment and card
  - inspection chips
  - event toasts, cards and sheets
  - the away summary, the minimal journal and naming
- **QA:** integration tests, UI scripts, the manual checklists, and reference screenshots against `art/previews/`.

**Exit:** every acceptance row passes, and the user plays a build on the simulator.

## Phase 4: Polish and the rest of the MVP

- Guided onboarding with the sped-up demo and the skip path.
- The P1 content from `mvp-scope.md`.
- The "warning signs" notification behind the `Notifier` wrapper (D-007, D-025).
- Audio, the iOS haptics plugin, VFX and transitions.
- Battery work: a lower frame cap when idle, and low-processor mode where it fits.
- The upgrade to Godot 4.8 stable, then a screen-reader pass with VoiceOver and TalkBack.

## Phase 5: Mobile validation

- iOS and Android builds across the device matrix: iPhone SE (3rd gen), 17e, 17 Pro and 17 Pro Max simulators, plus Android emulator sizes.
- Offline and airplane mode, a killed app mid-save, and clock changes on device.
- Battery and thermals over a 15-minute session. These need a real phone; until there is one, the numbers stay labeled as estimates (D-004).
- Store readiness: icons, a privacy statement (no data collected), age rating.

## Top risks

| Risk | Mitigation |
|---|---|
| Glass and bubbles too slow on mid and low Android phones | Quality tiers from day one. Measure on a real device as soon as one is available. Until then, the Mac numbers are estimates. |
| The Compatibility look falls short (banding, no refraction blur) | Tier A is designed for Compatibility. Check the iOS simulator in Phase 2, which runs only Compatibility. |
| The GDScript sim drifts from the reference script | The numbered step order in sim spec §7, plus test vectors V1 to V20 with tolerances. |
| Save or clock bugs on devices | The quiet loader, quarantine and re-anchoring (D-024), plus the save and clock suites. Kill-mid-save tests on device in Phase 5. |
| Notification plugin upkeep | The `Notifier` wrapper and a kept copy of the plugin source (D-007). |
| Scope creep from P1 and P2 | `mvp-scope.md` wins. New ideas become rows in `decisions.md` before any work starts. |
