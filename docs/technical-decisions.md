# Technical decisions

Owner: `tech-architect`. Status: **draft v0, wave A** (2026-11-26).
Each entry maps to a row in `decisions.md` where one exists. Status: **accepted** (evidence in hand), **proposed** (our bet, evidence pending), **amends D-0xx** (changes a logged decision; the director updates the log).
Evidence tags: **[ran]** = headless run in a scratch project (see the verification log at the end), **[src]** = read in the `4.7.2-stable` source, **[web]** = cited page, **[spike]** = `godot-developer`'s jar spike, **[unverified]**.

## Summary

| ADR | Topic | Log | Status |
|---|---|---|---|
| 001 | Renderer: Mobile plus Compatibility tier | D-008 | **accepted** (spike, Mac estimates); phone check in Phase 5 |
| 002 | Glass: opaque interior, Tier A two-pass, Tier B front pass with refraction | D-009 | **accepted, amends D-009** (spike) |
| 003 | Starter deformation: one shader fed by `VisualMapper` | D-010 | **accepted** (spike) |
| 004 | Custom headless test runner | D-011 | **accepted**, with a required wrapper |
| 005 | Save format and atomic write | D-013 | **accepted, amends D-013** |
| 006 | Time model and clock rules | D-006, D-013 | **accepted, amends D-013** |
| 007 | Local notifications after the slice | D-007 | proposed, deferred |
| 008 | Accessibility and the 4.8 upgrade | D-012 | accepted, with a device-test gate |
| 009 | Dependency policy | | accepted |
| 010 | Export and toolchain | D-016 | proposed |
| 011 | Performance and battery | | **accepted** for phone defaults and the evidence protocol (director ruling); phone numbers in Phase 5 |
| 012 | Layers, two autoloads, contracts commit | | accepted |
| 013 | Events: pure scheduler, no RNG in events | | accepted (agreed with `game-designer` and the scientist) |
| 014 | Localization: generated `en.csv` plus per-track pending CSVs | D-003 | **accepted** (confirmed by `narrative-designer`) |
| 015 | UI scale: 1 unit = 1 pt or dp | | proposed (Mac value in; simulator check in Phase 2) |

---

## ADR-001 Renderer (D-008)
- **Context.** Mobile has refraction-friendly screen textures and better color. Some Android devices lack usable Vulkan.
- **Options.** (a) Mobile only. (b) Compatibility only. (c) Mobile primary with a lighter Compatibility tier.
- **Decision.** (c). `rendering_method = mobile`. Keep `rendering/rendering_device/fallback_to_opengl3 = true`. `QualityTier` picks the tier from `RenderingServer.get_current_rendering_method()`.
- **Consequences.**
  - Every shader must compile and look acceptable in both renderers. CI renders nothing (headless draws nothing), so visual checks are captures on the Mac.
  - **Compatibility renders color noticeably differently** (the starter near white, the counter oversaturated) [spike]. The T2 view track owns the parity work, and `art-director` signs off (director ruling). What the follow-up probe found (`patch_probe.gd`, at_peak, Compatibility vs Mobile) [spike]:
    - **The near-white starter is not a tonemap problem.** Starter saturation stays at 0.03 (Mobile 0.21) under every tonemap, exposure, color, translucency, glass and reflection setting tried. Only `ambient_light_sky_contribution = 0` restores it (luminance within 1%, saturation within 5%), and that blacks out the shadows. **Root cause open.** Next test: a `StandardMaterial3D` stand-in, to rule out the custom shader path. This is a Phase 2 risk for the Compatibility tier's look.
    - Exposure is ignored on Compatibility unless `adjustment_enabled` is on. Turning adjustments on, even at saturation 1.0, switches to a separate tonemap pass and changes luminance (starter 0.847 to 0.727). Treat it as a pipeline switch, and give it a cost run in Phase 2.
    - On Mobile with the sky ambient source, `ambient_light_energy` does nothing, because `ambient_light_color` defaults to black. Presets express ambient as `ambient_light_sky_contribution` or as sky energy.
  - **GPU timing is only measurable on Vulkan.** `viewport_get_measured_render_time_gpu` returns 0 on Metal, opengl3 and ANGLE on macOS in 4.7.2 [spike]. `PerfLog` GPU numbers on the Mac must use `--rendering-driver vulkan` (MoltenVK). For Compatibility, the uncapped frame time is the upper bound.
- **Evidence** [spike]. All are **Mac estimates**: Apple M4, 1206x2622 (iPhone 17 Pro pixels), MSAA 4x, `jar_v0.glb`, state `collapsing`, 60 s scripted orbit. Raw data in `spikes/jar-spike/bench-results/summary.csv`, which I checked against the reported numbers.

  | Combo | CPU ms p50 / p95 / p99 | GPU ms p50 / p95 / p99 | Frame ms p50 / p95 / p99 |
  |---|---|---|---|
  | Mobile, Vulkan, Tier A | 0.12 / 0.17 / 0.19 | 3.60 / 5.87 / 6.34 | 8.33 (vsync) |
  | Mobile, Vulkan, Tier B | 0.16 / 0.20 / 0.22 | 4.76 / 6.22 / 6.46 | 8.33 (vsync) |
  | Mobile, Metal, Tier A | 0.11 / 0.19 / 0.21 | not measurable | 6.68 / 8.43 / 10.44 |
  | Compat, opengl3, Tier A | 0.13 / 0.19 / 0.30 | not measurable | 4.24 / 5.30 / 5.56 (uncapped) |

  Both revisit conditions pass on the Mac. Compatibility Tier A runs at about 236 fps (p99 180 fps). Tier B adds 1.16 ms GPU at p50 (0.35 at p95), under the 2 ms threshold. Also `fallback_to_opengl3` defaults to `true` **[ran]**, and `get_current_rendering_method()` exists **[ran]**.
- **Re-measure on a real device as soon as one exists** (D-004). An M4 at native resolution says little about a 2021 mid-range phone.
- **Revisit if** that device misses 60 fps at Tier A with `scaling_3d_scale` 0.75.

## ADR-002 Glass (D-009)
- **Context.** Godot sorts transparent objects by origin, so transparent things inside the jar would flicker in draw order.
- **Decision.**
  - Everything inside the glass is opaque: the starter, the liner streaks (alpha scissor) and the hooch band. `Jar_Glass` is the only transparent mesh (one node, surface 0 outer, surface 1 inner).
  - **Tier A** (both renderers): back faces first (`cull_front`, `render_priority -1`), then front faces (`cull_back`, `+1`), with fresnel, specular and a small cubemap.
  - **Tier B** (Mobile only): **front faces only**, sampling the screen texture with a normal-based offset, a depth check and an analytic far wall. A back-face pass is pointless here, because the screen copy holds only opaque objects and the front pass overwrites it [spike]. The Compatibility build compiles out the screen-texture code with `#if CURRENT_RENDERER == RENDERER_COMPATIBILITY`.
  - **Switching tiers swaps materials** (a Tier A glass material with no `hint_screen_texture`). It does **not** use a `tier_b` bool uniform: with the bool off, Tier B still costs 4.52 ms GPU against Tier A's 3.63, because the screen copy still happens [spike].
- **Amends D-009** ("Tier B adds screen-texture refraction"): Tier B replaces the two-pass glass rather than adding to it.
- **Evidence** [spike]:
  - The `#if CURRENT_RENDERER` define compiles and branches in both renderers. The compiled uniforms of `glass_front_b` include `refraction`, `jar_axis`, `far_wall_strength` and `refraction_on` on Mobile, and none of them on Compatibility. No shader errors in any log.
  - Glass normals in `jar_v0.glb`: outer 441/441 away from the axis, inner 343/343 toward it.
- **Revisit if** Tier B's analytic far wall reads wrong at extreme orbit angles in Phase 3 captures.

## ADR-003 Starter deformation (D-010)
- **Decision.** One `ShaderMaterial` on `Starter_Body`. Vertex displacement from `VisualParams` uniforms, which share the field names in `data-models.md` §7. Normals come from the height function. `custom_aabb` covers rise 3.0 plus the dome. Shape keys only for hand-made hero shapes.
- **Mesh contract.** Authored 40 mm tall, 64 segments, dense top. UV2.x = radial (0 center to 1 wall), UV2.y = height fraction, so the shader sets `VERTEX.y = UV2.y * level` without knowing the authored height. glTF node extras (`inner_radius_m` and so on) import as `get_meta("extras")` **[ran]**. `jar_geometry.gd` mirrors them and asserts at load.
- **Evidence** [spike]:
  - **`custom_aabb` works and is needed.** Godot culls by it: with a box placed 1 m under the table, the starter vanished (`objects_in_frame` 4 to 3). With the rise-3.0-plus-dome box, nothing popped during the orbit (screenshots `spikes/jar-spike/screenshots/mobile_artglb_aabb_*.png`).
  - **Procedural bubbles cost 0.63 ms GPU at p50** (3.63 to 3.01 ms with bubbles off), under the 1.5 ms threshold.
  - The GLB arrived with every contract name (`Jar_Glass` with 2 surfaces, `Starter_Body`, `Starter_Liner`, `StarterFloor`, `StarterRim`, `Jar_Lid_Loose`, `Jar_Lid_Tight`, `Cloth_Cover`, `Rubber_Band`, `Counter`, `Backdrop_placeholder`), and extras as `get_meta("extras")`.
  - The D-010 claim of "a reported normals bug in 4.7" for blend shapes is still **[unverified]**. It's moot because we use no blend shapes.
- **Revisit if** procedural bubbles exceed 1.5 ms GPU on a Phase 5 phone at Tier A.

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
  2. Payload written with `JSON.stringify(payload, "", true, true)`, with **every float stored as the hex string of its IEEE-754 bits** (`data-models.md` §1). Corrected in wave B, see below.
  3. Checksum over the stored payload bytes, not a re-serialization.
  4. RNG seeds and states as decimal strings.
  5. Write `save.tmp`, rename `save.json` to `save.prev`, rename `save.tmp` to `save.json`, using **`DirAccess.open("user://saves").rename()`**, never `DirAccess.rename_absolute()`.
  6. Load order `save.json`, `save.tmp`, `save.prev`. The first that verifies wins. A winning `save.tmp` is renamed to `save.json` at once. The loader is silent on bad input:
     - `get_file_as_bytes()` to read.
     - SHA-256 over the raw payload bytes, before decoding.
     - `JSON.new().parse()` to parse, never `JSON.parse_string()`, which logs an engine error on bad JSON **[ran]**.
     - `typeof()` checks before typed assignment, because a wrong-typed assignment logs a script error **[ran]**.
     Otherwise every corrupt-file test fails under the runner's Logger.
  7. Only a trusted `save.json` (loaded or written this session) rotates into `save.prev`. Anything that fails to load goes to `quarantine/` and is never deleted, except to keep the newest 5 sets. Before a fresh starter is created, all candidates are quarantined (`qa-engineer` findings SAVE-17 and SAVE-06, both data-loss paths in v0 of this design).
- **Why the amendments.**
  - Default `JSON.stringify` writes `1/3` as `0.333333333333333`, which does not round-trip. Full precision fixes that case **[ran]**, but **not in general**. My v0 evidence was one lucky value. `qa-engineer` found that the 4.7.2 JSON number parser isn't correctly rounded: `0.00038268223404884337` and even the 16-decimal 1.9469610637576158 read back 1 ulp off. I reproduced it: 33,968 of 100,000 log-uniform doubles between 1e-6 and 1e3 came back wrong through full-precision JSON. `String.num_scientific` plus `to_float()` gave the same 33,968. The hex of the 64-bit pattern gave 0 **[ran]**. Without the fix, a save then load changes the starter by 1 ulp, which breaks the exact determinism properties (PROP-01, PROP-02, SAVE-01). Player impact would be nil, but exact tests are what catch port bugs, so the save stays exact rather than tests gaining a tolerance.
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
- **Starting values until Phase 5 phone numbers:** `rendering/scaling_3d/scale = 0.75` and `rendering/anti_aliasing/quality/msaa_3d = 2x`. Both setting names exist in 4.7.2 **[ran]**. On the Mac, scale 0.75 cut GPU p50 from 3.63 to 2.34 ms (-35%), and MSAA 4x costs 0.44 ms (3.19 ms with it off) [spike].
- **Evidence protocol.** On the Mac, take GPU time from Vulkan (MoltenVK) only, plus frame time on Metal and Compatibility, because Metal, opengl3 and ANGLE report no GPU time in 4.7.2 [spike]. Label every number "Mac estimate". Re-measure on a phone as soon as one exists (D-004).
- **Evidence.** CPU is negligible: 0.12 to 0.16 ms p50 in every combo. GPU is 3.6 ms (Tier A) and 4.8 ms (Tier B) at p50 on an M4 at native iPhone 17 Pro resolution [spike, Mac estimate]. No phone numbers until a phone exists (D-004). `godot-developer` cautions that a 2021 mid-range phone could be several times slower.
- **Revisit if** idle at 30 fps looks choppy in the breathing animation (try 40), or Phase 5 phones have GPU headroom (raise the scale toward 1.0).

## ADR-012 Layers, two autoloads, contracts commit
- **Decision.** The four layers and the dependency rule in `architecture.md` §1. Exactly two autoloads (`Bus`, `Session`). Clock, store and settings are injected objects. Phase 2 opens with a contracts commit (T1) that freezes the public classes, `GameSession` API, `Bus` signals and `project.godot`. Then the parallel tracks in §14.
- **Evidence.** Autoload `_ready` runs after a `-s` script's `_init`, so tests can't rely on autoloads and construct services directly **[ran]**. `class_name` cannot equal an autoload name, hence `Session` and `GameSession` **[unverified as an error message; avoided by design]**.

## ADR-013 Events: pure scheduler, no RNG in events
- **Decision.** Rules, admission caps, cooldowns, quiet hours and the ledger live in `src/sim/events/` and are pure. Local time is an argument. The only RNG is `sim_rng`, with one draw per feed (`feed_u`, stored). Event rules take no RNG. `big_bubble` reads `feed_u` (spec §14.1). Presentation timing (don't interrupt a sheet) lives in the UI `EventPresenter`.
- **Revised in wave B.** v0 had a second stream, `event_rng`. The scientist moved `big_bubble`, its only user, into the sim so the jar shows the bubble (hard rule 2), and `game-designer` removed RNG from all rules. One fewer stream to save and test.
- **Why.** Events fire during offline catch-up, and their history changes later eligibility. That only stays deterministic and testable if admission is pure and saved. With no RNG in events, a new event rule never changes the starter's outcome.
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
- **Evidence.** `screen_get_scale`, `screen_get_dpi` and `Window.content_scale_factor` exist in 4.7.2 **[ran]**. On this Mac, `screen_get_scale` is 2.0 and dpi 303 [spike]. iOS and Android values need the Phase 2 simulator and emulator check.
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
| `t_silent.gd` (wave B), with a counting `Logger` | `JSON.parse_string("{not json")`: 1 logged error. `JSON.new().parse()`: `Parse error`, 0 logged. `FileAccess.open` and `file_exists` on a missing file: 0 logged. Typed `var x: float = "high"`: 1 logged script error. Invalid UTF-8 via `get_string_from_utf8`: 0 logged, string mangled |
| `t_float.gd` (wave B) | 100,000 doubles, `pow(10, randf_range(-6, 3))`, seed 42. Wrong after a round trip: JSON full precision 33,968; `num_scientific` through JSON 33,968; `num_scientific` plus `to_float()` 33,968; hex of `encode_double` bytes 0 |
| `t_hex.gd` (wave B) | 0.25 is `000000000000d03f`, 1/3 is `555555555555d53f`, 0.18 is `0ad7a3703d0ac73f`, 150.0 is `0000000000c06240`. All decode back equal |
| `t_bytes.gd` (wave B) | `HashingContext` SHA-256 over the payload bytes read back equals `sha256_text()` of the written string. `get_file_as_bytes` on a missing file: size 0, nothing logged |
| `assets/probe.gltf` import + `t_gltf.gd` | Node `extras` became `get_meta("extras")` Dictionaries with the authored values |

Source reads (`gh api repos/godotengine/godot/contents/<path>?ref=4.7.2-stable`): `core/io/dir_access.cpp` (`rename_absolute`, `create_for_path`), `drivers/unix/dir_access_unix.cpp` (`::rename`), `drivers/unix/file_access_unix.cpp` (no fsync, backup save), `drivers/unix/os_unix.cpp` and `drivers/apple_embedded/os_apple_embedded.*` (iOS uses the Unix drivers), `platform/android/os_android.cpp` (`ACCESS_USERDATA` is `DirAccessUnix`, `ACCESS_FILESYSTEM` is `DirAccessJAndroid`), and the Android Java files `FilesystemDirectoryAccess.kt`, `FileAccessHandler.kt`, `DataAccess.kt` and `FileData.kt` (`File.renameTo`).
