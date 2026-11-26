# Decision log

Owner: director. One row per decision, newest last.

Status values:
- **accepted**: settled.
- **proposed**: our current bet, waiting for evidence such as a spike or a review.
- **superseded**: replaced by a later decision, which is named.

| ID | Date | Decision | Why | Status |
|---|---|---|---|---|
| D-001 | 2026-11-26 | Brand-new project in Godot 4.7.2 with statically typed GDScript and Blender 5.3 GLB assets. Nothing is carried over from earlier prototypes. | User brief and instruction. | accepted |
| D-002 | 2026-11-26 | Mold is the only loss. Everything else is recoverable by feeding. Mold needs several days unfed at room temperature, with warnings first. The game says to discard it and keeps a journal memorial. | User decision. Matches real-world safety advice and keeps the game gentle. | accepted |
| D-003 | 2026-11-26 | English only for the MVP. Every player-facing string goes through `tr()` keys. | User decision. Localization stays cheap later. | accepted |
| D-004 | 2026-11-26 | No physical test phone yet. Use the Mac and simulators, and label performance numbers as estimates. | User decision. | accepted |
| D-005 | 2026-11-26 | No monetization in the MVP. Never ads, energy meters or paying to skip waiting. | The cozy, non-manipulative pillar. Pricing gets revisited after the vertical slice. | accepted |
| D-006 | 2026-11-26 | A real-time 1:1 clock. Leniency comes from realistic science, not from forgiveness timers. | Brief. Real starters are already forgiving, and the fridge pauses them. | accepted |
| D-007 | 2026-11-26 | Local notifications come after the vertical slice, using `godot-notification-scheduler` (MIT) behind a small `Notifier` wrapper. | Godot 4.7.2 has no notification API. The wrapper protects us from a single-maintainer plugin. | proposed |
| D-008 | 2026-11-26 | Mobile renderer, plus a lighter visual tier for Compatibility. | Mobile has blurred refraction and 10-bit color. Android falls back to Compatibility on its own, so both paths ship anyway. | proposed (Phase 1 spike) |
| D-009 | 2026-11-26 | Everything inside the glass is opaque. The glass is drawn back faces first, then front faces. Tier A uses fresnel and a cubemap; Tier B (Mobile only) adds screen-texture refraction. | Godot sorts transparent objects by origin, so things inside the jar would flicker in draw order. | proposed (Phase 1 spike) |
| D-010 | 2026-11-26 | The starter is shaped by one shader with uniforms from `VisualMapper`. Shape keys are used only for hand-made hero shapes. | Blend shapes cost a compute pass on Mobile, and 4.7 has a reported normals bug. | proposed (Phase 1 spike) |
| D-011 | 2026-11-26 | A custom headless test runner, with no test framework dependency. | The sim is pure and easy to test, and we avoid dependencies. GUT is the fallback if we need mocks. | proposed |
| D-012 | 2026-11-26 | Move to Godot 4.8 stable before any store release. | 4.7.2 has no VoiceOver or TalkBack. 4.8 adds both. | accepted |
| D-013 | 2026-11-26 | Saves are written to `save.tmp`, then renamed over the real file, with `save.prev`, a version and a checksum. Elapsed time is measured from the latest clock time ever seen. Catch-up is capped at 14 days. | Godot's safe save only works in the editor. Turning the clock back must never rewind or double-count. | proposed |
| D-014 | 2026-11-26 | Git: the scaffold goes on `main`, each phase gets its own pushed branch, and merging waits for the user's review. | The user approved committing and pushing. | accepted |
| D-015 | 2026-11-26 | Commit `.import` and `.uid` files. Ignore only `.godot/`. | Godot's version-control guidance. This corrects a note in the studio plan. | accepted |
| D-016 | 2026-11-26 | The iOS simulator check of the jar spike moves to Phase 2. | Exporting needs the 1,281 MB export templates, which wait for the user's OK. In Phase 1, the Mac running `--rendering-method gl_compatibility` stands in. | accepted |
