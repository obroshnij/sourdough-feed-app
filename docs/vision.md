# Sourdough: vision and team contract

Owner: director. Every other doc builds on this one. If something here looks wrong, raise it in your report or with the owner of the related doc. Don't work around it.

## The game in one line

Keep a living sourdough starter happy in a beautiful glass jar. Watch it rise, smell it, feed it, and learn to read it.

## Pillars

1. **Alive in the jar.** The starter breathes, rises, bubbles and settles on the real clock. The jar is worth looking at even when nothing is happening.
2. **Observe, understand, act.** Players learn by looking and smelling, not by reading meters. Every sign on screen comes from the simulation.
3. **Gentle real time.** A few minutes a day is enough. Normal life (work, sleep, a day away) never ruins the starter.
4. **Honest science.** Inspired by real fermentation and never wrong about safety. A player who finishes the game could keep a real starter.

## Audience and feel

- Adults who enjoy cozy games, baking, or both. Many are new to sourdough. Some are experienced bakers who will notice mistakes.
- Typical play: one to three check-ins a day of one to five minutes, plus a longer feeding session.
- Assume some players are older, low-vision or less tech-fluent. Portrait, one-handed play.
- Tone: warm, charming, slightly humorous, sometimes playful. Never childish. The starter's personality shows through its behavior and the game's narrator voice. **It has no face, no eyes and no speech bubbles.**
- Premium and calm. No dashboards on the main screen, no flashing alerts, no guilt.

## Decisions already made

Full log with reasons: [`decisions.md`](decisions.md).

| Decision | Source |
|---|---|
| Godot 4.7.2, statically typed GDScript, Blender assets as GLB. Brand-new project, nothing carried over from earlier prototypes. | User |
| **Mold is the only loss.** Hunger, hooch and sharp smells are always fixable by feeding. Mold appears only after several days unfed at room temperature, after warnings the player could have seen. The game then says to discard it, and the starter gets a journal memorial. | User |
| **English only** for the MVP. Every string goes through `tr()` keys from day one. | User |
| **No physical test phone yet.** Mac and simulator numbers are estimates and labeled as such. | User |
| No monetization in the MVP. Never ads, energy meters or paying to skip waiting. | Director |
| Real-time 1:1 clock. Leniency comes from realistic science, not from forgiveness timers. | Director |
| Push notifications come after the vertical slice. Events are shown when the player returns. | Director |

## Scope

Consolidated after Phase 1. Details are in [`mvp-scope.md`](mvp-scope.md) and decisions D-017 to D-025.

| Priority | Features |
|---|---|
| **P0** (must be excellent) | Beautiful central 3D starter, starter simulation, feeding, temperature (by place), smell, inspection (`height`, `bubbles`, `surface`), offline progression, core UI, **the 6 slice events, and a minimal journal with the memorial** (moved up from P1, D-017) |
| **P1** (in the MVP if P0 quality holds) | Starter personality (traits), all 4 flours, hydration presets, `consistency` and `development` inspection, `window_sill` and `proofing_box`, a richer journal, more events |
| **Before any store release** | One opt-in "warning signs" notification (D-025). Godot 4.8 for screen readers (D-012). |
| **P2** (later) | Multiple starters, bread recipes, achievements, advanced customization, **other containers and covers** (moved down from P1, D-019), more environments |
| **Not in the MVP** | Backend, accounts, cloud sync, multiplayer, ads, purchases |

**Vertical slice (Phase 3 target):**
1. A beautiful 3D jar.
2. An animated starter.
3. Rotate and zoom.
4. Starter lifecycle simulation.
5. Feeding interaction.
6. Temperature control.
7. Smell interaction.
8. Starter condition display.
9. Offline progression.
10. At least five contextual events.
11. Save and load.
12. A polished mobile UI.

## Canonical vocabulary

Use these ids exactly, in docs and later in code. Need a new id? Ask the director. Display names are working names; the narrative designer owns final copy.

### Starter states

States are **labels derived from continuous sim variables**, not separate models. The scientist defines how each is derived and which wins when two apply (for example, `recovering` can overlap a rise phase).

| id | Working name | Meaning |
|---|---|---|
| `freshly_fed` | Freshly fed | Just fed. Flat, smooth, smells of wet flour. |
| `developing` | Developing | First bubbles, starting to rise. |
| `active` | Active | Rising steadily, lots of bubbles. |
| `near_peak` | Near peak | Rise slowing, dome forming. |
| `at_peak` | At peak | Tallest and domed. Best moment to use it. |
| `collapsing` | Collapsing | The dome falls and leaves streaks on the glass. |
| `hungry` | Hungry | Food used up. Sour or acetone smell, maybe hooch. |
| `dormant` | Dormant | Barely active: cold (fridge) or long neglected. |
| `recovering` | Recovering | Regaining strength after neglect or cold. |
| `unhealthy` | Unhealthy | Warning signs: off smells, sluggish for days, contamination risk rising. |
| `moldy` | Moldy (end state) | Visible mold. Must be discarded. The only way to lose. |

### Actions (bottom bar, left to right)

`feed`, `smell`, `inspect`, `environment`, `journal`

### Feeding inputs

- `discard`: how much starter to keep before feeding.
- `flour`: which flour, or a mix.
- `ratio`: starter : flour : water by weight, for example 1:1:1 or 1:5:5.
- `hydration`: water ÷ flour × 100.

### Flours

`white_bread`, `whole_wheat`, `rye`, `spelt`

### Environment

- `temperature` in °C internally. The player sets it by choosing a `location` (D-018).
- `humidity` in %. A fixed property of each location, not a player control (D-018).
- `location`: `counter`, `warm_spot`, `fridge` (MVP); `window_sill`, `proofing_box` (P1).
- `container`: `classic_jar` (the only one in the MVP); `wide_mouth_jar`, `ceramic_crock`, `fermentation_vessel` (P2).
- `cover`: `loose_lid` (fixed in the MVP); `cloth`, `tight_lid` (P2).

### Maturity stages and traits (D-022)

- Maturity: `young`, `steady`, `mature`, `seasoned`. It never goes down.
- Traits (P1, wording only): `patient`, `energetic`, `sensitive`, `resilient`.

### Inspection kinds

`bubbles`, `consistency`, `height`, `surface`, `development`

### Smell descriptors

This is a seed list; the scientist finalizes it in the sim spec:
- `wet_flour`
- `mildly_fruity`
- `fresh_yeasty`
- `yogurt`
- `pleasantly_tangy`
- `strongly_acidic`
- `alcohol`
- `acetone`
- `cheesy`, for a young starter
- `musty`, a warning sign

### Event urgency tiers

`info`, `nudge`, `attention` (the designer defines the rules).

### Units

Grams, °C and seconds in code and data. The UI may show hours, and °F later.

## Time and leniency principles

- The real-world clock runs 1:1. Development builds have a debug time scale, and the tutorial may run sped up. Normal play never does.
- Offline progress is computed on return, deterministically, and summarized ("while you were away").
- A starter fed once or twice a day at room temperature thrives.
- A day away means hungry, hooch and sharp smells. One or two feeds bring it back.
- The fridge slows it to near dormant for weeks. Waking it takes a feed or two.
- Mold needs several days unfed at room temperature, plus warnings the player could have seen. Nothing else is a loss.
- Events are contextual, rare and mostly not urgent. Never more than one `attention` event waiting at a time. There are quiet hours.
- No streaks that punish, no timers that cost money, no fear of missing out.

## Safety rules (non-negotiable)

- Fuzzy growth of any color, or pink, orange or red streaks or tint, means **discard**. Never "scrape it off and carry on".
- Hooch, acetone or alcohol smells and gray liquid on top are normal signs of hunger, not danger. The game must not scare players about them.
- Copy never tells players that a starter showing contamination signs is safe to use or eat.
- Science claims come only from `sourdough-science.md`, which cites sources and marks anything uncertain.
- Sourdough is food, not medicine. The game gives no health or medical advice.

## Look and feel seeds

The art director and UX designer own the details.

- Modern, premium, cozy and tactile.
- Warm natural light, soft shadows, beautiful glass.
- Cream, beige, warm brown and muted green.
- The starter looks creamy, soft and appealing, never gross.
- Main screen: the jar dominates. The top holds the name, the status (icon plus word, never color alone) and settings. The bottom holds the five actions, in the thumb zone.

## Technical guardrails

The architect owns the details in `architecture.md` and `technical-decisions.md`.

- Godot 4.7.2 with typed GDScript. The Mobile renderer, plus a lighter Compatibility tier, which Android falls back to on its own.
- Everything inside the glass is opaque. The glass is drawn in two passes in a fixed order: back faces, then front.
- The starter is shaped by one shader fed by `VisualMapper` values, not by swapping models.
- A pure, deterministic sim in `src/sim/`.
- Atomic JSON saves.
- A custom headless test runner.
- All strings go through `tr()`.

## Team, ownership and reviews

Only the owner writes a file. Everyone may read everything.

| Agent | Owns | Reviews in wave B |
|---|---|---|
| director (main session) | `CLAUDE.md`, `docs/vision.md`, `docs/mvp-scope.md`, `docs/roadmap.md`, `docs/decisions.md`, `production/**`, `.claude/**` | Everything, and settles disagreements |
| `game-designer` | `docs/game-design.md`, `docs/game-mechanics.md`, `docs/progression.md` | Simulation spec, events catalog |
| `sourdough-scientist` | `docs/sourdough-science.md`, `docs/starter-simulation-spec.md`, `tools/sim-reference/**` (the reference model the golden tests compare against) | Mechanics, events catalog, game copy (accuracy and safety) |
| `narrative-designer` | `docs/narrative.md`, `docs/events-catalog.md`, `docs/game-copy.md`; from Phase 2, `tools/i18n/**` and the generated `src/i18n/en.csv` (D-028) | UX design (copy fit, tone) |
| `art-director` | `docs/art-direction.md`, `art/**`, `assets/3d/**`, `assets/textures/**`, `assets/icons/**` | UX design (visual fit) |
| `tech-architect` | `docs/architecture.md`, `docs/data-models.md`, `docs/technical-decisions.md` | Simulation spec (implementability), test plan |
| `godot-developer` | `spikes/**` in Phase 1. From Phase 2, the code tracks in `architecture.md` §14 (D-032). | Architecture |
| `ux-designer` | `docs/ux-design.md` | Art direction (contrast, legibility), mechanics (flows) |
| `qa-engineer` | `docs/test-plan.md` | Simulation spec, mechanics, architecture (testability) |

## How we work

1. **Wave A:** everyone writes their deliverables in parallel.
   - The scientist sends a first-draft state table and variable list to the whole team early.
   - Anyone who unblocks someone tells them right away with `SendMessage`, addressing teammates by agent name.
2. **Wave B:** reviewers read their assigned docs and send concrete findings (section, problem, fix) to the owner and the director. Owners revise.
3. **Consolidation:** the director writes the MVP scope, the roadmap and the decision log, and checks the docs agree with each other.
4. Disagreements go to the director with both positions and a recommendation. Decisions land in `decisions.md`.
5. Every agent's final message is a report: **Completed**, **Open decisions**, **Blockers**, **Disagreements**.
