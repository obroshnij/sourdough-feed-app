# Production board

Owner: director (the only writer). Teammates report by message. Last updated 2026-11-26.

## Phase 2: foundation (branch `phase-2-foundation`): done, waiting for the user's review

| Exit criterion (roadmap) | Result |
|---|---|
| `tests/run.sh --strict` green | 179 passed, 0 failed, 0 skipped, 4 lints passed, on two fresh clones |
| Sim matches the reference model | DIFF-01: 24 of 24 traces at 1e-9. V1 to V20 pass. 243 reference checks pass |
| Save, load and catch-up proven by tests | Lossless hex floats (D-040), quarantine, quiet loader, clock re-anchor, 14-day hold. A 14-day catch-up takes 206 ms (Mac estimate) |
| The jar renders every state on the Mac in both renderers | 99 captures. 154 of 156 look rows pass, and the 2 misses were granted as tolerances |
| Starter look signed off by art | Yes, on Mobile A, Mobile B and Compatibility A (D-037, art-direction §16.6) |
| Rendering on the iOS simulator | Replaced by D-044. The simulator can't render this project. Android emulator renders; iOS boot check only; real iPhone in Phase 5 |
| No file written by two tracks | Held. Stray doc edits in worktrees were moved by the director |

| Track | Owner | Result |
|---|---|---|
| T1 sim and core | `t1-sim-core` | Contracts, sim, clock, saves, catch-up, event engine skeleton, journal copy |
| T2 view | `t2-view` | Jar scene, starter shader, glass tiers, camera, kitchen set, look probe |
| T3 UI | `t3-ui` | Theme, components, HUD shell, settings, 26 layout tests |
| QA | `qa-engineer` | Runner and self-tests, lints, golden traces, save and clock suites |
| Narrative | `narrative-designer` | 640-string catalog, build and safety checker (pending CSVs too) |
| Art | `art-director` | Masks, reference board, 47 icons, kitchen set, sign-off |
| Toolchain | `t1-toolchain` | Android export works end to end. iOS simulator is boot-only (D-044) |

## Phase 3 backlog (vertical slice), carried from Phase 2

| Item | Owner |
|---|---|
| Event rules: the 6 slice events plus `mold_found`, the return summary, the time-lapse | T1, T2, T3 |
| Feed, environment, smell and inspect flows wired through `Session.apply()` | T1, T3 |
| Moldy locks (Feed, Smell, Place) with reasons, and the discard card (D-043) | T3 |
| Settings save through `Session.save_settings()`, journal rendering through `Keys.format()` | T3 |
| Environment sheet at 45% height. Emit `jar_region_changed` when a sheet opens and closes | T3 |
| One shared night-fade function used by lighting and the palette | T1, then T2 and T3 |
| Evening lighting presets and live `VisualParams` easing | T2 |
| Keep the bubbles inspection camera at or above the rim (pointed-cap view) | T2, UX |
| A wider, curved backdrop for yaw beyond ±15° | Art, then T2 |
| SettingsStore fields for haptics and "keep messages" | T1 |
| Use or remove `JOURNAL_LOG_HOOCH_POURED` and `_STIRRED`; fix the stale `FlourProfile` test reference | T1 |
| Catch-up budget check once event rules exist (206 of 250 ms today) | T1, QA |
| Look probe rows R12 and R13; the 411×914 Android profile in the layout test | T2, T3, QA |
| A flaky test seen once: `test_sheets.gd::test_every_sheet_fits_at_every_size` on 360×640 at 125% | T3, QA |
| Performance re-measure after the shader and texture changes (Mac estimates) | T2 |

## Waiting on the user

- Review Phase 2, then approve Phase 3.
- Before Phase 5: the bundle id and Apple Team ID, and whether to download the Metal Toolchain (about 0.7 GB, unverified) for iOS shader baking.
- Machine note: Godot's editor setting `export/android/java_sdk_path` now points to Android Studio's JDK (set during the toolchain dry run). Set it back to empty to undo.

## Later phases

| Phase | Status |
|---|---|
| 3. Vertical slice | Waiting for approval |
| 4. Polish and the rest of the MVP | |
| 5. Mobile validation | |
