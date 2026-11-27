# Production board

Owner: director (the only writer). Teammates report by message. Last updated 2026-11-27.

## Phase 3 exit (branch `phase-3-slice`, 2f7645b): code done, waiting for the user's play session

| Exit criterion (D-046) | Result |
|---|---|
| `tests/run.sh --strict` green on a fresh clone | 399 passed, 0 failed, 0 skipped, 5 lints passed. No import retry. Clean `git status` after import |
| AC-01 to AC-12 | 107 rows: 88 covered by tests, 11 manual only (MAN-S0 to S5), 8 waived to Phase 4 or 5 (D-052), 0 open |
| Budgets (Mac estimates, D-004) | 14-day catch-up 225.8 ms against 250 ms (PERF-03). Save write 5.45 ms against 10 ms (PERF-04). save.json about 104.6 KB flat to day 365, against 128 KB |
| Reference model | 243 of 243 checks. DIFF-01 golden traces pass |
| Look | Day and night signed off by art on Mobile A, Mobile B and Compatibility A. Probe 326 of 328 (2 granted). Kitchen wall: 0 sky pixels over the whole orbit |
| Mac windowed run | Metal, Forward Mobile, 0 errors |
| Android emulator run | Blocked: Godot's editor setting `export/android/java_sdk_path` is empty on this Mac. Waiting on the user |
| The user plays the build | Waiting on the user |

## Phase 2: foundation (branch `phase-2-foundation`): merged into `main` (PR #1)

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

## Phase 3: vertical slice (branch `phase-3-slice`): how it ran (D-046)

| Step | Owner | Status |
|---|---|---|
| Contracts commit: actions, events, return summary, time-lapse feed, journal API, new game and naming, night fade, settings fields, stable `project.godot` | `t1-sim-core` | done (131b3fe, time-lapse Bus signals 364baea) |
| Slice event rules: `first_rise`, `peaked_while_away` and `peak_now`, `hungry_again`, `hooch_forming`, `back_to_strength`, `warning_signs`, `mold_found` (D-032 T4 split, D-048) | `t4-events` | done (e4fd38c, 44 tests) |
| Wider kitchen wall for the whole ±70° orbit (D-049) | `art-director` | done (76595bf). Wall shape waits on the user |
| AC harness, traceability (107 rows), play-session checklists MAN-S0 to S5, import retry | `qa-engineer` | done (3aca626) |
| Rules wired, catch-up 230 ms with 8 rules and on a worker thread (D-050), F3 dev overlay | `t1-sim-core` | done (6bacb19) |
| Easing, breathing, bubble pops, feed and smell visuals | `t2-view` | done (ef6fcf6) |
| Kitchen wall and its `.import` files, inspection and mold cameras, time-lapse, day and night light, R12 and R13, performance | `t2-view` | done (111f37b, night re-tune dc5fb52) |
| Feed, place, smell and inspect sheets, event cards, away summary, journal, naming, moldy locks, restart (D-047), settings, 411×914 profile, flaky sheet test | `t3-ui` | done (148528c, be769de, edc9d50) |
| Architecture and data-model docs brought up to date | `tech-architect` | done |
| Test backfill for the 40 buildable AC rows, save-size fix (SAVE-13) | T1, T2, T3, QA | done (9551f26, bd88864, b057af3, 24e9b74) |
| Exit: AC-01 to AC-12 green under `--strict` on a fresh clone, and the user plays on the Mac and the Android emulator | director | |

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

## Phase 4 follow-ups raised in Phase 3

| Item | Owner |
|---|---|
| Commit the discard at "Discard", make the empty jar a real state, start the new starter in its own step (D-047 caveat) | T1, tech-architect, QA |
| OD-22: many quick place moves write one journal line each. Merge them? | game-designer, T1 |
| OD-23: freeze the first save-migration fixture from the build the user plays at the Phase 3 exit | QA |
| "Try inspecting the surface" for an ambiguous smell (ux §9): define a computable ambiguity rule first, since the docs disagree. The keys `SMELL_TRY_INSPECT` and `_BTN` are in the catalog, unused | scientist, then T1 and T3 |
| Feed sheet on 390×844: flour chips, discard line and forecast sit below the fold. Compact the rows? Sparse note and memorial pages | ux, T3 |
| Inspect meanings also fade after 3 views (mechanics §5): give the inspect sheet its own "What it means" button (reuse `SMELL_MEANING_BTN`) | T3 |
| Forecast as the status hint: how long it lasts (today only while `freshly_fed`), and `FORECAST_LINE` reaching 44 characters in the 34-character hint slot (it wraps) | ux, narrative, T3 |
| Copy and UX review of T1's choices: the schedule fit line, the `{window}` midpoint and OVERNIGHT, time-lapse length, the away summary moment rows | narrative, ux |
| "6 ObjectDB instances were leaked at exit" on every gate run (unchanged since Phase 2) | T1, QA |
| "Unicode parsing error ... Unexpected NUL character" on every fresh import. No tracked text file holds a NUL byte | QA |

## Waiting on the user

- Play the Phase 3 build (MAN-S0 to S5 in test-plan §6), then review `phase-3-slice` for merging.
- Android emulator run: Godot's editor setting `export/android/java_sdk_path` is empty on this Mac. Set it to Android Studio's JDK, or skip the emulator run.
- The kitchen wall shape: keep the curved sweep, or a straight backsplash with side walls (D-049).
- Before Phase 5: the bundle id and Apple Team ID, and whether to download the Metal Toolchain (about 0.7 GB, unverified) for iOS shader baking.

## Later phases

| Phase | Status |
|---|---|
| 3. Vertical slice | Code done, waiting for the user's play session |
| 4. Polish and the rest of the MVP | |
| 5. Mobile validation | |
