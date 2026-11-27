# Sourdough

A cozy 3D virtual pet for iOS and Android. The player keeps a living sourdough starter happy in a glass jar. Godot 4.7.2, statically typed GDScript, Blender 5.3 assets exported as GLB. Fully offline, no backend.

> **The workspace `CLAUDE.md` one folder up (`/Users/dev/dev/sourdough-app/CLAUDE.md`) and `AGENTS.md` describe Kultura, a different app.** None of their rules, stack, commands or file paths apply to this repo. Ignore them here.

## Where things are

| Start here | What |
|---|---|
| [`docs/vision.md`](docs/vision.md) | Pillars, scope, canonical ids (states, actions, flours), file ownership, team process. Read before anything else. |
| [`docs/decisions.md`](docs/decisions.md) | Every product and technical decision, with status. |
| [`production/board.md`](production/board.md) | Who is doing what right now. |
| `.claude/agents/` | The studio's specialist agents and the shared team contract. |

**Status:** Phase 2 is merged into `main`. Phase 3 (the vertical slice) is code-complete on branch `phase-3-slice` and waiting for the user's play session and review. It adds the feed, place, smell and inspect flows, the 8 live event rules, the away summary and time-lapse, the journal, naming, the mold-to-restart flow, day and night lighting, the wider kitchen wall, and the F3 dev overlay for time travel. All 107 acceptance rows are covered, manual or waived (D-052). Phase 4 (polish and the rest of the MVP) is next. Start with [`docs/mvp-scope.md`](docs/mvp-scope.md), [`docs/roadmap.md`](docs/roadmap.md) and [`production/board.md`](production/board.md).

## Toolchain (verified 2026-11-26)

| Tool | Path | Version |
|---|---|---|
| Godot | `/Applications/Godot.app/Contents/MacOS/Godot` | 4.7.2.stable.official.ed1daf0bf |
| Blender | `/Applications/Blender.app/Contents/MacOS/Blender` | 5.3.0 |
| Xcode | `/Applications/Xcode.app` | 27.2, iPhone 17 Pro simulators |
| JDK | `/Applications/Android Studio.app/Contents/jbr/Contents/Home` | OpenJDK 21.0.10 |
| Android SDK | `~/Library/Android/sdk` | Missing platform 36, build-tools 36.1.0 and the NDK. Deferred to the Android phase (D-054) |
| ffmpeg | `/opt/homebrew/bin/ffmpeg` | 9.0.2. Needed by the audio lint (`art/audio/scripts/verify_audio.py`) and the Ogg room loops |

Godot 4.7.2 export templates are installed in `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`, checksum-verified against the official SHA512-SUMS (2026-11-26). The physical test phone is the user's iPhone 13 Pro (D-058), built and installed with `tools/build/export_ios_device.sh --run`. Numbers from it are labeled "iPhone 13 Pro (device)". Numbers from the Mac or simulators are estimates and must be labeled that way.

## Verified commands

Only commands that have actually been run go here.

```bash
/Applications/Godot.app/Contents/MacOS/Godot --version      # 4.7.2.stable.official.ed1daf0bf
/Applications/Blender.app/Contents/MacOS/Blender --version  # Blender 5.3.0

# Reference simulation: checks test vectors V1 to V21 against the spec (about 3 s)
python3 -I tools/sim-reference/sim.py vectors   # ends "Checks: 269 run, 0 failed", exit 0; exit 1 on any miss (spec v1.1)

# Full test gate: imports first, runs every Godot test plus 5 lints; --strict fails on any skip (D-041).
# If Godot's first import crashes (an engine bug, test-plan §1), run.sh retries once and the RUN line says
# "import retried after signal N". Any phase-exit report must quote that note. A second crash fails the run.
tests/run.sh --strict   # "RESULT: 399 passed, 0 failed, 0 skipped" / "RUN: PASS" on a fresh clone (Phase 3 exit, 2f7645b; about 3.5 min)

# Copy checker (docs plus pending CSVs) and the catalog build
python3 -I tools/i18n/check_copy.py .              # 640 strings, "OK: ... pending CSVs", exit 0
python3 -I tools/i18n/build_catalog.py . --check   # "OK, up to date", exit 0 (drop --check to rebuild en.csv)

# Run the game windowed (desktop, 390x844 pt; F3 toggles the dev overlay).
# Import first after any pull or fresh clone: class_name types only resolve after an import,
# and a stale .godot/ cache gives "Identifier not declared" parse errors.
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --path . res://src/main/main.tscn   # Metal, Forward Mobile, 0 errors

# Builds (see tools/build/README.md): Android debug APK on a running emulator; iOS simulator is boot-check only
tools/build/export_android_debug.sh --run   # Android phase (D-054)
tools/build/export_ios_sim.sh --run          # boot check only; crashes in the GLES3 canvas renderer since Phase 3

# iPhone build, install and launch (D-058; signing from the keychain or tools/build/local.env, never committed).
# Phone unlocked and connected. "renderer: Metal 4.0 - Forward Mobile ... Apple A15 GPU", 0 script errors (2026-11-27)
tools/build/export_ios_device.sh --run
tools/build/export_ios_device.sh --verify   # unsigned build only, proves export and compile

# Jar GLB contract and triangle budgets: "PASS: contract nodes ..." and exit 0
python3 -I art/blender/scripts/verify_glb.py assets/3d/jar_v0.glb

# Rebuild the jar .blend, GLB and preview renders (about 100 s, run by art-director)
/Applications/Blender.app/Contents/MacOS/Blender -b -P art/blender/scripts/build_jar.py

# Kitchen wall contract (D-049): "PASS: kitchen wall node ..." and exit 0
python3 -I art/blender/scripts/verify_glb.py assets/3d/kitchen_wall.glb

# Rebuild the kitchen wall GLB, day and night textures and check sheet (about 60 s, run by art-director).
# Ends with a ray coverage check over the whole orbit: 0 misses within the limits.
/Applications/Blender.app/Contents/MacOS/Blender -b -P art/blender/scripts/bake_kitchen_wall.py
```

## Hard rules

1. **The simulation is pure.** `src/sim/` never touches Nodes, scenes or engine singletons (`Time`, `OS`, global `randi()`). Time arrives as arguments, randomness from a seeded `RandomNumberGenerator` passed in. Same inputs, same outputs.
2. **The jar never shows what the sim didn't produce.** Visuals come from `VisualMapper.from_state()`. Smell and inspection text come from the state, never from an unrelated random pick.
3. **Every player-facing string goes through `tr()`** with a key in `src/i18n/`. No literal text in scenes or scripts.
4. **Static typing everywhere.** Untyped declarations are errors.
5. **Never present potentially unsafe starter as safe.** Fuzzy growth of any color, or pink, orange or red streaks, means discard. See `docs/sourdough-science.md`.
6. **Offline only.** No network calls, accounts or analytics.
7. **Status is never shown by color alone.** Always an icon and a word too.
8. **Write only the files you own** (ownership map in `docs/vision.md`). Ask the owner to change anything else.
9. **Don't claim it works without running it.** Say what you ran and what you saw.
10. **Public repo.** No secrets, signing keys, keystores, provisioning profiles or personal data, ever.
11. **Writing style** for docs, comments and copy: plain language, American spelling, no em dashes.

## Git

- `main` holds the reviewed state. Each phase works on its own branch (`phase-1-design`, then `phase-2-foundation`, and so on), pushed to `origin`.
- Committing and pushing is approved. Merging a phase branch waits for the user's review.
- Commit `.import` and `.uid` files. Ignore only `.godot/`.
