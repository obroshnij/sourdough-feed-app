# Technical decisions

Owner: `tech-architect`. Status: **draft v0, wave A** (2026-11-26).
Each entry maps to a row in `decisions.md` where one exists. Status: **accepted** (evidence in hand), **proposed** (our bet, evidence pending), **amends D-0xx** (changes a logged decision; the director updates the log).
Evidence tags: **[ran]** = headless run in a scratch project (see the verification log at the end), **[src]** = read in the `4.7.2-stable` source, **[web]** = cited page, **[spike]** = `godot-developer`'s jar spike, **[unverified]**.

## Summary

| ADR | Topic | Log | Status |
|---|---|---|---|
| 001 | Renderer: Mobile plus Compatibility tier | D-008 | proposed (spike pending) |
| 002 | Glass: opaque interior, two-pass glass, Tier A and B | D-009 | proposed (spike pending) |
| 003 | Starter deformation: one shader fed by `VisualMapper` | D-010 | proposed (spike pending) |
| 004 | Custom headless test runner | D-011 | **accepted**, with a required wrapper |
| 005 | Save format and atomic write | D-013 | **accepted, amends D-013** |
| 006 | Time model and clock rules | D-006, D-013 | **accepted, amends D-013** |
| 007 | Local notifications after the slice | D-007 | proposed, deferred |
| 008 | Accessibility and the 4.8 upgrade | D-012 | accepted, with a device-test gate |
| 009 | Dependency policy | | accepted |
| 010 | Export and toolchain | D-016 | proposed |
| 011 | Performance and battery | | proposed (spike pending) |
| 012 | Layers, two autoloads, contracts commit | | accepted |
| 013 | Events: pure scheduler, two RNG streams | | accepted (agreed with `game-designer`) |
| 014 | Localization: generated `en.csv` plus per-track pending CSVs | D-003 | **accepted** (confirmed by `narrative-designer`) |
| 015 | UI scale: 1 unit = 1 pt or dp | | proposed (spike pending) |

---

## ADR-001 Renderer (D-008)
- **Context.** Mobile has refraction-friendly screen textures and better color. Some Android devices lack usable Vulkan.
- **Options.** (a) Mobile only. (b) Compatibility only. (c) Mobile primary with a lighter Compatibility tier.
- **Decision.** (c). `rendering_method = mobile`. Keep `rendering/rendering_device/fallback_to_opengl3 = true`. `QualityTier` picks the tier from `RenderingServer.get_current_rendering_method()`.
- **Consequences.** Every shader must compile and look acceptable in both renderers. CI renders nothing (headless draws nothing), so visual checks are captures on the Mac.
- **Evidence.** `fallback_to_opengl3` exists and defaults to `true` in 4.7.2 **[ran]**. `rendering_method.mobile` defaults to `mobile` **[ran]**. `get_current_rendering_method()` exists **[ran]**. Frame timings for Mobile+A, Mobile+B and Compat+A: **pending [spike]**.
- **Revisit if** Compatibility Tier A is under 60 fps on the Mac at phone resolution, or Tier B adds more than 2 ms GPU over Tier A.

## ADR-002 Glass (D-009)
- **Context.** Godot sorts transparent objects by origin, so transparent things inside the jar would flicker in draw order.
- **Decision.** Everything inside the glass is opaque: the starter, the liner streaks (alpha scissor) and the hooch band. `Jar_Glass` is the only transparent mesh: one node, surface 0 outer and surface 1 inner (art contract), drawn with back faces first (`cull_front`, `render_priority -1`), then front faces (`cull_back`, `+1`). Tier A: fresnel, specular, small cubemap. Tier B (Mobile only): plus screen-texture refraction on the front pass, behind `#if CURRENT_RENDERER == RENDERER_COMPATIBILITY` and a `tier_b` uniform.
- **Evidence.** Art contract agreed by message (thickness 3.5 mm, inner normals face the axis). Screenshots and the compile-time define: **pending [spike]**.
- **Revisit if** the inner surface drawn in the back pass looks wrong over the starter. Fallback: split `Jar_Glass_Outer` and `Jar_Glass_Inner` into separate nodes (art-director offered this).

## ADR-003 Starter deformation (D-010)
- **Decision.** One `ShaderMaterial` on `Starter_Body`. Vertex displacement from `VisualParams` uniforms, which share the field names in `data-models.md` §7. Normals come from the height function. `custom_aabb` covers rise 3.0 plus the dome. Shape keys only for hand-made hero shapes.
- **Mesh contract.** Authored 40 mm tall, 64 segments, dense top. UV2.x = radial (0 center to 1 wall), UV2.y = height fraction, so the shader sets `VERTEX.y = UV2.y * level` without knowing the authored height. glTF node extras (`inner_radius_m` and so on) import as `get_meta("extras")` **[ran]**. `jar_geometry.gd` mirrors them and asserts at load.
- **Evidence.** The D-010 claim of "a reported normals bug in 4.7" for blend shapes: **[unverified]** by me. Culling pops and normal quality: **pending [spike]**.
- **Revisit if** procedural bubbles cost more than 1.5 ms GPU at Tier A on the Mac.

## ADR-004 Test runner (D-011)
- **Context.** Godot 4.7.2 headless `-s` exits 0 in several broken cases, so a naive runner gives false passes.
- **Decision.** No framework. `tests/run_tests.gd` plus the wrapper `tests/run.sh` (owned by `qa-engineer`), with the contract in `architecture.md` §12: `--import` first, an outer alarm, a `Logger` that fails any test that logs an error, `load()` plus `can_instantiate()` per file, run from `_initialize()`, and pass only on exit 0 **and** a final `RESULT: N passed, 0 failed` line.
- **Evidence** (all **[ran]**, and `qa-engineer` got the same results independently):

| Case | Exit |
|---|---|
| Fresh checkout (no `.godot/`), `-s` script using a `class_name` type | **0**, "Identifier SimMath not declared". After `--headless --import`: resolves, correct output |
| Parse error in the `-s` script | **0** |
| `quit(1)` | 1 |
| Test file with a parse error, `load()`ed by the runner | non-null script, `can_instantiate() == false`. Caught |
| `untyped_declaration = 2` with `var y = 5` | parse error (caught as above). Hard rule 4 holds under `-s` |
| Runtime null call inside a test function | function aborts at that line, `call()` returns null, runner continues. A `Logger` via `OS.add_logger()` receives it (`_log_error`, type 2) |
| `push_error()` | reaches the `Logger` |
| Runtime error directly in `_init` | **hangs**. Killed by `perl -e 'alarm 15'`, exit 142 |
| `-- --filter=test_ok` | `OS.get_cmdline_user_args()` sees it |

- **Revisit if** we need mocks of engine classes. Then GUT is the fallback, under ADR-009.

## ADR-005 Save format and atomic write (amends D-013)
- **Context.** Godot's own backup save (temp file then rename, in `FileAccessUnix`) only runs when backup save is enabled, which the editor does **[src]**. Godot never calls `fsync` **[src]**.
- **Decision.**
  1. File = one JSON header line (`format`, `version`, `sha256`, `bytes`) + `\n` + the payload, byte for byte (`data-models.md` §9).
  2. Payload written with `JSON.stringify(payload, "", true, true)`.
  3. Checksum over the stored payload bytes, not a re-serialization.
  4. RNG seeds and states as decimal strings.
  5. Write `save.tmp`, rename `save.json` to `save.prev`, rename `save.tmp` to `save.json`, using **`DirAccess.open("user://saves").rename()`**, never `DirAccess.rename_absolute()`.
  6. Load order `save.json`, `save.tmp`, `save.prev`. The first that verifies wins.
  7. Only a trusted `save.json` (loaded or written this session) rotates into `save.prev`. Anything that fails to load goes to `quarantine/` and is never deleted, except to keep the newest 5 sets. Before a fresh starter is created, all candidates are quarantined (`qa-engineer` findings SAVE-17 and SAVE-06, both data-loss paths in v0 of this design).
- **Why the amendments.**
  - Default `JSON.stringify` writes `1/3` as `0.333333333333333`, which does not round-trip. Full precision does **[ran]**.
  - Parse then stringify is not byte-stable (`1` becomes `1.0`), so a re-serialized checksum would never match **[ran]**.
  - 2^53+1 and a real RNG state lose precision as JSON numbers. As strings they round-trip **[ran]**.
  - `rename_absolute` always uses `ACCESS_FILESYSTEM` with a globalized path **[src: core/io/dir_access.cpp]**. On Android, `ACCESS_FILESYSTEM` is `DirAccessJAndroid`, which goes through JNI to `FileData.rename`, which calls `File.renameTo` **[src]**. `user://` on Android, iOS and macOS is `DirAccessUnix`, which calls POSIX `::rename` **[src: drivers/unix/dir_access_unix.cpp, platform/android/os_android.cpp, drivers/unix/os_unix.cpp via OS_AppleEmbedded]**. POSIX rename replaces the destination atomically.
  - Overwriting rename returns `OK` and replaces the content, for both `rename_absolute` and the instance `rename` **[ran on macOS]**.
- **Consequences.** A kill at any point leaves at least one verifiable file. Tested by the `fault_point` seam. A power cut can still lose the newest save, because there is no fsync; the checksum makes that a fallback, not a corruption.
- **Revisit if** an Android emulator run (Phase 5) shows instance `rename` failing on an existing file **[unverified on device]**.

## ADR-006 Time model and clock rules (amends D-013, implements D-006)
- **Decision.**
  - Unix seconds as `int`. A fixed 60 s step on a grid aligned to Unix time, live and in catch-up.
  - Actions apply at `grid(now)`.
  - The catch-up cap is 14 days. Beyond it, hold the state and jump the anchor.
  - The anchor is `StarterState.sim_time_unix`. Clock rules are in `architecture.md` §5.3: re-anchor when the clock is more than 6 h behind the anchor, and a monotonic guard while foregrounded.
- **Why the amendment.** D-013's "latest clock time ever seen" freezes the starter for years after a mistaken forward jump is corrected (found by `qa-engineer`). Re-anchoring past 6 h fixes that, and small back-then-fix changes stay exact.
- **Consequences.**
  - One long catch-up and many short sessions take identical steps, so the property test is exact.
  - **Known limit (accepted).** If the clock is set back more than 6 h (re-anchor), the player plays a while, then fixes the clock, the next catch-up credits the whole gap, up to the 14-day cap, in one go. That is the price of fixing the freeze without trusted time. A cheat that only fast-forwards a starter is harmless in a single-player offline game. `qa-engineer` CLK-16 asserts the cap.
  - Determinism is promised per build and device. Cross-platform libm differences in `exp` and `pow` are possible and tiny, and saves never move between devices.
  - Catch-up cost: a toy 11-variable step took 1.1 µs, so 14 days (20,160 steps) took 22 ms on an Apple M4 **[ran, Mac estimate]**. Budget 250 ms with the real sim.
- **Revisit if** the scientist's v1 needs sub-minute dynamics, or the real catch-up exceeds budget. Then use a `WorkerThreadPool` task.

## ADR-007 Local notifications (D-007)
- **Decision.** Out of the MVP (vision: after the vertical slice). Define the seam now: `Notifier` (`src/core/notifier.gd`) with `request_permission()`, `schedule(id: StringName, at_unix: int, title_key: StringName, body_key: StringName)`, `cancel(id)` and `cancel_all()`. The MVP ships `NullNotifier`.
- **Evidence.** The candidate plugin by `cengiz-pz` ships as two separate plugins (Android and iOS) behind one GDScript interface. Current asset listings name Godot 4.6, so 4.7.2 and 4.8 compatibility is **[unverified]**. Its own docs warn that delivery can fail when Android battery optimization is on **[web: [Asset Library, Android plugin](https://godotengine.org/asset-library/asset/2547), [iOS plugin](https://godotengine.org/asset-library/asset/3186), [store page](https://store.godotengine.org/asset/cengiz/notification-scheduler-plugin/)]**. An alternative, `kyoz/godot-local-notification`, warns of delays of minutes **[web: [GitHub](https://www.GitHub.com/kyoz/godot-local-notification)]**. An Android plugin needs the Gradle build template.
- **Revisit** after the slice: run the plugin on 4.8 in a spike before adopting it (ADR-009).

## ADR-008 Accessibility and the 4.8 upgrade (D-012)
- **Decision.** Keep D-012: move to Godot 4.8 stable before any store release. Every interactive Control sets `accessibility_name` through `tr()` from day one. Add a release gate: a VoiceOver and TalkBack pass on real devices.
- **Evidence.**
  - 4.7.2 already has `accessibility/general/accessibility_support`, the `accesskit` driver and `Control.accessibility_name` and related properties **[ran]**. That is desktop support, which arrived in 4.5 **[web: [Godot 4.5 release](https://godotengine.org/releases/4.5/)]**.
  - Godot's 4.8 dev 7 post says iOS and Android are gaining native AccessKit support. It notes iOS limitations, including no support for editable text fields **[web: [4.8 dev 7](https://godotengine.org/article/dev-snapshot-godot-4-8-dev-7/)]**.
  - Forum reports say TalkBack did not work with 4.5 on Android **[web: [forum](https://forum.godotengine.org/t/question-about-accessibility-on-android/122578)]**.
- **Consequences.** Naming the starter uses a text field. On iOS under 4.8 that may not be screen-reader accessible: offer a "pick a suggested name" path (flagged to `ux-designer`).
- **Revisit if** 4.8 stable slips past our release window, or device tests fail.

## ADR-009 Dependency policy
- **Decision.** Zero third-party runtime code, addons or plugins in the MVP. Adding one needs an entry here with: the need, alternatives tried, license (MIT, BSD or Apache only), maintenance signal, Godot version support, size, and a wrapper so it can be swapped. Tools outside the game (Blender, Python scripts in `art/`) are not runtime dependencies.
- **Consequences.** Notifications (ADR-007) and GUT (ADR-004 fallback) are the only foreseen candidates.

## ADR-010 Export and toolchain (D-016)
- **Context.** Godot 4.7.2 and Blender 5.3.0 are verified. Export templates (1,281 MB) are not installed. The Android SDK is missing platform 36, build-tools 36.1.0 and the NDK (`CLAUDE.md`).
- **Decision.**
  - Phase 2 needs export templates for the iOS simulator check (D-016), which needs the user's OK to download.
  - Android SDK pieces are needed by Phase 5, and only for a Gradle build. The non-Gradle export needs no NDK **[unverified]**.
  - `import_etc2_astc = true`.
  - Signing material never enters the repo. Godot keeps export credentials in `.godot/export_credentials.cfg`, which is ignored.
  - CI runs `tests/run.sh` on macOS.
- **Revisit** when we move to 4.8 (re-verify every **[ran]** item in this file).

## ADR-011 Performance and battery
- **Decision.** Budgets are in `architecture.md` §11.
  - `Engine.max_fps` is 30 when idle and 60 while interacting (settable at runtime **[ran]**).
  - Hide `World` under opaque full-screen UI.
  - `keep_screen_on = false`. The 4.7.2 default is `true` **[ran]**.
  - No `low_processor_mode` for the 3D scene, because the jar always animates.
  - No physics nodes.
- **Evidence.** Mac frame timings: **pending [spike]**. Phone numbers: none until a phone exists (D-004).
- **Revisit if** idle at 30 fps looks choppy in the breathing animation. Try 40.

## ADR-012 Layers, two autoloads, contracts commit
- **Decision.** The four layers and the dependency rule in `architecture.md` §1. Exactly two autoloads (`Bus`, `Session`). Clock, store and settings are injected objects. Phase 2 opens with a contracts commit (T1) that freezes the public classes, `GameSession` API, `Bus` signals and `project.godot`. Then the parallel tracks in §14.
- **Evidence.** Autoload `_ready` runs after a `-s` script's `_init`, so tests can't rely on autoloads and construct services directly **[ran]**. `class_name` cannot equal an autoload name, hence `Session` and `GameSession` **[unverified as an error message; avoided by design]**.

## ADR-013 Events: pure scheduler, two RNG streams
- **Decision.** Rules, admission caps, cooldowns, quiet hours and the ledger live in `src/sim/events/` and are pure. Local time is an argument. `sim_rng` drives feed jitter only, and `event_rng` drives ambient events only. Presentation timing (don't interrupt a sheet) lives in the UI `EventPresenter`.
- **Why.** Events fire during offline catch-up, and their history changes later eligibility. That only stays deterministic and testable if admission is pure and saved. Separate streams mean a new event rule never changes the starter's outcome.
- **Evidence.**
  - Restoring `RandomNumberGenerator.state` from a string gives the identical next values **[ran]**.
  - Setting `seed` after `state` resets the stream **[ran]**, so restore order matters.
  - Agreed with `game-designer` by message.

## ADR-014 Localization files
- **Decision (revised after wave A).** One shipped catalog, `src/i18n/en.csv`, **generated** from the narrative docs' `Key | Text | Max` tables by `narrative-designer`'s build script. Each code track gets its own `pending_<track>.csv` for placeholder keys, so no file has two writers. Key format `^[A-Z][A-Z0-9_]*$` (narrative's convention). The build converts straight quotes to curly ones.
- **Why revised.** My v0 had per-track CSVs and lowercase dotted keys. But `narrative-designer` had already written 614 strings in UPPER_SNAKE, with a passing format check, and planned a single `en.csv`. `qa-engineer` flagged the conflict (OD-16). Renaming 614 keys buys nothing.
- **Build gate.** The `en.csv` build runs `narrative-designer`'s copy checker first: worst-case lengths, unique keys, banned words, the LINT-06 lists, and mold lines must say "discard". Any checker error fails the build. The checker runs clean on 615 strings today, per `narrative-designer`. Args use `tr(key).format({...})` with the placeholder names in `game-copy.md` §1.3.
- **Ownership gap.** `tools/i18n/` is not yet in `vision.md`'s ownership map. The director should add it under `narrative-designer` for Phase 2.
- **Evidence.** CSV plural support: **[unverified]**. MVP copy avoids it.
- **Revisit if** a second language arrives. Then the generator emits one column per locale.

## ADR-015 UI scale
- **Decision** (constraint from `ux-designer`). Stretch mode `disabled`, and `content_scale_factor = DisplayServer.screen_get_scale()` at boot, so 1 UI unit = 1 pt or dp. Text size scales Theme fonts only.
- **Evidence.** `screen_get_scale`, `screen_get_dpi` and `Window.content_scale_factor` exist in 4.7.2 **[ran]**. Values on Android and iOS: **pending [spike]**.
- **Revisit if** Android returns 1.0. Then derive the scale from `screen_get_dpi() / 160`.

---

## Verification log (what I ran)

Godot `4.7.2.stable.official.ed1daf0bf` on an Apple M4, scratch projects under `/private/tmp/claude-502/.../scratchpad/tech-architect/` (`proj/`, and `fresh1/`, a copy without `.godot/`). Command form: `Godot --headless --path . -s res://tests/<probe>.gd`, exit code read with `echo $?` after a redirect (not through a pipe).

| Probe | What it showed |
|---|---|
| `t_classname.gd` in `fresh1/` before import | Parse errors for `SimMath` and `FlourProfile`, exit 0 |
| same after `--headless --import` | `CLASSNAME OK step=0.0582... flour=rye speed=1.6`; `AUTOLOAD _ready ran` printed after the script's output |
| `run_tests.gd` probe with pass, fail, parse-error and runtime-error cases | `RESULT: 1 passed, 3 failed`, exit 1. Parse-error file: `LOADFAIL ... script_null=false`. Runtime error: `asserts=0 ret=<null>` |
| `--filter=test_ok` | Only that test ran |
| `t_logger.gd` | `errors=1 ... type=2` after a null call, `errors=2` after `push_error` |
| `t_hang.gd` (error in `_init`) under `perl -e 'alarm 15'` | exit 142 |
| `t_io.gd` | `rename_absolute` over an existing file: `OK`, content `NEW`. Default stringify `0.333333333333333` not equal on parse. Full precision equal. `2^53+1` came back `...992`. RNG state as a number came back wrong, as a string right. RNG resume from a saved state gave identical next 3 values. Notification constants 2015, 2014, 2017, 1006 |
| `t_rename2.gd` | `DirAccess.open("user://saves").rename()` over an existing file: `OK`, content replaced (relative and `user://` forms) |
| `t_restringify.gd` | `{"arr":[1,2.5],...,"version":1}` becomes `{"arr":[1.0,2.5],...,"version":1.0}`, `identical=false` |
| `t_perf.gd` (twice) | 20,160 steps of 60 s in 22.1 and 22.4 ms. 4,032 steps of 300 s in 4.6 and 4.4 ms |
| `t_settings.gd`, `t_api.gd`, `t_ui.gd` | Setting names and defaults cited above. `get_current_rendering_method` present. `Engine.max_fps` settable. Typed `Dictionary[StringName, float]` works. `Control.accessibility_*` present |
| `assets/probe.gltf` import + `t_gltf.gd` | Node `extras` became `get_meta("extras")` Dictionaries with the authored values |

Source reads (`gh api repos/godotengine/godot/contents/<path>?ref=4.7.2-stable`): `core/io/dir_access.cpp` (`rename_absolute`, `create_for_path`), `drivers/unix/dir_access_unix.cpp` (`::rename`), `drivers/unix/file_access_unix.cpp` (no fsync, backup save), `drivers/unix/os_unix.cpp` and `drivers/apple_embedded/os_apple_embedded.*` (iOS uses the Unix drivers), `platform/android/os_android.cpp` (`ACCESS_USERDATA` is `DirAccessUnix`, `ACCESS_FILESYSTEM` is `DirAccessJAndroid`), and the Android Java files `FilesystemDirectoryAccess.kt`, `FileAccessHandler.kt`, `DataAccess.kt` and `FileData.kt` (`File.renameTo`).
