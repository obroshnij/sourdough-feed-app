# MVP scope

Owner: director. Consolidated from the Phase 1 docs on 2026-11-26. This is the contract for Phases 2 to 4. If another doc disagrees with this page, this page wins until that doc is fixed.

## The MVP in one paragraph

One living starter, in one beautiful jar, in one kitchen. The player looks at it, smells it, inspects it, feeds it and chooses where it lives. It runs on the real clock: coming back plays a short time-lapse of what happened and a few lines about it. Hunger, hooch and cold are always fixable. Mold, after days of visible warnings, is the only loss. English only, fully offline, no monetization.

## Vertical slice (Phase 3): the brief's 12 items

The definition of done is acceptance criteria AC-01 to AC-12 in [`test-plan.md`](test-plan.md).

| # | Item | What ships in the slice | Specs |
|---|---|---|---|
| 1 | A beautiful 3D jar | `classic_jar`, 84 × 170 mm, with the loose lid and rubber band, on the kitchen counter. Warm light and a contact shadow. Two-pass glass: Tier B on the Mobile renderer, Tier A on Compatibility. | [`art-direction.md`](art-direction.md), ADR-001 and ADR-002, D-023 |
| 2 | An animated starter | One starter shader driven by `VisualParams`: rise, dome or collapse, bubbles, hooch band, streaks on the liner, an idle "breathing" motion. All 11 states are readable. | [`starter-simulation-spec.md`](starter-simulation-spec.md), art-direction state table, ADR-003 |
| 3 | Rotate and zoom | One-finger orbit (yaw ±70°) with inertia, our own two-finger pinch, and double-tap to reset. | [`ux-design.md`](ux-design.md), [`architecture.md`](architecture.md) §9 |
| 4 | Starter lifecycle simulation | Sim spec v1: 60 s steps, 11 derived states, deterministic catch-up, and one random draw per feed. | sim spec, [`data-models.md`](data-models.md) |
| 5 | Feeding | The schedule question picks 1:1:1, 1:2:2 or 1:5:5. 150 g is kept, and the discard is shown in grams. `white_bread` and `whole_wheat`, at 100% hydration. Hooch can be poured off or stirred in. A tactile mix. Feed like last time takes 2 taps. | [`game-mechanics.md`](game-mechanics.md) §2, D-020 |
| 6 | Temperature control | Choose a place: `counter` 22 °C, `warm_spot` 26 °C, `fridge` 4 °C. The starter's own temperature follows the room over about 1.5 h. | D-018 |
| 7 | Smell | The nose button, a short moment (camera nudge, wisps), then a card with the descriptor and what it means. Descriptors come from the smell model, and variants are picked deterministically. | sim spec smell model, [`game-copy.md`](game-copy.md) |
| 8 | Condition display | A status pill (icon plus word, never color alone), one hint line, and the jar itself. Inspection kinds: `height`, `bubbles`, `surface`. | ux-design, game-copy, D-021 |
| 9 | Offline progression | Catch-up up to 14 days (then held), a time-lapse on return, and a summary of up to 3 lines. | architecture §5 and §6, D-024 |
| 10 | Contextual events (at least 5) | `first_rise`, `peaked_while_away` with `peak_now`, `hungry_again`, `hooch_forming`, `back_to_strength`, `warning_signs`. Plus `mold_found` and the memorial, reached through the debug time scale. | [`events-catalog.md`](events-catalog.md), D-017 |
| 11 | Save and load | Atomic saves with `save.prev`, quarantine for bad files, a quiet loader, and a versioned schema v1. | data-models, D-024 |
| 12 | A polished mobile UI | Themed components only, Figtree, safe areas, a contrast-checked palette (with a night variant), accessibility labels, reduce motion and text size settings. | ux-design, art-direction UI palette |

Also in the slice:
- **A new-game start:** M.'s note, the gifted young starter and the naming moment.
- **A minimal journal:** feeds, peaks, events and the memorial page.
- **A development overlay:** with the debug time scale.

## The rest of the MVP (Phase 4)

- **Guided onboarding** (beats B1 to B8 in [`game-design.md`](game-design.md) §3), including the sped-up demo (architecture §5.5) and the skip path.
- **P1 content:**
  - all four flours
  - hydration presets of 60, 100 and 125%
  - `consistency` and `development` inspection
  - the `window_sill` and `proofing_box` places
  - the four traits and renaming
  - a richer journal
  - the remaining events: `first_acetone`, `off_to_nap`, `waking_up`, `fed_before_peak`, `warm_and_quick`, `big_bubble`, `getting_stretchy`, `trait_revealed`
- **The one opt-in "warning signs" notification** (D-025).
- **Polish:** audio, a small iOS haptics plugin, VFX, transitions, battery tuning.
- ~~**Godot 4.8** stable before any store release (D-012).~~ Superseded by D-055: we stay on Godot 4.7.2 and skip screen readers for now. iOS ships first (D-054).

## Not in the MVP

- Backend, accounts, cloud sync, analytics, multiplayer, ads, purchases.
- Other containers and covers (P2, D-019).
- Multiple starters, bread recipes, achievements, advanced customization (free gram steppers, flour mixes, no-discard feeding).
- A from-scratch starter, dried-starter backup, discard recipes.
- A pink or orange mold tint (D-026), and a left-handed mirrored layout.

## Rules that hold everywhere

These are already in `CLAUDE.md` and [`vision.md`](vision.md), repeated here because scope pressure tends to erode them:
- The jar never shows what the sim didn't produce.
- No randomness outside the one per-feed draw.
- Every string comes from the generated catalog. The copy checker blocks the build.
- Pink, orange and red appear only on a moldy starter. Mold copy always says discard, and never "safe" or "scrape".
- Status is never shown by color alone.
